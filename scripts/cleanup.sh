#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
if [[ "${1:-}" == --cluster ]]; then
  [[ "${KUBE_CONTEXT:-$(kubectl config current-context)}" == "k3d-$CLUSTER" ]] || { echo "--cluster only supports the matching local k3d cluster" >&2; exit 1; }
  k3d cluster delete "$CLUSTER"; exit
fi
kubectl -n demo delete deployment player-generator --ignore-not-found
kubectl -n flink delete flinkdeployment raid-score-engine --ignore-not-found
kubectl -n demo delete deployment raid-verifier raid-dashboard --ignore-not-found
kubectl -n demo delete service raid-verifier raid-dashboard --ignore-not-found
echo 'Workloads deleted; Kafka and evidence volumes retained. Use cleanup.sh --cluster for a fresh raid.'
kubectl -n demo delete ingress raid-dashboard --ignore-not-found
kubectl -n demo delete certificate raid-dashboard --ignore-not-found 2>/dev/null || true
echo "Shared operators, ingress controller, certificates secrets and ACME accounts are retained."
