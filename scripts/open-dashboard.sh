#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
port="${DASHBOARD_PORT:-18080}"
echo "Open http://localhost:$port — Ctrl-C stops forwarding."
args=()
[[ -z "${KUBE_CONTEXT:-}" ]] || args+=(--context "$KUBE_CONTEXT")
exec kubectl "${args[@]}" -n demo port-forward --address=127.0.0.1 service/bossraid-dashboard "$port:8080"
