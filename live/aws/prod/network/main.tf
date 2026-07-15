provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

locals {
  region = "us-east-1"
  name   = "nestjs-prod"
  tags = {
    Project     = "nestjs-k8s-microservice-stack"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

module "network" {
  source = "../../../../modules/aws/network"

  name     = local.name
  vpc_cidr = "10.1.0.0/16"
  azs      = ["${local.region}a", "${local.region}b", "${local.region}c"]

  public_subnet_cidrs       = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
  private_app_subnet_cidrs  = ["10.1.16.0/20", "10.1.32.0/20", "10.1.48.0/20"]
  private_data_subnet_cidrs = ["10.1.64.0/24", "10.1.65.0/24", "10.1.66.0/24"]

  # prod: 1 NAT por AZ (tolerancia a fallo de AZ)
  single_nat_gateway = false

  tags = local.tags
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "vpc_cidr" {
  value = module.network.vpc_cidr
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.network.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  value = module.network.private_data_subnet_ids
}

output "database_subnet_group_name" {
  value = module.network.database_subnet_group_name
}
