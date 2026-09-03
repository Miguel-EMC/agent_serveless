locals {
  name_prefix = "rag-serverless-demo"
}

module "s3_documents" {
  source = "../../modules/s3-documents"

  name_prefix = local.name_prefix
  tags        = var.tags
}

module "bedrock_kb" {
  source = "../../modules/bedrock-kb"

  name_prefix           = local.name_prefix
  documents_bucket_arn  = module.s3_documents.bucket_arn
  documents_bucket_name = module.s3_documents.bucket_name
  tags                  = var.tags
}
