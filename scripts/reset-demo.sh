#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
if [[ "${1:-}" == --cluster ]]; then
  echo "Recreating the entire $CLUSTER K3s cluster. This also clears the node image cache."
  "$ROOT/scripts/cleanup.sh" --cluster
  "$ROOT/scripts/01-create-cluster.sh"
else
  use_cluster
  echo "Resetting all live-raid workloads and data while retaining the K3s node image cache."
  kubectl -n flink delete flinkdeployment --all --ignore-not-found --wait=true --timeout=5m
  kubectl -n kafka delete kafka,kafkanodepool,kafkatopic --all --ignore-not-found --wait=true --timeout=5m
  helm -n kafka uninstall strimzi --wait --timeout=5m 2>/dev/null || true
  helm -n flink uninstall flink-kubernetes-operator --wait --timeout=5m 2>/dev/null || true
  kubectl delete namespace kafka flink demo observability --ignore-not-found --wait=true --timeout=5m
fi
"$ROOT/scripts/02-install-operators.sh"
"$ROOT/scripts/03-deploy-kafka.sh"
"$ROOT/scripts/04-build-images.sh"
"$ROOT/scripts/05-deploy-demo.sh"
echo "Fresh demo is ready. Run ./scripts/open-dashboard.sh and open http://localhost:${DASHBOARD_PORT:-18080}. All demo pods are newly created, so their k9s restart counts begin at zero. Use reset-demo.sh --cluster only when you also need a fresh K3s node."
