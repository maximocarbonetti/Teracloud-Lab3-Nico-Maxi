# Recursos del modulo observability
#
# Las alarmas estan organizadas en tres capas, de fuera hacia adentro:
#
#   1. Experiencia del usuario  -> mide lo que el cliente efectivamente sufre
#                                  (disponibilidad, errores, latencia). Son los
#                                  SLI del servicio y las que justifican
#                                  despertar a alguien.
#   2. Capacidad                -> mide si el sistema tiene margen para seguir
#                                  operando. Alarman ANTES de que el usuario
#                                  note algo.
#   3. Datos y persistencia     -> mide la salud de la base y su almacenamiento.
#                                  Es la capa donde un problema es irreversible.
#
# Una alarma compuesta al final resume "el servicio esta degradado" en una sola
# senal, para no tener que interpretar doce alarmas sueltas durante un incidente.

data "aws_region" "current" {}

locals {
  # CloudWatch usa el "suffix" del ARN como dimension, no el ARN completo:
  #   ALB:          app/<name>/<id>          (sin el prefijo "loadbalancer/")
  #   Target group: targetgroup/<name>/<id>  (con el prefijo "targetgroup/")
  alb_suffix = regex("loadbalancer/(.*)$", var.alb_arn)[0]
  tg_suffix  = regex("(targetgroup/.*)$", var.target_group_arn)[0]

  region = data.aws_region.current.name
}

# =============================================================================
# CAPA 1 - EXPERIENCIA DEL USUARIO (SLI)
# =============================================================================

# ---- Disponibilidad ---------------------------------------------------------
# La mas importante de todas: no queda ninguna instancia sana detras del
# balanceador, con lo cual el sitio devuelve 503 a todo el mundo. Periodo corto
# y pocas evaluaciones porque acá cada minuto cuenta.
resource "aws_cloudwatch_metric_alarm" "sitio_caido" {
  alarm_name          = "${var.name_prefix}-01-CRITICA-sitio-caido"
  alarm_description   = "CRITICA. No hay ninguna instancia sana en el target group: el sitio no responde a ningun usuario. Impacto de negocio: caida total del servicio. Revisar el estado del servicio ECS del frontend y los eventos del cluster."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.tg_suffix
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "experiencia-usuario", Severidad = "critica" })
}

# ---- Tasa de error (SLI de exito) -------------------------------------------
# Un contador absoluto de errores no dice nada sin el volumen: 50 errores sobre
# 10.000 peticiones es ruido, sobre 60 es un incidente. Por eso se calcula el
# porcentaje con metric math, sumando los 5xx de la aplicacion y los del propio
# balanceador. El IF evita que con trafico bajo un solo error dispare la alarma.
resource "aws_cloudwatch_metric_alarm" "tasa_error_alta" {
  alarm_name          = "${var.name_prefix}-02-CRITICA-tasa-error-alta"
  alarm_description   = "CRITICA. Mas del ${var.slo_error_rate_pct}% de las peticiones termina en error 5xx, incumpliendo el SLO de exito del ${100 - var.slo_error_rate_pct}%. Impacto de negocio: usuarios reales viendo errores. Revisar los logs de la aplicacion y la conectividad con la base."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = var.slo_error_rate_pct
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "tasa_error"
    expression  = "IF(peticiones >= ${var.min_requests_for_error_rate}, ((errores_app + errores_alb) / peticiones) * 100, 0)"
    label       = "Tasa de error (%)"
    return_data = true
  }

  metric_query {
    id = "peticiones"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions  = { LoadBalancer = local.alb_suffix }
    }
  }

  metric_query {
    id = "errores_app"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions  = { LoadBalancer = local.alb_suffix }
    }
  }

  metric_query {
    id = "errores_alb"
    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions  = { LoadBalancer = local.alb_suffix }
    }
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "experiencia-usuario", Severidad = "critica" })
}

