#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLUSTER="${CLUSTER:-live-raid}"
export KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"
trap 'echo "ERROR at line $LINENO: $BASH_COMMAND" >&2' ERR
# Optional explicit context is passed per command; never change the user's global context.
if [[ -n "${KUBE_CONTEXT:-}" ]]; then
  kubectl() { command kubectl --context "$KUBE_CONTEXT" "$@"; }
  helm() { command helm --kube-context "$KUBE_CONTEXT" "$@"; }
fi
use_cluster() {
  echo "Target Kubernetes context: ${KUBE_CONTEXT:-$(kubectl config current-context)}"
  kubectl cluster-info >/dev/null
}
apply_manifest() { python3 "$ROOT/scripts/render.py" "$@" | kubectl apply -f -; }
image_ref() { printf '%s%s:%s' "${IMAGE_REGISTRY:+${IMAGE_REGISTRY%/}/}" "$1" "${IMAGE_TAG:-local}"; }
pause() { read -r -p "Press Enter to continue..."; }
wait_job() {
  for ((i=0;i<180;i++)); do
    if kubectl -n flink get flinkdeployment raid-score-engine -o json 2>/dev/null | python3 -c '
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
