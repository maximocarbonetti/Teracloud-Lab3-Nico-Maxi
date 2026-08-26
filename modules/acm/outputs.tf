# Outputs del modulo acm

output "certificate_arn" {
  description = "ARN del certificado validado (para usar en el listener HTTPS del ALB)"
  value       = aws_acm_certificate_validation.this.certificate_arn
}
