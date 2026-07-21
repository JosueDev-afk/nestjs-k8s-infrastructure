#!/usr/bin/env bash
# Bootstrap GitOps completo sobre el k3s que floci levanta detrás de EKS:
#   1. crea el clúster EKS en floci (= un nodo k3s real) y espera ACTIVE
#   2. genera el kubeconfig y lo hace usable desde fuera de la VPS
#      (floci reporta el API como localhost:6500; lo reescribimos al host real)
#   3. instala ArgoCD por Helm
#   4. aplica el root Application → ArgoCD sincroniza el repo gitops
#
# Idempotente: se puede re-ejecutar. Requiere aws, kubectl, helm, python3.
#
#   scripts/floci-eks-bootstrap.sh
set -euo pipefail

FLOCI_HOST="${FLOCI_HOST:-floci-floci-bovybt-755121-76-13-24-93.sslip.io}"
FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://${FLOCI_HOST}}"
CLUSTER="${CLUSTER:-nestjs-floci}"
KUBECONFIG_OUT="${KUBECONFIG_OUT:-$HOME/.kube/floci}"
# DEPLOY_MODE=lean (default): solo ArgoCD + microservicios. La observabilidad
#   completa (kube-prometheus-stack/loki/tempo/…) satura el disco de una VPS
#   pequeña y dispara disk-pressure en k3s — usar DEPLOY_MODE=full solo con
#   holgura de disco real.
DEPLOY_MODE="${DEPLOY_MODE:-lean}"
GITOPS_RAW="https://raw.githubusercontent.com/JosueDev-afk/nestjs-k8s-gitops/main"
GITOPS_ROOT_APP="${GITOPS_ROOT_APP:-$GITOPS_RAW/bootstrap/root-app-aws-dev.yaml}"
GITOPS_MICROSERVICES_APP="${GITOPS_MICROSERVICES_APP:-$GITOPS_RAW/apps/aws-dev/microservices.yaml}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-7.3.3}"

# floci no valida credenciales: cualquier valor "test" sirve.
export AWS_ENDPOINT_URL="$FLOCI_ENDPOINT"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"
export KUBECONFIG="$KUBECONFIG_OUT"

echo "→ floci: $FLOCI_ENDPOINT   clúster: $CLUSTER"

# --- 1. clúster EKS (k3s) ---------------------------------------------------
if ! aws eks describe-cluster --name "$CLUSTER" >/dev/null 2>&1; then
  SUBNET="$(aws ec2 describe-subnets --query 'Subnets[0].SubnetId' --output text 2>/dev/null || true)"
  [ -z "$SUBNET" ] || [ "$SUBNET" = "None" ] && SUBNET="subnet-00000001"
  echo "→ creando clúster EKS (subnet $SUBNET)…"
  aws eks create-cluster --name "$CLUSTER" \
    --role-arn "arn:aws:iam::000000000000:role/eks-role" \
    --resources-vpc-config "subnetIds=$SUBNET" >/dev/null
fi
echo -n "→ esperando ACTIVE"
until [ "$(aws eks describe-cluster --name "$CLUSTER" --query 'cluster.status' --output text 2>/dev/null)" = "ACTIVE" ]; do
  echo -n "."; sleep 3
done
echo " ✓"

# --- 2. kubeconfig usable desde fuera de la VPS -----------------------------
mkdir -p "$(dirname "$KUBECONFIG_OUT")"
aws eks update-kubeconfig --name "$CLUSTER" --kubeconfig "$KUBECONFIG_OUT" >/dev/null
# floci reporta el API como https://localhost:6500; el puerto está expuesto en
# el host real. Reescribimos el server, saltamos verificación TLS (el cert es
# para localhost) y empotramos las credenciales en el exec para que kubectl
# funcione sin depender del entorno.
python3 - "$KUBECONFIG_OUT" "$FLOCI_HOST" "$FLOCI_ENDPOINT" <<'PY'
import sys, yaml
path, host, endpoint = sys.argv[1], sys.argv[2], sys.argv[3]
kc = yaml.safe_load(open(path))
for c in kc.get("clusters", []):
    cl = c["cluster"]
    cl["server"] = f"https://{host}:6500"
    cl["insecure-skip-tls-verify"] = True
    cl.pop("certificate-authority-data", None)
for u in kc.get("users", []):
    exec_ = u["user"].get("exec")
    if exec_:
        exec_["env"] = [
            {"name": "AWS_ENDPOINT_URL", "value": endpoint},
            {"name": "AWS_ACCESS_KEY_ID", "value": "test"},
            {"name": "AWS_SECRET_ACCESS_KEY", "value": "test"},
            {"name": "AWS_DEFAULT_REGION", "value": "us-east-1"},
        ]
yaml.safe_dump(kc, open(path, "w"))
print(f"  kubeconfig → {path} (server https://{host}:6500)")
PY
kubectl get nodes

# --- 3. ArgoCD --------------------------------------------------------------
# Abortar pronto si el nodo está en disk-pressure: nada se programaría y el
# helm se colgaría en los hooks (como pasó al saturarse el disco de la VPS).
if kubectl get nodes -o jsonpath='{.items[*].spec.taints[*].key}' 2>/dev/null | grep -q disk-pressure; then
  echo "✗ El nodo k3s está en disk-pressure: la VPS no tiene disco libre." >&2
  echo "  Libera disco (o reinicia la instancia floci) y reintenta. Ver README." >&2
  exit 1
fi

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
# Idempotente: si el release ya está 'deployed', no se re-lanza (re-ejecutar el
# upgrade re-corre los hooks pre-upgrade y puede dejar el namespace inconsistente).
if [ "$(helm -n argocd status argocd -o json 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin)["info"]["status"])' 2>/dev/null)" = "deployed" ]; then
  echo "→ ArgoCD ya instalado (deployed), omito helm"
else
  echo "→ instalando ArgoCD (lean: sin dex/notifications/applicationset)…"
  helm upgrade --install argocd argo/argo-cd --version "$ARGOCD_CHART_VERSION" \
    --namespace argocd --create-namespace --timeout 10m --wait \
    --set 'configs.params.server\.insecure=true' \
    --set dex.enabled=false \
    --set notifications.enabled=false \
    --set applicationSet.enabled=false >/dev/null
fi
kubectl -n argocd rollout status deploy/argocd-server --timeout=180s

# --- 4. Application(es) -----------------------------------------------------
# El namespace de la app lo crearía Terraform (capa platform); en floci lo
# creamos aquí para que la Application microservices pueda sincronizar.
kubectl create namespace microservices --dry-run=client -o yaml | kubectl apply -f - >/dev/null
if [ "$DEPLOY_MODE" = "full" ]; then
  echo "→ DEPLOY_MODE=full: root App-of-Apps (observabilidad incluida — necesita disco)"
  kubectl apply -f "$GITOPS_ROOT_APP"
else
  echo "→ DEPLOY_MODE=lean: solo la Application microservices"
  kubectl apply -f "$GITOPS_MICROSERVICES_APP"
fi

cat <<EOF

✔ Bootstrap listo (modo: $DEPLOY_MODE). ArgoCD sincronizando el repo gitops.

  export KUBECONFIG=$KUBECONFIG_OUT
  kubectl -n argocd get applications
  # UI: kubectl -n argocd port-forward svc/argocd-server 8080:80   (usuario admin)
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

Pendiente para que los pods arranquen: imágenes reales en el registry de floci
(workflow ci.yml en modo floci) y los Secrets *-secrets (hoy los crearía ESO).
EOF
