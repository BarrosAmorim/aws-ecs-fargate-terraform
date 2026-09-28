# Implementação da Infraestrutura de CI/CD: Amazon ECR e Autenticação OIDC com Terraform

Nesta etapa, implementei e provisionei a infraestrutura necessária para autenticação segura e armazenamento de imagens Docker do pipeline de CI/CD no GitHub Actions. 

Optei por aplicar isoladamente os componentes da esteira de automação (ecr.tf e oidc.tf) antes de provisionar a infraestrutura completa de rede e computação (ALB, NAT Gateway e ECS Fargate). Essa estratégia permitiu validar a segurança, o repositório de containers e a autenticação sem gerar custos fixos de rede na AWS.

---

## 1. Criação do Provedor OIDC e IAM Role (terraform/oidc.tf)

Para eliminar o uso de chaves estáticas de longa duração (AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY), configurei a autenticação federada via OpenID Connect (OIDC). O GitHub Actions solicita tokens criptográficos de curta duração diretamente ao AWS STS, assumindo uma IAM Role com permissões restritas ao repositório do projeto.

Criei o arquivo terraform/oidc.tf com o seguinte conteúdo:

```hcl
# ==============================================================================
# 1. Provedor OIDC para o GitHub Actions
# ==============================================================================
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "[https://token.actions.githubusercontent.com](https://token.actions.githubusercontent.com)"
  client_id_list  = ["sts.amazonaws.com"]
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
            "token.actions.githubusercontent.com:sub" = "repo:BarrosAmorim@24548784/aws-ecs-fargate-terraform:*"
          }
        }
      }
    ]
  })
}

# ==============================================================================
# 3. Permissões mínimas para a esteira (ECR e ECS)
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

resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}
```

---

## 2. Criação do Repositório de Containers (terraform/ecr.tf)

Para armazenar as imagens Docker geradas pela esteira, criei o arquivo terraform/ecr.tf. O repositório foi configurado com escaneamento automatizado de vulnerabilidades ativado:

```hcl
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
```

---

## 3. Centralização das Variáveis de Saída (terraform/outputs.tf)

Centralizei todos os outputs no arquivo terraform/outputs.tf, facilitando a exportação das informações necessárias para a esteira e mantendo o código modular:

```hcl
# ==============================================================================
# Outputs para a Pipeline de CI/CD (GitHub Actions)
# ==============================================================================

output "ecr_repository_url" {
  description = "URL do repositório ECR para push da imagem Docker"
  value       = aws_ecr_repository.app.repository_url
}

output "alb_dns_name" {
  description = "DNS publico gerado pelo Application Load Balancer para acesso a aplicacao"
  value       = aws_lb.main.dns_name
}
```

---

## 4. Validação e Formatação do Código

Antes de aplicar na AWS, formatei o código no padrão HCL e executei a validação estática no terminal:

```bash
terraform fmt && terraform validate
```

Saída obtida:
```text
Success! The configuration is valid.
```

---

## 5. Planejamento Direcionado (terraform plan -target)

Para isolar o cálculo do Terraform e visualizar estritamente o que seria criado pelos arquivos oidc.tf e ecr.tf (sem disparar a criação de recursos de rede como NAT Gateway e Application Load Balancer), utilizei o parâmetro -target:

```bash
terraform plan \
  -target=aws_ecr_repository.app \
  -target=aws_iam_openid_connect_provider.github_actions \
  -target=aws_iam_role.github_actions_role \
  -target=aws_iam_policy.github_actions_policy \
  -target=aws_iam_role_policy_attachment.github_actions_attach
```

O comando confirmou o planejamento dos novos recursos sem alterar nenhum item existente:
```text
Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + ecr_repository_url      = (known after apply)
  + github_actions_role_arn = (known after apply)
```

---

## 6. Provisionamento na AWS (terraform apply -target)

Executei o comando de provisionamento direcionado:

```bash
terraform apply \
  -target=aws_ecr_repository.app \
  -target=aws_iam_openid_connect_provider.github_actions \
  -target=aws_iam_role.github_actions_role \
  -target=aws_iam_policy.github_actions_policy \
  -target=aws_iam_role_policy_attachment.github_actions_attach
```

Confirmei com `yes`.

Saída dos Outputs:
```text
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

ecr_repository_url = "[696537703431.dkr.ecr.us-east-1.amazonaws.com/fargate-api-dev](https://696537703431.dkr.ecr.us-east-1.amazonaws.com/fargate-api-dev)"
github_actions_role_arn = "arn:aws:iam::696537703431:role/github-actions-ecs-cicd-role"
```

*(O output alb_dns_name não foi exibido intencionalmente, pois o recurso aws_lb.main permanece fora do escopo deste apply direcionado).*

---

## 7. Verificação via AWS CLI

Para validar a integridade da criação diretamente no ambiente da AWS, consultei o repositório ECR via terminal:

```bash
aws ecr describe-repositories --repository-names fargate-api-dev --region us-east-1
```

Retorno obtido:
```json
{
    "repositories": [
        {
            "repositoryArn": "arn:aws:ecr:us-east-1:696537703431:repository/fargate-api-dev",
            "registryId": "696537703431",
            "repositoryName": "fargate-api-dev",
            "repositoryUri": "[696537703431.dkr.ecr.us-east-1.amazonaws.com/fargate-api-dev](https://696537703431.dkr.ecr.us-east-1.amazonaws.com/fargate-api-dev)",
            "createdAt": "2026-09-28T19:03:04.807000-03:00"
        }
    ]
}
```

---

## 8. Configuração das Variáveis no Repositório GitHub

Com os recursos criados e os outputs obtidos, configurei as variáveis de ambiente necessárias para que a esteira do GitHub Actions consiga assumir a IAM Role e operar na região correta sem a necessidade de chaves estáticas ou valores hardcoded nos manifestos:

1. Acessei o repositório no GitHub: `https://github.com/BarrosAmorim/aws-ecs-fargate-terraform`.
2. Naveguei em **Settings** > **Secrets and variables** > **Actions** > aba **Variables**.
3. Adicionei as seguintes variáveis de repositório:
   * **`AWS_ROLE_TO_ASSUME`**: `arn:aws:iam::696537703431:role/github-actions-ecs-cicd-role` (ARN da role federada via OIDC).
   * **`AWS_REGION`**: `us-east-1` (Região onde os recursos foram provisionados).

Com a infraestrutura de autenticação, o repositório ECR e as variáveis configuradas, o ambiente está pronto para a criação do workflow de CI/CD (`.github/workflows/deploy.yml`).

