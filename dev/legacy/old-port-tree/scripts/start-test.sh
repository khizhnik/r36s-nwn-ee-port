#!/bin/bash
set +e

GAMEDIR_FALLBACK="/roms/ports/nwn-ee"
mkdir -p "$GAMEDIR_FALLBACK" 2>/dev/null || true
EARLYLOG="$GAMEDIR_FALLBACK/test-early.log"
exec > >(tee -a "$EARLYLOG") 2>&1

echo "=== start-test early ==="
date
echo "args: $@"
pwd
id
echo "HOME=$HOME"
echo "SHELL=$SHELL"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MODE="${1:-${NWN_TEST_MODE:-load}}"
MODULE_ID="${2:-${NWN_TEST_MODULE:-Prelude}}"
TIMEOUT="${3:-${NWN_TEST_TIMEOUT:-180}}"

case "$MODE" in
  load)
    MODE_ARG="+LoadNewModule"
    ;;
  test)
    MODE_ARG="+TestNewModule"
    ;;
  *)
    echo "Unknown mode: $MODE"
    echo "Usage: $0 {load|test} <module_id> [timeout_seconds]"
    exit 1
    ;;
esac

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
source "$controlfolder/device_info.txt"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"

get_controls

GAMEDIR="/$directory/ports/nwn-ee"
BINDIR="$GAMEDIR/bin/linux-arm64"
BIN="$BINDIR/nwmain-linux"
XCONF="$GAMEDIR/xorg-nwn.conf"
XLOG="$GAMEDIR/test-xorg.log"
NWNLOG="$GAMEDIR/test-nwn.log"
TESTLOG="$GAMEDIR/test-log.txt"

: > "$TESTLOG"
exec > >(tee -a "$TESTLOG") 2>&1

cleanup() {
  echo "=== cleanup ==="
  if [ -n "${GTPID:-}" ]; then
    kill -TERM "$GTPID" 2>/dev/null || true
    sleep 1
    kill -KILL "$GTPID" 2>/dev/null || true
    echo "gptokeyb stopped: yes"
  else
    echo "gptokeyb stopped: not started"
  fi
  if [ -n "${NWPID:-}" ]; then
    kill -TERM "$NWPID" 2>/dev/null || true
    sleep 1
    kill -KILL "$NWPID" 2>/dev/null || true
  fi
  if [ -n "${XPID:-}" ]; then
    $ESUDO kill -TERM "$XPID" 2>/dev/null || true
    sleep 1
    $ESUDO kill -KILL "$XPID" 2>/dev/null || true
  fi
  $ESUDO killall -9 nwmain-linux 2>/dev/null || true
  $ESUDO killall -9 gptokeyb 2>/dev/null || true
  $ESUDO killall -9 Xorg 2>/dev/null || true
  printf "\033c" >> /dev/tty1 2>/dev/null || true
}

trap cleanup EXIT INT TERM

export DEVICE_ARCH="${DEVICE_ARCH:-aarch64}"

if [ -f "${controlfolder}/libgl_${CFW_NAME}.txt" ]; then
  source "${controlfolder}/libgl_${CFW_NAME}.txt"
else
  source "${controlfolder}/libgl_default.txt"
fi

if [ "$LIBGL_FB" != "" ]; then
  export SDL_VIDEO_GL_DRIVER="$GAMEDIR/gl4es.aarch64/libGL.so.1"
  export SDL_VIDEO_EGL_DRIVER="$GAMEDIR/gl4es.aarch64/libEGL.so.1"
fi

export LD_LIBRARY_PATH="$GAMEDIR/libs:$BINDIR:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
export SDL_AUDIODRIVER=dummy
export ALSOFT_DRIVERS=null
export ALSOFT_LOGLEVEL=3

echo "=== NWN EE test wrapper diagnostics ==="
date
uname -a
echo "MODE=$MODE"
echo "MODE_ARG=$MODE_ARG"
echo "MODULE_ID=$MODULE_ID"
echo "TIMEOUT=$TIMEOUT"
echo "USER=$USER"
echo "HOME=$HOME"
echo "CFW_NAME=$CFW_NAME"
echo "DEVICE_ARCH=$DEVICE_ARCH"
echo "directory=$directory"
echo "GAMEDIR=$GAMEDIR"
echo "BINDIR=$BINDIR"
echo "BIN=$BIN"
echo "NWN_EXE=$NWN_EXE"
echo "XCONF=$XCONF"
echo "TESTLOG=$TESTLOG"
echo "XLOG=$XLOG"
echo "NWNLOG=$NWNLOG"
echo

echo "=== X11 checks ==="
which Xorg || true
which X || true
which startx || true
which xinit || true
which xdpyinfo || true
which xrandr || true
echo "DISPLAY=$DISPLAY"
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
echo "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
echo

echo "=== Runtime env ==="
echo "LIBGL_FB=$LIBGL_FB"
echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
echo "SDL_VIDEO_GL_DRIVER=$SDL_VIDEO_GL_DRIVER"
echo "SDL_VIDEO_EGL_DRIVER=$SDL_VIDEO_EGL_DRIVER"
echo "SDL_VIDEODRIVER=$SDL_VIDEODRIVER"
echo "SDL_AUDIODRIVER=$SDL_AUDIODRIVER"
echo "ALSOFT_DRIVERS=$ALSOFT_DRIVERS"
echo "SDL_GAMECONTROLLERCONFIG=$SDL_GAMECONTROLLERCONFIG"
echo

