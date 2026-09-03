variable "name_prefix" {
  type        = string
  description = "Prefijo para nombrar los recursos de la base vectorial."
}

variable "db_name" {
  type        = string
  description = "Nombre de la base de datos inicial."
  default     = "ragdb"
}

variable "master_username" {
  type        = string
  description = "Usuario maestro de PostgreSQL."
  default     = "ragadmin"
}

variable "instance_class" {
  type        = string
  description = "Clase de instancia RDS (free tier: db.t3.micro)."
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Almacenamiento en GB (free tier: 20)."
  default     = 20
}

variable "engine_version" {
  type        = string
  description = "Versión de PostgreSQL. Puede ser solo el major (\"16\") o major.minor (\"16.4\"). El parameter group deriva su familia del major."
  default     = "16"

  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?$", var.engine_version))
    error_message = "engine_version debe ser un major (\"16\") o major.minor (\"16.4\")."
  }
}

variable "agent_security_group_id" {
  type        = string
  description = "Security group del cómputo del agente (Lambda). Se conecta en la Fase 5; null hasta entonces."
  default     = null
}

variable "admin_cidr" {
  type        = string
  description = "CIDR de administración autorizado al puerto 5432 (p. ej. la IP del operador en /32) para setup e inspección. null = sin regla."
  default     = null

  validation {
    condition     = var.admin_cidr == null || var.admin_cidr != "0.0.0.0/0"
    error_message = "admin_cidr no puede ser 0.0.0.0/0: la base de datos no debe quedar expuesta al mundo."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags a aplicar a los recursos."
  default     = {}
}
