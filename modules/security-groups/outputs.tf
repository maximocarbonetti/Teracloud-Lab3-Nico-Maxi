# Outputs del modulo security-groups

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "ecs_frontend_sg_id" {
  value = aws_security_group.ecs_frontend.id
}

output "ecs_mysql_sg_id" {
  value = aws_security_group.ecs_mysql.id
}

output "efs_sg_id" {
  value = aws_security_group.efs.id
}
