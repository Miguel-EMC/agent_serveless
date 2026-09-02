provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "rag-serverless-demo"
      ManagedBy   = "terraform"
      Environment = "dev"
    }
  }
}
