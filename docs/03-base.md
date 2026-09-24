# Diário de Bordo: Passo a Passo da Infraestrutura (Pasta terraform - Parte 1)

Neste documento eu registrei como iniciei a infraestrutura como código (IaC) com Terraform, explicando por que comecei por esses arquivos, o que cada linha faz e a importância de não deixar valores fixos no código.

---

## 1. O que eu construí nesta etapa

Antes de sair criando servidores, redes ou containers, preparei a fundação do Terraform. Criei a pasta `terraform/` com dois arquivos essenciais:

```text
terraform/
├── versions.tf   # Define a versão do Terraform, do provedor AWS e as tags padrão
└── variables.tf  # Declara as variáveis (parâmetros configuráveis da infraestrutura)
```

---

## 2. Passo a Passo dos Arquivos

### Passo 2.1: O arquivo de provedores e versões (`terraform/versions.tf`)
Criei este arquivo para travar as versões das ferramentas e garantir que tudo o que eu criar na AWS receba etiquetas (tags) de identificação automáticas:

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-ecs-fargate-terraform"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
```

* **`required_version = ">= 1.7.0"`:** Exige que qualquer pessoa que rode esse projeto use uma versão moderna do Terraform.
* **`required_providers` com `~> 5.40`:** Avisa ao Terraform para baixar o plugin oficial da AWS na versão 5.40 ou atualizações seguras de correção, impedindo que mudanças bruscas quebrem o código.
* **`provider "aws"`:** Conecta o Terraform à conta da AWS usando a região que defini na variável (`var.aws_region`).
* **`default_tags`:** Um dos pontos mais importantes para boas práticas. Qualquer recurso que eu criar (rede, balanceador, container) vai receber automaticamente as tags `Project`, `Environment` e `ManagedBy`. Isso ajuda a identificar quem criou o recurso e facilita o controle de custos na AWS.

---

### Passo 2.2: O arquivo de variáveis (`terraform/variables.tf`)
Em vez de escrever nomes, regiões e números de IP direto no meio do código, centralizei tudo em variáveis com valores padrão:

```hcl
variable "aws_region" {
  description = "Região da AWS onde os recursos serão provisionados"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de implantação (ex: dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "Bloco CIDR principal da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Blocos CIDR para as subnets públicas em 2 AZs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Zonas de Disponibilidade utilizadas para garantir alta disponibilidade"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
```

* **`aws_region`:** A região geográfica da AWS onde tudo vai rodar. Escolhi `us-east-1` (Norte da Virgínia) por ter maior variedade de serviços e menor custo.
* **`environment`:** Identifica o estágio do projeto (neste caso, `dev` para desenvolvimento).
* **`vpc_cidr` (`10.0.0.0/16`):** O espaço de endereçamento total da minha rede privada na AWS (permite até 65.536 endereços IP privados).
* **`public_subnet_cidrs`:** Dois pedaços menores da rede (`10.0.1.0/24` e `10.0.2.0/24`), cada um comportando até 256 endereços IP.
* **`availability_zones`:** As duas Zonas de Disponibilidade físicas da AWS (`us-east-1a` e `us-east-1b`) onde vou espalhar as sub-redes para que a aplicação continue no ar mesmo se um data center físico da AWS falhar.

---

## 3. Por que separei versions.tf e variables.tf?

* **Padrão de mercado:** Em times de DevOps e empresas, ferramentas automatizadas (como bots de atualização de dependências) procuram especificamente o arquivo `versions.tf` para atualizar versões sem mexer no resto da infraestrutura.
* **Organização humana:** Manter variáveis em um arquivo separado torna muito mais fácil mudar a região ou a faixa de IPs no futuro sem precisar caçar linhas de configuração dentro dos arquivos de recursos.

