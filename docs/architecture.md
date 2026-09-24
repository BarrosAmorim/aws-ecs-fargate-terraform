# Arquitetura do Projeto: aws-ecs-fargate-terraform

> **Status do Projeto:** 🟡 Em desenvolvimento — Fase 1: Especificação e Implementação da API Local

---

## 1. O que a aplicação vai fazer

Vou desenvolver uma API em Python utilizando o framework **FastAPI** com dois endpoints principais:
- `/health`: Rota leve de verificação de integridade para ser consumida ativamente pelo balanceador de carga, confirmando se o container está operante.
- `/diag`: Rota de diagnóstico de runtime para inspecionar métricas do sistema (CPU, memória, hostname do container) e validar que a aplicação roda sem privilégios de root.

---

## 2. Componentes da AWS Planejados

A infraestrutura será provisionada 100% via Terraform utilizando os seguintes serviços:

* **VPC (Virtual Private Cloud):** Rede isolada com blocos CIDR dedicados para conter todos os recursos.
* **Subnets:** Sub-redes públicas distribuídas em 2 Zonas de Disponibilidade (us-east-1a e us-east-1b) para garantir redundância física e alta disponibilidade.
* **Internet Gateway (IGW):** Ponto de conexão da VPC com a internet pública.
* **Security Groups:** Firewalls virtuais configurados sob o princípio do menor privilégio para restringir estritamente portas e origens de tráfego.
* **Application Load Balancer (ALB):** Balanceador de carga de camada 7 exposto à internet para distribuir requisições HTTP entre as tasks.
* **Amazon ECR:** Registro privado para armazenar as imagens Docker com escaneamento de vulnerabilidades ativado no push.
* **Amazon ECS com AWS Fargate:** Orquestrador serverless escolhido para rodar os containers sem a necessidade de gerenciar servidores EC2 ou aplicar patches de sistema operacional.
* **CloudWatch Logs:** Grupo de logs para centralizar stdout e stderr da aplicação, com política de retenção definida para conter custos.

---

## 3. O Fluxo de Tráfego Planejado

1. O cliente faz uma requisição HTTP que chega ao **Application Load Balancer (ALB)** pelas subnets públicas.
2. O ALB processa a requisição e a encaminha para as tasks no **ECS Fargate**.
3. **Isolamento de rede:** O Security Group das tasks será configurado para aceitar conexões **exclusivamente originadas do Security Group do ALB**. Mesmo com IP público para comunicação de saída, qualquer tentativa de acesso direto da internet para o container será descartada.
4. A API processa a requisição e devolve a resposta através do ALB.
5. **Auto-recuperação (Self-healing):** Se uma task falhar sucessivamente nas checagens da rota `/health`, o Target Group a marcará como não saudável e o ECS Service provisionará uma nova task automaticamente.

