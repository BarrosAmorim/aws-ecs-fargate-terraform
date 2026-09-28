# terraform/ecr.tf

resource "aws_ecr_repository" "app" {
  name                 = "fargate-api-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "fargate-api-${var.environment}-ecr"
  }
}

