# Diário de Bordo: Camada de Segurança (security.tf)

Neste documento registo a implementação dos Security Groups (firewalls virtuais da AWS) para proteger a entrada pública no Application Load Balancer e blindar o acesso interno aos contentores da aplicação no ECS Fargate, incluindo a parametrização de variáveis necessárias.

---

## 1. Visão Geral da Arquitetura de Segurança

A estratégia adotada segue o princípio de **Defesa em Profundidade** (*Defense in Depth*), garantindo que nenhum contentor da aplicação seja exposto diretamente à Internet pública sem a mediação do balanceador.

Implementei dois Security Groups distintos no ficheiro `terraform/security.tf`:

1. **Security Group do Application Load Balancer (ALB):** Atua como a linha de frente pública, aceitando apenas tráfego HTTP na porta `80`.
2. **Security Group das Tasks do ECS Fargate:** Atua como o firewall interno dos contentores, permitindo conexões na porta da aplicação (`3000`) **exclusivamente originadas do Security Group do ALB**.

---

## 2. Parametrização em `terraform/variables.tf`

Antes de definir as regras de segurança, foi necessário declarar a variável correspondente à porta do contentor no ficheiro `terraform/variables.tf`, evitando valores fixos no código (*hardcoded*):

```hcl
variable "app_port" {
  description = "Porta TCP exposta pela aplicacao conteinerizada"
  type        = number
  default     = 3000
}
```

* **Vantagem:** Permite alterar centralmente a porta de comunicação do serviço sem modificar a lógica das regras nos Security Groups, Target Groups ou Task Definitions.

---

## 3. Fluxo de Tráfego e Filtragem de Pacotes

O tráfego de rede percorre o seguinte fluxo com verificação rigorosa antes de alcançar a aplicação:

```text
[Utilizador / Internet Pública]
         │
         ▼ (Porta 80 / 0.0.0.0/0)
[SG do Load Balancer: fargate-api-dev-sg-alb]
         │
         ▼ (Encaminha para a porta 3000)
[Application Load Balancer (ALB)]
         │
         ▼ (Permitido apenas tráfego do SG do ALB)
[SG das Tasks ECS: fargate-api-dev-sg-ecs-tasks]
         │
         ▼ (Porta 3000)
[Contentor da Aplicação]
```

---

## 4. Padrão de Nomenclatura (*Naming Convention*)

Mantendo a consistência dos recursos de rede, os Security Groups seguem o padrão estruturado:

$$\text{[projeto]}-\text{[ambiente]}-\text{[tipo-de-recurso]}-\text{[camada/componente]}$$

| Recurso AWS | Nome no Terraform | Nome no Console AWS | Função Principal |
|---|---|---|---|
| **SG do ALB** | `aws_security_group.alb` | `fargate-api-dev-sg-alb` | Porta de entrada HTTP pública |
| **SG do ECS** | `aws_security_group.ecs_tasks` | `fargate-api-dev-sg-ecs-tasks` | Blindagem interna dos contentores |

---

## 5. Implementação Completa (`terraform/security.tf`)

```hcl
# ==============================================================================
# Security Group para o Application Load Balancer (ALB)
# ==============================================================================
resource "aws_security_group" "alb" {
  name        = "fargate-api-${var.environment}-sg-alb"
  description = "Controle de trafego publico de entrada para o Load Balancer"
  vpc_id      = aws_vpc.main.id

  # Regra de Entrada (Ingress): Aceita requisicoes HTTP da internet publica
  ingress {
    description = "Acesso HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de Saida (Egress): Permite enviar trafego para qualquer destino (inclusive os containers)
  egress {
    description = "Permite saida irrestrita para encaminhar o trafego"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fargate-api-${var.environment}-sg-alb"
  }
}

# ==============================================================================
# Security Group para as Tasks do ECS Fargate (Containers)
# ==============================================================================
resource "aws_security_group" "ecs_tasks" {
  name        = "fargate-api-${var.environment}-sg-ecs-tasks"
  description = "Permite conexao apenas a partir do Load Balancer para a aplicacao"
  vpc_id      = aws_vpc.main.id

  # Regra de Entrada (Ingress): Aceita conexoes na porta do app APENAS do Security Group do ALB
  ingress {
    description     = "Trafego recebido exclusivamente do ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Regra de Saida (Egress): Permite que o container acesse a internet para baixar pacotes ou imagens
  egress {
    description = "Permite saida para download de imagens e comunicacao externa"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "fargate-api-${var.environment}-sg-ecs-tasks"
  }
}
```

---

## 6. Análise Técnica das Regras

### 6.1. Regra de Entrada do ALB (*Ingress*)
* **`from_port = 80 / to_port = 80`**: Limita o ponto de contacto à porta padrão HTTP.
* **`cidr_blocks = ["0.0.0.0/0"]`**: Representa a rede IPv4 global inteira, permitindo que utilizadores legítimos acedam à aplicação a partir de qualquer navegador.

### 6.2. Regra de Entrada das Tasks ECS (*Ingress*)
* **`from_port = var.app_port / to_port = var.app_port`**: Parametrizado com a variável `app_port` (definida como `3000` em `variables.tf`).
* **`security_groups = [aws_security_group.alb.id]`**: Em vez de expor a porta para a Internet, a entrada restringe-se aos pacotes provenientes das interfaces de rede associadas ao próprio Security Group do ALB. Chamadas externas diretas são automaticamente descartadas pela AWS a nível de rede.

### 6.3. Regras de Saída (*Egress*)
* Ambas as camadas utilizam `protocol = "-1"` e `from_port = 0 / to_port = 0` para `0.0.0.0/0`.
* Isso permite a resolução de consultas DNS (porta 53), transferências de imagens a partir do registo de contentores (HTTPS porta 443) e chamadas a APIs ou serviços externos de monitorização sem bloqueios indesejados.

