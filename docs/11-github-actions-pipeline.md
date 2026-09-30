# Automação de CI/CD: Pipeline de Build e Push para o Amazon ECR com GitHub Actions -

Nesta etapa, implementei a automação de Integração Contínua (CI) utilizando o **GitHub Actions**. O objetivo foi construir um fluxo seguro, reprodutível e totalmente integrado à AWS, capaz de gerar a imagem Docker da aplicação FastAPI e publicá-la automaticamente no **Amazon ECR** a cada novo commit.

Todo o processo de autenticação foi projetado com base em segurança moderna de nuvem, utilizando **OpenID Connect (OIDC)** para assumir permissões temporárias via IAM Role, eliminando por completo o uso de chaves estáticas de longa duração.

---

## 1. Estrutura do Workflow (`.github/workflows/deploy.yml`)

Criei o manifesto da esteira dentro do diretório padrão `.github/workflows/deploy.yml`. 

Configurei o pipeline para ser acionado automaticamente em eventos de `push` nas branches `main` e `feature/cicd-pipeline`, bem como em `pull_request` direcionados para a branch `main`:

```yaml
name: CI/CD Pipeline - ECS Fargate

on:
  push:
    branches:
      - main
      - feature/cicd-pipeline
    paths-ignore:
      - 'docs/**'
      - '*.md'
      - 'terraform/**'
  pull_request:
    branches:
      - main
    paths-ignore:
      - 'docs/**'
      - '*.md'
      - 'terraform/**'

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: ${{ vars.AWS_REGION }}
  ROLE_TO_ASSUME: ${{ vars.AWS_ROLE_TO_ASSUME }}
  ECR_REPOSITORY: fargate-api-dev
  ECS_CLUSTER: fargate-api-dev-cluster
  ECS_SERVICE: fargate-api-dev-service
  CONTAINER_NAME: fargate-api-dev-app

jobs:
  build-and-deploy:
    name: Build, Push & Deploy to ECS
    runs-on: ubuntu-latest

    steps:
      - name: Checkout do Repositório
        uses: actions/checkout@v4

      - name: Configurar Credenciais AWS via OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ env.ROLE_TO_ASSUME }}
          aws-region: ${{ env.AWS_REGION }}
          audience: sts.amazonaws.com

      - name: Login no Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, Tag e Push da Imagem Docker
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG -t $ECR_REGISTRY/$ECR_REPOSITORY:latest ./app
          docker push $ECR_REGISTRY/$ECR_REPOSITORY --all-tags
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

      - name: Baixar Task Definition Atual do ECS
        run: |
          aws ecs describe-task-definition \
            --task-definition fargate-api-dev-task \
            --query taskDefinition > task-definition.json

      - name: Renderizar Nova Imagem na Task Definition
        id: render-web-container
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: task-definition.json
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ steps.build-image.outputs.image }}

      - name: Deploy da Task Definition no ECS Fargate
        uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ${{ steps.render-web-container.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true
```

---

## 2. Detalhamento dos Passos da Esteira

Cada etapa foi estruturada seguindo boas práticas de DevOps e arquitetura em nuvem:

* **Controle Estrito de Permissões (`permissions`)**: Concedi apenas `id-token: write` (necessário para o runner solicitar o token JWT emitido pelo GitHub) e `contents: read` (para clonar o repositório), aplicando o princípio de menor privilégio.
* **Autenticação Federada via OIDC (`aws-actions/configure-aws-credentials`)**: Utilizei a action oficial da AWS para trocar o token JWT do GitHub por credenciais temporárias do AWS STS (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN`). Isso garantiu que nenhuma senha ficasse gravada em secrets.
* **Login Automatizado no ECR (`aws-actions/amazon-ecr-login`)**: Obteve o token de autenticação gerenciado pela AWS e configurou o daemon do Docker no runner para comunicação com o registry privado `696537703431.dkr.ecr.us-east-1.amazonaws.com`.
* **Estratégia de Tagging Dupla**:
  * `${{ github.sha }}`: Tag imutável baseada no hash do commit, essencial para rastreabilidade e auditoria de deploys.
  * `latest`: Tag móvel apontando sempre para o artefato mais recente aprovado pela esteira.

---

## 3. Validação da Execução

Após enviar as configurações para a branch `feature/cicd-pipeline`, acompanhei a execução na aba **Actions** do GitHub. O job `Build & Push Docker Image` foi executado com sucesso em aproximadamente 34 segundos.

Para validar se as imagens foram devidamente armazenadas no ECR, executei a verificação diretamente via AWS CLI:

```bash
aws ecr list-images --repository-name fargate-api-dev --region us-east-1
```

O comando retornou as duas tags criadas pela esteira (`latest` e a hash correspondente ao commit), confirmando que a fase de integração contínua e entrega de artefatos está totalmente operacional e sem custos ociosos de infraestrutura.