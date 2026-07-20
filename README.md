# nestjs-k8s-infrastructure

Infraestructura como código (Terraform) para el stack
[nestjs-k8s-microservice-stack](https://github.com/JosueDev-afk/nestjs-k8s-microservice-stack):
red, Kubernetes gestionado, bases de datos gestionadas y plataforma de
observabilidad. Fase 1 = AWS (EKS); Fase 2 = Azure (AKS) sobre los mismos
contratos de módulo.

## Topología (por entorno)

```
VPC /16, 3 AZs
├── subnets públicas      → solo ALB + NAT. Ningún pod ni DB.
├── subnets private-app   → nodos EKS (egress vía NAT)
└── subnets private-data  → RDS PostgreSQL, DocumentDB, ElastiCache
                            (sin ruta a internet; SG solo admite el node SG)

En el clúster — bootstrap por Terraform (capa platform):
├── External Secrets Operator  → Secrets Manager -> Secrets de K8s (IRSA)
├── AWS Load Balancer Controller   → Ingress ALB del api-gateway
└── ArgoCD + root Application  → GitOps: a partir de aquí TODO lo demás
                                 (observabilidad y microservicios) lo
                                 sincroniza ArgoCD desde nestjs-k8s-gitops
Capa shared (live/aws/shared/ecr-ci): repos ECR + rol OIDC para GitHub Actions
```

> Modelo GitOps completo: ver [ADR-004](docs/adr/004-gitops-argocd.md) y el
> repo [nestjs-k8s-gitops](https://github.com/JosueDev-afk/nestjs-k8s-gitops).

## Estructura

```
modules/aws/…           implementación AWS
modules/azure/…         contratos Fase 2 (README por módulo)
modules/k8s-platform/…  agnóstico de nube (se reutiliza en AKS)
live/aws/{dev,prod}/{network,eks,data,platform}   un estado por capa
docs/adr/               decisiones de arquitectura
```

Ver [modules/README.md](modules/README.md) para los contratos de paridad.

## Uso

```bash
# 0. Prerrequisito (una vez): bucket de estado
aws s3api create-bucket --bucket <TU-BUCKET-TFSTATE> --region us-east-1
aws s3api put-bucket-versioning --bucket <TU-BUCKET-TFSTATE> \
  --versioning-configuration Status=Enabled
# Reemplazar CHANGEME-nestjs-k8s-tfstate en live/**/backend.tf y en los
# data "terraform_remote_state".

# 1. Capa compartida (una vez): ECR + rol OIDC de CI
terraform -chdir=live/aws/shared/ecr-ci init && terraform -chdir=live/aws/shared/ecr-ci apply

# 2. Aplicar por capas, en orden:
for layer in network eks data platform; do
  terraform -chdir=live/aws/dev/$layer init
  terraform -chdir=live/aws/dev/$layer apply
done

# 3. Rellenar los REPLACE_ME del repo gitops con los outputs (ver su README)
#    y push: ArgoCD sincroniza observabilidad + microservicios él solo.
```

Después del apply, los outputs de `data` (endpoints) se colocan en
`helm/values.prod.yaml` del repo de la app; los Secrets de K8s
(`*-secrets`) ya existen en el namespace `microservices`, creados por ESO.

## Costos estimados (us-east-1, aproximados)

| Entorno | Mensual aprox. | Drivers |
|---|---|---|
| dev | ~350-400 USD | EKS 73 + 2×t3.medium spot + NAT + db.t4g.micro + docdb t3.medium + cache.t4g.micro + endpoints |
| prod | ~1.700-2.200 USD | 3×m6i.large + 3 NAT + RDS r6g.large Multi-AZ + 2×DocDB r6g.large + 2×ElastiCache r6g.large |

`terraform destroy` de dev cuando no se use; la capa data de prod tiene
`deletion_protection` y snapshot final obligatorio.

## Seguridad

- Ningún secreto en el repo ni en tfvars: RDS gestiona su master password en
  Secrets Manager; DocumentDB/Redis/JWT usan `random_password` + Secrets
  Manager; los pods los reciben vía ESO + IRSA.
- TLS obligatorio en los tres datastores (`rds.force_ssl`, `tls enabled`,
  `transit_encryption_enabled`).
- Nada público excepto el ALB; API server de prod restringido por CIDR.

## Siguientes pasos (fuera de esta fase)

- Migración de datos (DMS / dump-restore) — ver plan en el repo de la app.
- CD con ArgoCD/Flux apuntando el chart a ambos clústeres.
- Fase 2: implementar `modules/azure/*` contra los contratos y espejar `live/azure/`.
