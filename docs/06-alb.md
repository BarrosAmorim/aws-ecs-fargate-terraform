# Diário de Bordo: Camada de Balanceamento (alb.tf e outputs.tf)

Neste documento registo a arquitetura, as decisões técnicas e a implementação do Application Load Balancer (ALB), do Target Group e do Listener HTTP na AWS utilizando o Terraform, além da exportação do endereço DNS de acesso público.

---

## 1. Visão Geral da Camada de Balanceamento

O Application Load Balancer atua como o ponto de entrada único para o tráfego da aplicação vindo da Internet. Os componentes implementados nos ficheiros `terraform/alb.tf` e `terraform/outputs.tf` foram:

* **Application Load Balancer (ALB):** Balanceador de carga gerenciado da camada de aplicação (Camada 7 / HTTP) configurado como público (*internet-facing*).
* **Target Group:** Grupo de destino responsável por registrar os endereços IP dos contentores Fargate e monitorizar a saúde do serviço através de verificações contínuas (*health checks*).
* **Listener HTTP:** Componente que escuta as conexões na porta pública `80` e encaminha o tráfego diretamente para o Target Group.
* **Output DNS (`outputs.tf`):** Exportação declarativa do nome de domínio gerado pela AWS para acesso direto via terminal após o provisionamento.

---

## 2. Decisões Arquiteturais e Padrão de Nomenclatura

Mantendo o alinhamento com a convenção do projeto, os recursos receberam identificadores descritivos:

`[projeto]-[ambiente]-[tipo-de-recurso]`

| Recurso AWS | Definição no Terraform | Nome Exibido no Console AWS | Função |
|---|---|---|---|
| **Load Balancer** | `aws_lb.main` | `fargate-api-dev-alb` | Distribuição de carga pública em multi-AZ |
| **Target Group** | `aws_lb_target_group.app` | `fargate-api-dev-tg` | Registro dinâmico de IPs das tasks e health checks |
| **Listener** | `aws_lb_listener.http` | (Associado ao ALB) | Escuta na porta 80 e encaminha para o Target Group |

---

## 3. Parametrização em `terraform/variables.tf`

Adicionei a variável para o caminho do *health check*, evitando valores fixos no código:

```hcl
variable "health_check_path" {
  description = "Caminho da rota para o health check do Load Balancer"
  type        = string
  default     = "/"
}
```

---

## 4. Implementação Completa (`terraform/alb.tf`)

```hcl
# ==============================================================================
# 1. Application Load Balancer (ALB)
# ==============================================================================
resource "aws_lb" "main" {
  name               = "fargate-api-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "fargate-api-${var.environment}-alb"
  }
}

# ==============================================================================
# 2. Target Group (Alvo para onde as requisições serão enviadas)
# ==============================================================================
resource "aws_lb_target_group" "app" {
  name        = "fargate-api-${var.environment}-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "fargate-api-${var.environment}-tg"
  }
}

# ==============================================================================
# 3. Listener HTTP (Escuta na porta 80 e encaminha para o Target Group)
# ==============================================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

---

## 5. Exportação Declarativa (`terraform/outputs.tf`)

Para obter a URL de acesso público gerada pela AWS diretamente no terminal ao rodar o comando `terraform apply`, criei o ficheiro `outputs.tf`:

```hcl
output "alb_dns_name" {
  description = "DNS publico gerado pelo Application Load Balancer para acesso a aplicacao"
  value       = aws_lb.main.dns_name
}
```

---

## 6. Análise Técnica dos Parâmetros

### 6.1. Alta Disponibilidade com Operador Splat (`[*]`)
* No bloco `aws_lb`, o atributo `subnets = aws_subnet.public[*].id` utiliza o operador *splat* do Terraform para extrair dinamicamente a lista de IDs de todas as sub-redes públicas criadas no `vpc.tf`. O ALB exige pelo menos duas sub-redes em Zonas de Disponibilidade diferentes para garantir tolerância a falhas.

### 6.2. Target Type Definido como `ip`
* No AWS ECS Fargate, as tarefas utilizam o modo de rede `awsvpc`, no qual cada contentor recebe a sua própria interface de rede elástica (ENI) e um endereço IP privado dentro da VPC. Por esta razão, o parâmetro `target_type` tem de ser explicitamente configurado como `"ip"`, em vez do padrão `"instance"`.

### 6.3. Configuração do Health Check
* O balanceador envia requisições `HTTP GET` para o caminho definido em `var.health_check_path` (porta `var.app_port`) a cada 30 segundos (`interval = 30`).
* **`healthy_threshold = 2`:** O contentor precisa responder com status `200` duas vezes consecutivas para ser considerado saudável e passar a receber tráfego.
* **`unhealthy_threshold = 3`:** Três falhas consecutivas sinalizam que a réplica está degradada, fazendo o ALB suspender o encaminhamento para esse IP até a recuperação ou substituição pelo serviço ECS.

