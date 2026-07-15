# ADR-002: DocumentDB para product-service (vs MongoDB Atlas)

- **Estado**: aceptada (2026-07)
- **Contexto**: RDS no ofrece MongoDB. Alternativas: Amazon DocumentDB,
  MongoDB Atlas, o migrar el servicio a PostgreSQL/JSONB.
- **Decisión**: **Amazon DocumentDB** — nativo en la VPC, IaC 100% provider
  AWS, IAM/Secrets Manager integrados, sin cuenta de terceros.
- **Riesgo aceptado**: DocumentDB implementa la API de MongoDB **5.0** (el
  chart de dev usa mongo:7). Antes del cutover hay que validar la app contra
  DocumentDB: sin retryable writes (`retryWrites=false` ya viene en la URI
  generada), sin change streams completos, operadores de agregación
  parciales. Plan B documentado: MongoDB Atlas con PrivateLink (además daría
  paridad exacta AWS/Azure en Fase 2; en Azure el equivalente elegido es
  Cosmos DB API for MongoDB, con la misma necesidad de validación).
