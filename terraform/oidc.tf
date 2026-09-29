# ==============================================================================
# 1. Provedor OIDC para o GitHub Actions
# ==============================================================================
resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58e3a85b0673e554bdef855cc1116e88f6e53c"
  ]
}

# ==============================================================================
# 2. IAM Role assumida pelo GitHub Actions
# ==============================================================================
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-ecs-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:BarrosAmorim@24548784/aws-ecs-fargate-terraform@*:*",
              "repo:BarrosAmorim/aws-ecs-fargate-terraform:*"
            ]
          }
        }
      }
    ]
  })
}

# ==============================================================================
# 3. Permissões da esteira (ECR e ECS)
# ==============================================================================
resource "aws_iam_policy" "github_actions_policy" {
  name        = "github-actions-ecs-cicd-policy"
  description = "Permissoes minimas para o GitHub Actions fazer push no ECR e deploy no ECS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRActions"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.app.arn
      },
      {
        Sid    = "ECSDeployActions"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRoleToECS"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.ecs_execution_role.arn
        ]
      }
    ]
  })
}

# ==============================================================================
# 4. Anexo da Policy na Role
# ==============================================================================
resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}