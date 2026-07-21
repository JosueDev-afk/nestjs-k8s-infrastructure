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
| RDS PostgreSQL + param group + SG | `enable_data` | ✅ instancia `available` (~90 s; contenedor real) |

Se dejó fuera `enable_interface_endpoints` (los VPC interface endpoints suelen ser
lo primero que un emulador no cubre).

## EKS + platform (ArgoCD) — no en un solo apply

floci **sí** levanta un k3s real por cada `eks:CreateCluster`, así que la capa
`platform` es testeable, pero necesita el kubeconfig del clúster *después* de
crearlo (los providers `helm`/`kubernetes` no pueden configurarse en el mismo
apply que crea el clúster — la misma restricción que con EKS real). Flujo manual:

```bash
export AWS_ENDPOINT_URL=http://floci-floci-bovybt-755121-76-13-24-93.sslip.io
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1

aws eks create-cluster --name nestjs-floci \
  --role-arn arn:aws:iam::000000000000:role/eks-role \
  --resources-vpc-config subnetIds=<subnet-de-la-red-floci>
aws eks update-kubeconfig --name nestjs-floci      # floci devuelve el kubeconfig del k3s
kubectl get nodes                                   # k3s real

# A partir de aquí se instalan ArgoCD/observabilidad con helm/kubectl apuntando
# a ese kubeconfig, o reutilizando los módulos k8s-platform/* con un provider
# kubernetes/helm que lea ese contexto.
```

## Limpieza

```bash
scripts/floci.sh destroy -auto-approve -var enable_network=true -var enable_data=true
```

O directamente reiniciar la instancia floci (es efímera).
