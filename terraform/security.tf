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