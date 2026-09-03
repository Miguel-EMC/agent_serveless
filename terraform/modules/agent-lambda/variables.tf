variable "name_prefix" {
  type        = string
  description = "Prefijo para nombrar la función, el rol y el log group."
}

variable "knowledge_base_id" {
  type        = string
  description = "ID de la Bedrock Knowledge Base que el agente consulta."
}

variable "knowledge_base_arn" {
  type        = string
  description = "ARN de la Knowledge Base (para acotar el permiso bedrock:Retrieve)."
}

variable "model_id" {
  type        = string
  description = "ID del modelo de generación (Converse). Acota también el permiso bedrock:InvokeModel."
  default     = "amazon.nova-lite-v1:0"
}

variable "top_k" {
  type        = number
  description = "Número de fragmentos a recuperar."
  default     = 5
}

variable "min_score" {
  type        = number
  description = "Umbral de score para descartar fragmentos poco relevantes."
  default     = 0.4
}

variable "region" {
  type        = string
  description = "Región AWS (para construir el ARN del modelo)."
  default     = "us-east-1"
}

variable "log_retention_days" {
  type        = number
  description = "Retención de logs de CloudWatch."
  default     = 14
}

variable "tags" {
  type        = map(string)
  description = "Tags a aplicar a los recursos."
  default     = {}
}
