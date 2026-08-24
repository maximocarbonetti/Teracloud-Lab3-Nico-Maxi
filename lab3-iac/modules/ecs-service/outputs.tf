# Outputs del modulo ecs-service

output "frontend_service_name" {
  value = aws_ecs_service.frontend.name
}

output "mysql_service_name" {
  value = aws_ecs_service.mysql.name
}

output "mysql_dns_name" {
  description = "FQDN interno para que el frontend se conecte a mysql (service discovery)"
  value       = "mysql.${var.private_dns_namespace_name}"
}

output "frontend_execution_role_arn" {
  value = aws_iam_role.execution.arn
}
