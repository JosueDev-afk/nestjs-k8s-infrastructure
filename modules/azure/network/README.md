# azure/network — CONTRATO (Fase 2, pendiente de implementar)

Espejo de `modules/aws/network`. Implementación esperada: VNet + 3 subnets
(pública/app/datos), NAT Gateway, NSGs, subnet de datos **delegada** a
`Microsoft.DBforPostgreSQL/flexibleServers`, Private DNS Zones.

## Variables (mismas que aws/network)
`name`, `vpc_cidr` (address_space), `azs` (zones), `public_subnet_cidrs`,
`private_app_subnet_cidrs`, `private_data_subnet_cidrs`, `tags`.

## Outputs obligatorios (paridad)
| Output | Equivalente Azure |
|---|---|
| `vpc_id` | ID de la VNet |
| `vpc_cidr` | address_space |
| `public_subnet_ids` / `private_app_subnet_ids` / `private_data_subnet_ids` | IDs de subnets |
| `database_subnet_group_name` | ID de la subnet delegada de datos |
