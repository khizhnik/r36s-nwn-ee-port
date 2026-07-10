#!/usr/bin/env bash

R36S_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$R36S_COMMON_DIR/../.." && pwd)"

R36S_IP="${R36S_IP:-192.168.7.2}"
HOST_IP="${HOST_IP:-192.168.7.1}"
R36S_USER="${R36S_USER:-ark}"
R36S_PASS="${R36S_PASS:-ark}"
# Default matches the current two-SD setup on R36S.
# Override per command for single-SD layouts, e.g. R36S_PORT_DIR=/roms/ports/nwn-ee.
R36S_PORT_DIR="${R36S_PORT_DIR:-/roms2/ports/nwn-ee}"

R36S_SSH_OPTS=(
  -o StrictHostKeyChecking=accept-new
)

R36S_SSH_TARGET="$R36S_USER@$R36S_IP"
R36S_SSH_CMD=(sshpass -p "$R36S_PASS" ssh "${R36S_SSH_OPTS[@]}")
R36S_RSYNC_RSH="sshpass -p $R36S_PASS ssh ${R36S_SSH_OPTS[*]}"

r36s_need() {
  command -v "$1" >/dev/null 2>&1
}

r36s_require_tool() {
  if ! r36s_need "$1"; then
    echo "Missing required tool: $1" >&2
    exit 1
  fi
}
