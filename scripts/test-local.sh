#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
export KUBE_CONTEXT="k3d-$CLUSTER"
echo 'End-to-end K3s test. Use a fresh dedicated cluster; load is stopped after final proof.'
python3 -m unittest discover -s "$ROOT/tests" -v
"$ROOT/scripts/01-create-cluster.sh"
source "$ROOT/.runtime/local-cluster.env"
"$ROOT/scripts/02-install-operators.sh"
"$ROOT/scripts/03-deploy-kafka.sh"
"$ROOT/scripts/04-build-images.sh"
"$ROOT/scripts/05-deploy-demo.sh"
for phase in phase-1-baseline phase-2-scale-load phase-3-kill-worker phase-4-upgrade-job; do
  "$ROOT/scripts/$phase.sh" <<< ''
  echo 'Collecting 30 seconds of traffic and checkpoints...'
  sleep 30
done
"$ROOT/scripts/phase-5-final-proof.sh" <<< ''
