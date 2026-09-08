#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
mkdir -p "$ROOT/.runtime"
exec 9>"$ROOT/.runtime/reset-demo.lock"
flock -n 9 || { echo 'A demo reset is already running. Wait for it to finish before starting another one.' >&2; exit 1; }
if [[ "${1:-}" == --cluster ]]; then
  echo "Recreating the entire $CLUSTER K3s cluster. This also clears the node image cache."
  "$ROOT/scripts/cleanup.sh" --cluster
  "$ROOT/scripts/01-create-cluster.sh"
else
  use_cluster
  echo "Resetting all live-raid workloads and data while retaining the K3s node image cache."
  step '1/8' 'Deleting the Flink job while its operator is still running'
  kubectl -n flink delete flinkdeployment --all --ignore-not-found --wait=false
  wait_for_empty flink flinkdeployment 'Flink job'
  step '2/7' 'Deleting Kafka topics before removing the Kafka cluster'
  kubectl -n kafka delete kafkatopic --all --ignore-not-found --wait=false
  wait_for_empty kafka kafkatopic 'Kafka topics'
  step '3/7' 'Deleting Kafka after its topics are gone'
  kubectl -n kafka delete kafka,kafkanodepool --all --ignore-not-found --wait=false
  wait_for_empty kafka kafka 'Kafka cluster'
  wait_for_empty kafka kafkanodepool 'Kafka node pool'
  step '4/8' 'Removing operators after their managed resources are gone'
  helm -n kafka uninstall strimzi --wait --timeout=5m 2>/dev/null || true
  helm -n flink uninstall flink-kubernetes-operator --wait --timeout=5m 2>/dev/null || true
  step '5/8' 'Removing old demo namespaces and data'
  kubectl delete namespace kafka flink demo observability --ignore-not-found --wait=true --timeout=5m
fi
step '6/8' 'Installing cached operator charts'
"$ROOT/scripts/02-install-operators.sh"
step '7/8' 'Creating Kafka and its topics'
"$ROOT/scripts/03-deploy-kafka.sh"
step '8/8' 'Building/importing app images and deploying the live dashboard'
"$ROOT/scripts/04-build-images.sh"
"$ROOT/scripts/05-deploy-demo.sh"
echo "Fresh demo is ready. Run ./scripts/open-dashboard.sh and open http://localhost:${DASHBOARD_PORT:-18080}. All demo pods are newly created, so their k9s restart counts begin at zero. Use reset-demo.sh --cluster only when you also need a fresh K3s node."
