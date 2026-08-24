# Inputs del modulo observability

variable "name_prefix" {
  type = string
}

variable "cluster_name" {
  description = "Nombre del cluster ECS (output del modulo ecs-cluster)"
  type        = string
}

variable "frontend_service_name" {
  description = "Nombre del servicio ECS del frontend (output del modulo ecs-service)"
  type        = string
}

variable "mysql_service_name" {
  description = "Nombre del servicio ECS de mysql (output del modulo ecs-service)"
  type        = string
}

variable "alb_arn" {
  description = "ARN del ALB (output del modulo alb)"
  type        = string
}

variable "target_group_arn" {
  description = "ARN del target group del frontend (output del modulo alb)"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN del topico SNS para las alarmas (output del modulo notifications)"
  type        = string
}

variable "cpu_alarm_threshold" {
  type    = number
  default = 80
}

variable "memory_alarm_threshold" {
  type    = number
  default = 80
}

variable "http_5xx_threshold" {
  description = "Cantidad de errores 5xx en 5 minutos que dispara la alarma"
  type        = number
  default     = 10
}

variable "tags" {
  type    = map(string)
  default = {}
}
