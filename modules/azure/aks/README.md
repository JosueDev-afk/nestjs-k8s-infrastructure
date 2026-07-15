# azure/aks — CONTRATO (Fase 2, pendiente de implementar)

Espejo de `modules/aws/eks`. Implementación: `azurerm_kubernetes_cluster` con
Workload Identity + OIDC issuer habilitados, node pools en la subnet de app,
Azure CNI (soporta NetworkPolicies), API server autorizado por CIDR.

## Outputs obligatorios (paridad)
| Output | Equivalente Azure |
|---|---|
| `cluster_name` | name |
| `cluster_endpoint` | kube host |
| `cluster_certificate_authority_data` | kube CA |
| `oidc_provider_arn` | `oidc_issuer_url` (Workload Identity) |
| `node_security_group_id` | ID del NSG/subnet de nodos (para reglas de las DBs) |
