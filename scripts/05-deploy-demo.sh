#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
apply_manifest "$ROOT/k8s/flink/storage-rbac.yaml" "$ROOT/k8s/observability/rbac.yaml"
apply_manifest "$ROOT/k8s/demo/verifier.yaml" "$ROOT/k8s/demo/dashboard.yaml"
"$ROOT/scripts/deploy-object-storage.sh"
apply_manifest "$ROOT/k8s/flink/job.yaml"
wait_job
kubectl -n demo rollout status deployment/raid-verifier --timeout=180s
kubectl -n demo rollout status deployment/raid-dashboard --timeout=180s
apply_manifest "$ROOT/k8s/demo/generator.yaml"
kubectl -n demo rollout status deployment/player-generator --timeout=180s
echo "Dashboard: http://localhost:${DASHBOARD_PORT:-18080} — run ./scripts/open-dashboard.sh in a second terminal."
