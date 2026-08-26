# Inputs del modulo ecr

variable "repository_name" {
  description = "Nombre del repositorio ECR"
  type        = string
}

variable "image_tag_mutability" {
  description = <<-EOT
    MUTABLE o IMMUTABLE.

    Usamos MUTABLE a proposito: el pipeline publica cada imagen con un tag
    versionado (el hash del commit) y ademas mueve el tag "latest" al ultimo
    build. Con IMMUTABLE, "latest" no se podria reescribir nunca y ademas
    fallaria cualquier re-ejecucion del pipeline sobre el mismo commit
    ("tag invalid: ... cannot be overwritten because the tag is immutable").
    El versionado real lo da el tag del commit, que nunca se reutiliza.
  EOT
  type        = string
  default     = "MUTABLE"
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
