#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  helm repo add jetstack https://charts.jetstack.io
  helm repo update jetstack
  helm upgrade --install cert-manager jetstack/cert-manager --version v1.17.4 --namespace cert-manager --create-namespace --set crds.enabled=true --wait --timeout 10m
else
  echo 'Using the existing cert-manager installation.'
fi
kubectl wait --for=condition=Established crd/certificates.cert-manager.io crd/issuers.cert-manager.io --timeout=120s
