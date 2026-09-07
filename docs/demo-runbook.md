# Demo runbook

Run commands from the repository root. Reserve 10–20 minutes to preload images before presenting. Check Docker resources and close competing workloads. Execute scripts 00 through 05 in README order; keep `./scripts/open-dashboard.sh` in another terminal.

Before phase 3, allow at least 30 seconds of baseline traffic to establish checkpoints. Inspect checkpoints if desired:

```bash
kubectl -n flink port-forward service/raid-score-engine-rest 8081:8081
# Another terminal; use the job ID returned by the first command:
curl -fsS http://localhost:8081/jobs/overview
JOB_ID=$(curl -fsS http://localhost:8081/jobs/overview | python3 -c 'import json,sys; print(json.load(sys.stdin)["jobs"][0]["jid"])')
curl -fsS "http://localhost:8081/jobs/$JOB_ID/checkpoints"
```

Keep the dashboard visible during phases 3 and 4. Recovery timeline is sampled, so a very fast intermediate job state may not appear; pod identity changes remain observable.

After phase 4:

```bash
kubectl -n flink get flinkdeployment raid-score-engine -o jsonpath='{.spec.image}{"\n"}{.status.jobStatus.upgradeSavepointPath}{"\n"}{.status.jobStatus.state}{"\n"}'
```

Expect `raid-score-engine-v2:local`, an `s3://flink/...` savepoint and `RUNNING`. Existing player damage persists and the version label changes once v2 emits. Phase 4 is intended to run once per fresh raid.

Phase 5 removes generator pods gracefully, then polls for up to 15 minutes. Three consecutive unchanged passing observations after the initial observation avoid reporting a transient live match. Exit code 0 and PASS indicate success; inspect `reports/final-proof.json`. Report files are local and ignored by Git.

To replay verifier evidence after a verifier failure, use `./scripts/reset-demo.sh`. This leaves generators stopped and rebuilds from the Kafka logs. For a completely fresh run, use `./scripts/cleanup.sh --cluster`, then scripts 01–05. Never clear Kafka alone while keeping Flink state.

Default local cluster name is `live-raid`. `01-create-cluster.sh` saves an ignored repo-local kubeconfig and context under `.runtime/`; every later script loads it automatically when the shell does not already define `KUBECONFIG` or `KUBE_CONTEXT`. Scripts never change the global kubectl context. Use explicit `IMAGE_REGISTRY`, `IMAGE_TAG`, optional `STORAGE_CLASS`, `IMAGE_PULL_SECRET`, `KUBECONFIG` and `KUBE_CONTEXT` for an existing cluster, then run `./scripts/deploy.sh`. See README for Ingress and LoadBalancer access. Shared S3-compatible checkpoint storage allows Flink workers on different nodes. A remote deployment needs no Docker or k3d once its images are published.
