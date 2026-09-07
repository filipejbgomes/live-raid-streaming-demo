#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
missing=0
tools=(kubectl helm python3 curl)
if [[ "${1:-local}" == local ]]; then tools+=(docker); fi
for tool in "${tools[@]}"; do
  if command -v "$tool" >/dev/null; then echo "OK: $tool"; else echo "MISSING: $tool — see README.md prerequisites for installation links"; missing=1; fi
done
if [[ "${1:-local}" == local ]]; then
  if ! k3d_path=$(k3d_bin); then
    echo 'Installing pinned project-local k3d…'
    "$ROOT/scripts/install-k3d.sh"
    k3d_path=$(k3d_bin)
  fi
  echo "OK: k3d ($k3d_path)"
fi
(( missing == 0 )) || exit 1
if [[ "${1:-local}" == local ]]; then docker info >/dev/null; fi
printf 'Ready. Recommended local capacity: 8 CPU, 16 GiB RAM, 25 GiB free disk.\n'
