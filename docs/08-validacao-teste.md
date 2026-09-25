# Validação e Testes de Alta Disponibilidade

Este documento detalha os procedimentos de teste executados para validar o balanceamento de carga, a comunicação interna e o isolamento de rede dos containers ECS Fargate após o provisionamento dos 25 recursos.

---

### 1. Teste de Conectividade e Resposta da Aplicação

Executou-se uma requisição HTTP diretamente contra o endpoint público fornecido pelo Application Load Balancer:

Comando:
curl -i http://fargate-api-dev-alb-1557749007.us-east-1.elb.amazonaws.com

Saída obtida:
Server address: 10.0.20.152:80
Server name: ip-10-0-20-152.ec2.internal
Date: 25/Sep/2026:00:17:09 +0000
URI: /
Request ID: 0df79204a201b173334a2d5813274875

Análise do Resultado:
- O IP retornado (10.0.20.152) pertence à Subnet Privada 2 (bloco CIDR 10.0.20.0/24).
- Confirma que o tráfego externo acessou o ALB na subnet pública e foi roteado com sucesso até o container confinado na subnet privada, sem exposição de IP público direto.

---

### 2. Validação do Balanceamento Round-Robin e Alta Disponibilidade

Para comprovar a distribuição equilibrada de requisições entre tarefas distribuídas em Zonas de Disponibilidade distintas (us-east-1a e us-east-1b), foram disparadas quatro requisições consecutivas via script em loop:

Comando:
for i in {1..4}; do curl -s http://fargate-api-dev-alb-1557749007.us-east-1.elb.amazonaws.com | grep "Server address"; done

Saída obtida:
Server address: 10.0.20.152:80
Server address: 10.0.10.117:80
Server address: 10.0.20.152:80
Server address: 10.0.10.117:80

Análise do Resultado:
- Tarefa A (AZ us-east-1b): IP privado 10.0.20.152
- Tarefa B (AZ us-east-1a): IP privado 10.0.10.117
- O Target Group alternou as requisições com exatidão no modo Round-Robin entre os dois containers em execução, assegurando tolerância a falhas em nível de Zona de Disponibilidade.

