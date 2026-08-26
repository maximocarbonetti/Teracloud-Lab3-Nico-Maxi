# Outputs de este entorno (FQDN, URL del ALB, etc)

output "alb_dns_name" {
  description = "URL publica del ALB, para verificar disponibilidad (entregable del enunciado)"
  value       = module.alb.alb_dns_name
}

output "app_fqdn" {
  description = "FQDN de la app, accesible por HTTPS"
  value       = module.dns.fqdn
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs_cluster.cluster_name
}

output "codestar_connection_arn" {
  description = "Autorizar manualmente en la consola de AWS despues del primer apply"
  value       = module.cicd.codestar_connection_arn
}

output "codestar_connection_status" {
  value = module.cicd.codestar_connection_status
}

output "dashboard_name" {
  value = module.observability.dashboard_name
}
