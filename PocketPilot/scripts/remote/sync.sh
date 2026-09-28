#!/usr/bin/env bash
# Sync local code to remote desktop: push, pull, rebuild, check proxy tunnel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCAL_ENV="${POCKETPILOT_LOCAL_ENV:-$PROJECT_ROOT/.pocketpilot-local.env}"
if [[ -f "$LOCAL_ENV" ]]; then
    # shellcheck source=/dev/null
    source "$LOCAL_ENV"
fi

REMOTE="${POCKETPILOT_REMOTE:-desktop}"
REMOTE_DIR="${POCKETPILOT_REMOTE_DIR:-~/pocketpilot}"

ensure_remote_checkout() {
    if ssh "$REMOTE" "test -d $REMOTE_DIR/.git"; then
        return
    fi
    echo "sync: remote checkout not found at ${REMOTE}:${REMOTE_DIR}" >&2
    echo "sync: set POCKETPILOT_REMOTE_DIR in .pocketpilot-local.env; see .pocketpilot-local.env.example" >&2
    exit 1
}

ensure_remote_checkout

echo "==> git push"
git push

echo "==> Remote: git pull + assembleDebug"
ssh "$REMOTE" "cd $REMOTE_DIR && git pull && ./gradlew assembleDebug"

echo "==> Remote: proxy tunnel status"
ssh "$REMOTE" "cd $REMOTE_DIR && ./scripts/remote/proxy_tunnel.sh status" || {
    echo "Tunnel not running. Starting..."
    ssh "$REMOTE" "cd $REMOTE_DIR && ./scripts/remote/proxy_tunnel.sh start"
}

echo "==> Sync complete"
