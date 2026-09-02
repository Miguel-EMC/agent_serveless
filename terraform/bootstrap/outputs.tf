output "state_bucket_name" {
  description = "Nombre del bucket S3 del remote state. Copiar a environments/dev/backend.tf."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN del bucket S3 del remote state."
  value       = aws_s3_bucket.state.arn
}

output "lock_table_name" {
  description = "Nombre de la tabla DynamoDB de locking."
  value       = aws_dynamodb_table.lock.name
}

output "lock_table_arn" {
  description = "ARN de la tabla DynamoDB de locking."
  value       = aws_dynamodb_table.lock.arn
}

output "region" {
  description = "Región AWS del backend."
  value       = var.region
}
