# k9s observability console

This folder contains the demo's terminal observability profile and a checksum-verified k9s v0.50.11 installer. It works with local K3s and remote Kubernetes through the same kubeconfig/context as the deployment scripts. k9s runs on the presenter's workstation; no additional cluster service is required.

```bash
./k9s/install.sh
export KUBE_CONTEXT=k3d-live-raid   # or your remote context
./k9s/open.sh
```

The binary goes into ignored `.tools/k9s`. Tracked configuration lives here; writable runtime configuration, logs and context history go into ignored `.runtime/k9s`. Your normal k9s profile is retained. Linux/macOS amd64 and arm64 are supported; on other systems supply an upstream executable with `K9S_BIN`. `./k9s/open.sh info` prints the resolved paths. Installation requires curl, Python 3 and internet. Launch requires kubectl and a terminal.

## Presenter shortcuts

| Shortcut | View |
| --- | --- |
| Shift-1 | Demo pods: generators, verifier, dashboard |
| Shift-2 | Flink operator, JobManager and TaskManagers |
| Shift-3 | Kafka broker and operator |
| Shift-4 | FlinkDeployment job and reconciliation status |
| Shift-5 | All three KafkaTopic resources |
| Shift-6 | Dashboard TLS Certificate |
| Shift-7 | Ingress controller in observability |
| Shift-8 | Cluster events across namespaces |
| Shift-9 | Nodes and resource usage |
| F6 | Verifier evidence JSON |
| F7 | Flink checkpoint/savepoint JSON |
| F8 | Certificate, issuer, order and challenge status |

Use `l` for pod logs, `d` for describe, `y` for YAML, `/` to filter, `?` for help and `:quit` to exit. Command aliases `:raidjobs`, `:raidkafka`, `:raidtopics`, `:raidcerts` open custom resources. You can also enter `:pods cert-manager` to inspect certificate controllers. Logs show timestamps, wrap lines and retain 5,000 lines. CPU/memory warning thresholds are 70% and critical thresholds 90%.

During phase 3, keep Shift-2 open to see worker replacement; F7 shows recovered checkpoint history. F6 reports live backlog and integrity, and is not a substitute for phase 5's stopped/drained final proof. During TLS setup, use Shift-6 and F8 to inspect issuance and renewal.

The launcher enables k9s read-only mode so presentation navigation does not modify workloads. The included plugins only read metrics/status; F6 and F7 use pod exec to run an HTTP GET inside the verifier, so your account needs `pods/exec` permission as well as pod discovery. Read-only mode is a UI preference, not an RBAC security boundary. Use the phase scripts for the intentional worker deletion and upgrade.

CPU/memory columns require metrics-server (included by K3s). On a different cluster, an administrator must install a compatible metrics API if absent. Missing metrics display as unavailable; k9s does not synthesize them. Your account needs list/watch/get for pods, events, nodes, the custom resources and pod logs across the demo namespaces. TLS views are useful after cert-manager is installed; they may report an unknown resource beforehand. No extra cluster-admin binding is created for k9s.

References: [k9s configuration](https://k9scli.io/topics/config/), [hotkeys](https://k9scli.io/topics/hotkeys/), [plugins](https://k9scli.io/topics/plugins/).
