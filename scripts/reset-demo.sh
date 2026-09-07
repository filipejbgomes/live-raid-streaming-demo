#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
echo "Resetting the entire $CLUSTER demo cluster. Kafka logs, verifier evidence, checkpoints, pods and restart history will be deleted."
if k3d cluster list -o json | python3 -c 'import json,sys;sys.exit(not any(c["name"]==sys.argv[1] for c in json.load(sys.stdin)))' "$CLUSTER"; then
  k3d cluster delete "$CLUSTER"
fi
rm -f "$ROOT/.runtime/kubeconfig" "$ROOT/.runtime/local-cluster.env"
unset KUBECONFIG KUBE_CONTEXT
"$ROOT/scripts/01-create-cluster.sh"
"$ROOT/scripts/02-install-operators.sh"
"$ROOT/scripts/03-deploy-kafka.sh"
"$ROOT/scripts/04-build-images.sh"
"$ROOT/scripts/05-deploy-demo.sh"
echo "Fresh demo is ready. Run ./scripts/open-dashboard.sh and open http://localhost:${DASHBOARD_PORT:-18080}. All pods are newly created, so k9s restart counts begin at zero."
