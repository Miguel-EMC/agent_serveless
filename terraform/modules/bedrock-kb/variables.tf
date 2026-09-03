variable "name_prefix" {
  type        = string
  description = "Prefijo para nombrar los recursos de la Knowledge Base."
}

variable "documents_bucket_arn" {
  type        = string
  description = "ARN del bucket S3 con los documentos fuente."
}

variable "documents_bucket_name" {
  type        = string
  description = "Nombre del bucket S3 con los documentos fuente."
}

variable "embedding_dimension" {
  type        = number
  description = "Dimensión de los embeddings. Debe coincidir en el índice y en el modelo. INMUTABLE en el índice. Titan Text Embeddings v2: 1024 (default), 512 o 256."
  default     = 1024
}

variable "region" {
  type        = string
  description = "Región AWS (para construir los ARN de modelo y de la condición de trust)."
  default     = "us-east-1"
}

variable "tags" {
  type        = map(string)
  description = "Tags a aplicar a los recursos."
  default     = {}
}
