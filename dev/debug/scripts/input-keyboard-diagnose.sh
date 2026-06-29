#!/bin/bash

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBUG_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$DEBUG_DIR/../.." && pwd)"
PORT_DIR="$REPO_ROOT/port"

LOGDIR="$DEBUG_DIR/logs"
LOGFILE="$LOGDIR/input-keyboard-diagnose.log"
mkdir -p "$LOGDIR" 2>/dev/null || true
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== input-keyboard-diagnose ==="
date
id
echo "pwd=$(pwd)"
echo "DISPLAY=${DISPLAY:-}"

echo "=== /dev/uinput ==="
ls -l /dev/uinput 2>/dev/null || true

echo "=== /dev/input ==="
ls -l /dev/input/ 2>/dev/null || true

echo "=== /proc/bus/input/devices ==="
cat /proc/bus/input/devices 2>/dev/null || true

echo "=== gptokeyb process ==="
ps aux | grep -i '[g]ptokeyb' || true

echo "=== gptokeyb config ==="
if [ -f "$PORT_DIR/conf/nwmain-linux.gptk" ]; then
  cat "$PORT_DIR/conf/nwmain-linux.gptk"
elif [ -f "$PORT_DIR/nwmain-linux.gptk" ]; then
  cat "$PORT_DIR/nwmain-linux.gptk"
else
  echo "missing: nwmain-linux.gptk"
fi

echo "=== X11 probe ==="
DISPLAY=:0 xinput list 2>/dev/null || true
DISPLAY=:0 xset q 2>/dev/null || true

echo "=== input diagnostic tools ==="
which xinput || true
which xev || true
which evtest || true
which jstest || true
which sdl2-jstest || true
which showkey || true

echo "=== GPTK mode grep ==="
grep -R -i '\[GPTK\].*UINPUT\|Running in UINPUT\|Fake Keyboard\|gptokeyb' \
  "$PORT_DIR"/logs/*.log \
  "$PORT_DIR"/logs/*.txt \
  2>/dev/null || true

echo "=== process grep: gptokeyb xvkbd nwmain Xorg ==="
ps aux | grep -Ei '[g]ptokeyb|[x]vkbd|[n]wmain|[X]org' || true

echo "=== manual tests ==="
echo "If jstest exists: jstest /dev/input/js0"
echo "If evtest exists: evtest /dev/input/event2 and /dev/input/event3"
echo "If xev exists under X: DISPLAY=:0 xev"

echo "=== log grep: Fake Keyboard ==="
grep -i 'Fake Keyboard' "$PORT_DIR/logs/test-xorg.log" 2>/dev/null || true
grep -i 'Fake Keyboard' "$PORT_DIR/logs/xorg.log" 2>/dev/null || true

echo "=== log tail: test-xorg.log ==="
tail -200 "$PORT_DIR/logs/test-xorg.log" 2>/dev/null || true

echo "=== log tail: xorg.log ==="
tail -200 "$PORT_DIR/logs/xorg.log" 2>/dev/null || true

echo "=== log tail: test-log.txt ==="
tail -200 "$PORT_DIR/logs/test-log.txt" 2>/dev/null || true

echo "=== log tail: test-early.log ==="
tail -200 "$PORT_DIR/logs/test-early.log" 2>/dev/null || true

echo "=== done ==="
