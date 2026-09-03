terraform {
  backend "s3" {
    # bucket: output `state_bucket_name` del bootstrap
    #         (terraform -chdir=terraform/bootstrap output -raw state_bucket_name)
    bucket = "rag-serverless-demo-tfstate-777a8ea1"

    key    = "dev/terraform.tfstate"
    region = "us-east-1"
    # Locking con DynamoDB (arquitectura decidida). Terraform >= 1.11 marca este
    # parámetro como deprecado a favor de use_lockfile (S3 nativo); el aviso es
    # cosmético y se mantiene la tabla a propósito.
    dynamodb_table = "rag-serverless-demo-tflock"
    encrypt        = true
  }
}
