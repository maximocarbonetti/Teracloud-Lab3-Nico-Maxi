# Inputs del modulo notifications

variable "name" {
  description = "Nombre del topico SNS"
  type        = string
}

variable "email_addresses" {
  description = "Emails a suscribir para recibir las notificaciones (pipeline + alarmas)"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
