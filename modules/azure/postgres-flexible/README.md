# azure/postgres-flexible — CONTRATO (Fase 2, pendiente de implementar)

Espejo de `modules/aws/rds-postgres`. Implementación:
`azurerm_postgresql_flexible_server` con VNet integration (subnet delegada),
`require_secure_transport=ON`, zone-redundant HA (prod), backups 7-35 días,
password en Key Vault (equivalente de manage_master_user_password).

## Outputs obligatorios (paridad)
`endpoint`, `port`, `database_name`, `secret_ref` (ID del secreto en Key
Vault), `security_group_id` (NSG rule/subnet).
