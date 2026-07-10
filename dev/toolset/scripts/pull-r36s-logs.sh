#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/r36s-common.sh"

LOCAL_LOG_ROOT="${LOCAL_LOG_ROOT:-$REPO_ROOT/dev/logs/r36s}"
REMOTE_LOG_DIR="${REMOTE_LOG_DIR:-$R36S_PORT_DIR/dev-logs}"

STAMP="$(date +%Y%m%d-%H%M%S)"
LOCAL_RUN_DIR="$LOCAL_LOG_ROOT/$STAMP"

r36s_require_tool sshpass
r36s_require_tool rsync
r36s_require_tool ssh

mkdir -p "$LOCAL_RUN_DIR"

echo "Collecting logs to $LOCAL_RUN_DIR"

mkdir -p "$LOCAL_RUN_DIR/remote-runtime"

for logfile in test-early.log test-log.txt test-nwn.log test-xorg.log; do
  if "${R36S_SSH_CMD[@]}" "$R36S_SSH_TARGET" "test -f '$R36S_PORT_DIR/$logfile'"; then
    rsync -a -v --protect-args -e "$R36S_RSYNC_RSH" \
      "$R36S_SSH_TARGET:$R36S_PORT_DIR/$logfile" \
      "$LOCAL_RUN_DIR/remote-runtime/"
  fi
done

if "${R36S_SSH_CMD[@]}" "$R36S_SSH_TARGET" "test -d '$REMOTE_LOG_DIR'"; then
  rsync -a -v --protect-args -e "$R36S_RSYNC_RSH" \
    --include='*/' \
    --include='*.log' \
    --include='*.txt' \
    --exclude='*' \
    "$R36S_SSH_TARGET:$REMOTE_LOG_DIR/" \
    "$LOCAL_RUN_DIR/remote-dev-logs/"
else
  echo "Remote log directory not found: $REMOTE_LOG_DIR"
fi

echo "Logs collected under $LOCAL_RUN_DIR"
