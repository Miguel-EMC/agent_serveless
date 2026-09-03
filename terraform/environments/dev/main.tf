locals {
  name_prefix = "rag-serverless-demo"
}

module "s3_documents" {
  source = "../../modules/s3-documents"

  name_prefix = local.name_prefix
  tags        = var.tags
}

module "rds_pgvector" {
  source = "../../modules/rds-pgvector"

  name_prefix = local.name_prefix
  admin_cidr  = var.admin_cidr

  # El SG de la Lambda todavía no existe; se conecta en la Fase 5.
  agent_security_group_id = null

  tags = var.tags
}
