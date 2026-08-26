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

variable "frontend_desired_count" {
  description = "Cantidad de tasks que deberia tener el frontend. La alarma de capacidad avisa si corren menos."
  type        = number
  default     = 2
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

variable "efs_file_system_id" {
  description = "ID del filesystem EFS (output del modulo efs), para las alarmas de la capa de datos"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN del topico SNS para las alarmas (output del modulo notifications)"
  type        = string
}

# ---- Umbrales (SLO) ----------------------------------------------------------
#
# Los defaults son los objetivos de nivel de servicio acordados para el entorno
# dev. Se exponen como variables para poder endurecerlos en produccion sin
# tocar el codigo del modulo.

variable "slo_error_rate_pct" {
  description = "Porcentaje maximo de peticiones con error 5xx admitido antes de alarmar. 1% = SLO de exito del 99%."
  type        = number
  default     = 1
}

variable "slo_latency_p99_seconds" {
  description = "Latencia maxima admitida para el percentil 99 de las peticiones, en segundos."
  type        = number
  default     = 2
}

variable "min_requests_for_error_rate" {
  description = "Peticiones minimas en el periodo para evaluar la tasa de error. Evita que 1 error sobre 2 visitas dispare una alarma del 50%."
  type        = number
  default     = 20
}

variable "cpu_alarm_threshold" {
  description = "Porcentaje de CPU sostenido que dispara la alarma de saturacion"
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Porcentaje de memoria sostenido que dispara la alarma de saturacion"
  type        = number
  default     = 80
}

variable "cluster_reservation_threshold" {
  description = "Porcentaje de capacidad del cluster reservada a partir del cual no entran nuevas tasks"
  type        = number
  default     = 85
}

variable "efs_burst_credit_threshold_bytes" {
  description = "Creditos de burst de EFS por debajo de los cuales la performance de la base se degrada. Default: 1 TiB."
  type        = number
  default     = 1099511627776
}

variable "tags" {
  type    = map(string)
  default = {}
}
