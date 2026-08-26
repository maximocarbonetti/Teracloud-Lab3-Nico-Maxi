# Recursos del modulo security-groups
#
# 4 security groups:
#   alb          -> internet (80/443)
#   ecs_frontend -> solo desde alb
#   ecs_mysql    -> solo desde ecs_frontend (3306)
#   efs          -> solo desde ecs_mysql (NFS 2049), el unico que monta el volumen

resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "ALB publico - HTTP/HTTPS desde internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })
}

resource "aws_security_group" "ecs_frontend" {
  name_prefix = "${var.name_prefix}-ecs-frontend-"
  description = "Tasks ECS del frontend - solo desde el ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Desde el ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-ecs-frontend-sg" })
}

resource "aws_security_group" "ecs_mysql" {
  name_prefix = "${var.name_prefix}-ecs-mysql-"
  description = "Task ECS de MySQL - solo desde el frontend"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL desde el frontend"
    from_port       = var.mysql_port
    to_port         = var.mysql_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_frontend.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-ecs-mysql-sg" })
}

resource "aws_security_group" "efs" {
  name_prefix = "${var.name_prefix}-efs-"
  description = "EFS - solo NFS desde la task de MySQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS desde MySQL"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_mysql.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-efs-sg" })
}
