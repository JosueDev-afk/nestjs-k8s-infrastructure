# azure/redis-cache — CONTRATO (Fase 2, pendiente de implementar)

Espejo de `modules/aws/elasticache-redis`: `azurerm_redis_cache` con TLS
(puerto 6380 — ojo: REDIS_PORT cambia respecto a AWS), Private Endpoint,
access key en Key Vault con clave `auth_token` (mismo property-path que ESO
consume en AWS).

## Outputs obligatorios (paridad)
`endpoint`, `port` (6380), `secret_ref`, `security_group_id`.
