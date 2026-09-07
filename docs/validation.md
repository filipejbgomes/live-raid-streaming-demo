# Version 0.1 validation record

Validated on 2026-09-07 against a real single-node K3s v1.31.6+k3s1 cluster created with k3d v5.8.3, Docker 29.4.0, a 10 GiB node memory cap and local-path persistent volumes. All five application images were built locally and imported into K3s. This records one development validation run; use `scripts/test-local.sh` on a fresh dedicated cluster to repeat the complete scripted experiment.

## Final integrity result: PASS

| Evidence | Result |
| --- | ---: |
| Expected attacks | 552,902 |
| Unique processed attacks | 552,902 |
| Integrity records | 552,902 |
| Duplicate attacks | 0 |
| Missing attacks / sequence gaps | 0 / 0 |
| Invalid sequences | 0 |
| Payload / damage mismatches | 0 |
| Player state / integrity errors | 0 / 0 |
| Global state match | true |
| Checksum | OK |
| Kafka / observer lag | 0 / 0 |
| v1 / v2 output events | 416,806 / 136,096 |
| Players with output in both versions | 2,087 |

The real phase-5 script stopped generation, waited for stable matching snapshots and exited successfully. The complete local report is in ignored `reports/final-proof.json`; a compact tracked record is [validation-result.json](validation-result.json).

## Exercised behavior

- Baseline: two generators, 1,000 active players and approximately 1,000 committed attacks/sec. A post-upgrade sample measured P50 3.26 seconds, P95 5.44 seconds and P99 5.72 seconds; these include the five-second transactional checkpoint interval.
- Increased load: eight generators and 4,000 active players; a sample showed approximately 3,098 committed attacks/sec and a growing backlog. Throughput is hardware-dependent.
- Deleted TaskManager pods in both v1 and v2. Replacement workers restored checkpointed state and processing resumed; the final evidence includes both failure experiments.
- Suspended v1 with an actual savepoint at `s3://flink/savepoints/savepoint-24f680-64bae239ff03`, then restored v2. The operator records this in `status.jobStatus.upgradeSavepointPath`. Retained player and global state passed independent verification.
- Restarted the verifier with its existing evidence PVC and resumed from stored offsets. Background SQLite snapshots keep health and metrics requests responsive as evidence grows; a revision gate prevents stale snapshots from passing final proof.
- Opened the live dashboard with headless Chromium, verified the v2 metrics and MATCHED verdict, clicked the final presentation phase and captured [a full-page screenshot](dashboard.png). No JavaScript page errors occurred; a 390-pixel mobile viewport had no horizontal overflow.
- Installed the pinned k9s binary with checksum verification, loaded the separate profile, navigated live Flink pods and invoked the F6 verifier plugin.
- Installed cert-manager and successfully validated Issuer, Certificate and Ingress resources with Kubernetes server-side dry runs.
- Python: 22 unit tests passed, covering proof failure cases, state continuity, stale-snapshot rejection, image/storage rendering and TLS configuration. Java: serialization regression test passed in the Maven container build. Shell/Python/JavaScript syntax checks and server-side manifest validation passed.

## Findings fixed during validation

The first Flink build exposed a Jackson runtime conflict; the job now uses a consistent Jackson BOM and relocates its classes. Retained Kafka input was replayed after this pre-output failure. High load exposed Kafka memory exhaustion with automatic heap sizing under nested container limits; the final manifest uses an explicit 768 MiB maximum heap, 256 MiB direct memory and 3 GiB container limit. Broker recovery during this development run required intervention while applying the corrected configuration; no retained evidence was deleted. The final drain and subsequent v2 worker recovery passed with the corrected broker settings.

The Flink workload now uses its own `raid-flink` service account and RBAC rather than overwriting chart-owned resources. The upgrade script reads the operator's upgrade savepoint field and refuses an unproven stateless transition.

## Untested boundaries

No real public hostname or ACME account was supplied, so a public Let's Encrypt certificate was not issued and external renewal was not exercised. Traefik LoadBalancer exposure, private-registry publication, multi-architecture builds and deployment to a remote Kubernetes distribution remain deployment paths to validate in the destination environment. TLS manifests were accepted by the installed APIs, not proven by a public browser handshake. The single-broker/object-store topology does not test storage loss or production high availability.
