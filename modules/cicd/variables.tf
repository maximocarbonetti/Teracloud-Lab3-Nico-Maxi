# Inputs del modulo cicd
#
# Pipeline: Source (GitHub via CodeStar Connection) -> Build (CodeBuild:
# docker build + push a ECR) -> Deploy (CodePipeline ECS deploy action,
# actualiza el servicio del frontend). Se dispara solo con push a main.

variable "name_prefix" {
  type = string
}

variable "github_repository_id" {
  description = "owner/repo del repositorio en GitHub (ej: maximocarbonetti/Teracloud-Lab3-Nico-Maxi)"
  type        = string
}

variable "github_branch" {
  type    = string
  default = "main"
}

variable "buildspec_path" {
  description = "Path del buildspec.yml dentro del repo"
  type        = string
  default     = "buildspec.yml"
}

variable "ecr_repository_url" {
  description = "Output repository_url del modulo ecr"
  type        = string
}

variable "ecr_repository_arn" {
  description = "Output repository_arn del modulo ecr"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Output cluster_name del modulo ecs-cluster"
  type        = string
}

variable "ecs_service_name" {
  description = "Output frontend_service_name del modulo ecs-service"
  type        = string
}

variable "container_name" {
  description = "Nombre del contenedor en la task definition del frontend (debe matchear ecs-service)"
  type        = string
  default     = "frontend"
}

variable "sns_topic_arn" {
  description = "Output topic_arn del modulo notifications, para notificar el estado del pipeline"
  type        = string
}

variable "enable_pipeline_notifications" {
  description = <<-EOT
    Crea la notification rule del pipeline. La primera vez que se crea una en
    una cuenta AWS nueva, el service-linked role de CodeStar Notifications
    puede tardar hasta 15 minutos en existir y el apply falla con
    "ConfigurationException: ... service-linked role ... might not yet exist".
    Si pasa eso: volver a correr el apply mas tarde, o poner esto en false
    para desbloquear el resto y activarlo despues.
  EOT
  type        = bool
  default     = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
