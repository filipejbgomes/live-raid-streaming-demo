#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
mode="${1:-local}"
if [[ "$mode" != local && "$mode" != push ]]; then echo 'Usage: 04-build-images.sh [local|push]' >&2; exit 1; fi
if [[ "$mode" == push ]]; then : "${IMAGE_REGISTRY:?Set IMAGE_REGISTRY to your writable registry/repository prefix}"; fi
images=()
for app in player-generator raid-verifier raid-dashboard raid-score-engine-v1 raid-score-engine-v2; do
  ref=$(image_ref "$app");images+=("$ref")
  context="$ROOT/apps/$app";dockerfile="$context/Dockerfile"
  if [[ "$app" == raid-score-engine-* ]]; then context="$ROOT/apps/raid-score-engine";dockerfile="$context/${app##*-}/Dockerfile"; fi
  if [[ "$mode" == push && -n "${PLATFORMS:-}" ]]; then
    docker buildx build --platform "$PLATFORMS" -t "$ref" -f "$dockerfile" --push "$context"
  else
    docker build -t "$ref" -f "$dockerfile" "$context"
    if [[ "$mode" == push ]]; then docker push "$ref"; fi
  fi
done
if [[ "$mode" == local ]]; then k3d image import -c "$CLUSTER" "${images[@]}"; fi
