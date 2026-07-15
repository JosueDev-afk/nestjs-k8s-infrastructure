provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

locals {
  region = "us-east-1"
  name   = "nestjs-dev"
  tags = {
    Project     = "nestjs-k8s-microservice-stack"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

module "network" {
  source = "../../../../modules/aws/network"

  name     = local.name
  vpc_cidr = "10.0.0.0/16"
  azs      = ["${local.region}a", "${local.region}b", "${local.region}c"]

  public_subnet_cidrs       = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs  = ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
  private_data_subnet_cidrs = ["10.0.64.0/24", "10.0.65.0/24", "10.0.66.0/24"]

  # dev: 1 NAT compartido (ahorro); prod usa 1 por AZ
  single_nat_gateway = true

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
