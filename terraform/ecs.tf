# ==============================================================================
# 1. A Caixa: Cluster ECS
# ==============================================================================
resource "aws_ecs_cluster" "main" {
  name = "fargate-api-${var.environment}-cluster"

  tags = {
    Name = "fargate-api-${var.environment}-cluster"
  }
}

# ==============================================================================
# 2. O Diário: Log Group no CloudWatch
# ==============================================================================
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/fargate-api-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "fargate-api-${var.environment}-logs"
  }
}

# ==============================================================================
# 3. O Crachá: IAM Role para o Fargate (Task Execution Role)
# ==============================================================================
resource "aws_iam_role" "ecs_execution_role" {
  name = "fargate-api-${var.environment}-execution-role"

  # Permite que o servico ECS assuma este cracha
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "fargate-api-${var.environment}-execution-role"
  }
}

# Anexa a permissao oficial da AWS para puxar imagens e gravar logs no CloudWatch
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==============================================================================
# 4. A Receita: Task Definition (Plano de Execução do Container)
# ==============================================================================

resource "aws_ecs_task_definition" "app" {
  family                   = "fargate-api-${var.environment}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.fargate_cpu
  memory                   = var.fargate_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "fargate-api-${var.environment}-app"
      image     = var.app_image
      essential = true

      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "fargate-api-${var.environment}-task"
  }
}

# ==============================================================================
# 5. O Vigia: ECS Service (Gerenciador do Ciclo de Vida e Réplicas)
# ==============================================================================

resource "aws_ecs_service" "main" {
  name            = "fargate-api-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "fargate-api-${var.environment}-app"
    container_port   = var.app_port
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "fargate-api-${var.environment}-service"
  }
}