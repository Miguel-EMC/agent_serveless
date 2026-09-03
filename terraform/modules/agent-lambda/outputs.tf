output "function_name" {
  description = "Nombre de la función Lambda del agente."
  value       = aws_lambda_function.agent.function_name
}

output "function_arn" {
  description = "ARN de la función Lambda del agente."
  value       = aws_lambda_function.agent.arn
}

output "role_arn" {
  description = "ARN del rol de ejecución."
  value       = aws_iam_role.exec.arn
}

output "log_group_name" {
  description = "Nombre del log group de CloudWatch."
  value       = aws_cloudwatch_log_group.this.name
}
