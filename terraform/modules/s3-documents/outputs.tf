output "bucket_name" {
  description = "Nombre del bucket de documentos."
  value       = aws_s3_bucket.docs.id
}

output "bucket_arn" {
  description = "ARN del bucket de documentos."
  value       = aws_s3_bucket.docs.arn
}
