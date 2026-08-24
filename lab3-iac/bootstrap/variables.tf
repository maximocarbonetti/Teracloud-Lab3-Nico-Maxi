variable "aws_region" {
  description = "Region de AWS donde se crea el bucket de tfstate"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto (usado para nombrar el bucket y tagging)"
  type        = string
  default     = "lab3"
}

variable "environment" {
  description = "Entorno al que sirve este bootstrap (dev, staging, prod, etc)"
  type        = string
  default     = "dev"
}

variable "extra_tags" {
  description = "Tags adicionales para el bucket de tfstate"
  type        = map(string)
  default     = {}
}
