# Recursos del modulo observability
#
# Alarmas sobre los KPIs clave de la arquitectura (salud del ALB, CPU/memoria
# de los dos servicios ECS) + un dashboard que junta todo. Las alarmas
# publican al topico SNS de "notifications".

locals {
  # CloudWatch necesita el "suffix" del ARN para las dimensiones, no el ARN completo:
  #   ALB:          app/<name>/<id>          (sin el prefijo "loadbalancer/")
  #   Target group: targetgroup/<name>/<id>  (con el prefijo "targetgroup/")
  alb_suffix = regex("loadbalancer/(.*)$", var.alb_arn)[0]
  tg_suffix  = regex("(targetgroup/.*)$", var.target_group_arn)[0]
}

# -----------------------------------------------------------------------------
# Alarmas - ALB
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name_prefix}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = var.http_5xx_threshold
  treat_missing_data  = "notBreaching"
  alarm_description   = "Muchos errores 5xx del target group del frontend"

  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.tg_suffix
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.name_prefix}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_description   = "Hay instancias del frontend marcadas unhealthy en el target group"

  dimensions = {
    LoadBalancer = local.alb_suffix
    TargetGroup  = local.tg_suffix
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions    = [var.sns_topic_arn]
  tags          = var.tags
}

# -----------------------------------------------------------------------------
# Alarmas - ECS frontend
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "frontend_cpu" {
  alarm_name          = "${var.name_prefix}-frontend-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
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
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "frontend_memory" {
  alarm_name          = "${var.name_prefix}-frontend-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
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
  tags          = var.tags
}

# -----------------------------------------------------------------------------
# Alarmas - ECS mysql
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "mysql_cpu" {
  alarm_name          = "${var.name_prefix}-mysql-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
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
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "mysql_memory" {
  alarm_name          = "${var.name_prefix}-mysql-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 3
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
  tags          = var.tags
}

# -----------------------------------------------------------------------------
# Dashboard
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.name_prefix}-health"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB - Requests / 5xx"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_suffix, { stat = "Sum" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alb_suffix, { stat = "Sum" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB - Latencia / Hosts sanos"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_suffix, { stat = "Average" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", local.alb_suffix, "TargetGroup", local.tg_suffix, { stat = "Average" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS Frontend - CPU / Memoria"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.frontend_service_name, { stat = "Average" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", var.frontend_service_name, { stat = "Average" }],
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS MySQL - CPU / Memoria"
          view   = "timeSeries"
          region = data.aws_region.current.name
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", var.mysql_service_name, { stat = "Average" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", var.mysql_service_name, { stat = "Average" }],
          ]
        }
      }
    ]
  })
}

data "aws_region" "current" {}
