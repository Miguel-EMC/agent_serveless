variable "prefix" {
  type        = string
  description = "Prefijo para nombrar los recursos del bootstrap (bucket de state y tabla de lock)."
  default     = "rag-serverless-demo"
}

variable "region" {
  type        = string
  description = "Región AWS donde se crean el bucket de state y la tabla de lock."
  default     = "us-east-1"
}
