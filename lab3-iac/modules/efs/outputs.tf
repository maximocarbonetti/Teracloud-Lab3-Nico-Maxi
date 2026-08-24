# Outputs del modulo efs

output "file_system_id" {
  value = aws_efs_file_system.this.id
}

output "file_system_arn" {
  value = aws_efs_file_system.this.arn
}

output "access_point_id" {
  description = "Access point para montar en la task definition de MySQL"
  value       = aws_efs_access_point.mysql.id
}
