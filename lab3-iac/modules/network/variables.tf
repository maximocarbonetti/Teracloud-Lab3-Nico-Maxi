# Inputs del modulo network

variable "project_name" {
  description = "Nombre del proyecto, se usa como prefijo en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones a usar (minimo 2 para alta disponibilidad)"
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Se necesitan al menos 2 AZs para alta disponibilidad."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las subnets publicas, uno por AZ, en el mismo orden que var.azs"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las subnets privadas, uno por AZ, en el mismo orden que var.azs"
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Si es true, crea un NAT Gateway para dar salida a internet a las subnets privadas. Necesario para que las instancias EC2 del cluster ECS descarguen imagenes y se registren."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Si es true, crea un unico NAT Gateway compartido entre todas las AZs (mas barato). Si es false, crea un NAT Gateway por AZ (mas resiliente, mas caro)."
  type        = bool
  default     = true
}

variable "extra_tags" {
  description = "Tags adicionales para todos los recursos de este modulo"
  type        = map(string)
  default     = {}
}
