#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
apply_manifest "$ROOT/k8s/kafka/kafka.yaml"
kubectl -n kafka wait kafka/raid --for=condition=Ready --timeout=600s
apply_manifest "$ROOT/k8s/kafka/topics.yaml"
kubectl -n kafka wait kafkatopic --all --for=condition=Ready --timeout=180s
