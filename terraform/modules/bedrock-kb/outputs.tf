output "knowledge_base_id" {
  description = "ID de la Bedrock Knowledge Base."
  value       = aws_bedrockagent_knowledge_base.this.id
}

output "knowledge_base_arn" {
  description = "ARN de la Bedrock Knowledge Base."
  value       = aws_bedrockagent_knowledge_base.this.arn
}

output "data_source_id" {
  description = "ID del data source S3 de la Knowledge Base."
  value       = aws_bedrockagent_data_source.this.data_source_id
}

output "vector_index_arn" {
  description = "ARN del índice de S3 Vectors."
  value       = aws_s3vectors_index.this.index_arn
}

output "vector_bucket_name" {
  description = "Nombre del vector bucket de S3 Vectors."
  value       = aws_s3vectors_vector_bucket.this.vector_bucket_name
}

output "role_arn" {
  description = "ARN del rol IAM de la Knowledge Base."
  value       = aws_iam_role.kb.arn
}
