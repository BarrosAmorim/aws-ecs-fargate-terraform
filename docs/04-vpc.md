# Diário de Bordo: Camada de Rede (vpc.tf)

Neste documento registo a arquitetura e a implementação da camada de rede isolada na AWS utilizando o Terraform, cobrindo as decisões de topologia, convenção de nomes e conectividade à Internet.

---

## 1. Visão Geral da Rede

Para suportar o serviço conteinerizado no AWS ECS Fargate, criei uma infraestrutura de rede resiliente, de alta disponibilidade e com acesso à Internet. Os componentes implementados no ficheiro `terraform/vpc.tf` foram:

* **Virtual Private Cloud (VPC):** Espaço de rede virtual isolado para alojar todos os recursos da aplicação.
* **Internet Gateway (IGW):** Ponto de saída e entrada que liga a VPC à rede pública da Internet.
* **Sub-redes Públicas (Multi-AZ):** Duas sub-redes distribuídas em Zonas de Disponibilidade (AZs) distintas (`us-east-1a` e `us-east-1b`) para garantir tolerância a falhas.
* **Tabela de Rotas (Route Table) e Associações:** Definição explícita do caminho que o tráfego externo deve percorrer para aceder ou sair das sub-redes via IGW.

---

## 2. Decisão Arquitetural: Padrão de Nomenclatura (*Naming Convention*)

Com o intuito de facilitar a manutenção, monitorização e resolução de incidentes (*troubleshooting*) na consola da AWS ou por linha de comandos, adotei uma convenção de nomes descritiva e consistente:

$$\text{[projeto]}-\text{[ambiente]}-\text{[tipo-de-recurso]}-\text{[camada]}-\text{[zona/sufixo]}$$

### Mapeamento dos Recursos Provisionados

| Recurso AWS | Definição no Terraform | Nome Exibido na Consola AWS |
|---|---|---|
| **VPC** | `"fargate-api-${var.environment}-vpc"` | `fargate-api-dev-vpc` |
| **Internet Gateway** | `"fargate-api-${var.environment}-igw"` | `fargate-api-dev-igw` |
| **Subnet 1** | `"fargate-api-${var.environment}-subnet-public-${var.availability_zones[0]}"` | `fargate-api-dev-subnet-public-us-east-1a` |
| **Subnet 2** | `"fargate-api-${var.environment}-subnet-public-${var.availability_zones[1]}"` | `fargate-api-dev-subnet-public-us-east-1b` |
| **Route Table** | `"fargate-api-${var.environment}-rt-public"` | `fargate-api-dev-rt-public` |

---

## 3. Implementação e Análise do Código (`terraform/vpc.tf`)

O ficheiro completo de provisionamento da rede foi estruturado do seguinte modo:

```hcl
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

