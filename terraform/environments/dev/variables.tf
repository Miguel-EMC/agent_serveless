variable "model_id" {
  type        = string
  description = "ID del modelo de generación del agente (Converse). Acota el permiso bedrock:InvokeModel del rol de la Lambda."
  default     = "amazon.nova-lite-v1:0"
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
