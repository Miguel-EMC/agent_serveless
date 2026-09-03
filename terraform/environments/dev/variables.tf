variable "admin_cidr" {
  type        = string
  description = "CIDR de administración con acceso al puerto 5432 de la BD (p. ej. la IP del operador en /32) para el setup de pgvector e inspección. null = sin regla."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags comunes para los recursos del entorno dev."
  default = {
    Project     = "rag-serverless-demo"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