# ---- Latencia percentil 99 --------------------------------------------------
# Se usa p99 y no el promedio a proposito: el promedio esconde la cola. Con
# 1000 peticiones, si 10 tardan 30 segundos el promedio apenas se mueve, pero
# esos 10 usuarios abandonan el sitio. El p99 es la experiencia del peor 1%.
resource "aws_cloudwatch_metric_alarm" "latencia_alta" {
  alarm_name          = "${var.name_prefix}-03-ALTA-latencia-p99"
  alarm_description   = "El percentil 99 de latencia supera los ${var.slo_latency_p99_seconds}s: el 1% de los usuarios percibe el sitio como lento o caido. Impacto de negocio: abandono. Revisar saturacion del frontend y tiempos de respuesta de la base."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p99"
  threshold           = var.slo_latency_p99_seconds
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.tg_suffix
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "experiencia-usuario", Severidad = "alta" })
}

# =============================================================================
# CAPA 2 - CAPACIDAD
# =============================================================================

# ---- Tasks del frontend por debajo de lo deseado ----------------------------
# Avisa que se perdio redundancia aunque el sitio siga respondiendo: con una
# sola task viva, cualquier falla adicional es una caida total.
resource "aws_cloudwatch_metric_alarm" "frontend_sin_redundancia" {
  alarm_name          = "${var.name_prefix}-04-ALTA-frontend-sin-redundancia"
  alarm_description   = "Corren menos de ${var.frontend_desired_count} tasks del frontend. El sitio puede seguir respondiendo, pero se perdio la redundancia: una falla mas es una caida total. Revisar si hay capacidad libre en el cluster."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.frontend_desired_count
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.frontend_service_name
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "capacidad", Severidad = "alta" })
}

# ---- Cluster sin espacio ----------------------------------------------------
# Metrica de reserva, no de uso: mide cuanta capacidad esta comprometida por las
# task definitions. Si esta al tope, el escalado y los despliegues fallan aunque
# el consumo real sea bajo.
resource "aws_cloudwatch_metric_alarm" "cluster_sin_capacidad" {
  alarm_name          = "${var.name_prefix}-05-MEDIA-cluster-sin-capacidad"
  alarm_description   = "Mas del ${var.cluster_reservation_threshold}% de la CPU del cluster esta reservada. No entran tasks nuevas: los despliegues y el escalado van a fallar. Impacto de negocio: no se puede publicar. Sumar instancias al Auto Scaling Group."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUReservation"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cluster_reservation_threshold
  treat_missing_data  = "notBreaching"

  dimensions = { ClusterName = var.cluster_name }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "capacidad", Severidad = "media" })
}

# ---- Saturacion del frontend ------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "frontend_cpu" {
  alarm_name          = "${var.name_prefix}-06-MEDIA-frontend-cpu"
  alarm_description   = "CPU del servicio frontend sostenida por encima del ${var.cpu_alarm_threshold}%. Antesala de la degradacion de latencia. Evaluar escalar horizontalmente."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.frontend_service_name
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "capacidad", Severidad = "media" })
}

resource "aws_cloudwatch_metric_alarm" "frontend_memoria" {
  alarm_name          = "${var.name_prefix}-07-MEDIA-frontend-memoria"
  alarm_description   = "Memoria del servicio frontend por encima del ${var.memory_alarm_threshold}%. Riesgo de que ECS mate el contenedor por OOM."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.frontend_service_name
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "capacidad", Severidad = "media" })
}

# =============================================================================
# CAPA 3 - DATOS Y PERSISTENCIA
# =============================================================================

# ---- Base de datos caida ----------------------------------------------------
# La aplicacion puede seguir sirviendo HTML sin base, pero no cumple su funcion.
# Es critica porque ademas es la capa donde los problemas son irreversibles.
resource "aws_cloudwatch_metric_alarm" "mysql_caido" {
  alarm_name          = "${var.name_prefix}-08-CRITICA-mysql-caido"
  alarm_description   = "CRITICA. No hay ninguna task de MySQL corriendo. Impacto de negocio: la aplicacion no puede leer ni escribir datos. Si la task no logra arrancar, revisar el montaje del volumen EFS y los eventos del servicio."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.mysql_service_name
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "datos", Severidad = "critica" })
}

