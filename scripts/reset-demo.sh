#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
kubectl -n demo scale deployment/player-generator --replicas=0
kubectl -n demo wait pod -l app=player-generator --for=delete --timeout=120s
kubectl -n demo scale deployment/raid-verifier --replicas=0
kubectl -n demo wait pod -l app=raid-verifier --for=delete --timeout=120s
# Delete only verifier evidence so it is reconstructed from all three durable logs.
kubectl -n demo run reset-verifier --image=python:3.12-slim --restart=Never --overrides='{"spec":{"containers":[{"name":"reset-verifier","image":"python:3.12-slim","command":["python","-c","import glob,os; [os.remove(p) for p in glob.glob(\"/data/proof.db*\")]"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"verifier-data"}}]}}'
kubectl -n demo wait pod/reset-verifier --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
kubectl -n demo delete pod reset-verifier
kubectl -n demo scale deployment/raid-verifier --replicas=1
kubectl -n demo rollout status deployment/raid-verifier --timeout=180s
echo 'Evidence replay started; generators remain stopped. Full history must still be within Kafka retention.'
