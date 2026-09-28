output "alb_dns_name" {
  description = "DNS publico gerado pelo Application Load Balancer para acesso a aplicacao"
  value       = aws_lb.main.dns_name
}

# Outputs para a Pipeline de CI/CD (GitHub Actions)
output "github_actions_role_arn" {
  description = "ARN da IAM Role assumida pelo GitHub Actions via OIDC"
  value       = aws_iam_role.github_actions_role.arn
}

output "ecr_repository_url" {
  description = "URL do repositório ECR para push da imagem Docker"
  value       = aws_ecr_repository.app.repository_url
}

