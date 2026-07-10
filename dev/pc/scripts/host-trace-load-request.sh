#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export TRACE_MODE="load-request"
exec "$SCRIPT_DIR/host-trace-handle-select.sh" "$@"
