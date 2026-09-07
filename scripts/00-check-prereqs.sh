#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
missing=0
tools=(kubectl helm python3 curl)
if [[ "${1:-local}" == local ]]; then tools+=(docker k3d); fi
for tool in "${tools[@]}"; do
  if command -v "$tool" >/dev/null; then echo "OK: $tool"; else echo "MISSING: $tool — see README.md prerequisites for installation links"; missing=1; fi
done
(( missing == 0 )) || exit 1
if [[ "${1:-local}" == local ]]; then docker info >/dev/null; fi
printf 'Ready. Recommended local capacity: 8 CPU, 16 GiB RAM, 25 GiB free disk.\n'
