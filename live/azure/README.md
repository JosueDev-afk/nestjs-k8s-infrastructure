# live/azure — Fase 2 (multi-cloud)

Espejo estructural de `live/aws`: mismas cuatro capas por entorno
(`network -> aks -> data -> platform`) usando `modules/azure/*` (ver los
contratos en cada módulo) y **reutilizando `modules/k8s-platform/*` sin
cambios** — solo varían:

- `secret_store`: `{ type = "azure", vault_url = ... }`
- `service_account_annotations`: `azure.workload.identity/client-id`
- Backend de estado: `azurerm` (Storage Account) en lugar de S3

Principio: las nubes no se interconectan (sin VPN/peering entre AWS y Azure);
cada nube es una isla activa con su plano de datos completo, con DNS/traffic
management por encima si se requiere activo-activo.