$ESUDO chmod 666 /dev/tty1 2>/dev/null || true
$ESUDO chmod 666 /dev/uinput 2>/dev/null || true
$ESUDO chmod 666 /dev/fb0 2>/dev/null || true
$ESUDO chmod 666 /dev/dri/card0 2>/dev/null || true
$ESUDO chmod 666 /dev/input/js0 2>/dev/null || true
$ESUDO chmod 666 /dev/input/event2 2>/dev/null || true
$ESUDO chmod 666 /dev/input/event3 2>/dev/null || true

cat > "$XCONF" <<'EOF'
Section "Device"
    Identifier "Card0"
    Driver "modesetting"
    Option "kmsdev" "/dev/dri/card0"
    Option "AccelMethod" "none"
EndSection

Section "Screen"
    Identifier "Screen0"
    Device "Card0"
    DefaultDepth 24
EndSection
EOF

cd "$BINDIR" || exit 1

NWN_EXE="./nwmain-linux"

rm -f "$XLOG" "$NWNLOG"

echo "=== Starting Xorg for NWN test ==="
$ESUDO Xorg :0 \
  -config "$XCONF" \
  -logfile "$XLOG" \
  -nolisten tcp \
  -keeptty \
  vt1 &
XPID=$!
echo "Xorg pid=$XPID"

sleep 5

export DISPLAY=:0
export SDL_VIDEO_X11_XRANDR=1
export SDL_VIDEO_X11_XVIDMODE=0
export SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR=0
export vblank_mode=0
export SDL_JOYSTICK_DEVICE=/dev/input/js0

echo "DISPLAY=$DISPLAY"
echo "SDL_VIDEO_X11_XRANDR=$SDL_VIDEO_X11_XRANDR"
echo "SDL_VIDEO_X11_XVIDMODE=$SDL_VIDEO_X11_XVIDMODE"
echo "SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR=$SDL_VIDEO_X11_NET_WM_BYPASS_COMPOSITOR"
echo "vblank_mode=$vblank_mode"
echo "SDL_JOYSTICK_DEVICE=$SDL_JOYSTICK_DEVICE"
echo

echo "=== X display info ==="
DISPLAY=:0 xdpyinfo 2>/dev/null | grep -E "dimensions|depth|resolution" || true
DISPLAY=:0 xrandr 2>/dev/null || true
echo

echo "=== Launch command ==="
RUN_CMD=("$NWN_EXE" "$MODE_ARG" "$MODULE_ID")
printf 'Command: '
printf '%q ' "${RUN_CMD[@]}"
printf '\n'
echo

GPTK_CONFIG="$GAMEDIR/nwmain-linux.gptk"
echo "GPTOKEYB=$GPTOKEYB"
echo "gptokeyb config=$GPTK_CONFIG"
ls -l "$GPTK_CONFIG" 2>/dev/null || true

if [ ! -f "$GPTK_CONFIG" ]; then
  echo "WARNING: gptokeyb config not found: $GPTK_CONFIG"
fi

if [ -n "${GPTOKEYB:-}" ]; then
  echo "=== Starting gptokeyb ==="
  echo "GPTOKEYB=$GPTOKEYB"
  echo "gptokeyb target=$BIN"
  echo "gptokeyb config=$GPTK_CONFIG"
  echo "gptokeyb command: $GPTOKEYB $BIN -c $GPTK_CONFIG"
  $GPTOKEYB "$BIN" -c "$GPTK_CONFIG" &
  GTPID=$!
  echo "gptokeyb pid=$GTPID"
  sleep 1
  ps | grep -i '[g]ptokeyb' || true
else
  echo "WARNING: GPTOKEYB variable is empty, continuing without control mapping"
fi

echo "=== Starting NWN test run ==="
"$NWN_EXE" "$MODE_ARG" "$MODULE_ID" > "$NWNLOG" 2>&1 &
NWPID=$!
echo "NWN pid=$NWPID"

sleep 10

#echo "=== Launching xvkbd test ==="
#if [ -x "$GAMEDIR/show-keyboard.sh" ]; then
#  "$GAMEDIR/show-keyboard.sh"
#  XVKBD_RC=$?
#  echo "xvkbd exit code=$XVKBD_RC"
#else
#  XVKBD_RC=127
#  echo "xvkbd exit code=$XVKBD_RC"
#  echo "WARNING: show-keyboard.sh not found or not executable: $GAMEDIR/show-keyboard.sh"
#fi
#echo "=== xvkbd finished ==="

sleep "$TIMEOUT"

echo "=== stopping NWN pid=$NWPID ==="
kill -TERM "$NWPID" 2>/dev/null || true
sleep 3
kill -KILL "$NWPID" 2>/dev/null || true
$ESUDO killall -9 nwmain-linux 2>/dev/null || true

echo "=== stopping gptokeyb ==="
if [ -n "${GTPID:-}" ]; then
  kill -TERM "$GTPID" 2>/dev/null || true
  sleep 1
  kill -KILL "$GTPID" 2>/dev/null || true
fi
$ESUDO killall -9 gptokeyb 2>/dev/null || true

echo "=== stopping Xorg pid=$XPID ==="
$ESUDO kill -TERM "$XPID" 2>/dev/null || true
sleep 2
$ESUDO kill -KILL "$XPID" 2>/dev/null || true
$ESUDO killall -9 Xorg 2>/dev/null || true

echo "=== test-nwn.log tail ==="
tail -200 "$NWNLOG" || true

echo "=== test-xorg.log tail ==="
tail -200 "$XLOG" || true

exit 0
