terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "docs" {
  bucket = "${var.name_prefix}-docs-${random_id.suffix.hex}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket                  = aws_s3_bucket.docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "docs" {
  bucket = aws_s3_bucket.docs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Fija los prefijos de organización. raw/ = documentos originales,
# processed/ = reservado para uso futuro.
resource "aws_s3_object" "raw_prefix" {
  bucket  = aws_s3_bucket.docs.id
  key     = "raw/.keep"
  content = ""
}

resource "aws_s3_object" "processed_prefix" {
  bucket  = aws_s3_bucket.docs.id
  key     = "processed/.keep"
  content = ""
}
