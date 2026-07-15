# CONTRATO DE PARIDAD: azure/aks debe exponer los mismos outputs
# (oidc_provider_arn -> oidc issuer para Workload Identity, etc.)

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "oidc_provider_arn" {
  description = "ARN del OIDC provider para IRSA (ESO, ALB controller, etc.)"
  value       = module.eks.oidc_provider_arn
}

output "node_security_group_id" {
  description = "SG de los nodos: referencia para los SG de las bases de datos gestionadas"
  value       = module.eks.node_security_group_id
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}
