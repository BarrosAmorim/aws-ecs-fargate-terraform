# Procedimento de Desprovisionamento e Auditoria de Custos Residuais

Este documento descreve os comandos executados para a destruição integral dos 25 recursos provisionados via Terraform e as rotinas de auditoria via AWS CLI para assegurar que nenhum recurso tarifável por hora (notavelmente endereços IPv4 públicos alocados, NAT Gateways e Application Load Balancers) permaneça ativo na conta.

---

### 1. Destruição da Infraestrutura via Terraform

Dentro do diretório de configuração do Terraform, executa-se a destruição completa do estado gerenciado:

Comando:
cd ~/projects/aws-ecs-fargate-terraform/terraform
terraform destroy

Confirmação:
Digitar 'yes' quando solicitado.

Saída esperada:
Destroy complete! Resources: 25 destroyed.

Validação no State local:
terraform show

Observação: O comando acima não deve retornar nenhum recurso listado, confirmando o esvaziamento do arquivo de estado (`terraform.tfstate`).

---

### 2. Auditoria e Validação Anti-Cobrança via AWS CLI (Região us-east-1)

Após a conclusão do destroy, executa-se a checagem direta na API da AWS para garantir a ausência de componentes órfãos ou com cobrança contínua:

#### 2.1 Verificação de Endereços IPv4 Públicos Estáticos (Elastic IPs)
Garante que o Elastic IP criado para o NAT Gateway foi desalocado/liberado:

Comando:
aws ec2 describe-addresses --region us-east-1 --output table

Resultado esperado:
Tabela vazia ou retorno vazio (nenhum EIP associado ao projeto).

---

#### 2.2 Verificação de NAT Gateways Ativos
Confirma que o NAT Gateway foi removido das subnets públicas:

Comando:
aws ec2 describe-nat-gateways --region us-east-1 --filter "Name=state,Values=available,pending" --output table

Resultado esperado:
Retorno vazio, comprovando que não existem NAT Gateways provisionados ou em transição.

---

#### 2.3 Verificação de Application Load Balancers (ALB)
Garante que o balanceador de carga HTTP foi desalocado:

Comando:
aws elbv2 describe-load-balancers --region us-east-1 --output table

Resultado esperado:
Retorno vazio, confirmando que o DNS do ALB e a infraestrutura subjacente foram finalizados.

---

#### 2.4 Verificação de Tarefas e Cluster Amazon ECS
Valida o encerramento do cluster e dos containers Fargate:

Comando:
aws ecs list-tasks --cluster fargate-api-dev-cluster --region us-east-1

Resultado esperado:
ClusterNotFoundException ou lista de tasks vazia, assegurando encerramento completo do workload.