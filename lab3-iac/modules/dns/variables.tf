# Inputs del modulo dns

variable "zone_name" {
  description = "Nombre de la hosted zone (ej: midominio.com)"
  type        = string
}

variable "create_zone" {
  description = "true = crea una hosted zone nueva. false = usa una existente (data source)"
  type        = bool
  default     = false
}

variable "record_name" {
  description = "FQDN del registro a crear apuntando al ALB (ej: lab3.midominio.com)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name del ALB (output del modulo alb)"
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID del ALB (output del modulo alb)"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
