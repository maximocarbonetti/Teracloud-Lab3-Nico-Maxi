# Inputs del modulo acm

variable "domain_name" {
  description = "Dominio principal a certificar (ej: app.midominio.com)"
  type        = string
}

variable "subject_alternative_names" {
  description = "Dominios alternativos (SANs), ej: [\"www.midominio.com\"]"
  type        = list(string)
  default     = []
}

variable "zone_id" {
  description = "Route53 Hosted Zone ID para la validacion DNS (output del modulo dns)"
  type        = string
}

variable "tags" {
  description = "Tags para el certificado"
  type        = map(string)
  default     = {}
}
