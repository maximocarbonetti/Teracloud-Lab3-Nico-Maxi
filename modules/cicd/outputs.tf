# Outputs del modulo cicd

output "codestar_connection_arn" {
  description = "Autorizar manualmente en la consola de AWS (Developer Tools > Connections) despues del apply"
  value       = aws_codestarconnections_connection.github.arn
}

output "codestar_connection_status" {
  value = aws_codestarconnections_connection.github.connection_status
}

output "pipeline_name" {
  value = aws_codepipeline.this.name
}

output "codebuild_project_name" {
  value = aws_codebuild_project.this.name
}
