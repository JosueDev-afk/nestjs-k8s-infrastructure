#!/usr/bin/env bash
# Corre la composición live/floci contra el emulador floci de la VPS.
#
#   scripts/floci.sh plan            # solo ECR (default)
#   scripts/floci.sh apply
#   scripts/floci.sh apply -var enable_network=true
#   scripts/floci.sh destroy
#
# floci no valida credenciales: cualquier valor "test" sirve.
set -euo pipefail

FLOCI_ENDPOINT="${FLOCI_ENDPOINT:-http://floci-floci-bovybt-755121-76-13-24-93.sslip.io}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/live/floci"

# Endpoint global para el provider AWS (aws-sdk-go-v2 base endpoint) y el backend S3
export AWS_ENDPOINT_URL="$FLOCI_ENDPOINT"
export AWS_ENDPOINT_URL_S3="$FLOCI_ENDPOINT"
export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_REGION="us-east-1"
# Menos ruido: sin cache compartida contaminada y sin checkpoints
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

CMD="${1:-plan}"; shift || true

echo "→ floci endpoint: $FLOCI_ENDPOINT"
terraform -chdir="$DIR" init -reconfigure -input=false >/dev/null
terraform -chdir="$DIR" "$CMD" -input=false "$@"
