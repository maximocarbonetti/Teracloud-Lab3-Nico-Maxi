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

# La consola de AWS agrega esta policy sola cuando creas una notification rule
# a mano; por Terraform hay que declararla, si no CodeStar Notifications (y
# CloudWatch) no pueden publicar en el topico.
data "aws_iam_policy_document" "topic_policy" {
  statement {
    sid     = "AllowServicesToPublish"
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type = "Service"
      identifiers = [
        "codestar-notifications.amazonaws.com",
        "cloudwatch.amazonaws.com",
      ]
    }

    resources = [aws_sns_topic.this.arn]
  }

  statement {
    sid     = "AllowAccountOwnerFullControl"
    effect  = "Allow"
    actions = [
      "SNS:Publish",
      "SNS:Subscribe",
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:ListSubscriptionsByTopic",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }

    resources = [aws_sns_topic.this.arn]
  }
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.topic_policy.json
}

data "aws_caller_identity" "current" {}
