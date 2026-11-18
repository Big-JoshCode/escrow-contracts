#!/usr/bin/env bash
#
# Stub-based tests for scripts/deploy-mainnet.sh. `curl` and `stellar` are
# replaced by small scripts on PATH, so nothing touches the network.
#
#   bash scripts/tests/deploy-mainnet.test.sh
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat > "$tmp/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s' "$FAKE_HORIZON_JSON"
EOF
cat > "$tmp/bin/stellar" <<'EOF'
#!/usr/bin/env bash
case "$1 $2" in
  "keys address") printf 'G%s\n' "$3" ;;
  "contract id") printf '%s\n' "$FAKE_USDC_ID" ;;
  *) echo "unexpected stellar call: $*" >&2; exit 99 ;;
esac
EOF
chmod +x "$tmp/bin/curl" "$tmp/bin/stellar"

printf 'fake wasm bytes' > "$tmp/bounty_escrow.wasm"
good_hash="$(shasum -a 256 "$tmp/bounty_escrow.wasm" | cut -d' ' -f1)"
good_usdc="CUSDCGOOD"
multisig='{"signers":[{"key":"GS1","weight":1},{"key":"GS2","weight":1}],"thresholds":{"low_threshold":1,"med_threshold":2,"high_threshold":2}}'
single='{"signers":[{"key":"GS1","weight":1}],"thresholds":{"low_threshold":0,"med_threshold":0,"high_threshold":0}}'

base=(
  "PATH=$tmp/bin:$PATH"
  ADMIN=ADM
  ARBITER=ARB
  TREASURY=TRE
  RELAYER=REL
  MAINNET_USDC="$good_usdc"
  EXPECTED_WASM_SHA256="$good_hash"
  WASM="$tmp/bounty_escrow.wasm"
  HORIZON_URL=https://horizon.example.invalid
  FAKE_HORIZON_JSON="$multisig"
  FAKE_USDC_ID="$good_usdc"
)

failed=0
run() {
  local want="$1" label="$2"; shift 2
  local out code=0
  out="$(env "${base[@]}" "$@" bash "$root/scripts/deploy-mainnet.sh" --dry-run 2>&1)" || code=$?
  if [ "$code" -eq "$want" ]; then
    echo "ok    $label"
  else
    echo "FAIL  $label (exit $code, want $want)"
    echo "$out"
    failed=1
  fi
}

run 0 "all checks pass"
run 2 "admin is a single-key account" FAKE_HORIZON_JSON="$single"
run 2 "two roles share an account" TREASURY=ARB
run 2 "relayer equals admin" RELAYER=ADM
run 2 "MAINNET_USDC is not the derived id" FAKE_USDC_ID=CSOMETHINGELSE
run 2 "MAX_AMOUNT above the 500 USDC cap" MAX_AMOUNT=6000000000
run 0 "MAX_AMOUNT above the cap with ALLOW_ABOVE_CAP=1" MAX_AMOUNT=6000000000 ALLOW_ABOVE_CAP=1
run 2 "WASM hash does not match" EXPECTED_WASM_SHA256=0000
run 1 "a required variable is empty" ARBITER=

# Without --dry-run and without the approval flag, the script must refuse.
code=0
env "${base[@]}" bash "$root/scripts/deploy-mainnet.sh" >/dev/null 2>&1 || code=$?
if [ "$code" -eq 1 ]; then echo "ok    refuses without approval"; else echo "FAIL  refuses without approval (exit $code)"; failed=1; fi

exit "$failed"
