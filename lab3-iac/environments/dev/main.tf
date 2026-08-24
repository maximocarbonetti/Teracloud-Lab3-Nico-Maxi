# Instancia todos los modulos: network, security-groups, acm, ecr, ecs-cluster, ecs-service, alb, efs, dns, ssm-parameters, cicd, observability, notifications

module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  extra_tags           = local.common_tags
}

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix = local.name_prefix
  vpc_id      = module.network.vpc_id
  tags        = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name = "${local.name_prefix}-frontend"
  tags            = local.common_tags
}

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  cluster_name = "${local.name_prefix}-cluster"
  subnet_ids   = module.network.private_subnet_ids

  security_group_ids = [
    module.security_groups.ecs_frontend_sg_id,
    module.security_groups.ecs_mysql_sg_id,
  ]

  instance_type    = var.ecs_instance_type
  min_size         = var.ecs_min_size
  max_size         = var.ecs_max_size
  desired_capacity = var.ecs_desired_capacity
  key_name         = var.ec2_key_name
  tags             = local.common_tags
}

# dns crea/busca la hosted zone (para acm) y, ademas, el record final que
# apunta al ALB (por eso recibe alb_dns_name/alb_zone_id como input).
module "dns" {
  source = "../../modules/dns"

  zone_name    = var.domain_zone_name
  create_zone  = var.create_dns_zone
  record_name  = var.app_record_name
  alb_dns_name = module.alb.alb_dns_name
  alb_zone_id  = module.alb.alb_zone_id
  tags         = local.common_tags
}

module "acm" {
  source = "../../modules/acm"

  domain_name = var.app_record_name
  zone_id     = module.dns.zone_id
  tags        = local.common_tags
}

module "alb" {
  source = "../../modules/alb"

  name               = "${local.name_prefix}-alb"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.public_subnet_ids
  security_group_ids = [module.security_groups.alb_sg_id]
  certificate_arn    = module.acm.certificate_arn
  tags               = local.common_tags
}

module "efs" {
  source = "../../modules/efs"

  name               = "${local.name_prefix}-mysql-data"
  subnet_ids         = module.network.private_subnet_ids
  security_group_ids = [module.security_groups.efs_sg_id]
  tags               = local.common_tags
}

module "ssm_parameters" {
  source = "../../modules/ssm-parameters"

  path_prefix = "/${var.project_name}/${var.environment}"
  db_host     = local.mysql_dns_name
  db_name     = var.db_name
  db_user     = var.db_user
  db_password = var.db_password
  tags        = local.common_tags
}

module "ecs_service" {
  source = "../../modules/ecs-service"

  # El servicio del frontend se registra en el target group del ALB, pero ese
  # target group recien queda asociado a un load balancer cuando existe el
  # listener. Sin este depends_on, en un despliegue desde cero Terraform puede
  # crear el servicio antes que el listener y ECS rechaza el registro.
  depends_on = [module.alb]

  name_prefix                = local.name_prefix
  cluster_id                 = module.ecs_cluster.cluster_id
  cluster_name               = module.ecs_cluster.cluster_name
  vpc_id                     = module.network.vpc_id
  private_dns_namespace_name = local.private_dns_namespace_name

  frontend_image            = "${module.ecr.repository_url}:${var.frontend_image_tag}"
  frontend_target_group_arn = module.alb.frontend_target_group_arn

  frontend_secrets = {
    DB_HOST     = module.ssm_parameters.db_host_arn
    DB_PORT     = module.ssm_parameters.db_port_arn
    DB_NAME     = module.ssm_parameters.db_name_arn
    DB_USER     = module.ssm_parameters.db_user_arn
    DB_PASSWORD = module.ssm_parameters.db_password_arn
  }

  # La task de mysql usa awsvpc network mode (requisito del A record en Cloud
  # Map), asi que necesita sus propias subnets y security group para la ENI.
  mysql_subnet_ids         = module.network.private_subnet_ids
  mysql_security_group_ids = [module.security_groups.ecs_mysql_sg_id]

  efs_file_system_id  = module.efs.file_system_id
  efs_file_system_arn = module.efs.file_system_arn
  efs_access_point_id = module.efs.access_point_id

  mysql_secrets = {
    MYSQL_ROOT_PASSWORD = module.ssm_parameters.db_password_arn
    MYSQL_DATABASE      = module.ssm_parameters.db_name_arn
    MYSQL_USER          = module.ssm_parameters.db_user_arn
    MYSQL_PASSWORD      = module.ssm_parameters.db_password_arn
  }

  tags = local.common_tags
}

module "notifications" {
  source = "../../modules/notifications"

  name            = "${local.name_prefix}-notifications"
  email_addresses = var.notification_emails
  tags            = local.common_tags
}

module "observability" {
  source = "../../modules/observability"

  name_prefix           = local.name_prefix
  cluster_name          = module.ecs_cluster.cluster_name
  frontend_service_name = module.ecs_service.frontend_service_name
  mysql_service_name    = module.ecs_service.mysql_service_name
  alb_arn               = module.alb.alb_arn
  target_group_arn      = module.alb.frontend_target_group_arn
  sns_topic_arn         = module.notifications.topic_arn
  tags                  = local.common_tags
}

module "cicd" {
  source = "../../modules/cicd"

  name_prefix          = local.name_prefix
  github_repository_id = var.github_repository_id
  github_branch        = var.github_branch
  ecr_repository_url   = module.ecr.repository_url
  ecr_repository_arn   = module.ecr.repository_arn
  ecs_cluster_name     = module.ecs_cluster.cluster_name
  ecs_service_name     = module.ecs_service.frontend_service_name
  container_name       = "frontend"
  sns_topic_arn        = module.notifications.topic_arn
  tags                 = local.common_tags
}
