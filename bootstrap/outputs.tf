output "tfstate_bucket_name" {
  description = "Nombre del bucket S3 creado para el tfstate remoto"
  value       = aws_s3_bucket.tfstate.id
}

output "tfstate_bucket_arn" {
  description = "ARN del bucket S3 de tfstate"
  value       = aws_s3_bucket.tfstate.arn
}

output "backend_config_snippet" {
  description = "Snippet para pegar en environments/<env>/backend.tf"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${aws_s3_bucket.tfstate.id}"
        key          = "${var.environment}/terraform.tfstate"
        region       = "${var.aws_region}"
        encrypt      = true
        use_lockfile = true   # lock nativo de S3, no requiere DynamoDB
      }
    }
  EOT
}
