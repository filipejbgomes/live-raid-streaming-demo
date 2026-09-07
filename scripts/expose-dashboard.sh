#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
mode="${1:-port-forward}"
if [[ "$mode" == port-forward ]]; then
  echo "Run ./scripts/open-dashboard.sh, then open http://localhost:${DASHBOARD_PORT:-18080} (works with remote contexts too)."
  exit
fi
if [[ "$mode" != ingress && "$mode" != loadbalancer ]]; then
  echo 'Usage: expose-dashboard.sh [port-forward|ingress|loadbalancer]' >&2; exit 1
fi
: "${DASHBOARD_HOST:?Set DASHBOARD_HOST to your public dashboard DNS name}"
export TLS_SECRET="${TLS_SECRET:-raid-dashboard-tls}"
if [[ "$mode" == loadbalancer ]]; then
  # The public LoadBalancer belongs to the TLS-terminating ingress controller.
  export INGRESS_CLASS=raid-traefik
  helm repo add traefik https://traefik.github.io/charts
  helm repo update traefik
  helm upgrade --install raid-traefik traefik/traefik --version 35.0.0 -n observability --create-namespace --set ingressClass.name=raid-traefik --set ingressClass.isDefaultClass=false --set service.type=LoadBalancer --wait --timeout 10m
  kubectl -n observability get service raid-traefik
  echo "Point $DASHBOARD_HOST DNS at the ingress LoadBalancer address; ports 80 and 443 must be reachable."
fi
: "${INGRESS_CLASS:?Set INGRESS_CLASS to an installed Ingress controller class}"
export DASHBOARD_HOST INGRESS_CLASS
python3 "$ROOT/scripts/tls-resources.py" ingress >/dev/null
if [[ "${TLS_MODE:-letsencrypt}" == letsencrypt ]]; then
  "$ROOT/scripts/06-configure-tls.sh"
elif [[ "${TLS_MODE:-}" == existing ]]; then
  kubectl -n demo get secret "$TLS_SECRET" >/dev/null
else
  echo 'TLS_MODE must be letsencrypt or existing' >&2; exit 1
fi
# Keep direct app service internal; the ingress controller terminates TLS.
kubectl -n demo patch service raid-dashboard --type=merge -p '{"spec":{"type":"ClusterIP"}}'
kubectl -n demo set env deployment/raid-dashboard DASHBOARD_HOST="$DASHBOARD_HOST"
kubectl -n demo rollout status deployment/raid-dashboard --timeout=180s
python3 "$ROOT/scripts/tls-resources.py" ingress | kubectl apply -f -
if [[ "${TLS_MODE:-letsencrypt}" == letsencrypt ]]; then
  generation=$(kubectl -n demo get certificate raid-dashboard -o jsonpath='{.metadata.generation}')
  kubectl -n demo wait certificate/raid-dashboard --for=jsonpath='{.status.conditions[?(@.type=="Ready")].observedGeneration}'="$generation" --timeout="${CERT_TIMEOUT:-600s}"
  kubectl -n demo wait certificate/raid-dashboard --for=condition=Ready --timeout="${CERT_TIMEOUT:-600s}"
fi
echo "Dashboard: https://$DASHBOARD_HOST"
if [[ "${ACME_ENV:-production}" == staging && "${TLS_MODE:-letsencrypt}" == letsencrypt ]]; then
  echo 'Staging certificate issued: browsers will not trust it. Rerun with ACME_ENV=production for a trusted certificate.'
fi
