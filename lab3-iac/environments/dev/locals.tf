# Valores locales calculados (name_prefix, tags comunes, etc)

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Namespace privado de Cloud Map para service discovery de mysql.
  # Se calcula una sola vez y se usa tanto para el DB_HOST de ssm-parameters
  # como para el modulo ecs-service, para que ambos queden consistentes.
  private_dns_namespace_name = "${local.name_prefix}.local"
  mysql_dns_name             = "mysql.${local.private_dns_namespace_name}"
}
