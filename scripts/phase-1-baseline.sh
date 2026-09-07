#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
echo 'Phase 1: The Raid Begins'
kubectl -n demo scale deployment/player-generator --replicas=2
kubectl -n demo rollout status deployment/player-generator --timeout=180s
echo 'Presenter: Observe baseline throughput and stable latency. Duplicates should stay 0. Live missing includes in-flight events; final missing must reach 0 after drain.'
pause
