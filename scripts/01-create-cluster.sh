#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
"$ROOT/scripts/00-check-prereqs.sh"
if k3d cluster list -o json | python3 -c 'import json,sys;sys.exit(not any(c["name"]==sys.argv[1] for c in json.load(sys.stdin)))' "$CLUSTER"; then
  echo "Using existing $CLUSTER"
else
  k3d cluster create "$CLUSTER" --image rancher/k3s:v1.31.6-k3s1 --servers 1 --agents 0 --servers-memory "${CLUSTER_MEMORY:-10g}" --k3s-arg '--disable=traefik@server:0' --wait
fi
export KUBE_CONTEXT="k3d-$CLUSTER"
# The wrapper is established before this script exports the newly created context.
kubectl() { command kubectl --context "$KUBE_CONTEXT" "$@"; }
use_cluster
for ns in kafka flink demo observability; do kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -; done
echo "For subsequent scripts: export KUBE_CONTEXT=k3d-$CLUSTER"
