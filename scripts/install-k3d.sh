#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

version="${K3D_VERSION:-v5.8.3}"
case "$(uname -s)/$(uname -m)" in
  Linux/x86_64) asset="k3d-linux-amd64" ;;
  Linux/aarch64|Linux/arm64) asset="k3d-linux-arm64" ;;
  Darwin/x86_64) asset="k3d-darwin-amd64" ;;
  Darwin/arm64) asset="k3d-darwin-arm64" ;;
  *) echo "Unsupported platform for project-local k3d: $(uname -s)/$(uname -m). Set K3D_BIN to an installed executable." >&2; exit 1 ;;
esac

destination="$ROOT/.tools/k3d/k3d"
if [[ -x "$destination" ]] && "$destination" version | grep -q "k3d version $version"; then
  echo "Project-local k3d $version is already installed at $destination"
  exit 0
fi

base="https://github.com/k3d-io/k3d/releases/download/$version"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
curl -fsSL "$base/$asset" -o "$tmp_dir/$asset"
expected=$(curl -fsSL "$base/checksums.txt" | awk -v file="$asset" '{name=$2; sub(/^\*/, "", name); if (name == file) print $1}')
[[ -n "$expected" ]] || { echo "Release checksum for $asset was not found" >&2; exit 1; }
actual=$(sha256sum "$tmp_dir/$asset" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || { echo "Checksum mismatch for $asset" >&2; exit 1; }
mkdir -p "$(dirname "$destination")"
install -m 0755 "$tmp_dir/$asset" "$destination"
echo "Installed verified project-local k3d $version at $destination"
