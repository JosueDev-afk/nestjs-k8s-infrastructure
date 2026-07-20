# ADR-004: GitOps con ArgoCD (App-of-Apps, repo dedicado)

- **Estado**: aceptada (2026-07)
- **Contexto**: el despliegue era push-based (Terraform `helm_release` para la
  plataforma; ningún pipeline para la app). Sin trazabilidad de "qué corre",
  sin rollback declarativo, y drift manual posible en el clúster.
- **Decisión**:
  1. **Frontera Terraform/GitOps**: Terraform hace *bootstrap* — todo lo que
     toca IAM/cloud o debe existir antes del primer sync (VPC, EKS, datos,
     ESO+IRSA, ALB controller, namespaces, ArgoCD y el root Application).
     ArgoCD gestiona el *runtime* — observabilidad completa y microservicios,
     desde el repo dedicado `nestjs-k8s-gitops` (App-of-Apps por entorno con
     sync-waves y Applications multi-source: chart + values vía `$values`).
  2. **ArgoCD por clúster** (dev y prod independientes, destino
     `kubernetes.default.svc`). Se descartó el hub central multi-cluster:
     exige credenciales cross-cluster y rompe el aislamiento por entorno; con
     dos entornos no compensa.
  3. **Despliegue = commit**: el CI del repo de la app construye imágenes
     (tags inmutables `sha-*`, ECR con `IMMUTABLE`), y bumpea el tag en
     `values/aws-dev/`. Prod se promueve por PR (mismo artefacto, distinto
     entorno). Rollback = `git revert`. Se descartó ArgoCD Image Updater:
     introduce despliegues que no nacen de un commit.
  4. El módulo `k8s-platform/observability` se eliminó: sus values viven
     ahora en `nestjs-k8s-gitops/values/<env>/` (mismos charts y versiones).
     La password de Grafana pasó de helm value a `admin.existingSecret`
     materializado por ESO.
- **Consecuencias**: el clúster converge solo (`automated+prune+selfHeal`);
  cambios manuales se revierten automáticamente. La protección de prod es
  branch protection en el repo gitops, no permisos de kubectl. Terraform
  apply queda reservado a cambios de infraestructura real.
