# azure/cosmosdb-mongo — CONTRATO (Fase 2, pendiente de implementar)

Espejo de `modules/aws/documentdb`: `azurerm_cosmosdb_account` (kind MongoDB)
+ Private Endpoint + connection string en Key Vault con clave `uri`
(= MONGODB_URI, mismo property-path que consume ESO en AWS).

## Outputs obligatorios (paridad)
`endpoint`, `port`, `database_name`, `secret_ref`, `security_group_id`.

Nota: validar la paridad de features Mongo igual que con DocumentDB (ADR-002).
