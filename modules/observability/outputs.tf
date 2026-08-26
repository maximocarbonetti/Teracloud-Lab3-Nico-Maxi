# Outputs del modulo observability

output "dashboard_negocio_name" {
  description = "Dashboard con los indicadores de nivel de servicio (SLI/SLO)"
  value       = aws_cloudwatch_dashboard.negocio.dashboard_name
}

output "dashboard_operaciones_name" {
  description = "Dashboard de diagnostico: capacidad, recursos y persistencia"
  value       = aws_cloudwatch_dashboard.operaciones.dashboard_name
}

output "dashboard_negocio_url" {
  value = "https://${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.negocio.dashboard_name}"
}

output "dashboard_operaciones_url" {
  value = "https://${local.region}.console.aws.amazon.com/cloudwatch/home?region=${local.region}#dashboards:name=${aws_cloudwatch_dashboard.operaciones.dashboard_name}"
}

output "composite_alarm_name" {
  description = "Alarma que resume si hay usuarios afectados en este momento"
  value       = aws_cloudwatch_composite_alarm.servicio_degradado.alarm_name
}

output "alarm_names" {
  description = "Todas las alarmas creadas, agrupadas por capa"
  value = {
    resumen = [aws_cloudwatch_composite_alarm.servicio_degradado.alarm_name]
    experiencia_usuario = [
      aws_cloudwatch_metric_alarm.sitio_caido.alarm_name,
      aws_cloudwatch_metric_alarm.tasa_error_alta.alarm_name,
      aws_cloudwatch_metric_alarm.latencia_alta.alarm_name,
    ]
    capacidad = [
      aws_cloudwatch_metric_alarm.frontend_sin_redundancia.alarm_name,
      aws_cloudwatch_metric_alarm.cluster_sin_capacidad.alarm_name,
      aws_cloudwatch_metric_alarm.frontend_cpu.alarm_name,
      aws_cloudwatch_metric_alarm.frontend_memoria.alarm_name,
    ]
    datos = [
      aws_cloudwatch_metric_alarm.mysql_caido.alarm_name,
      aws_cloudwatch_metric_alarm.mysql_cpu.alarm_name,
      aws_cloudwatch_metric_alarm.mysql_memoria.alarm_name,
      aws_cloudwatch_metric_alarm.efs_burst_credits.alarm_name,
      aws_cloudwatch_metric_alarm.efs_io_limite.alarm_name,
    ]
  }
}
