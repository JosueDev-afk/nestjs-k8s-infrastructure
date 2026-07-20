provider "aws" {
  region = local.region

  default_tags {
    tags = local.tags
  }
}

locals {
  region   = "us-east-1"
  app_repo = "JosueDev-afk/nestjs-k8s-microservice-stack"
  services = ["api-gateway", "user-service", "product-service", "notification-service"]
  tags = {
    Project     = "nestjs-k8s-microservice-stack"
    Environment = "shared"
    ManagedBy   = "terraform"
  }
}

module "ecr" {
  source = "../../../../modules/aws/ecr"

  repository_names = local.services
  max_images       = 20
  tags             = local.tags
}

# --- GitHub Actions -> AWS via OIDC (cero access keys en GitHub) ---
module "github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.39"

  tags = local.tags
}

module "github_oidc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.39"

  name = "nestjs-ci-ecr-push"

  # Solo el repo de la app puede asumir el rol (cualquier rama/tag: el push
  # de imágenes solo ocurre en el workflow de main; acotar más con :ref si se desea)
  subjects = ["${local.app_repo}:*"]

  policies = {
    ecr_push = aws_iam_policy.ecr_push.arn
  }

  tags = local.tags

  depends_on = [module.github_oidc_provider]
}

resource "aws_iam_policy" "ecr_push" {
  name        = "nestjs-ci-ecr-push"
  description = "Push de imágenes a los repos ECR del stack NestJS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Auth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "Push"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = module.ecr.repository_arns
      },
    ]
  })

  tags = local.tags
}

output "registry_url" {
  description = "Valor de REPLACE_ME_ECR_REGISTRY en el repo gitops"
  value       = module.ecr.registry_url
}

output "repository_urls" {
  value = module.ecr.repository_urls
}

output "ci_role_arn" {
  description = "Secret AWS_CI_ROLE_ARN en GitHub Actions del repo de la app"
  value       = module.github_oidc_role.arn
}
