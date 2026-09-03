terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Major de PostgreSQL, para derivar la familia del parameter group.
  postgres_major = split(".", var.engine_version)[0]
}

# ---------------------------------------------------------------------------
# Red: se usa la VPC default de la cuenta (ver design.md DD1).
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db"
  subnet_ids = data.aws_subnets.default.ids
  tags       = var.tags
}

# ---------------------------------------------------------------------------
# Security group: NADA de ingress a 0.0.0.0/0 (ver design.md DD2).
# Reglas de ingress separadas y condicionales.
# ---------------------------------------------------------------------------
resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db"
  description = "Acceso a PostgreSQL solo desde el agente y el CIDR de administracion."
  vpc_id      = data.aws_vpc.default.id
  tags        = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "from_agent" {
  count = var.agent_security_group_id == null ? 0 : 1

  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL desde el cómputo del agente."
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.agent_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "from_admin" {
  count = var.admin_cidr == null ? 0 : 1

  security_group_id = aws_security_group.db.id
  description       = "PostgreSQL desde el CIDR de administracion (setup e inspeccion)."
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.db.id
  description       = "Salida sin restriccion."
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Grupo de parámetros: TLS obligatorio (ver design.md DD5).
# ---------------------------------------------------------------------------
resource "aws_db_parameter_group" "this" {
  name   = "${var.name_prefix}-pg${local.postgres_major}"
  family = "postgres${local.postgres_major}"
  tags   = var.tags

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot" # parámetro estático
  }
}

# ---------------------------------------------------------------------------
# Instancia PostgreSQL. La contraseña la gestiona RDS en Secrets Manager
# (manage_master_user_password = true): nunca entra al state (ver design.md DD4).
# pgvector se instala aparte con psql (ver design.md DD3 / runbook Fase 2).
# ---------------------------------------------------------------------------
resource "aws_db_instance" "this" {
  identifier     = "${var.name_prefix}-pgvector"
  engine         = "postgres"
  engine_version = var.engine_version

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name                     = var.db_name
  username                    = var.master_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = true
  multi_az               = false

  backup_retention_period    = 1
  skip_final_snapshot        = true
  deletion_protection        = false
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = var.tags
}
