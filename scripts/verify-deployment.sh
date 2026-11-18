#!/usr/bin/env bash
#
# Checks that the Wasm running at the contract id in deployments/<network>.json
# is the Wasm recorded there. It fetches the on-chain bytes, hashes them and
# compares the hash with the recorded wasm_hash.
#
#   bash scripts/verify-deployment.sh testnet
#
# Requires the stellar CLI and jq. Exits 1 on mismatch or when the record has no
# valid wasm_hash yet.
set -euo pipefail

network="${1:?usage: verify-deployment.sh <network>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
record="$root/deployments/$network.json"
[ -f "$record" ] || { echo "error: no deployment record at deployments/$network.json" >&2; exit 1; }

id="$(jq -r '.contract_id // empty' "$record")"
want="$(jq -r '.wasm_hash // empty' "$record")"
commit="$(jq -r '.commit // "unknown"' "$record")"
[ -n "$id" ] || { echo "error: no contract_id in $record" >&2; exit 1; }
if ! [[ "$want" =~ ^[0-9a-f]{64}$ ]]; then
  echo "error: deployments/$network.json has no valid wasm_hash (got '$want'). Record it from the reproducible build before verifying." >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
stellar contract fetch --id "$id" --network "$network" --out-file "$tmp/on-chain.wasm" >/dev/null
got="$(shasum -a 256 "$tmp/on-chain.wasm" | cut -d' ' -f1)"

if [ "$got" = "$want" ]; then
  echo "ok: $id runs the Wasm recorded for commit $commit"
else
  echo "MISMATCH: $id" >&2
  echo "  on chain: $got" >&2
  echo "  recorded: $want (commit $commit)" >&2
  echo "  If the deployed Wasm came from an older commit, check that commit out and run scripts/reproducible-build.sh." >&2
  exit 1
fi
