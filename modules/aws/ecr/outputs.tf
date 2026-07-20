output "registry_url" {
  description = "Registry base (REPLACE_ME_ECR_REGISTRY en el repo gitops)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

output "repository_urls" {
  value = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "ARNs para acotar la policy del rol de CI"
  value       = [for repo in aws_ecr_repository.this : repo.arn]
}
