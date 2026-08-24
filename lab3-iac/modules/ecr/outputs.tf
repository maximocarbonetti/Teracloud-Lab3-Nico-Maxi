# Outputs del modulo ecr

output "repository_url" {
  description = "URL del repositorio (para docker push/pull y buildspec)"
  value       = aws_ecr_repository.this.repository_url
}

output "repository_arn" {
  description = "ARN del repositorio"
  value       = aws_ecr_repository.this.arn
}

output "repository_name" {
  description = "Nombre del repositorio"
  value       = aws_ecr_repository.this.name
}
