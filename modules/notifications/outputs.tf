# Outputs del modulo notifications

output "topic_arn" {
  value = aws_sns_topic.this.arn
}
