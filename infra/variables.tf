variable "s3_bucket_name" {
  description = "The name of the S3 bucket to create"
  type        = string
}
variable "s3_bucket_region" {
  description = "The AWS region where the S3 bucket will be created"
  type        = string
  default     = "us-east-1"
}

variable "bedrock_instance_type" {
  description = "The instance type for the Bedrock service"
  type        = string
  default     = "t3.medium"
}
variable "rds_pgvector_instance_type" {
  description = "The instance type for the RDS PostgreSQL service"
  type        = string
  default     = "db.t3.medium"
}
variable "rds_pgvector_allocated_storage" {
  description = "The allocated storage (in GB) for the RDS PostgreSQL service"
  type        = number
  default     = 20
}
