#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
if ! kubectl -n flink get secret bossraid-object-storage >/dev/null 2>&1; then
  python3 - <<'SECRET' | kubectl apply -f -
import json,secrets
print(json.dumps({'apiVersion':'v1','kind':'Secret','metadata':{'name':'bossraid-object-storage','namespace':'flink'},'stringData':{'access-key':'bossraid-'+secrets.token_hex(8),'secret-key':secrets.token_urlsafe(32)}}))
SECRET
fi
apply_manifest "$ROOT/k8s/flink/object-storage.yaml"
kubectl -n flink rollout status deployment/minio --timeout=300s
apply_manifest "$ROOT/k8s/flink/bucket-init.yaml"
kubectl -n flink wait job/bossraid-bucket-init --for=condition=Complete --timeout=180s
