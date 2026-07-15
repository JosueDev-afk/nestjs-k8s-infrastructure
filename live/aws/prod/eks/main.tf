provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

locals {
  region       = "us-east-1"
  cluster_name = "nestjs-prod"
  tags = {
    Project     = "nestjs-k8s-microservice-stack"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-nestjs-k8s-tfstate"
    key    = "aws/prod/network/terraform.tfstate"
    region = local.region
  }
}

module "eks" {
  source = "../../../../modules/aws/eks"

  cluster_name    = local.cluster_name
  cluster_version = "1.30"

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_app_subnet_ids

  # prod: API server público SOLO desde CIDRs conocidos (CI + VPN). Para
  # endpoint 100% privado (endpoint_public_access = false) hay que ejecutar
  # Terraform/kubectl desde dentro de la VPC (runner/bastion/VPN).
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["203.0.113.0/24"] # REEMPLAZAR: CIDR de oficina/VPN/CI

  node_instance_types = ["m6i.large"]
  node_min_size       = 3
  node_max_size       = 10
  node_desired_size   = 3
  node_capacity_type  = "ON_DEMAND"

  tags = local.tags
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}
