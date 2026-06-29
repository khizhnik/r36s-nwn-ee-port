#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBUG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DEBUG_DIR/../.." && pwd)"

STEAM_NWN_DIR="${STEAM_NWN_DIR:-$HOME/.steam/debian-installation/steamapps/common/Neverwinter Nights}"
GAME_ROOT="$STEAM_NWN_DIR"
GAME_BIN_DIR="$GAME_ROOT/bin/linux-x86"
COMPILER_DIR="$REPO_ROOT/dev/external/nwn_script_comp/bin"
SCRIPT_SRC="$REPO_ROOT/dev/bootstrap/scripts/ML_Version.nss"
USERDIR="$DEBUG_DIR/userdir"
LOG_DIR="$DEBUG_DIR/logs"
DEVDIR="$USERDIR/development"
SCRIPT_BIN="$DEVDIR/ML_Version.ncs"
MODULE_NAME="XP1-Chapter 2"
TIMEOUT_SECONDS="${1:-25}"
RUNLOG="$LOG_DIR/run-nui-test.log"
CLIENT_LOG="$LOG_DIR/nwclientLog1.txt"
ENGINE_LOG="$LOG_DIR/nwengineLog.txt"
NWN_NUI_SOFTWARE_GL="${NWN_NUI_SOFTWARE_GL:-0}"

mkdir -p "$DEVDIR" "$LOG_DIR"

echo "=== compile ==="
echo "source=$SCRIPT_SRC"
echo "output=$SCRIPT_BIN"
LD_LIBRARY_PATH="$COMPILER_DIR" \
  "$COMPILER_DIR/nwn_script_comp" \
  --root "$GAME_ROOT" \
  -o "$SCRIPT_BIN" \
  "$SCRIPT_SRC" || exit 1

echo "=== launch ==="
echo "REPO_ROOT=$REPO_ROOT"
echo "STEAM_NWN_DIR=$STEAM_NWN_DIR"
echo "userdir=$USERDIR"
echo "module=$MODULE_NAME"
echo "timeout_seconds=$TIMEOUT_SECONDS"
echo "runlog=$RUNLOG"
echo "client_log=$CLIENT_LOG"
echo "engine_log=$ENGINE_LOG"
echo "software_gl_enabled=$NWN_NUI_SOFTWARE_GL"
echo "DISPLAY=${DISPLAY:-}"
if [ "$NWN_NUI_SOFTWARE_GL" = "1" ]; then
  echo "LIBGL_ALWAYS_SOFTWARE=1"
  echo "MESA_LOADER_DRIVER_OVERRIDE=llvmpipe"
else
  echo "LIBGL_ALWAYS_SOFTWARE=${LIBGL_ALWAYS_SOFTWARE:-}"
  echo "MESA_LOADER_DRIVER_OVERRIDE=${MESA_LOADER_DRIVER_OVERRIDE:-}"
fi

rm -f "$CLIENT_LOG" "$ENGINE_LOG"

cd "$GAME_BIN_DIR" || exit 1
if [ "$NWN_NUI_SOFTWARE_GL" = "1" ]; then
  env DISPLAY=:0 LIBGL_ALWAYS_SOFTWARE=1 MESA_LOADER_DRIVER_OVERRIDE=llvmpipe ./nwmain-linux -userdirectory "$USERDIR" +TestNewModule "$MODULE_NAME" >"$RUNLOG" 2>&1 &
else
  env DISPLAY=:0 ./nwmain-linux -userdirectory "$USERDIR" +TestNewModule "$MODULE_NAME" >"$RUNLOG" 2>&1 &
fi
GAME_PID=$!
echo "game_pid=$GAME_PID"

(
  sleep "$TIMEOUT_SECONDS"
  echo "=== timeout reached, stopping pid $GAME_PID ==="
  kill -TERM "$GAME_PID" 2>/dev/null || true
  sleep 2
  kill -KILL "$GAME_PID" 2>/dev/null || true
) &
KILLER_PID=$!
echo "killer_pid=$KILLER_PID"

wait "$GAME_PID"
GAME_STATUS=$?

kill -TERM "$KILLER_PID" 2>/dev/null || true
wait "$KILLER_PID" 2>/dev/null || true

echo "=== finished ==="
echo "game_exit_status=$GAME_STATUS"
echo "client_log=$CLIENT_LOG"
echo "engine_log=$ENGINE_LOG"
