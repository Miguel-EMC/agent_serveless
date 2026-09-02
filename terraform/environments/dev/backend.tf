terraform {
  backend "s3" {
    # bucket: output `state_bucket_name` del bootstrap
    #         (terraform -chdir=terraform/bootstrap output -raw state_bucket_name)
    bucket = "rag-serverless-demo-tfstate-777a8ea1"

    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "rag-serverless-demo-tflock"
    encrypt        = true
  }
}
