# Inputs del modulo ecs-cluster

variable "cluster_name" {
  description = "Nombre del cluster ECS"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets donde corren las instancias EC2 del cluster (output del modulo network)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups para las instancias EC2 (ej: ecs_frontend_sg_id)"
  type        = list(string)
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para el cluster"
  type        = string
  default     = "t3.small"
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "desired_capacity" {
  type    = number
  default = 2
}

variable "key_name" {
  description = "Key pair para SSH a las instancias (opcional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
