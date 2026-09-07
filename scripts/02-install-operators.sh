#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
for ns in kafka flink demo observability; do kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -; done
helm repo add strimzi https://strimzi.io/charts/
helm repo add flink-operator https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.11.0/
helm repo update
helm upgrade --install strimzi strimzi/strimzi-kafka-operator --version 0.46.0 -n kafka --wait --timeout 10m
helm upgrade --install flink-kubernetes-operator flink-operator/flink-kubernetes-operator --version 1.11.0 -n flink --set webhook.create=false --wait --timeout 10m
kubectl wait --for=condition=Established crd/kafkas.kafka.strimzi.io crd/kafkanodepools.kafka.strimzi.io crd/kafkatopics.kafka.strimzi.io crd/flinkdeployments.flink.apache.org --timeout=120s
kubectl -n kafka rollout status deployment/strimzi-cluster-operator --timeout=180s
kubectl -n flink rollout status deployment/flink-kubernetes-operator --timeout=180s
