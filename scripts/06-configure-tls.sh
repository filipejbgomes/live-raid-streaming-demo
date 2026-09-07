#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
# Validate settings before installing anything.
python3 "$ROOT/scripts/tls-resources.py" tls >/dev/null
"$ROOT/scripts/install-cert-manager.sh"
python3 "$ROOT/scripts/tls-resources.py" tls | kubectl apply -f -
kubectl -n demo wait issuer/"raid-letsencrypt-${ACME_ENV:-production}" --for=condition=Ready --timeout=180s
echo 'Certificate requested. External access script checks issuance after creating Ingress.'
