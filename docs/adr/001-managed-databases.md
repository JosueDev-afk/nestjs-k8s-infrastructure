# ADR-001: Bases de datos gestionadas en lugar de pods en Kubernetes

- **Estado**: aceptada (2026-07)
- **Contexto**: los datastores corrían como StatefulSets/sidecars en el
  clúster con `replicas: 1`, sin backups, sin probes, PVC zonal (RWO) y
  credenciales en el chart. RPO efectivo = infinito; RTO ante fallo de AZ =
  manual/indefinido.
- **Decisión**: mover el estado a servicios gestionados — RDS PostgreSQL
  (user-service), DocumentDB (product-service), ElastiCache Redis
  (notification-service) — en subnets privadas de datos, TLS obligatorio y
  acceso solo desde el SG de nodos EKS.
- **Consecuencias**:
  - RPO ≈ 0 en failover (Multi-AZ síncrono) y ≤ 5 min vía PITR; RTO 60-120 s.
  - El clúster queda 100% stateless: upgrades y autoscaling sin riesgo de datos.
  - +1-3 ms de latencia por query (red intra-AZ) — aceptable.
  - Costo directo mayor; TCO menor (sin operación manual de DBs ni incidentes
    de pérdida de datos).
  - Los StatefulSets del chart quedan solo para dev local (kind).
