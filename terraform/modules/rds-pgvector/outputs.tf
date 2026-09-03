output "db_host" {
  description = "Hostname del endpoint de la instancia PostgreSQL."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Puerto de PostgreSQL."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Nombre de la base de datos inicial."
  value       = aws_db_instance.this.db_name
}

output "master_user_secret_arn" {
  description = "ARN del secreto de Secrets Manager con la contraseña del usuario maestro (gestionado por RDS)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "security_group_id" {
  description = "ID del security group de la instancia."
  value       = aws_security_group.db.id
}
