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
# Subnets Privadas (onde os containers ECS Fargate vao rodar)
# ==============================================================================
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "fargate-api-${var.environment}-private-subnet-${count.index + 1}"
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

# ==============================================================================
# Elastic IP para o NAT Gateway
# ==============================================================================
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "fargate-api-${var.environment}-nat-eip"
  }
}

# ==============================================================================
# NAT Gateway (alocado em uma Subnet Pública)
# ==============================================================================
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "fargate-api-${var.environment}-nat-gw"
  }

  depends_on = [aws_internet_gateway.gw]
}

# ==============================================================================
# Tabela de Rotas Privada (Saída via NAT Gateway)
# ==============================================================================
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "fargate-api-${var.environment}-private-rt"
  }
}

# ==============================================================================
# Associação das Subnets Privadas com a Tabela de Rotas Privada
# ==============================================================================
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}