# Variables de este entorno (project_name, environment, region, cidrs, etc)

variable "project_name" {
  description = "Nombre del proyecto, se usa como prefijo en tags y nombres de recursos"
  type        = string
  default     = "lab3"
}

variable "environment" {
  description = "Ambiente"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Region de AWS donde se despliega la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "Availability Zones a usar"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "vpc_cidr" {
  description = "CIDR block de la VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las subnets publicas, una por AZ, mismo orden que var.azs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las subnets privadas, una por AZ, mismo orden que var.azs"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "enable_nat_gateway" {
  description = "Si es true, crea NAT Gateway(s) para dar salida a internet a las subnets privadas"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Si es true, un solo NAT compartido (mas barato). Si es false, uno por AZ (mas resiliente)."
  type        = bool
  default     = true
}
