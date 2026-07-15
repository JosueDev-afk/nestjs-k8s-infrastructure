terraform {
  # Backend remoto: crear el bucket una sola vez (versioning + SSE habilitados):
  #   aws s3api create-bucket --bucket <TU-BUCKET-TFSTATE> --region us-east-1
  # y reemplazar el nombre aquí. Estado segmentado por capa = blast radius mínimo.
  backend "s3" {
    bucket       = "CHANGEME-nestjs-k8s-tfstate"
    key          = "aws/dev/data/terraform.tfstate"
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
