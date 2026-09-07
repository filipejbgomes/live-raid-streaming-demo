#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
if [[ "${1:-}" == --cluster ]]; then
  if k3d cluster list -o json | python3 -c 'import json,sys;sys.exit(not any(c["name"]==sys.argv[1] for c in json.load(sys.stdin)))' "$CLUSTER"; then
    k3d cluster delete "$CLUSTER"
  fi
  rm -f "$ROOT/.runtime/kubeconfig" "$ROOT/.runtime/local-cluster.env"
  exit
fi
use_cluster
kubectl -n demo delete deployment player-generator --ignore-not-found
kubectl -n flink delete flinkdeployment raid-score-engine --ignore-not-found
kubectl -n demo delete deployment raid-verifier raid-dashboard --ignore-not-found
kubectl -n demo delete service raid-verifier raid-dashboard --ignore-not-found
echo 'Workloads deleted; Kafka and evidence volumes retained. Use cleanup.sh --cluster for a fresh raid.'
kubectl -n demo delete ingress raid-dashboard --ignore-not-found
kubectl -n demo delete certificate raid-dashboard --ignore-not-found 2>/dev/null || true
echo "Shared operators, ingress controller, certificates secrets and ACME accounts are retained."
