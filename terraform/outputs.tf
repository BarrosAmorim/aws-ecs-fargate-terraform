output "alb_dns_name" {
  description = "DNS publico gerado pelo Application Load Balancer para acesso a aplicacao"
  value       = aws_lb.main.dns_name
}