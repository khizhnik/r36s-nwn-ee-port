#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/r36s-common.sh"

STAMP="$(date +%Y%m%d-%H%M%S)"
REMOTE_LOG_DIR="${REMOTE_LOG_DIR:-$R36S_PORT_DIR/dev-logs}"
REMOTE_LOG_FILE="${REMOTE_LOG_FILE:-$REMOTE_LOG_DIR/run-$STAMP.log}"

r36s_require_tool sshpass
r36s_require_tool ssh

echo "Running NWN on R36S"
echo "Target: $R36S_SSH_TARGET:$R36S_PORT_DIR"
echo "Remote log: $REMOTE_LOG_FILE"

"${R36S_SSH_CMD[@]}" "$R36S_SSH_TARGET" \
  "bash -s -- '$R36S_PORT_DIR' '$REMOTE_LOG_DIR' '$REMOTE_LOG_FILE'" <<'EOF'
set -u

PORT_DIR="$1"
LOG_DIR="$2"
LOG_FILE="$3"

cd "$PORT_DIR"
if [ -x ./start.sh ]; then
  ENTRYPOINT=./start.sh
elif [ -x ./nwn-play.sh ]; then
  ENTRYPOINT=./nwn-play.sh
else
  echo "No launcher found in $(pwd)" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
echo "Using launcher: $ENTRYPOINT"
echo "Remote log: $LOG_FILE"
"$ENTRYPOINT" 2>&1 | tee "$LOG_FILE"
status="${PIPESTATUS[0]}"
exit "$status"
EOF
