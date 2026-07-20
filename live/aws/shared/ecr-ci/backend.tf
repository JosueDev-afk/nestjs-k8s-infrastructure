terraform {
  # Capa compartida entre entornos: los repos ECR y el rol OIDC de CI se
  # crean una sola vez (las imágenes se promueven dev -> prod por tag).
  backend "s3" {
    bucket       = "CHANGEME-nestjs-k8s-tfstate"
    key          = "aws/shared/ecr-ci/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # lock nativo S3 (Terraform >= 1.10)
  }

  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40"
    }
  }
}
