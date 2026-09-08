#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
echo 'Phase 4: Rules Change Mid-Fight'
state=$(kubectl -n flink get flinkdeployment bossraid-score-engine -o jsonpath='{.status.jobStatus.state}')
if [[ "$state" != FINISHED ]]; then
  wait_job
  # Suspending in savepoint mode forces a completed savepoint before changing the image.
  kubectl -n flink patch flinkdeployment bossraid-score-engine --type=merge -p '{"spec":{"job":{"state":"suspended","upgradeMode":"savepoint"}}}'
  kubectl -n flink wait flinkdeployment/bossraid-score-engine --for=jsonpath='{.status.jobStatus.state}'=FINISHED --timeout=600s
fi
savepoint=$(kubectl -n flink get flinkdeployment bossraid-score-engine -o jsonpath='{.status.jobStatus.upgradeSavepointPath}')
[[ -n "$savepoint" ]] || { echo 'Upgrade refused: no savepoint recorded' >&2; exit 1; }
echo "Restoring v2 from $savepoint"
patch=$(python3 -c 'import json,sys; print(json.dumps({"spec":{"image":sys.argv[1],"job":{"state":"running","upgradeMode":"savepoint"}}}))' "$(image_ref bossraid-score-engine-v2)")
kubectl -n flink patch flinkdeployment bossraid-score-engine --type=merge -p "$patch"
sleep 5
wait_job
echo 'Presenter: State names and operator IDs stayed stable. Every tenth valid attack now doubles damage. Show version v2, retained leaderboard and clean integrity after drain.'
pause
