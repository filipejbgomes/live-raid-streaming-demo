#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
"$ROOT/scripts/00-check-prereqs.sh" existing
use_cluster
# Images must already be imported locally or published to IMAGE_REGISTRY.
if [[ -z "${IMAGE_REGISTRY:-}" && "${KUBE_CONTEXT:-$(kubectl config current-context)}" != k3d-* ]]; then
  echo 'Set IMAGE_REGISTRY and IMAGE_TAG to images your cluster can pull.' >&2; exit 1
fi
"$ROOT/scripts/02-install-operators.sh"
"$ROOT/scripts/03-deploy-kafka.sh"
"$ROOT/scripts/05-deploy-demo.sh"
"$ROOT/scripts/expose-dashboard.sh" "${DASHBOARD_ACCESS:-port-forward}"
