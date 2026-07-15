# Capa platform: todo lo que corre DENTRO del clúster. Aplicar después de
# network -> eks -> data. Reutilizable tal cual en Azure (los módulos
# k8s-platform son agnósticos; solo cambian IRSA -> Workload Identity y el
# backend del ClusterSecretStore).

provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

locals {
  region        = "us-east-1"
  env           = "dev"
  app_namespace = "microservices"
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

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-nestjs-k8s-tfstate"
    key    = "aws/dev/eks/terraform.tfstate"
    region = local.region
  }
}

data "terraform_remote_state" "data" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-nestjs-k8s-tfstate"
    key    = "aws/dev/data/terraform.tfstate"
    region = local.region
  }
}

locals {
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
  oidc_arn     = data.terraform_remote_state.eks.outputs.oidc_provider_arn
  data_out     = data.terraform_remote_state.data.outputs
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  # Sintaxis de atributo (provider helm >= 3.0)
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = local.app_namespace
  }
}

# --- IRSA para External Secrets Operator (lectura de Secrets Manager) ---
module "eso_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                      = "${local.cluster_name}-external-secrets"
  attach_external_secrets_policy = true
  external_secrets_secrets_manager_arns = [
    "arn:aws:secretsmanager:${local.region}:*:secret:nestjs/${local.env}/*",
    "arn:aws:secretsmanager:${local.region}:*:secret:rds!*",
  ]

  oidc_providers = {
    main = {
      provider_arn               = local.oidc_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = local.tags
}

module "external_secrets" {
  source = "../../../../modules/k8s-platform/external-secrets"

  service_account_annotations = {
    "eks.amazonaws.com/role-arn" = module.eso_irsa.iam_role_arn
  }

  secret_store = {
    type   = "aws"
    region = local.region
  }

  # Nombres = existingSecret en helm/values.prod.yaml del repo de la app
  external_secrets = {
    api-gateway-secrets = {
      namespace = local.app_namespace
      data = [
        { secret_key = "JWT_SECRET", remote_key = local.data_out.jwt_secret_arn, property = "JWT_SECRET" },
      ]
    }
    user-service-secrets = {
      namespace = local.app_namespace
      data = [
        { secret_key = "DATABASE_PASSWORD", remote_key = local.data_out.postgres_secret_arn, property = "password" },
        { secret_key = "JWT_SECRET", remote_key = local.data_out.jwt_secret_arn, property = "JWT_SECRET" },
      ]
    }
    product-service-secrets = {
      namespace = local.app_namespace
      data = [
        { secret_key = "MONGODB_URI", remote_key = local.data_out.documentdb_secret_arn, property = "uri" },
      ]
    }
    notification-service-secrets = {
      namespace = local.app_namespace
      data = [
        { secret_key = "REDIS_PASSWORD", remote_key = local.data_out.redis_secret_arn, property = "auth_token" },
        { secret_key = "JWT_SECRET", remote_key = local.data_out.jwt_secret_arn, property = "JWT_SECRET" },
      ]
    }
    # Credenciales de los exporters de observabilidad
    postgres-exporter-datasource = {
      namespace = "observability"
      data = [
        { secret_key = "DATA_SOURCE_NAME", remote_key = local.data_out.postgres_exporter_dsn_secret_arn, property = "DATA_SOURCE_NAME" },
      ]
    }
    mongodb-exporter-uri = {
      namespace = "observability"
      data = [
        { secret_key = "MONGODB_URI", remote_key = local.data_out.documentdb_secret_arn, property = "uri" },
      ]
    }
    redis-exporter-auth = {
      namespace = "observability"
      data = [
        { secret_key = "REDIS_PASSWORD", remote_key = local.data_out.redis_secret_arn, property = "auth_token" },
      ]
    }
  }

  depends_on = [kubernetes_namespace.app]
}

# --- Observabilidad (4 señales doradas) ---
resource "random_password" "grafana_admin" {
  length  = 24
  special = false
}

resource "aws_secretsmanager_secret" "grafana_admin" {
  name        = "nestjs/${local.env}/observability/grafana-admin"
  description = "Credenciales admin de Grafana"
  tags        = local.tags
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id     = aws_secretsmanager_secret.grafana_admin.id
  secret_string = jsonencode({ username = "admin", password = random_password.grafana_admin.result })
}

module "observability" {
  source = "../../../../modules/k8s-platform/observability"

  grafana_admin_password = random_password.grafana_admin.result
  app_namespace          = local.app_namespace
  retention_days         = 7 # dev

  postgres_exporter = {
    enabled                = true
    datasource_secret_name = "postgres-exporter-datasource"
  }
  mongodb_exporter = {
    enabled         = true
    uri_secret_name = "mongodb-exporter-uri"
  }
  redis_exporter = {
    enabled              = true
    redis_addr           = local.data_out.redis_endpoint
    password_secret_name = "redis-exporter-auth"
  }

  depends_on = [module.external_secrets]
}

# --- AWS Load Balancer Controller (Ingress ALB del api-gateway) ---
module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                              = "${local.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = local.oidc_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.tags
}

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.1"
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName = local.cluster_name
    region      = local.region
    vpcId       = data.terraform_remote_state.network.outputs.vpc_id
    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.alb_controller_irsa.iam_role_arn
      }
    }
  })]
}

output "grafana_admin_secret_arn" {
  description = "Recuperar con: aws secretsmanager get-secret-value --secret-id nestjs/dev/observability/grafana-admin"
  value       = aws_secretsmanager_secret.grafana_admin.arn
}

output "otlp_endpoint" {
  value = module.observability.otlp_endpoint
}

output "app_namespace" {
  value = local.app_namespace
}
