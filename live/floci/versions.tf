terraform {
  # Backend S3 apuntado a floci (emulador). Sin use_lockfile: el locking nativo
  # usa PutObject condicional (If-None-Match) que el S3 emulado puede no soportar.
  backend "s3" {
    bucket = "nestjsk8s-dev-tfstate" # bucket ya creado en floci
    key    = "floci/dev.tfstate"
    region = "us-east-1"

    endpoints                   = { s3 = "http://floci-floci-bovybt-755121-76-13-24-93.sslip.io" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
  }

  required_version = ">= 1.10"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 5.55 soporta el override global AWS_ENDPOINT_URL (base endpoint)
      version = ">= 5.55"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}
