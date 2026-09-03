variable "tags" {
  type        = map(string)
  description = "Tags comunes para los recursos del entorno dev."
  default = {
    Project     = "rag-serverless-demo"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
