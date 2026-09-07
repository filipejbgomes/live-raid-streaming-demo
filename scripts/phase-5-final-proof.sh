#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
use_cluster
echo 'Phase 5: The Referee Checks the Score'
kubectl -n demo scale deployment/player-generator --replicas=0
kubectl -n demo wait pod -l app=player-generator --for=delete --timeout=120s
mkdir -p "$ROOT/reports"
proof_port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
kubectl -n demo port-forward --address=127.0.0.1 service/raid-verifier "$proof_port:8080" >"$ROOT/reports/port-forward.log" 2>&1 &
pf=$!
trap 'kill "$pf" 2>/dev/null || true' EXIT
sleep 1
kill -0 "$pf" || { cat "$ROOT/reports/port-forward.log" >&2; exit 1; }
python3 "$ROOT/scripts/final-proof.py" "$ROOT/reports/final-proof.json" "$proof_port"
echo 'Presenter: Input identities, output identities, raw payload hashes, version-aware damage, integrity records and global totals agree. The report is saved in reports/final-proof.json.'
pause
