#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/lib.sh"
bin="${K9S_BIN:-$ROOT/.tools/k9s}"
if [[ ! -x "$bin" ]]; then
  if command -v k9s >/dev/null; then bin=$(command -v k9s); else echo 'Install first: ./k9s/install.sh' >&2; exit 1; fi
fi
runtime="$ROOT/.runtime/k9s"
export K9S_CONFIG_DIR="$runtime/config"
export XDG_DATA_HOME="$runtime/data"
export XDG_STATE_HOME="$runtime/state"
export K9S_LOGS_DIR="$runtime/logs"
mkdir -p "$K9S_CONFIG_DIR" "$XDG_DATA_HOME/k9s" "$XDG_STATE_HOME" "$K9S_LOGS_DIR"
cp "$ROOT/k9s/config.yaml" "$ROOT/k9s/aliases.yaml" "$ROOT/k9s/plugins.yaml" "$K9S_CONFIG_DIR/"
# Pin compatibility with both locations used by k9s releases.
cp "$ROOT/k9s/hotkeys.yaml" "$K9S_CONFIG_DIR/hotkeys.yaml"
cp "$ROOT/k9s/hotkeys.yaml" "$XDG_DATA_HOME/k9s/hotkeys.yaml"
if [[ "${1:-}" == info ]]; then exec "$bin" info; fi
context="${KUBE_CONTEXT:-$(kubectl config current-context)}"
echo "Opening raid observability in Kubernetes context: $context"
#exec "$bin" --context "$context" --namespace demo --readonly "$@"
exec "$bin" --context "$context" -A