resource "aws_cloudwatch_metric_alarm" "mysql_cpu" {
  alarm_name          = "${var.name_prefix}-09-MEDIA-mysql-cpu"
  alarm_description   = "CPU de MySQL sostenida por encima del ${var.cpu_alarm_threshold}%. Suele indicar consultas sin indice o falta de recursos asignados a la task."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.mysql_service_name
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "datos", Severidad = "media" })
}

resource "aws_cloudwatch_metric_alarm" "mysql_memoria" {
  alarm_name          = "${var.name_prefix}-10-MEDIA-mysql-memoria"
  alarm_description   = "Memoria de MySQL por encima del ${var.memory_alarm_threshold}%. Si ECS mata el contenedor por OOM, la base se reinicia y se cortan las conexiones abiertas."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.memory_alarm_threshold
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.mysql_service_name
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "datos", Severidad = "media" })
}

# ---- Creditos de burst de EFS ----------------------------------------------
# En modo bursting, EFS acumula creditos mientras no se usa y los consume al
# leer/escribir. Agotados, el throughput cae al minimo garantizado y la base se
# vuelve lentisima. Es una falla silenciosa: no hay error, solo lentitud.
resource "aws_cloudwatch_metric_alarm" "efs_burst_credits" {
  alarm_name          = "${var.name_prefix}-11-ALTA-efs-creditos-bajos"
  alarm_description   = "Los creditos de burst del EFS estan por agotarse. Cuando lleguen a cero el throughput del volumen cae al minimo garantizado y MySQL se degrada de forma severa, sin arrojar ningun error. Evaluar migrar el filesystem a throughput provisionado."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3
  metric_name         = "BurstCreditBalance"
  namespace           = "AWS/EFS"
  period              = 300
  statistic           = "Average"
  threshold           = var.efs_burst_credit_threshold_bytes
  treat_missing_data  = "notBreaching"

  dimensions = { FileSystemId = var.efs_file_system_id }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "datos", Severidad = "alta" })
}

# ---- Limite de I/O de EFS ---------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "efs_io_limite" {
  alarm_name          = "${var.name_prefix}-12-MEDIA-efs-limite-io"
  alarm_description   = "El EFS opera por encima del 90% de su limite de operaciones de I/O. Las escrituras de MySQL empiezan a encolarse. Impacto de negocio: lentitud generalizada en la aplicacion."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "PercentIOLimit"
  namespace           = "AWS/EFS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  treat_missing_data  = "notBreaching"

  dimensions = { FileSystemId = var.efs_file_system_id }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "datos", Severidad = "media" })
}

# =============================================================================
# ALARMA COMPUESTA - ESTADO GENERAL DEL SERVICIO
# =============================================================================
#
# Durante un incidente real llegan varias alarmas a la vez y hay que deducir la
# gravedad. Esta las resume en una sola senal accionable: si esta en ALARM, hay
# usuarios afectados ahora.
resource "aws_cloudwatch_composite_alarm" "servicio_degradado" {
  alarm_name        = "${var.name_prefix}-00-SERVICIO-DEGRADADO"
  alarm_description = "Resumen del estado del servicio. Se dispara si el sitio no responde, si la tasa de error supera el SLO, o si la base de datos no esta disponible. Una sola senal para saber si hay usuarios afectados en este momento."

  alarm_rule = join(" OR ", [
    "ALARM(${aws_cloudwatch_metric_alarm.sitio_caido.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.tasa_error_alta.alarm_name})",
    "ALARM(${aws_cloudwatch_metric_alarm.mysql_caido.alarm_name})",
  ])

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = merge(var.tags, { Capa = "resumen", Severidad = "critica" })
}
