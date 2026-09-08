#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
step 'Kafka 1/3' 'Creating the Kafka cluster'
apply_manifest "$ROOT/k8s/kafka/kafka.yaml"
step 'Kafka 2/3' 'Waiting for the Kafka broker to become Ready'
kubectl -n kafka wait kafka/bossraid --for=condition=Ready --timeout=600s
step 'Kafka 3/3' 'Creating and validating Kafka topics'
apply_manifest "$ROOT/k8s/kafka/topics.yaml"
kubectl -n kafka wait kafkatopic --all --for=condition=Ready --timeout=180s
