#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
step 'operators 1/4' 'Ensuring demo namespaces exist'
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
step 'operators 2/4' 'Resolving local operator charts'
flink_version=1.11.0
flink_asset="flink-kubernetes-operator-${flink_version}-helm.tgz"
flink_base="https://archive.apache.org/dist/flink/flink-kubernetes-operator-${flink_version}"
flink_chart_dir="$CACHE_DIR/charts"
flink_chart="$flink_chart_dir/$flink_asset"
if [[ ! -f "$flink_chart" ]]; then
  expected_sha512=$(curl -4 -fsSL --retry 3 --retry-all-errors "$flink_base/$flink_asset.sha512" | awk '{print $1}')
  [[ "$expected_sha512" =~ ^[[:xdigit:]]{128}$ ]] || { echo 'Could not read the Flink operator chart checksum over IPv4.' >&2; exit 1; }
  mkdir -p "$flink_chart_dir"
  chart_tmp=$(mktemp "$flink_chart_dir/$flink_asset.XXXXXX")
  curl -4 -fsSL --retry 3 --retry-all-errors "$flink_base/$flink_asset" -o "$chart_tmp"
  actual_sha512=$(python3 -c 'import hashlib,sys; print(hashlib.sha512(open(sys.argv[1],"rb").read()).hexdigest())' "$chart_tmp")
  [[ "$actual_sha512" == "$expected_sha512" ]] || { rm -f "$chart_tmp"; echo 'Flink operator chart checksum mismatch.' >&2; exit 1; }
  mv "$chart_tmp" "$flink_chart"
fi
strimzi_chart="$flink_chart_dir/strimzi-kafka-operator-helm-3-chart-0.46.0.tgz"
if [[ ! -f "$strimzi_chart" ]]; then
  mkdir -p "$flink_chart_dir"
  helm repo add strimzi https://strimzi.io/charts/
  helm repo update strimzi
  helm pull strimzi/strimzi-kafka-operator --version 0.46.0 --destination "$flink_chart_dir"
fi
step 'operators 3/4' 'Installing Strimzi and Flink operators'
helm upgrade --install strimzi "$strimzi_chart" -n kafka --atomic --wait --timeout 10m
helm upgrade --install flink-kubernetes-operator "$flink_chart" -n flink --set webhook.create=false --atomic --wait --timeout 10m
step 'operators 4/4' 'Waiting for operator APIs and deployments'
kubectl wait --for=condition=Established crd/kafkas.kafka.strimzi.io crd/kafkanodepools.kafka.strimzi.io crd/kafkatopics.kafka.strimzi.io crd/flinkdeployments.flink.apache.org --timeout=120s
kubectl -n kafka rollout status deployment/strimzi-cluster-operator --timeout=180s
kubectl -n flink rollout status deployment/flink-kubernetes-operator --timeout=180s
