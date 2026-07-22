# =============================================================================
# Escenario de prueba contra floci (emulador de AWS en la VPS).
# NO es un entorno real: reutiliza los mismos modules/aws/* que dev/prod para
# validar que la IaC aplica contra una API con forma de AWS, sin cuenta ni costos.
#
# El endpoint se inyecta por AWS_ENDPOINT_URL (ver scripts/floci.sh); el provider
# solo desactiva las validaciones que un emulador no satisface.
# =============================================================================

provider "aws" {
  region     = "us-east-1"
  access_key = "test"
  secret_key = "test"

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  default_tags {
    tags = {
      Project     = "nestjs-k8s-microservice-stack"
      Environment = "floci"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  services = ["api-gateway", "user-service", "product-service", "notification-service"]
  tags = {
    Project     = "nestjs-k8s-microservice-stack"
    Environment = "floci"
    ManagedBy   = "terraform"
  }
}

# --- ECR (siempre): el apply más simple y de mayor probabilidad de éxito ---
module "ecr" {
  count  = var.enable_ecr ? 1 : 0
  source = "../../modules/aws/ecr"

  repository_names = local.services
  max_images       = 20
  tags             = local.tags
}

# --- Red (opcional): VPC de 3 niveles ---
module "network" {
  count  = var.enable_network ? 1 : 0
  source = "../../modules/aws/network"

  name     = "nestjs-floci"
  vpc_cidr = "10.42.0.0/16"
  azs      = ["us-east-1a", "us-east-1b", "us-east-1c"]

  public_subnet_cidrs       = ["10.42.0.0/24", "10.42.1.0/24", "10.42.2.0/24"]
  private_app_subnet_cidrs  = ["10.42.16.0/20", "10.42.32.0/20", "10.42.48.0/20"]
  private_data_subnet_cidrs = ["10.42.64.0/24", "10.42.65.0/24", "10.42.66.0/24"]

  single_nat_gateway         = true
  enable_interface_endpoints = false # interface endpoints suelen ser lo primero que un emulador no cubre
  tags                       = local.tags
}

# --- Datos gestionados (opcional): requiere red ---
module "rds" {
  count  = var.enable_data && var.enable_network ? 1 : 0
  source = "../../modules/aws/rds-postgres"

  identifier                 = "nestjs-floci-userdb"
  vpc_id                     = module.network[0].vpc_id
  db_subnet_group_name       = module.network[0].database_subnet_group_name
  allowed_security_group_ids = []
  tags                       = local.tags
}

# NOTA: DocumentDB y ElastiCache NO se emulan completos en floci community.
# El apply falla con UnsupportedOperation:
#   - DocDB:       DescribeGlobalClusters (lo llama el provider al crear el cluster)
#   - ElastiCache: CreateCacheSubnetGroup
# RDS sí funciona de punta a punta. Para product/notification en floci, usar
# datastores in-cluster (mongodb/redis del chart) en lugar de servicios gestionados.

output "floci_endpoint" {
  value = var.floci_endpoint
}

output "ecr_registry_url" {
  value = var.enable_ecr ? module.ecr[0].registry_url : null
}

output "ecr_repository_urls" {
  value = var.enable_ecr ? module.ecr[0].repository_urls : {}
}
