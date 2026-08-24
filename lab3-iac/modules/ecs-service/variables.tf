# Inputs del modulo ecs-service
#
# Crea las 2 tasks/services que pide el enunciado: frontend (2 tasks,
# detras del ALB) y mysql (1 task, con EFS). Launch type EC2, bridge
# networking (necesario para usar target_type "instance" en el ALB y
# puertos dinamicos en las instancias del cluster).

variable "name_prefix" {
  type = string
}

variable "cluster_id" {
  description = "ID del cluster ECS (output del modulo ecs-cluster)"
  type        = string
}

variable "cluster_name" {
  type = string
}

variable "capacity_provider_name" {
  description = "Capacity provider del cluster (output del modulo ecs-cluster)"
  type        = string
}

variable "vpc_id" {
  description = "VPC donde crear el namespace de service discovery"
  type        = string
}

variable "private_dns_namespace_name" {
  description = "Namespace privado de Cloud Map, ej: lab3.local -> mysql queda en mysql.lab3.local"
  type        = string
  default     = "lab3.local"
}

# ---- Frontend ----

variable "frontend_image" {
  description = "URI completa de la imagen en ECR, con tag (ej: <repo_url>:v1)"
  type        = string
}

variable "frontend_container_port" {
  type    = number
  default = 80
}

variable "frontend_cpu" {
  type    = number
  default = 256
}

variable "frontend_memory" {
  type    = number
  default = 512
}

variable "frontend_desired_count" {
  type    = number
  default = 2
}

variable "frontend_target_group_arn" {
  description = "Target group del ALB (output del modulo alb)"
  type        = string
}

variable "frontend_secrets" {
  description = "Map nombre_env_var => ARN de SSM parameter (output del modulo ssm-parameters)"
  type        = map(string)
  default     = {}
}

variable "frontend_environment" {
  description = "Variables de entorno planas (no secretas) para el frontend"
  type        = map(string)
  default     = {}
}

# ---- MySQL ----

variable "mysql_image" {
  type    = string
  default = "mysql:8.0"
}

variable "mysql_port" {
  type    = number
  default = 3306
}

variable "mysql_cpu" {
  type    = number
  default = 512
}

variable "mysql_memory" {
  type    = number
  default = 1024
}

variable "efs_file_system_id" {
  description = "Output file_system_id del modulo efs"
  type        = string
}

variable "efs_file_system_arn" {
  description = "Output file_system_arn del modulo efs (para el permiso IAM del task role)"
  type        = string
}

variable "efs_access_point_id" {
  description = "Output access_point_id del modulo efs"
  type        = string
}

variable "mysql_secrets" {
  description = "Map nombre_env_var => ARN de SSM parameter para la task de mysql"
  type        = map(string)
  default     = {}
}

variable "mysql_environment" {
  type    = map(string)
  default = {}
}

variable "log_retention_days" {
  type    = number
  default = 14
}

variable "tags" {
  type    = map(string)
  default = {}
}
