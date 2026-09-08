#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
for ns in kafka flink demo observability; do kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -; done
recover_pending_release() {
  local release="$1" namespace="$2" status
  status=$({ helm -n "$namespace" status "$release" 2>/dev/null || true; } | awk '/^STATUS:/ {print $2}')
  if [[ "$status" == pending-* ]]; then
    echo "Removing interrupted Helm release $namespace/$release ($status) before retrying."
    helm -n "$namespace" uninstall "$release" --wait --timeout 5m
  fi
  return 0
}
recover_pending_release strimzi kafka
recover_pending_release flink-kubernetes-operator flink
helm repo add strimzi https://strimzi.io/charts/
helm repo add flink-operator https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.11.0/
helm repo update strimzi flink-operator
helm upgrade --install strimzi strimzi/strimzi-kafka-operator --version 0.46.0 -n kafka --atomic --wait --timeout 10m
helm upgrade --install flink-kubernetes-operator flink-operator/flink-kubernetes-operator --version 1.11.0 -n flink --set webhook.create=false --atomic --wait --timeout 10m
kubectl wait --for=condition=Established crd/kafkas.kafka.strimzi.io crd/kafkanodepools.kafka.strimzi.io crd/kafkatopics.kafka.strimzi.io crd/flinkdeployments.flink.apache.org --timeout=120s
kubectl -n kafka rollout status deployment/strimzi-cluster-operator --timeout=180s
kubectl -n flink rollout status deployment/flink-kubernetes-operator --timeout=180s
