# Inputs del modulo ecr

variable "repository_name" {
  description = "Nombre del repositorio ECR"
  type        = string
}

variable "image_tag_mutability" {
  description = "MUTABLE o IMMUTABLE"
  type        = string
  default     = "IMMUTABLE"
}

variable "scan_on_push" {
  description = "Escanear vulnerabilidades al pushear una imagen"
  type        = bool
  default     = true
}

variable "max_image_count" {
  description = "Cantidad maxima de imagenes tageadas a retener (lifecycle policy)"
  type        = number
  default     = 10
}

variable "untagged_expire_days" {
  description = "Dias despues de los cuales se borran imagenes sin tag"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags para el repositorio"
  type        = map(string)
  default     = {}
}
