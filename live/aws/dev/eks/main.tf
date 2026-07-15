provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

locals {
  region       = "us-east-1"
  cluster_name = "nestjs-dev"
  tags = {
    Project     = "nestjs-k8s-microservice-stack"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-nestjs-k8s-tfstate"
    key    = "aws/dev/network/terraform.tfstate"
    region = local.region
  }
}

module "eks" {
  source = "../../../../modules/aws/eks"

  cluster_name    = local.cluster_name
  cluster_version = "1.30"

  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_app_subnet_ids

  # dev: API pública restringible; en prod endpoint privado + VPN/CI
  endpoint_public_access       = true
  endpoint_public_access_cidrs = ["0.0.0.0/0"] # TODO: restringir a CIDR de oficina/CI

  node_instance_types = ["t3.medium"]
  node_min_size       = 2
  node_max_size       = 4
  node_desired_size   = 2
  node_capacity_type  = "SPOT" # dev tolera interrupciones

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
