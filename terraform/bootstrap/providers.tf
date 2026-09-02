# Credenciales: se toman del entorno (AWS_PROFILE / AWS_ACCESS_KEY_ID / SSO).
# Nunca se hardcodean aquí.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "rag-serverless-demo"
      ManagedBy = "terraform"
      Component = "tf-bootstrap"
    }
  }
}
