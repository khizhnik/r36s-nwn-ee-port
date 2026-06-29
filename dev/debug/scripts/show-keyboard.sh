#!/bin/bash

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBUG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export DISPLAY=:0
LOGFILE="$DEBUG_DIR/logs/show-keyboard.log"
mkdir -p "$(dirname "$LOGFILE")" 2>/dev/null || true

log() {
  echo "$@" >> "$LOGFILE"
}

log "=== show-keyboard ==="
date >> "$LOGFILE"
log "DISPLAY=$DISPLAY"
log "xvkbd_path=$(command -v xvkbd 2>/dev/null || echo missing)"

if pgrep -x xvkbd >/dev/null 2>&1; then
  log "mode=toggle-close"
  pkill -x xvkbd
  log "xvkbd closed"
  exit 0
fi

if [ ! -x /usr/bin/xvkbd ]; then
  log "ERROR: /usr/bin/xvkbd not found or not executable"
  exit 1
fi

run_xvkbd() {
  log "mode=$1"
  if [ "$1" = "primary" ]; then
    /usr/bin/xvkbd -always-on-top -no-jump-pointer -compact -windowgeometry 640x180+0+300 >> "$LOGFILE" 2>&1 &
  else
    /usr/bin/xvkbd -no-jump-pointer -compact -windowgeometry 640x180+0+300 >> "$LOGFILE" 2>&1 &
  fi
  XVKBD_PID=$!
  log "xvkbd pid=$XVKBD_PID"
  sleep 1
  if ! pgrep -x xvkbd >/dev/null 2>&1; then
    log "xvkbd not running after launch"
    return 1
  fi
  return 0
}

if ! run_xvkbd primary; then
  log "fallback=compact-only"
  run_xvkbd fallback || exit 1
fi

log "=== show-keyboard started ==="
