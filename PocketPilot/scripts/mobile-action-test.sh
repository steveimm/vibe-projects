#!/usr/bin/env bash
# mobile-action-test.sh: Direct MobileActionTool invocation for CTN device QA

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

PACKAGE="id.steveimm.pocketpilot"
INTENT="id.steveimm.pocketpilot.ACTION_DEBUG_MOBILE_ACTION"
DEVICE_OUTPUT_DIR="/sdcard/Android/data/$PACKAGE/files/mobile-action-debug/latest"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${BLUE}> $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}! $1${NC}"; }
err()  { echo -e "${RED}✗ $1${NC}"; }

TAG=""
SNAPSHOT_PRE=false
ARGS_JSON=""

usage() {
    cat <<'EOF'
Usage: mobile-action-test.sh [options] <mobile_action_args_json>

Options:
  --tag NAME       Save output to debug-output/mobile-action-test/<NAME>/
  --snapshot-pre   Capture a host-side screenshot before the action

Example:
  ./scripts/mobile-action-test.sh --tag ctn-1 \
    '{"action":"click","element_index":3,"x":540,"y":1200}'
EOF
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tag)          TAG="$2"; shift 2 ;;
        --snapshot-pre) SNAPSHOT_PRE=true; shift ;;
        -h|--help)      usage ;;
        *)              ARGS_JSON="$1"; shift ;;
    esac
done

[[ -z "$ARGS_JSON" ]] && usage

DEVICE=$(select_device) || { err "No device connected"; exit 1; }
log "Device: $DEVICE"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "$TAG" ]]; then
    validate_output_tag "$TAG" || exit 1
    OUT_DIR="$ROOT/debug-output/mobile-action-test/$TAG"
else
    OUT_DIR="$ROOT/debug-output/mobile-action-test/latest"
fi
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

if $SNAPSHOT_PRE; then
    adb -s "$DEVICE" exec-out screencap -p > "$OUT_DIR/before.png"
fi

# Clear sentinel
adb -s "$DEVICE" shell "rm -f '$DEVICE_OUTPUT_DIR/.done'" >/dev/null 2>&1 || true

# Escape single quotes for shell wrapping
ESCAPED=${ARGS_JSON//\'/\'\\\'\'}

log "Broadcasting mobile_action..."
echo "  args: $ARGS_JSON"
adb -s "$DEVICE" shell "am broadcast -a $INTENT -p $PACKAGE --es args '$ESCAPED'" >/dev/null

# Wait for .done
waited=0
max=20000
while [[ $waited -lt $max ]]; do
    if adb -s "$DEVICE" shell "test -f '$DEVICE_OUTPUT_DIR/.done'" 2>/dev/null; then
        break
    fi
    sleep 0.2
    waited=$((waited + 200))
done

if [[ $waited -ge $max ]]; then
    err "Timed out waiting for result"
    exit 1
fi

# Post-screenshot
adb -s "$DEVICE" exec-out screencap -p > "$OUT_DIR/after.png"

# Pull results
adb -s "$DEVICE" pull "$DEVICE_OUTPUT_DIR/result.json" "$OUT_DIR/result.json" >/dev/null 2>&1 || true
adb -s "$DEVICE" pull "$DEVICE_OUTPUT_DIR/pre_tree.json" "$OUT_DIR/pre_tree.json" >/dev/null 2>&1 || true
adb -s "$DEVICE" pull "$DEVICE_OUTPUT_DIR/post_tree.json" "$OUT_DIR/post_tree.json" >/dev/null 2>&1 || true

if [[ -f "$OUT_DIR/result.json" ]]; then
    echo ""
    echo -e "${BOLD}─── Result ───${NC}"
    status=$(python3 -c "import json; d=json.load(open('$OUT_DIR/result.json')); print(d.get('result',{}).get('status','?'))" 2>/dev/null || echo "?")
    phase=$(python3 -c "import json; d=json.load(open('$OUT_DIR/result.json')); print(d.get('phase','?'))" 2>/dev/null || echo "?")
    msg=$(python3 -c "import json; d=json.load(open('$OUT_DIR/result.json')); print(d.get('result',{}).get('message',''))" 2>/dev/null || true)
    elapsed=$(python3 -c "import json; d=json.load(open('$OUT_DIR/result.json')); print(d.get('elapsed_ms','?'))" 2>/dev/null || echo "?")

    case "$status" in
        success) ok  "status=$status phase=$phase elapsed=${elapsed}ms" ;;
        failure) warn "status=$status phase=$phase elapsed=${elapsed}ms" ;;
        *)       err  "status=$status phase=$phase elapsed=${elapsed}ms" ;;
    esac
    echo "  message: $msg"
    echo "  output:  $OUT_DIR/"
else
    err "No result.json found"
    exit 1
fi
