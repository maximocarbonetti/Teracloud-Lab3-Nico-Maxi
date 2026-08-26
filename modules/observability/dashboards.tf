# Dashboards de CloudWatch
#
# Se publican dos, con audiencias distintas:
#
#   <prefix>-negocio      Responde "como esta el servicio para el usuario".
#                         Indicadores de nivel de servicio: disponibilidad,
#                         tasa de exito, latencia, volumen atendido.
#
#   <prefix>-operaciones  Responde "por que esta asi". Recursos, capacidad,
#                         estado de las tasks y salud del almacenamiento.

# =============================================================================
# DASHBOARD DE NEGOCIO
# =============================================================================
resource "aws_cloudwatch_dashboard" "negocio" {
  dashboard_name = "${var.name_prefix}-negocio"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = join("", [
            "# Estado del servicio — vision de negocio\n",
            "Indicadores de nivel de servicio (SLI) medidos sobre el trafico real. ",
            "**SLO comprometidos:** disponibilidad de peticiones exitosas ≥ ${100 - var.slo_error_rate_pct}% · latencia p99 ≤ ${var.slo_latency_p99_seconds}s.",
          ])
        }
      },

      # ---- Fila de KPIs (valores unicos) ----
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 6
        height = 4
        properties = {
          title   = "Tasa de exito (SLI)"
          view    = "singleValue"
          region  = local.region
          stat    = "Sum"
          period  = 3600
          sparkline = true
          metrics = [
            [{ expression = "IF(m_total > 0, ((m_total - m_err_app - m_err_alb) / m_total) * 100, 100)", label = "% peticiones exitosas", id = "exito" }],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_suffix, { id = "m_total", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alb_suffix, { id = "m_err_app", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.alb_suffix, { id = "m_err_alb", visible = false }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 2
        width  = 6
        height = 4
        properties = {
          title     = "Peticiones atendidas"
          view      = "singleValue"
          region    = local.region
          stat      = "Sum"
          period    = 3600
          sparkline = true
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_suffix, { label = "Peticiones" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 6
        height = 4
        properties = {
          title     = "Latencia p99"
          view      = "singleValue"
          region    = local.region
          stat      = "p99"
          period    = 3600
          sparkline = true
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_suffix, "TargetGroup", local.tg_suffix, { label = "Segundos (p99)" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 2
        width  = 6
        height = 4
        properties = {
          title     = "Instancias sirviendo trafico"
          view      = "singleValue"
          region    = local.region
          stat      = "Minimum"
          period    = 300
          sparkline = true
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", local.alb_suffix, "TargetGroup", local.tg_suffix, { label = "Sanas" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { label = "Con fallas" }],
          ]
        }
      },

      # ---- Series temporales ----
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Tasa de error vs. SLO"
          view   = "timeSeries"
          region = local.region
          period = 300
          yAxis  = { left = { min = 0, label = "%", showUnits = false } }
          metrics = [
            [{ expression = "IF(t > 0, ((ea + eb) / t) * 100, 0)", label = "Tasa de error (%)", id = "tasa", color = "#d62728" }],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_suffix, { id = "t", stat = "Sum", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alb_suffix, { id = "ea", stat = "Sum", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.alb_suffix, { id = "eb", stat = "Sum", visible = false }],
          ]
          annotations = {
            horizontal = [{
              label = "SLO: ${var.slo_error_rate_pct}%"
              value = var.slo_error_rate_pct
              fill  = "above"
              color = "#d62728"
            }]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Latencia percibida por el usuario"
          view   = "timeSeries"
          region = local.region
          period = 60
          yAxis  = { left = { min = 0, label = "segundos", showUnits = false } }
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_suffix, "TargetGroup", local.tg_suffix, { stat = "p99", label = "p99 (peor 1%)", color = "#d62728" }],
            ["...", { stat = "p90", label = "p90", color = "#ff7f0e" }],
            ["...", { stat = "p50", label = "p50 (mediana)", color = "#2ca02c" }],
          ]
          annotations = {
            horizontal = [{
              label = "SLO p99: ${var.slo_latency_p99_seconds}s"
              value = var.slo_latency_p99_seconds
              fill  = "above"
              color = "#d62728"
            }]
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 6
        properties = {
          title   = "Volumen de trafico por codigo de respuesta"
          view    = "timeSeries"
          stacked = true
          region  = local.region
          period  = 300
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", local.alb_suffix, { stat = "Sum", label = "2xx — exitosas", color = "#2ca02c" }],
            [".", "HTTPCode_Target_3XX_Count", ".", ".", { stat = "Sum", label = "3xx — redirecciones", color = "#1f77b4" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", label = "4xx — error del cliente", color = "#ff7f0e" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", label = "5xx — error del servidor", color = "#d62728" }],
          ]
        }
      },
      {
        type   = "alarm"
        x      = 0
        y      = 18
        width  = 24
        height = 3
        properties = {
          title = "Alarmas que afectan al usuario"
          alarms = [
            aws_cloudwatch_composite_alarm.servicio_degradado.arn,
            aws_cloudwatch_metric_alarm.sitio_caido.arn,
            aws_cloudwatch_metric_alarm.tasa_error_alta.arn,
            aws_cloudwatch_metric_alarm.latencia_alta.arn,
            aws_cloudwatch_metric_alarm.mysql_caido.arn,
          ]
        }
      },
    ]
  })
}

# =============================================================================
# DASHBOARD DE OPERACIONES
# =============================================================================
resource "aws_cloudwatch_dashboard" "operaciones" {
  dashboard_name = "${var.name_prefix}-operaciones"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = join("", [
            "# Operaciones — diagnostico\n",
            "Recursos, capacidad y persistencia. Se usa para responder **por que** ",
            "el dashboard de negocio muestra lo que muestra.",
          ])
        }
      },

      # ---- Capacidad del cluster ----
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Capacidad del cluster ECS (reservada vs. usada)"
          view   = "timeSeries"
          region = local.region
          period = 300
          yAxis  = { left = { min = 0, max = 100, label = "%", showUnits = false } }
          metrics = [
            ["AWS/ECS", "CPUReservation", "ClusterName", var.cluster_name, { stat = "Average", label = "CPU reservada" }],
            [".", "MemoryReservation", ".", ".", { stat = "Average", label = "Memoria reservada" }],
            [".", "CPUUtilization", ".", ".", { stat = "Average", label = "CPU en uso real" }],
            [".", "MemoryUtilization", ".", ".", { stat = "Average", label = "Memoria en uso real" }],
          ]
          annotations = {
            horizontal = [{
              label = "Sin espacio para nuevas tasks"
              value = var.cluster_reservation_threshold
              fill  = "above"
              color = "#ff7f0e"
            }]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Tasks corriendo por servicio"
          view   = "timeSeries"
          region = local.region
          period = 60
          yAxis  = { left = { min = 0, label = "tasks", showUnits = false } }
          metrics = [
            ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.cluster_name, "ServiceName", var.frontend_service_name, { stat = "Average", label = "Frontend" }],
            ["...", var.mysql_service_name, { stat = "Average", label = "MySQL" }],
            ["ECS/ContainerInsights", "PendingTaskCount", "ClusterName", var.cluster_name, "ServiceName", var.frontend_service_name, { stat = "Average", label = "Frontend (pendientes)" }],
          ]
          annotations = {
            horizontal = [{
              label = "Frontend deseado: ${var.frontend_desired_count}"
              value = var.frontend_desired_count
              color = "#2ca02c"
            }]
          }
        }
      },

      # ---- Recursos por servicio ----
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Frontend — CPU y memoria"
          view   = "timeSeries"
          region = local.region
          period = 60
          yAxis  = { left = { min = 0, max = 100, label = "%", showUnits = false } }
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.frontend_service_name, { stat = "Average", label = "CPU" }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { stat = "Average", label = "Memoria" }],
          ]
          annotations = {
            horizontal = [{ label = "Umbral", value = var.cpu_alarm_threshold, fill = "above", color = "#ff7f0e" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "MySQL — CPU y memoria"
          view   = "timeSeries"
          region = local.region
          period = 60
          yAxis  = { left = { min = 0, max = 100, label = "%", showUnits = false } }
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.mysql_service_name, { stat = "Average", label = "CPU" }],
            [".", "MemoryUtilization", ".", ".", ".", ".", { stat = "Average", label = "Memoria" }],
          ]
          annotations = {
            horizontal = [{ label = "Umbral", value = var.cpu_alarm_threshold, fill = "above", color = "#ff7f0e" }]
          }
        }
      },

      # ---- Persistencia ----
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 8
        height = 6
        properties = {
          title  = "EFS — creditos de burst disponibles"
          view   = "timeSeries"
          region = local.region
          period = 300
          yAxis  = { left = { min = 0, label = "bytes", showUnits = false } }
          metrics = [
            ["AWS/EFS", "BurstCreditBalance", "FileSystemId", var.efs_file_system_id, { stat = "Average", label = "Creditos" }],
          ]
          annotations = {
            horizontal = [{
              label = "Umbral de degradacion"
              value = var.efs_burst_credit_threshold_bytes
              fill  = "below"
              color = "#d62728"
            }]
          }
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 14
        width  = 8
        height = 6
        properties = {
          title  = "EFS — uso del limite de I/O"
          view   = "timeSeries"
          region = local.region
          period = 300
          yAxis  = { left = { min = 0, max = 100, label = "%", showUnits = false } }
          metrics = [
            ["AWS/EFS", "PercentIOLimit", "FileSystemId", var.efs_file_system_id, { stat = "Average", label = "% del limite" }],
          ]
          annotations = {
            horizontal = [{ label = "Saturacion", value = 90, fill = "above", color = "#d62728" }]
          }
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 14
        width  = 8
        height = 6
        properties = {
          title  = "EFS — throughput"
          view   = "timeSeries"
          region = local.region
          period = 300
          metrics = [
            ["AWS/EFS", "DataReadIOBytes", "FileSystemId", var.efs_file_system_id, { stat = "Sum", label = "Lectura" }],
            [".", "DataWriteIOBytes", ".", ".", { stat = "Sum", label = "Escritura" }],
          ]
        }
      },

      # ---- Logs ----
      {
        type   = "log"
        x      = 0
        y      = 20
        width  = 24
        height = 6
        properties = {
          title  = "Ultimos errores en los logs de la aplicacion"
          region = local.region
          query  = "SOURCE '/ecs/${var.name_prefix}-frontend' | fields @timestamp, @message | filter @message like /(?i)(error|fatal|exception|denied)/ | sort @timestamp desc | limit 25"
          view   = "table"
        }
      },

      {
        type   = "alarm"
        x      = 0
        y      = 26
        width  = 24
        height = 4
        properties = {
          title = "Todas las alarmas"
          alarms = [
            aws_cloudwatch_composite_alarm.servicio_degradado.arn,
            aws_cloudwatch_metric_alarm.sitio_caido.arn,
            aws_cloudwatch_metric_alarm.tasa_error_alta.arn,
            aws_cloudwatch_metric_alarm.latencia_alta.arn,
            aws_cloudwatch_metric_alarm.frontend_sin_redundancia.arn,
            aws_cloudwatch_metric_alarm.cluster_sin_capacidad.arn,
            aws_cloudwatch_metric_alarm.frontend_cpu.arn,
            aws_cloudwatch_metric_alarm.frontend_memoria.arn,
            aws_cloudwatch_metric_alarm.mysql_caido.arn,
            aws_cloudwatch_metric_alarm.mysql_cpu.arn,
            aws_cloudwatch_metric_alarm.mysql_memoria.arn,
            aws_cloudwatch_metric_alarm.efs_burst_credits.arn,
            aws_cloudwatch_metric_alarm.efs_io_limite.arn,
          ]
        }
      },
    ]
  })
}
