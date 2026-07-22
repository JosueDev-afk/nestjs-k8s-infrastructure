# live/floci — pruebas contra el emulador floci

Escenario **de prueba**, no un entorno real. Reutiliza los mismos `modules/aws/*`
que dev/prod para validar que la IaC aplica contra una API con forma de AWS
([floci](https://floci.io), emulador tipo LocalStack) desplegado en una VPS —
sin cuenta de AWS ni costos.

## Cómo funciona

- El endpoint (todos los servicios AWS responden en la misma URL base) se inyecta
  por `AWS_ENDPOINT_URL`; el provider solo desactiva las validaciones que un
  emulador no satisface (`skip_credentials_validation`, `s3_use_path_style`, …).
- El state vive en S3 **dentro de floci** (bucket `nestjsk8s-dev-tfstate`, key
  `floci/dev.tfstate`), sin `use_lockfile` (el locking nativo usa PutObject
  condicional que el S3 emulado puede no soportar).
- Credenciales: floci no las valida, `test`/`test` sirve.

## Uso

```bash
scripts/floci.sh plan                                    # solo ECR (default)
scripts/floci.sh apply -auto-approve                     # crea 4 repos ECR
scripts/floci.sh apply -auto-approve -var enable_network=true
scripts/floci.sh apply -auto-approve -var enable_network=true -var enable_data=true
scripts/floci.sh destroy -auto-approve -var enable_network=true -var enable_data=true
```

> Al aplicar, **pasa todos los toggles que quieras mantener**: si omites
> `enable_network=true` en un apply posterior, Terraform destruye la red (el
> default del toggle es `false`).

Cambiar de instancia floci: `FLOCI_ENDPOINT=http://otra-url scripts/floci.sh ...`.

## Qué se ha verificado (julio 2026, floci 1.5.33 community)

| Capa | Toggle | Resultado |
|---|---|---|
| ECR (4 repos + lifecycle) | `enable_ecr` (on) | ✅ apply; registry Docker real en `…:5100` |
| VPC 3 niveles + NAT + endpoint S3 | `enable_network` | ✅ 32 recursos (ec2 emulado sorprendentemente completo) |
| RDS PostgreSQL + param group + SG | `enable_data` | ✅ instancia `available` (~90 s; contenedor real); pods conectan a ella (IP enrutable, p. ej. `10.0.1.20:7001`) |
| DocumentDB | — | ❌ floci community: `UnsupportedOperation: DescribeGlobalClusters` al crear el cluster |
| ElastiCache Redis | — | ❌ floci community: `UnsupportedOperation: CreateCacheSubnetGroup` |

> Para product-service (Mongo) y notification-service (Redis) en floci: usar los
> datastores **in-cluster** del chart (`mongodb.enabled`/`redis.enabled`), ya que
> floci community no aprovisiona DocumentDB/ElastiCache vía Terraform. RDS sí.

Se dejó fuera `enable_interface_endpoints` (los VPC interface endpoints suelen ser
lo primero que un emulador no cubre).

## EKS + platform (ArgoCD) — `scripts/floci-eks-bootstrap.sh`

floci levanta un **k3s real** por cada `eks:CreateCluster`, así que la capa
`platform` (ArgoCD + GitOps) es testeable. El script automatiza el encadenado:

```bash
scripts/floci-eks-bootstrap.sh              # lean: ArgoCD + microservicios
DEPLOY_MODE=full scripts/floci-eks-bootstrap.sh   # + observabilidad (necesita disco)
```

> **Disco de la VPS.** El stack completo de observabilidad (kube-prometheus-stack,
> grafana, loki, tempo, promtail, exporters) tira varios GB de imágenes y satura
> el disco de una VPS pequeña; k3s entra en `disk-pressure` y deja de programar
> pods (todo queda `Pending`/`Evicted`). Por eso el modo por defecto es **lean**.
> Si ves `disk-pressure`: libera disco en la VPS — lo más rápido es reiniciar la
> instancia floci (es efímera) o `terraform -chdir=live/floci destroy` para soltar
> los recursos emulados (RDS, etc.), y reintentar en modo lean.

Hace, de forma idempotente:
1. `aws eks create-cluster` → floci arranca un nodo k3s; espera `ACTIVE`.
2. Genera el kubeconfig y lo hace usable **desde fuera de la VPS**: floci
   reporta el API server como `https://localhost:6500`, pero el puerto está
   expuesto en el host real — el script reescribe el `server`, salta la
   verificación TLS (el cert es para `localhost`) y empotra las credenciales
   en el `exec` para que `kubectl` no dependa del entorno.
3. Instala ArgoCD por Helm.
4. Aplica el root Application → ArgoCD sincroniza el repo gitops.

> Los providers `helm`/`kubernetes` no pueden configurarse en el mismo apply que
> crea el clúster (misma restricción que con EKS real), por eso el bootstrap va
> por script y no por Terraform.

### Resultado verificado (julio 2026)

El nodo k3s (`v1.34.1+k3s1`) queda `Ready`, ArgoCD instala y registra las 10
Applications del repo gitops. Casi todas llegan a `Synced`; observabilidad
(tempo, otel-collector, promtail, exporters, loki) sube a `Healthy/Progressing`.

**Límite conocido:** los pods de `microservices` quedan en
`Pending / InvalidImageName` — el `values/aws-dev/microservices.yaml` trae el
placeholder `REPLACE_ME_ECR_REGISTRY/…:bootstrap`. Los objetos K8s sí se crean
(ArgoCD: "successfully synced"); solo falta que existan **imágenes reales** en
el ECR de floci. Para cerrarlo hace falta Docker: construir las 4 imágenes y
subirlas al registry de floci (`terraform -chdir=live/floci output -raw
ecr_registry_url`), y sustituir el placeholder en el repo gitops.

## Limpieza

```bash
scripts/floci.sh destroy -auto-approve -var enable_network=true -var enable_data=true
```

O directamente reiniciar la instancia floci (es efímera).
