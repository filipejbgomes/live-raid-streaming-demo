#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
step 'demo 1/4' 'Applying storage, verifier and dashboard resources'
apply_manifest "$ROOT/k8s/flink/storage-rbac.yaml" "$ROOT/k8s/observability/rbac.yaml"
apply_manifest "$ROOT/k8s/demo/verifier.yaml" "$ROOT/k8s/demo/dashboard.yaml"
step 'demo 2/4' 'Starting MinIO object storage'
"$ROOT/scripts/deploy-object-storage.sh"
step 'demo 3/4' 'Starting the stateful Flink job'
apply_manifest "$ROOT/k8s/flink/job.yaml"
wait_job
step 'demo 4/4' 'Waiting for dashboard, verifier and player generator'
kubectl -n demo rollout status deployment/bossraid-verifier --timeout=180s
kubectl -n demo rollout status deployment/bossraid-dashboard --timeout=180s
apply_manifest "$ROOT/k8s/demo/generator.yaml"
kubectl -n demo rollout status deployment/bossraid-player-generator --timeout=180s
echo "Dashboard: http://localhost:${DASHBOARD_PORT:-18080} — run ./scripts/open-dashboard.sh in a second terminal."
