# ==============================================================================
# VPC Principal
# ==============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "fargate-api-${var.environment}-vpc"
  }
}

# ==============================================================================
# Internet Gateway (IGW) - Saída e entrada para a Internet
# ==============================================================================
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "fargate-api-${var.environment}-igw"
  }
}

# ==============================================================================
# Subnets Públicas (distribuídas em 2 Zonas de Disponibilidade)
# ==============================================================================
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "fargate-api-${var.environment}-subnet-public-${var.availability_zones[count.index]}"
  }
}

# ==============================================================================
# Tabela de Rotas Pública e Rota para o Internet Gateway
# ==============================================================================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "fargate-api-${var.environment}-rt-public"
  }
}

# Associação das Subnets Públicas à Tabela de Rotas
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}