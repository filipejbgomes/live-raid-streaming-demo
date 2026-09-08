#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${CLUSTER:-live-raid}"
CACHE_DIR="${DEMO_CACHE_DIR:-$ROOT/.cache/live-raid}"
K3D_LOCAL_BIN="$ROOT/.tools/k3d/k3d"

k3d_bin() {
  if [[ -n "${K3D_BIN:-}" && -x "$K3D_BIN" ]]; then printf '%s\n' "$K3D_BIN"; return; fi
  if [[ -x "$K3D_LOCAL_BIN" ]]; then printf '%s\n' "$K3D_LOCAL_BIN"; return; fi
  type -P k3d || return 1
}

k3d() {
  local bin
  bin=$(k3d_bin) || {
    echo "k3d CLI is not installed. Install it or set K3D_BIN to its executable path." >&2
    return 127
  }
  command "$bin" "$@"
}
step() { printf '\n==> [%s] %s\n' "$1" "$2"; }
wait_for_empty() {
  local namespace="$1" resource="$2" label="$3" deadline=$((SECONDS + 300))
  while kubectl -n "$namespace" get "$resource" --no-headers 2>/dev/null | grep -q .; do
    (( SECONDS < deadline )) || { echo "Timed out waiting for $label to be deleted." >&2; return 1; }
    echo "    Waiting for $label to finish deleting..."
    sleep 5
  done
}
LOCAL_ENV="$ROOT/.runtime/local-cluster.env"
# Local setup writes this ignored file. A named context is an explicit remote
# choice; an inherited KUBECONFIG alone is common on K3s hosts and must not
# prevent the documented local script sequence from selecting live-raid.
if [[ -z "${KUBE_CONTEXT:-}" && -r "$LOCAL_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LOCAL_ENV"
fi
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
trap 'echo "ERROR at line $LINENO: $BASH_COMMAND" >&2' ERR
# Optional explicit context is passed per command; never change the user's global context.
if [[ -n "${KUBE_CONTEXT:-}" ]]; then
  kubectl() { command kubectl --context "$KUBE_CONTEXT" "$@"; }
  helm() { command helm --kube-context "$KUBE_CONTEXT" "$@"; }
fi
use_cluster() {
  local context="${KUBE_CONTEXT:-$(kubectl config current-context 2>/dev/null || true)}"
  [[ -n "$context" ]] || {
    echo "No Kubernetes context is configured. Run ./scripts/01-create-cluster.sh for local K3s, or export KUBECONFIG and KUBE_CONTEXT for an existing cluster." >&2
    return 1
  }
  echo "Target Kubernetes context: $context"
  kubectl cluster-info >/dev/null 2>&1 || {
    echo "Cannot reach Kubernetes context '$context'. For local K3s, run ./scripts/01-create-cluster.sh once to regenerate .runtime/kubeconfig; for another cluster, export its KUBECONFIG and KUBE_CONTEXT." >&2
    return 1
  }
}
apply_manifest() { python3 "$ROOT/scripts/render.py" "$@" | kubectl apply -f -; }
image_ref() { printf '%s%s:%s' "${IMAGE_REGISTRY:+${IMAGE_REGISTRY%/}/}" "$1" "${IMAGE_TAG:-local}"; }
pause() { read -r -p "Press Enter to continue..."; }
wait_job() {
  for ((i=0;i<180;i++)); do
    if kubectl -n flink get flinkdeployment bossraid-score-engine -o json 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin); s=d.get("status",{})
    ready=(s.get("jobStatus",{}).get("state")=="RUNNING"
           and s.get("reconciliationStatus",{}).get("state")=="DEPLOYED"
           and s.get("observedGeneration")==d["metadata"]["generation"])
    sys.exit(0 if ready else 1)
except (ValueError,KeyError): sys.exit(1)
'; then return; fi
    sleep 5
  done
  echo 'Flink failed to reach RUNNING/DEPLOYED. Inspect operator logs and FlinkDeployment status.' >&2; return 1
}
