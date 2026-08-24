# Inputs del modulo efs

variable "name" {
  description = "Nombre del filesystem EFS"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets (privadas) donde crear los mount targets, una por AZ (output del modulo network)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security groups para los mount targets (output efs_sg_id del modulo security-groups)"
  type        = list(string)
}

variable "access_point_path" {
  description = "Path dentro del EFS para el access point de datos de MySQL"
  type        = string
  default     = "/mysql"
}

variable "posix_uid" {
  description = "UID posix del access point (dueno de /mysql dentro del EFS)"
  type        = number
  default     = 999 # uid tipico del usuario mysql en la imagen oficial
}

variable "posix_gid" {
  description = "GID posix del access point"
  type        = number
  default     = 999
}

variable "tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
