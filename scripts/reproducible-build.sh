#!/usr/bin/env bash
#
# Builds the contract Wasm twice, each time from a fresh target directory, and
# fails if the two files differ. A reproducible build is what lets anyone check
# that a deployed Wasm came from this source.
#
#   bash scripts/reproducible-build.sh
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for i in 1 2; do
  echo "==> build $i"
  CARGO_TARGET_DIR="$tmp/target$i" stellar contract build --out-dir "$tmp/out$i" >/dev/null
done

wasm=bounty_escrow.wasm
h1="$(shasum -a 256 "$tmp/out1/$wasm" | cut -d' ' -f1)"
h2="$(shasum -a 256 "$tmp/out2/$wasm" | cut -d' ' -f1)"
echo "build 1: $h1"
echo "build 2: $h2"
if [ "$h1" != "$h2" ]; then
  echo "error: the two builds differ; the build is not reproducible" >&2
  exit 1
fi
echo "ok: reproducible"
