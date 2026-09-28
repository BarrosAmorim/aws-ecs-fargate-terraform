# terraform/oidc.tf

# 1. Provedor OIDC do GitHub Actions na AWS
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58e3a85b0673e554bdef855cc1116e88f6e53c"]
}

# 2. IAM Role que o GitHub Actions assumirá temporariamente via OIDC
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-ecs-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Bloqueio estrito para o seu repositório
            "token.actions.githubusercontent.com:sub" = "repo:BarrosAmorim@24548784/aws-ecs-fargate-terraform:*"
          }
        }
      }
    ]
  })
}


