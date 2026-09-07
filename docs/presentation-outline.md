# Presentation outline

1. **The Raid Begins** — Run phase 1. Two generators simulate 1,000 players and target 1,000 attacks/sec. Explain the durable combat log, per-player partition key and baseline commit latency. Show no duplicates; explain live missing means pending until drain.
2. **Reinforcements Arrive** — Run phase 2. Eight generators simulate 4,000 players and target 4,000 attacks/sec. Compare actual throughput, lag and P95/P99. The single boss aggregation and verifier can limit actual throughput. Give the system 30–60 seconds to respond.
3. **A Worker Falls** — Run phase 3 while watching the dashboard. Point out the worker identity change, possible job restart, latency spike and eventual lag drain. Kubernetes replaces compute; Flink restores state and replays the durable log. Recovery is verified in the final phase, not inferred solely from a green pod.
4. **Rules Change Mid-Fight** — Run phase 4. Read out the savepoint location. Show v2 on the dashboard and retained damage. Every tenth attack doubles damage. The source offset and player combo survive alongside accumulated damage.
5. **The Referee Checks the Score** — Run phase 5. Generation stops and transaction commits settle. Read the expected/unique counts, duplicates, missing, invalid and checksum aloud. PASS requires positive input, a fully observed drain, equal evidence and stable snapshots. Open the saved JSON report if challenged.

Pause at each script's Enter prompt. Do not promise sub-second latency with five-second transactional checkpoints. Do not hide a FAIL: inspect the report and follow the troubleshooting guide.

## Audience view

Open `./scripts/open-dashboard.sh` and put the browser on the projector. Click the phase cards to change the explanation and highlighted pipeline component; they do not execute destructive actions. The throughput chart records the last two minutes while the page stays open. Keep a second terminal with `./k9s/open.sh`: Shift+2 shows Flink pods and F6 opens live verifier evidence. Run the phase scripts in a third terminal. Finish by showing the saved JSON proof and its matching counts.
