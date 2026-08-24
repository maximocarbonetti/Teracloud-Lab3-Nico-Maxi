# Outputs del modulo alb

output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name del ALB (para el registro Route53)"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Zone ID del ALB (para el alias de Route53)"
  value       = aws_lb.this.zone_id
}

output "frontend_target_group_arn" {
  value = aws_lb_target_group.frontend.arn
}
