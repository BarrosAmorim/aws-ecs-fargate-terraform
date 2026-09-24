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