output "documents_bucket_name" {
  description = "Bucket S3 de los documentos fuente."
  value       = module.s3_documents.bucket_name
}

output "db_host" {
  description = "Hostname del endpoint de PostgreSQL."
  value       = module.rds_pgvector.db_host
}

output "db_port" {
  description = "Puerto de PostgreSQL."
  value       = module.rds_pgvector.db_port
}

output "db_name" {
  description = "Nombre de la base de datos inicial."
  value       = module.rds_pgvector.db_name
}

output "db_secret_arn" {
  description = "ARN del secreto con la contraseña del usuario maestro (gestionado por RDS)."
  value       = module.rds_pgvector.master_user_secret_arn
}

output "db_security_group_id" {
  description = "Security group de la instancia de base de datos."
  value       = module.rds_pgvector.security_group_id
}
