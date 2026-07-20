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
  env           = "prod"
  app_namespace = "microservices"
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

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-nestjs-k8s-tfstate"
    key    = "aws/prod/eks/terraform.tfstate"
    region = local.region
  }
}

data "terraform_remote_state" "data" {
  backend = "s3"
  config = {
    bucket = "CHANGEME-nestjs-k8s-tfstate"
    key    = "aws/prod/data/terraform.tfstate"
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

# Lo crea Terraform (no ArgoCD) porque los ExternalSecrets de observabilidad
# deben existir antes de la primera sincronización del stack.
resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
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
    # Credenciales admin de Grafana (kube-prometheus-stack: grafana.admin.existingSecret)
    grafana-admin-credentials = {
      namespace = "observability"
      data = [
        { secret_key = "admin-user", remote_key = aws_secretsmanager_secret.grafana_admin.arn, property = "username" },
        { secret_key = "admin-password", remote_key = aws_secretsmanager_secret.grafana_admin.arn, property = "password" },
      ]
    }
  }

  depends_on = [kubernetes_namespace.app, kubernetes_namespace.observability]
}

# --- Grafana admin: la password vive en Secrets Manager y llega al clúster
#     vía ESO (grafana-admin-credentials). El stack de observabilidad ya no
#     lo gestiona Terraform: lo sincroniza ArgoCD desde el repo gitops. ---
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

# --- ArgoCD (GitOps): Terraform solo hace bootstrap — instala ArgoCD y el
#     root Application (App-of-Apps); desde ahí todo converge desde
#     github.com/JosueDev-afk/nestjs-k8s-gitops ---
locals {
  gitops_repo_url = "https://github.com/JosueDev-afk/nestjs-k8s-gitops.git"
  # true cuando el repo gitops sea privado: requiere haber creado antes el
  # secreto nestjs/<env>/gitops/repo-credentials en Secrets Manager
  # con JSON {"username":"git","password":"<fine-grained PAT read-only>"}
  gitops_repo_private = false
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.3.3"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600

  values = [yamlencode({
    configs = {
      params = {
        # dev: sin TLS propio (acceso por port-forward o Ingress con TLS del ALB)
        "server.insecure" = true
      }
    }
  })]
}

data "aws_secretsmanager_secret_version" "gitops_repo_creds" {
  count     = local.gitops_repo_private ? 1 : 0
  secret_id = "nestjs/${local.env}/gitops/repo-credentials"
}

resource "kubernetes_secret" "gitops_repo_creds" {
  count = local.gitops_repo_private ? 1 : 0

  metadata {
    name      = "gitops-repo-creds"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repo-creds"
    }
  }

  # repo-creds por prefijo: cubre el repo gitops y el repo de la app
  data = {
    type     = "git"
    url      = "https://github.com/JosueDev-afk"
    username = jsondecode(data.aws_secretsmanager_secret_version.gitops_repo_creds[0].secret_string).username
    password = jsondecode(data.aws_secretsmanager_secret_version.gitops_repo_creds[0].secret_string).password
  }

  depends_on = [helm_release.argocd]
}

resource "kubernetes_manifest" "root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name       = "root-aws-${local.env}"
      namespace  = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = local.gitops_repo_url
        targetRevision = "main"
        path           = "apps/aws-${local.env}"
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
      }
    }
  }

  depends_on = [helm_release.argocd, module.external_secrets]
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
  description = "Recuperar con: aws secretsmanager get-secret-value --secret-id nestjs/prod/observability/grafana-admin"
  value       = aws_secretsmanager_secret.grafana_admin.arn
}

output "otlp_endpoint" {
  description = "Endpoint OTLP gRPC para los microservicios (lo despliega ArgoCD)"
  value       = "http://otel-collector-opentelemetry-collector.observability.svc:4317"
}

output "app_namespace" {
  value = local.app_namespace
}

output "argocd_bootstrap" {
  description = "Acceso inicial a la UI de ArgoCD"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d ; kubectl -n argocd port-forward svc/argocd-server 8080:80"
}
