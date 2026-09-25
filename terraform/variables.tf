variable "aws_region" {
  description = "Região da AWS onde os recursos serão provisionados"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de implantação (ex: dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "Bloco CIDR principal da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Blocos CIDR para as subnets públicas em 2 AZs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Zonas de Disponibilidade utilizadas para garantir alta disponibilidade"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "app_port" {
  description = "Porta TCP exposta pela aplicacao conteinerizada"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Caminho da rota para o health check do Load Balancer"
  type        = string
  default     = "/"
}

variable "app_image" {
  description = "Imagem Docker a ser executada nos containers"
  type        = string
  default     = "nginxdemos/hello:plain-text"
}

variable "fargate_cpu" {
  description = "Quantidade de CPU alocada para a task Fargate (256 = 0.25 vCPU)"
  type        = string
  default     = "256"
}

variable "fargate_memory" {
  description = "Quantidade de memoria alocada para a task Fargate em MB"
  type        = string
  default     = "512"
}

variable "app_count" {
  description = "Numero de replicas de containers gerenciadas pelo service"
  type        = number
  default     = 2
}

variable "private_subnet_cidrs" {
  description = "Blocos CIDR para as subnets privadas em 2 AZs"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}