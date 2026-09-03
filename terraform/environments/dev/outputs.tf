output "documents_bucket_name" {
  description = "Bucket S3 de los documentos fuente."
  value       = module.s3_documents.bucket_name
}
