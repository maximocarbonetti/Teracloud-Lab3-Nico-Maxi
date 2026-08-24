# Inputs del modulo alb

variable "name" {
  description = "Nombre del ALB"
  type        = string
}

variable "vpc_id" {
  description = "VPC donde vive el ALB"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets publicas para el ALB (output del modulo network)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups del ALB (output del modulo security-groups)"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ARN del certificado ACM validado, para el listener HTTPS"
  type        = string
}

variable "target_port" {
  description = "Puerto del contenedor frontend"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Path del health check del target group"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
