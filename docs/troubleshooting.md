# Troubleshooting

## Missing tools or Docker access

Run `./scripts/00-check-prereqs.sh` and follow the installation links in README. Ensure Docker is running and your account has access. A missing k3d executable prevents cluster creation. Image build or Helm download failures require outbound internet; repeat the failed step after fixing connectivity.

## Pending pods or restarts

```bash
kubectl get pods -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl -n flink get pvc
kubectl -n flink describe pods
kubectl -n demo logs deployment/player-generator --tail=100
```

Insufficient memory: lower generator replicas first. Flink needs a JobManager and two TaskManagers at parallelism 4 with two slots each. Pending PVCs need a working provisioner: K3s uses local-path by default. Flink workers reach shared checkpoint state through `minio.flink:9000`; check its Service, pod and PVC. On remote clusters, set `STORAGE_CLASS` to an installed CSI class before initial deployment. ImagePullBackOff for `*:local`: repeat image import via script 04.

## Kafka or operator unavailable

```bash
kubectl -n kafka describe kafka raid
kubectl -n kafka logs deployment/strimzi-cluster-operator --tail=100
kubectl -n flink logs deployment/flink-kubernetes-operator --tail=100
kubectl -n flink get flinkdeployment raid-score-engine -o yaml
```

Check pinned chart versions and CRDs. The broker has an explicit 768 MiB maximum Java heap and 3 GiB container limit; keep these settings when using nested Docker/K3s to avoid automatic heap sizing exceeding the effective memory budget. Kafka uses one combined controller/broker; transaction and offset replication are explicitly 1. The Flink admission webhook is disabled to avoid needing certificate infrastructure on the laptop.

## Lag grows or dashboard disconnects

Reduce load with `kubectl -n demo scale deployment/player-generator --replicas=2`. The global boss key and SQLite verifier are intentional local bottlenecks. Background evidence snapshots take longer as the table grows; HTTP polling serves the latest cached snapshot, and final proof waits for its revision to catch up. Keep the demo short. Verify the port-forward is alive and inspect verifier logs:

```bash
kubectl -n demo logs deployment/raid-verifier --tail=100
kubectl -n demo get pods
./scripts/open-dashboard.sh
```

P50/P95/P99 include waiting for transactional commit; multi-second values are expected. Lag uses checkpoint offsets rather than instantaneous source positions.

## Upgrade fails

Inspect the FlinkDeployment status and operator logs. Phase 4 refuses to change the image without a recorded savepoint. Fix storage or job health first. Do not use a stateless upgrade to make the script pass. The same state descriptor names, serializers, UIDs and maximum parallelism must remain across versions.

## Final proof fails

Read `reports/final-proof.json`. Missing output plus lag means drain is incomplete. Duplicate event IDs, invalid sequences, hash mismatch or wrong combo damage are actual failures. Zero input is never a pass. Unavailable Kafka lag or a stopped observer prevents a pass. Evidence reset replays Kafka; it does not remove duplicates from the logs. If retention truncated history, recreate the entire dedicated cluster and rerun. Do not reuse a successful old report as evidence for a new run.

## Remote cluster image or access problems

Ensure `IMAGE_REGISTRY` and `IMAGE_TAG` match the published images for every script, including phase 4. The nodes must support the image architecture. For private registries, provision the named `IMAGE_PULL_SECRET` in both `demo` and `flink`. A pending LoadBalancer address means your cluster has no working load-balancer implementation; use Ingress or port-forwarding. An Ingress resource alone does not install a controller or create DNS. Pass the installed `INGRESS_CLASS`, point `DASHBOARD_HOST` at it, and configure cert-manager/Let's Encrypt with `ACME_EMAIL`, or supply an existing TLS Secret with `TLS_MODE=existing`. Check that your context has permission to install cluster-scoped CRDs and operator RBAC.

See [TLS troubleshooting and renewal](tls.md) for Pending certificates, challenge routing and staging-to-production promotion.
