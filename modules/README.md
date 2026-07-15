# Módulos

## Regla de oro

`modules/k8s-platform/*` es **agnóstico de nube** (solo providers helm/
kubernetes) y se reutiliza sin cambios en EKS y AKS. `modules/aws/*` y
`modules/azure/*` son implementaciones por proveedor detrás de un **contrato
de paridad**: mismos nombres de variables clave y mismos outputs.

## Contratos de paridad (outputs obligatorios)

| Módulo AWS | Módulo Azure (Fase 2) | Outputs comunes |
|---|---|---|
| `aws/network` | `azure/network` | `vpc_id`, `vpc_cidr`, `public_subnet_ids`, `private_app_subnet_ids`, `private_data_subnet_ids`, `database_subnet_group_name` |
| `aws/eks` | `azure/aks` | `cluster_name`, `cluster_endpoint`, `cluster_certificate_authority_data`, `oidc_provider_arn`, `node_security_group_id` |
| `aws/rds-postgres` | `azure/postgres-flexible` | `endpoint`, `port`, `database_name`, `secret_ref`, `security_group_id` |
| `aws/documentdb` | `azure/cosmosdb-mongo` | `endpoint`, `port`, `database_name`, `secret_ref`, `security_group_id` |
| `aws/elasticache-redis` | `azure/redis-cache` | `endpoint`, `port`, `secret_ref`, `security_group_id` |

## Property-paths de secretos (consumidos por ESO)

Para que los `ExternalSecret` sean idénticos entre nubes, el secreto remoto
de cada datastore expone siempre las mismas claves JSON:

| Datastore | Claves del secreto remoto |
|---|---|
| PostgreSQL | `username`, `password` |
| Mongo/DocumentDB/Cosmos | `username`, `password`, `host`, `port`, `uri` |
| Redis | `auth_token`, `host`, `port`, `tls` |

## Orden de aplicación

`network` → `eks`/`aks` → `data` → `platform` (la capa platform necesita el
API server del clúster en fase de plan por los `kubernetes_manifest`).
