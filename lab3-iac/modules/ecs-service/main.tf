# Recursos del modulo ecs-service

locals {
  frontend_secrets_list = [for k, v in var.frontend_secrets : { name = k, valueFrom = v }]
  frontend_env_list     = [for k, v in var.frontend_environment : { name = k, value = v }]
  mysql_secrets_list    = [for k, v in var.mysql_secrets : { name = k, valueFrom = v }]
  mysql_env_list        = [for k, v in var.mysql_environment : { name = k, value = v }]

  all_secret_arns = concat(values(var.frontend_secrets), values(var.mysql_secrets))
}

# -----------------------------------------------------------------------------
# Service discovery (Cloud Map) - namespace privado para que el frontend
# resuelva "mysql.<namespace>" en vez de una IP fija.
# -----------------------------------------------------------------------------
resource "aws_service_discovery_private_dns_namespace" "this" {
  name = var.private_dns_namespace_name
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "mysql" {
  name = "mysql"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# -----------------------------------------------------------------------------
# IAM - execution role compartido (pull de ECR, logs, leer los SSM secrets)
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name_prefix        = "${var.name_prefix}-exec-"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_secrets" {
  count = length(local.all_secret_arns) > 0 ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameters"]
    resources = local.all_secret_arns
  }

  statement {
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"] # SecureString con la KMS key administrada por AWS (alias/aws/ssm)
  }
}

resource "aws_iam_role_policy" "read_secrets" {
  count  = length(local.all_secret_arns) > 0 ? 1 : 0
  name   = "${var.name_prefix}-read-ssm-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_secrets[0].json
}

# Task role de mysql: necesita permiso IAM explicito para montar el EFS
# (el access point se creo con autorizacion iam = ENABLED).
resource "aws_iam_role" "mysql_task" {
  name_prefix        = "${var.name_prefix}-mysql-task-"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "efs_access" {
  statement {
    effect    = "Allow"
    actions   = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
    resources = [var.efs_file_system_arn]
  }
}

resource "aws_iam_role_policy" "mysql_efs_access" {
  name   = "${var.name_prefix}-mysql-efs-access"
  role   = aws_iam_role.mysql_task.id
  policy = data.aws_iam_policy_document.efs_access.json
}

resource "aws_iam_role" "frontend_task" {
  name_prefix        = "${var.name_prefix}-frontend-task-"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
  tags               = var.tags
}

# -----------------------------------------------------------------------------
# Logs
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.name_prefix}-frontend"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "mysql" {
  name              = "/ecs/${var.name_prefix}-mysql"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# -----------------------------------------------------------------------------
# Frontend: task definition + service (2 tasks, detras del ALB)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.name_prefix}-frontend"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.frontend_task.arn

  container_definitions = jsonencode([
    {
      name      = "frontend"
      image     = var.frontend_image
      cpu       = var.frontend_cpu
      memory    = var.frontend_memory
      essential = true

      portMappings = [
        {
          containerPort = var.frontend_container_port
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      environment = local.frontend_env_list
      secrets     = local.frontend_secrets_list

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "frontend"
        }
      }
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.name_prefix}-frontend"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.frontend_desired_count

  load_balancer {
    target_group_arn = var.frontend_target_group_arn
    container_name    = "frontend"
    container_port    = var.frontend_container_port
  }

  # Reparte las tasks entre AZs y despues entre instancias, para alta disponibilidad
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  tags = var.tags
}

# -----------------------------------------------------------------------------
# MySQL: task definition + service (1 task, con volumen EFS persistente)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "mysql" {
  family                   = "${var.name_prefix}-mysql"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.mysql_task.arn

  volume {
    name = "mysql-data"

    efs_volume_configuration {
      file_system_id     = var.efs_file_system_id
      transit_encryption = "ENABLED"

      authorization_config {
        access_point_id = var.efs_access_point_id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "mysql"
      image     = var.mysql_image
      cpu       = var.mysql_cpu
      memory    = var.mysql_memory
      essential = true

      portMappings = [
        {
          containerPort = var.mysql_port
          hostPort      = 0
          protocol      = "tcp"
        }
      ]

      environment = local.mysql_env_list
      secrets     = local.mysql_secrets_list

      mountPoints = [
        {
          sourceVolume  = "mysql-data"
          containerPath = "/var/lib/mysql"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.mysql.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "mysql"
        }
      }
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "mysql" {
  name            = "${var.name_prefix}-mysql"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.mysql.arn
  desired_count   = 1

  service_registries {
    registry_arn   = aws_service_discovery_service.mysql.arn
    container_name = "mysql"
    container_port = var.mysql_port
  }

  # Una sola task: no hay problema de conflicto de puerto ni necesidad de spread
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  tags = var.tags
}

data "aws_region" "current" {}
