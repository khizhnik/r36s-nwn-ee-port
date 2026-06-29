#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PC_DIR/../.." && pwd)"

STEAM_NWN_DIR="${STEAM_NWN_DIR:-$HOME/.steam/debian-installation/steamapps/common/Neverwinter Nights}"
STEAM_NWN_BIN_DIR="$STEAM_NWN_DIR/bin/linux-x86"
STEAM_NWN_BIN="$STEAM_NWN_BIN_DIR/nwmain-linux"

MODE="${1:-load}"
MODULE_NAME="${2:-03_r36s_bootstrap_nui_window}"

case "$MODE" in
  load)
    MODE_ARG="+LoadNewModule"
    ;;
  test)
    MODE_ARG="+TestNewModule"
    ;;
  *)
    echo "Usage: $0 {load|test} [module_name]"
    exit 1
    ;;
esac

USER_DIR="$PC_DIR/userdir"
LOG_DIR="$PC_DIR/logs"
HARNESS_TIMEOUT="${HARNESS_TIMEOUT:-300}"
SENTINEL="R36S_BOOTSTRAP_EXIT_CONFIRMED"

mkdir -p "$USER_DIR" "$LOG_DIR"
rm -f "$USER_DIR"/logs/nwclientLog*.txt "$USER_DIR"/logs/nwengineLog*.txt

RUN_LOG="$LOG_DIR/run-nui-bootstrap-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$RUN_LOG") 2>&1

echo "=== PC NUI bootstrap harness ==="
date
echo "SCRIPT_DIR=$SCRIPT_DIR"
echo "PC_DIR=$PC_DIR"
echo "REPO_ROOT=$REPO_ROOT"
echo "STEAM_NWN_DIR=$STEAM_NWN_DIR"
echo "STEAM_NWN_BIN=$STEAM_NWN_BIN"
echo "MODE=$MODE"
echo "MODE_ARG=$MODE_ARG"
echo "MODULE_NAME=$MODULE_NAME"
echo "USER_DIR=$USER_DIR"
echo "LOG_DIR=$LOG_DIR"
echo "RUN_LOG=$RUN_LOG"
echo "HARNESS_TIMEOUT=$HARNESS_TIMEOUT"
echo "DISPLAY=${DISPLAY:-}"
echo "LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE:-}"
echo "MESA_LOADER_DRIVER_OVERRIDE=${MESA_LOADER_DRIVER_OVERRIDE:-}"
echo

if [ ! -x "$STEAM_NWN_BIN" ]; then
  echo "ERROR: NWN binary not found or not executable: $STEAM_NWN_BIN"
  exit 1
fi

export DISPLAY="${DISPLAY:-:0}"
export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
export MESA_LOADER_DRIVER_OVERRIDE="${MESA_LOADER_DRIVER_OVERRIDE:-llvmpipe}"

echo "=== Launch command ==="
cd "$STEAM_NWN_BIN_DIR"
echo "cd $STEAM_NWN_BIN_DIR"
echo "env DISPLAY=$DISPLAY LIBGL_ALWAYS_SOFTWARE=$LIBGL_ALWAYS_SOFTWARE MESA_LOADER_DRIVER_OVERRIDE=$MESA_LOADER_DRIVER_OVERRIDE ./nwmain-linux -userdirectory $USER_DIR $MODE_ARG $MODULE_NAME"

cleanup() {
  if [ -n "${NWN_PID:-}" ] && kill -0 "$NWN_PID" 2>/dev/null; then
    kill -TERM "$NWN_PID" 2>/dev/null || true
    sleep 1
    kill -KILL "$NWN_PID" 2>/dev/null || true
    wait "$NWN_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

env \
  DISPLAY="$DISPLAY" \
  LIBGL_ALWAYS_SOFTWARE="$LIBGL_ALWAYS_SOFTWARE" \
  MESA_LOADER_DRIVER_OVERRIDE="$MESA_LOADER_DRIVER_OVERRIDE" \
  ./nwmain-linux \
  -userdirectory "$USER_DIR" \
  "$MODE_ARG" \
  "$MODULE_NAME" &

NWN_PID=$!
echo "NWN_PID=$NWN_PID"

deadline=$((SECONDS + HARNESS_TIMEOUT))
while true; do
  if grep -Rqs -- "$SENTINEL" "$USER_DIR/logs" "$RUN_LOG"; then
    echo "R36S sentinel exit confirmed; sending SIGINT to nwmain-linux"
    kill -INT "$NWN_PID" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
      if kill -0 "$NWN_PID" 2>/dev/null; then
        sleep 1
      else
        break
      fi
    done
    if kill -0 "$NWN_PID" 2>/dev/null; then
      echo "nwmain-linux still alive after SIGINT; sending SIGKILL"
      kill -KILL "$NWN_PID" 2>/dev/null || true
    fi
    wait "$NWN_PID" || true
    exit 0
  fi

  if ! kill -0 "$NWN_PID" 2>/dev/null; then
    wait "$NWN_PID"
    EXIT_CODE=$?
    echo "nwmain-linux exited on its own with code $EXIT_CODE"
    exit "$EXIT_CODE"
  fi

  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "ERROR: harness timeout reached (${HARNESS_TIMEOUT}s)"
    kill -TERM "$NWN_PID" 2>/dev/null || true
    sleep 2
    if kill -0 "$NWN_PID" 2>/dev/null; then
      kill -KILL "$NWN_PID" 2>/dev/null || true
    fi
    wait "$NWN_PID" || true
    exit 1
  fi

  sleep 1
done
