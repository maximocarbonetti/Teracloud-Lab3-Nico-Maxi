# Instancia todos los modulos: network, security-groups, acm, ecr, ecs-cluster, ecs-service, alb, efs, dns, ssm-parameters, cicd, observability, notifications
#
# Estado actual: solo "network" esta implementado. El resto se va agregando
# a medida que cada modulo se completa (ver PLAN-FASES.md).

module "network" {
  source = "../../modules/network"

  project_name = var.project_name
  environment  = var.environment

  azs                   = var.azs
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  enable_nat_gateway    = var.enable_nat_gateway
  single_nat_gateway    = var.single_nat_gateway

  extra_tags = local.common_tags
}

# TODO: module "security-groups" (depende de module.network.vpc_id)
# TODO: module "acm"
# TODO: module "ecr"
# TODO: module "efs" (depende de vpc_id + subnets privadas + SG)
# TODO: module "alb" (depende de subnets publicas + SG)
# TODO: module "ecs-cluster" (depende de subnets privadas + SG + IAM)
# TODO: module "ecs-service" (depende de ecs-cluster + alb + efs + ssm-parameters)
# TODO: module "dns" (depende de alb)
# TODO: module "ssm-parameters"
# TODO: module "cicd" (depende de ecr + ecs-cluster/ecs-service)
# TODO: module "observability"
# TODO: module "notifications"
