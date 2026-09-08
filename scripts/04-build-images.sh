#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
mode="${1:-local}"
if [[ "$mode" != local && "$mode" != push ]]; then echo 'Usage: 04-build-images.sh [local|push]' >&2; exit 1; fi
if [[ "$mode" == push ]]; then : "${IMAGE_REGISTRY:?Set IMAGE_REGISTRY to your writable registry/repository prefix}"; fi
images=()
step 'images 1/2' "Building five application images (${mode})"
for app in bossraid-player-generator bossraid-verifier bossraid-dashboard bossraid-score-engine-v1 bossraid-score-engine-v2; do
  ref=$(image_ref "$app");images+=("$ref")
  case "$app" in
    bossraid-player-generator) context="$ROOT/apps/player-generator";dockerfile="$context/Dockerfile";;
    bossraid-verifier) context="$ROOT/apps/raid-verifier";dockerfile="$context/Dockerfile";;
    bossraid-dashboard) context="$ROOT/apps/raid-dashboard";dockerfile="$context/Dockerfile";;
    bossraid-score-engine-*) context="$ROOT/apps/raid-score-engine";dockerfile="$context/${app##*-}/Dockerfile";;
  esac
  if [[ "$mode" == push && -n "${PLATFORMS:-}" ]]; then
    docker buildx build --platform "$PLATFORMS" -t "$ref" -f "$dockerfile" --push "$context"
  else
    docker build -t "$ref" -f "$dockerfile" "$context"
    if [[ "$mode" == push ]]; then docker push "$ref"; fi
  fi
done
if [[ "$mode" == local ]]; then
  step 'images 2/2' 'Importing application images into the K3s node'
  k3d image import -c "$CLUSTER" "${images[@]}"
fi
