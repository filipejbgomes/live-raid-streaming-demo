#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
echo 'Phase 2: Reinforcements Arrive'
kubectl -n demo scale deployment/player-generator --replicas="${HIGH_REPLICAS:-8}"
kubectl -n demo rollout status deployment/player-generator --timeout=180s
echo 'Presenter: Compare higher concurrency, Kafka lag, Flink throughput, and latency. Integrity errors should remain 0; backlog may grow on a small laptop.'
pause
