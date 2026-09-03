locals {
  name_prefix = "rag-serverless-demo"
}

module "s3_documents" {
  source = "../../modules/s3-documents"

  name_prefix = local.name_prefix
  tags        = var.tags
}
