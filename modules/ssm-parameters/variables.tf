# Inputs del modulo ssm-parameters

variable "path_prefix" {
  description = "Prefijo de path en Parameter Store, ej: /lab3/dev"
  type        = string
}

variable "db_host" {
  description = "Host/endpoint de conexion a MySQL (ej: mysql.lab3.local, del service discovery)"
  type        = string
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "db_name" {
  type    = string
  default = "app"
}

variable "db_user" {
  type = string
}

variable "db_password" {
  description = "Password de MySQL, se guarda como SecureString"
  type        = string
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
