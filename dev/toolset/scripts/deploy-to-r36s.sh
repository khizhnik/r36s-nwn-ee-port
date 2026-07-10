#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/r36s-common.sh"

PORT_SRC="$REPO_ROOT/port"
DELETE_MODE="${DELETE_MODE:-0}"

usage() {
  cat <<'EOF'
Usage: deploy-to-r36s.sh [--delete]

Copies the current ./port runtime tree to the R36S over USB SSH.
By default the sync is non-destructive and does not remove remote files.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --delete)
      DELETE_MODE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

r36s_require_tool sshpass
r36s_require_tool rsync
r36s_require_tool ssh

if [ ! -d "$PORT_SRC" ]; then
  echo "Port source directory not found: $PORT_SRC" >&2
  exit 1
fi

echo "Deploying $PORT_SRC to $R36S_SSH_TARGET:$R36S_PORT_DIR"

"${R36S_SSH_CMD[@]}" "$R36S_SSH_TARGET" "mkdir -p '$R36S_PORT_DIR'"

RSYNC_ARGS=(
  -a
  -v
  --human-readable
  --info=stats2,progress2
  --protect-args
  -e "$R36S_RSYNC_RSH"
)

if [ "$DELETE_MODE" = "1" ]; then
  RSYNC_ARGS+=(--delete)
  echo "Delete mode enabled: remote files not present in ./port will be removed."
else
  echo "Non-destructive sync: remote files are preserved."
fi

rsync "${RSYNC_ARGS[@]}" \
  "$PORT_SRC"/ \
  "$R36S_SSH_TARGET:$R36S_PORT_DIR"/

echo "Deployment complete."
