# Recursos del modulo network
#
# VPC + subnets publicas/privadas en N AZs + NAT Gateway(s) + route tables.
# Las subnets publicas alojan el ALB. Las privadas alojan las instancias EC2
# del cluster ECS (frontend y MySQL), que necesitan salida a internet via
# NAT para registrarse en el ECS agent y bajar imagenes de ECR.

locals {
  name = "${var.project_name}-${var.environment}"

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Module      = "network"
    },
    var.extra_tags
  )

  # Cuantos NAT Gateways crear: 1 si single_nat_gateway, uno por AZ si no.
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 0
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${local.name}-igw" })
}

# -----------------------------------------------------------------------------
# Subnets publicas (una por AZ)
# -----------------------------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-${var.azs[count.index]}"
    Tier = "public"
  })
}

# -----------------------------------------------------------------------------
# Subnets privadas (una por AZ)
# -----------------------------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.name}-private-${var.azs[count.index]}"
    Tier = "private"
  })
}

# -----------------------------------------------------------------------------
# NAT Gateway(s)
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = local.nat_gateway_count
  domain = "vpc"

  tags = merge(local.common_tags, { Name = "${local.name}-nat-eip-${count.index}" })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  # single_nat_gateway=true -> siempre en la primera subnet publica
  # single_nat_gateway=false -> un NAT por AZ, en su propia subnet publica
  subnet_id = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, { Name = "${local.name}-nat-${count.index}" })

  depends_on = [aws_internet_gateway.this]
}

# -----------------------------------------------------------------------------
# Route table publica (una sola, compartida por todas las subnets publicas)
# -----------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Route table(s) privada(s)
#
# Con single_nat_gateway=true: una sola route table privada, compartida,
# apuntando al unico NAT.
# Con single_nat_gateway=false: una route table por AZ, cada una apuntando
# a su propio NAT en la misma AZ (evita trafico cross-AZ).
# -----------------------------------------------------------------------------
resource "aws_route_table" "private" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.azs)) : 1

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
    }
  }

  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway ? "${local.name}-rt-private" : "${local.name}-rt-private-${var.azs[count.index]}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway || !var.enable_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}
