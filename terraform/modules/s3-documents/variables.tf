variable "name_prefix" {
  type        = string
  description = "Prefijo para el nombre del bucket de documentos."
}

variable "tags" {
  type        = map(string)
  description = "Tags a aplicar al bucket."
  default     = {}
}
