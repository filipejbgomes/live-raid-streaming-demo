#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
echo 'Phase 3: A Worker Falls'
pod=$(kubectl -n flink get pods -l app=raid-score-engine,component=taskmanager -o jsonpath='{.items[0].metadata.name}')
[[ -n "$pod" ]] || { echo 'No TaskManager found' >&2; exit 1; }
kubectl -n flink delete pod "$pod" --wait=true
sleep 10
wait_job
kubectl -n flink wait pod -l app=raid-score-engine,component=taskmanager --for=condition=Ready --timeout=180s
kubectl -n flink get pods -l app=raid-score-engine
echo 'Presenter: Inspect the recovery timeline. Kubernetes replaced the worker; Flink restores checkpoint state and Kafka retains the combat log. Final proof checks replay caused no duplicate or missing output.'
pause
