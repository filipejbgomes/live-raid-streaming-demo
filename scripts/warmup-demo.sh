#!/usr/bin/env bash
# Builds a fresh, idle Bossraid and proves its presentation baseline is ready.
source "$(dirname "$0")/lib.sh"

step 'warmup 1/5' 'Rebuilding a fresh Bossraid while keeping cached K3s images'
"$ROOT/scripts/reset-demo.sh"

step 'warmup 2/5' 'Confirming Kafka, Flink and dashboard workloads are ready'
use_cluster
kubectl -n kafka wait kafka/bossraid --for=condition=Ready --timeout=180s
wait_job
kubectl -n demo rollout status deployment/bossraid-dashboard --timeout=180s
kubectl -n demo rollout status deployment/bossraid-verifier --timeout=180s

step 'warmup 3/5' 'Confirming the Bossraid is idle before the presentation'
kubectl -n demo scale deployment/bossraid-player-generator --replicas=0
if kubectl -n demo get pods -l app=bossraid-player-generator --no-headers 2>/dev/null | grep -q .; then
  kubectl -n demo wait pod -l app=bossraid-player-generator --for=delete --timeout=120s
fi

step 'warmup 4/5' 'Checking dashboard control status and verifier readiness'
control=$(kubectl -n demo exec deployment/bossraid-dashboard -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8080/control-status').read().decode())")
health=$(kubectl -n demo exec deployment/bossraid-verifier -- python -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8080/health').read().decode())")
python3 - "$control" "$health" <<'PY'
import json,sys
control,health=map(json.loads,sys.argv[1:])
assert control['state']=='READY', control
assert health['ready'] is True, health
PY

step 'warmup 5/5' 'Running repository validation checks'
python3 -m unittest discover -s "$ROOT/tests" -v
echo
echo "Bossraid is warm and presentation-ready."
echo "Dashboard: http://localhost:${DASHBOARD_PORT:-18080}  (run ./scripts/open-dashboard.sh)"
echo "Status: READY. Generator replicas: 0. Click Start boss raid when the presentation reaches that moment."
