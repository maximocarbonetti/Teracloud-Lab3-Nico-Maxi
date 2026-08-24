# Inputs del modulo security-groups

variable "name_prefix" {
  description = "Prefijo para nombrar los security groups"
  type        = string
}

variable "vpc_id" {
  description = "VPC donde se crean los security groups (output del modulo network)"
  type        = string
}

variable "frontend_container_port" {
  description = "Puerto en el que escucha el contenedor del frontend"
  type        = number
  default     = 80
}

variable "mysql_port" {
  description = "Puerto de MySQL"
  type        = number
  default     = 3306
}

variable "allowed_http_cidrs" {
  description = "CIDRs permitidos para acceder al ALB por 80/443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
