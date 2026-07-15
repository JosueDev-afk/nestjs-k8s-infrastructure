# ADR-003: Estructura del repo y contratos de paridad multi-cloud

- **Estado**: aceptada (2026-07)
- **Decisión**:
  1. `modules/<cloud>/*` — implementación por proveedor; `modules/k8s-platform/*`
     — agnóstico (helm/kubernetes providers), reutilizado tal cual en ambas nubes.
  2. **Contrato de paridad**: los módulos homólogos AWS/Azure exponen los
     mismos outputs (`endpoint`, `port`, `database_name`, `secret_ref`,
     `security_group_id`). Los secretos remotos usan los mismos
     property-paths (`password`, `uri`, `auth_token`) para que los
     ExternalSecrets sean idénticos entre nubes.
  3. `live/<cloud>/<env>/<capa>` con estado segmentado por capa
     (network -> eks|aks -> data -> platform): blast radius mínimo por apply
     y políticas más estrictas en la capa data.
  4. Los manifiestos de la aplicación NO viven aquí (chart Helm en el repo de
     la app); este repo provee red, clústeres, datos y plataforma.
- **Alternativas descartadas**: Terragrunt (menos tooling estándar, se puede
  adoptar después si la duplicación de leaves crece); un solo estado global
  (blast radius inaceptable); módulos "multicloud" con count por proveedor
  (abstracción con fugas).
