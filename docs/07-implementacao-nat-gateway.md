# Implementação do NAT Gateway e Isolamento Privado do ECS Fargate

Este documento regista as alterações de código efectuadas para transformar a infra-estrutura num modelo empresarial em camadas (*tier-3*), mantendo as tarefas do ECS Fargate 100% isoladas em subnets privadas com saída para a Internet gerida por NAT Gateway.

---

### Passo 1: Declaração das Subnets Privadas em terraform/variables.tf

No ficheiro variables.tf, foi adicionada a lista de blocos CIDR para provisionar as subnets privadas distribuídas em duas Zonas de Disponibilidade:

variable "private_subnet_cidrs" {
  description = "Blocos CIDR para as subnets privadas em 2 AZs"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

---

### Passo 2: Adição das Subnets Privadas, NAT Gateway e Rotas em terraform/vpc.tf

No ficheiro vpc.tf, foram adicionados os recursos necessários para criar as subnets privadas, o Elastic IP, o NAT Gateway alocado na subnet pública e a tabela de rotas com saída 0.0.0.0/0:

# ==============================================================================
# Subnets Privadas (onde os contentores ECS Fargate são executados)
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
# Elastic IP para o NAT Gateway
# ==============================================================================
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "fargate-api-${var.environment}-nat-eip"
  }
}

# ==============================================================================
# NAT Gateway (alocado na Subnet Pública 1)
# ==============================================================================
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "fargate-api-${var.environment}-nat-gw"
  }

  # Dependência explícita do Internet Gateway da VPC
  depends_on = [aws_internet_gateway.gw]
}

# ==============================================================================
# Tabela de Rotas Privada (Saída para Internet via NAT Gateway)
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

---

### Passo 3: Configuração de Rede do Serviço ECS em terraform/ecs.tf

No ficheiro ecs.tf, o bloco network_configuration do recurso aws_ecs_service.main foi configurado para apontar para as subnets privadas, desabilitando IP público directo no contentor:

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

---

### Passo 4: Validação Sintáctica e Planeamento

Executado dentro do directório terraform/:

cd terraform
terraform validate
terraform plan

* Resultado do Plan: Total de 25 recursos calculados para criação (incluindo VPC, Subnets Públicas/Privadas, IGW, NAT Gateway, EIP, Rotas, Security Groups, ALB e ECS Fargate).

---

### Passo 5: Provisionamento e Execução

Aplicação das alterações na infra-estrutura AWS:

terraform apply

* Output obtido:
Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

Outputs:
alb_dns_name = "fargate-api-dev-alb-1557749007.us-east-1.elb.amazonaws.com"