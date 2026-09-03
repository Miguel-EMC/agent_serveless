output "documents_bucket_name" {
  description = "Bucket S3 de los documentos fuente."
  value       = module.s3_documents.bucket_name
}

output "knowledge_base_id" {
  description = "ID de la Bedrock Knowledge Base."
  value       = module.bedrock_kb.knowledge_base_id
}

output "data_source_id" {
  description = "ID del data source S3 de la Knowledge Base."
  value       = module.bedrock_kb.data_source_id
}

output "vector_bucket_name" {
  description = "Nombre del vector bucket de S3 Vectors."
  value       = module.bedrock_kb.vector_bucket_name
}
