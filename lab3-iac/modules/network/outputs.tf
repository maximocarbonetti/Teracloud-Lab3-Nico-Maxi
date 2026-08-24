# Outputs del modulo network

output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block de la VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subnets publicas (para el ALB)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas (para las instancias EC2 del cluster ECS)"
  value       = aws_subnet.private[*].id
}

output "azs" {
  description = "AZs usadas, en el mismo orden que las subnets"
  value       = var.azs
}

output "internet_gateway_id" {
  description = "ID del Internet Gateway"
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateway(s) creados (vacio si enable_nat_gateway = false)"
  value       = aws_nat_gateway.this[*].id
}

output "public_route_table_id" {
  description = "ID de la route table publica"
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "IDs de la(s) route table(s) privada(s)"
  value       = aws_route_table.private[*].id
}
