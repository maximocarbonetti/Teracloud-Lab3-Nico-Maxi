# Outputs del modulo ssm-parameters
#
# ARNs, para usar en las "secrets" de la task definition del frontend
# (valueFrom = ARN => se inyecta como env var en runtime).

output "db_host_arn" {
  value = aws_ssm_parameter.db_host.arn
}

output "db_port_arn" {
  value = aws_ssm_parameter.db_port.arn
}

output "db_name_arn" {
  value = aws_ssm_parameter.db_name.arn
}

output "db_user_arn" {
  value = aws_ssm_parameter.db_user.arn
}

output "db_password_arn" {
  value = aws_ssm_parameter.db_password.arn
}

output "all_arns" {
  description = "Todos los ARNs juntos, listos para darle permiso ssm:GetParameters al execution role"
  value = [
    aws_ssm_parameter.db_host.arn,
    aws_ssm_parameter.db_port.arn,
    aws_ssm_parameter.db_name.arn,
    aws_ssm_parameter.db_user.arn,
    aws_ssm_parameter.db_password.arn,
  ]
}
