# Variables de este entorno (project_name, environment, region, cidrs, etc)

variable "project_name" {
  type    = string
  default = "lab3"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# ---- Red ----

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ---- ECS cluster (EC2) ----

variable "ecs_instance_type" {
  type    = string
  default = "t3.small"
}

variable "ecs_min_size" {
  type    = number
  default = 1
}

variable "ecs_max_size" {
  type    = number
  default = 3
}

variable "ecs_desired_capacity" {
  type    = number
  default = 2
}

variable "ec2_key_name" {
  description = "Key pair para SSH a las instancias del cluster (opcional)"
  type        = string
  default     = null
}

# ---- Imagen / ECR ----

variable "frontend_image_tag" {
  description = "Tag de la imagen del frontend a desplegar (el pipeline la actualiza despues)"
  type        = string
  default     = "latest"
}

# ---- DNS / ACM ----

variable "domain_zone_name" {
  description = "Hosted zone existente (ej: midominio.com)"
  type        = string
}

variable "create_dns_zone" {
  description = "true si hay que crear la hosted zone, false si ya existe"
  type        = bool
  default     = false
}

variable "app_record_name" {
  description = "FQDN de la app (ej: lab3.midominio.com)"
  type        = string
}

# ---- Base de datos ----

variable "db_name" {
  type    = string
  default = "app"
}

variable "db_user" {
  type    = string
  default = "app_user"
}

variable "db_password" {
  description = "Password de MySQL (root y de la app). No la pongan en tfvars versionado."
  type        = string
  sensitive   = true
}

variable "mysql_data_path" {
  description = <<-EOT
    Directorio dentro del EFS donde MySQL guarda sus datos.

    OJO: MySQL solo aplica MYSQL_USER / MYSQL_PASSWORD / MYSQL_ROOT_PASSWORD la
    primera vez que inicializa el datadir. Si se cambia la password despues de
    que la base ya existe, las credenciales viejas siguen vigentes adentro y el
    frontend falla con "Access denied for user". Cambiar este path a uno nuevo
    fuerza a MySQL a inicializarse de cero con las credenciales actuales
    (se pierden los datos que hubiera).
  EOT
  type        = string
  default     = "/mysql"
}

# ---- CI/CD ----

variable "github_repository_id" {
  description = "owner/repo del repo en GitHub"
  type        = string
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "enable_manual_approval" {
  description = "Exigir aprobacion manual entre el build y el despliegue al servicio ECS"
  type        = bool
  default     = true
}

# ---- Objetivos de nivel de servicio (SLO) ----

variable "slo_error_rate_pct" {
  description = "Porcentaje maximo de peticiones con error 5xx admitido. 1% equivale a un SLO de exito del 99%."
  type        = number
  default     = 1
}

variable "slo_latency_p99_seconds" {
  description = "Latencia maxima admitida para el percentil 99, en segundos."
  type        = number
  default     = 2
}

variable "frontend_desired_count" {
  description = "Cantidad de tasks del frontend. El enunciado exige 2."
  type        = number
  default     = 2
}

# ---- Notificaciones ----

variable "notification_emails" {
  description = "Emails que reciben el estado del pipeline y las alarmas"
  type        = list(string)
}
