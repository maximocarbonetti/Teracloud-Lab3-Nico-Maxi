# Outputs del modulo dns

output "zone_id" {
  description = "Zone ID (para que lo use el modulo acm en la validacion DNS)"
  value       = local.zone_id
}

output "fqdn" {
  description = "FQDN final de la app, accesible por HTTPS (DoD del enunciado)"
  value       = aws_route53_record.app.fqdn
}
