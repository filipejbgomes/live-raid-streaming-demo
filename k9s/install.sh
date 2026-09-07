#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
version="${K9S_VERSION:-v0.50.11}"
case "$(uname -s)" in Linux) os=Linux;; Darwin) os=Darwin;; *) echo 'Use an upstream k9s binary on this OS and set K9S_BIN.' >&2; exit 1;; esac
case "$(uname -m)" in x86_64|amd64) arch=amd64;; aarch64|arm64) arch=arm64;; *) echo 'Unsupported CPU architecture' >&2; exit 1;; esac
archive="k9s_${os}_${arch}.tar.gz"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
base="https://github.com/derailed/k9s/releases/download/$version"
curl -fL --retry 3 "$base/$archive" -o "$tmp/$archive"
curl -fL --retry 3 "$base/checksums.sha256" -o "$tmp/checksums.sha256"
mkdir -p "$ROOT/.tools"
python3 - "$tmp" "$archive" "$ROOT/.tools/k9s" <<'VERIFY'
import hashlib,pathlib,sys,tarfile
folder=pathlib.Path(sys.argv[1]);name=sys.argv[2];target=pathlib.Path(sys.argv[3])
entries={line.split()[-1].lstrip('*'):line.split()[0] for line in (folder/'checksums.sha256').read_text().splitlines() if line.strip()}
actual=hashlib.sha256((folder/name).read_bytes()).hexdigest()
if entries.get(name)!=actual:sys.exit('Checksum mismatch or missing checksum; refusing installation')
with tarfile.open(folder/name) as tf:
    members=[m for m in tf.getmembers() if pathlib.PurePosixPath(m.name).name=='k9s' and m.isfile()]
    if len(members)!=1:sys.exit('Unexpected release archive layout')
    target.write_bytes(tf.extractfile(members[0]).read())
target.chmod(0o755)
print('SHA-256 verified; installed',target)
VERIFY
"$ROOT/.tools/k9s" version
