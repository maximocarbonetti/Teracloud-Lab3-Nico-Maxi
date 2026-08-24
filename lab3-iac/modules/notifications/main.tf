# Recursos del modulo notifications
#
# Un topico SNS con suscripciones por email. Lo usan tanto "cicd" (estado
# del pipeline) como "observability" (alarmas de Cloudwatch).
# Nota: cada email debe confirmar la suscripcion (link que llega por correo)
# antes de empezar a recibir notificaciones.

resource "aws_sns_topic" "this" {
  name = var.name
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.email_addresses)

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}
