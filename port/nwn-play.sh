#!/bin/bash
set +e

GAMEDIR_FALLBACK="/roms/ports/nwn-ee"
mkdir -p "$GAMEDIR_FALLBACK" 2>/dev/null || true
EARLYLOG="$GAMEDIR_FALLBACK/test-early.log"
exec > >(tee -a "$EARLYLOG") 2>&1

NWN_DEBUG="${NWN_DEBUG:-0}"

debug_log() {
  [ "$NWN_DEBUG" = "1" ] && echo "$@"
}

debug_cmd() {
  if [ "$NWN_DEBUG" = "1" ]; then
    "$@" || true
  fi
}

echo "=== start-test early ==="
date
echo "args: $@"
echo "HOME=$HOME"
if [ "$NWN_DEBUG" = "1" ]; then
  debug_cmd pwd
  debug_cmd id
  debug_log "SHELL=$SHELL"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

#MODE="${1:-${NWN_TEST_MODE:-load}}"
#MODULE_ID="${2:-${NWN_TEST_MODULE:-Prelude}}"
MODE="${1:-${NWN_TEST_MODE:-test}}"
MODULE_ID="${2:-${NWN_TEST_MODULE:-03_r36s_bootstrap_nui_window}}"
TIMEOUT="${3:-${NWN_TEST_TIMEOUT:-180}}"
SENTINEL="R36S_BOOTSTRAP_EXIT_CONFIRMED"
LOAD_SENTINEL="R36S_BOOTSTRAP_LOAD_REQUESTED"
LOAD_REQUEST_HANDLED=0
SAVEINDEX_WRITTEN=0

sanitize_field() {
  local value="${1//$'\r'/ }"
  value="${value//$'\n'/ }"
  value="${value//|/ }"
  printf '%s' "$value"
}

extract_bic_meta() {
  local bic_file="$1"
  python3 - "$bic_file" <<'PY'
import struct
import sys
from pathlib import Path

class_map = [
    "Barbarian", "Bard", "Cleric", "Druid", "Fighter", "Monk", "Paladin",
    "Ranger", "Rogue", "Sorcerer", "Wizard", "Arcane Archer", "Assassin",
    "Blackguard", "Black Monk", "Champion of Torm", "Red Dragon Disciple",
    "Shadowdancer", "Harper Scout", "Neverwinter Nine", "Commoner",
    "Beast", "Giant", "Magical Beast", "Outsider", "Shapechanger",
    "Vermin", "Shadowdancer", "Harper Scout", "Arcane Archer", "Assassin",
    "Blackguard", "Divine Champion", "Weapon Master", "Pale Master",
    "Shifter", "Dwarven Defender", "Dragon Disciple", "Ooze",
    "Eye of Gruumsh", "Shou Disciple", "Purple Dragon Knight",
]

path = Path(sys.argv[1])
try:
    data = path.read_bytes()
    if len(data) < 56 or data[:4] != b"BIC ":
        raise ValueError("not a BIC file")

    (
        struct_off, struct_count,
        field_off, field_count,
        label_off, label_count,
        fielddata_off, fielddata_count,
        fieldidx_off, fieldidx_count,
        listidx_off, listidx_count,
    ) = struct.unpack("<12I", data[8:56])

    labels = [
        data[label_off + i * 16:label_off + i * 16 + 16].split(b"\0", 1)[0].decode("latin1", "replace")
        for i in range(label_count)
    ]

    def read_locstring(offset: int) -> str:
        p = fielddata_off + offset
        if p + 12 > len(data):
            return ""
        try:
            _, _, count = struct.unpack("<III", data[p:p + 12])
            p += 12
            texts = []
            for _ in range(count):
                if p + 8 > len(data):
                    break
                _, length = struct.unpack("<II", data[p:p + 8])
                p += 8
                texts.append(data[p:p + length].decode("latin1", "replace"))
                p += length
            if texts:
                return texts[0]
        except Exception:
            pass
        raw = data[p:p + 128]
        return raw.split(b"\0", 1)[0].decode("latin1", "replace")

    def read_resref(offset: int) -> str:
        p = fielddata_off + offset
        if p >= len(data):
            return ""
        length = data[p]
        if p + 1 + length > len(data):
            return ""
        return data[p + 1:p + 1 + length].decode("latin1", "replace")

    found = {}
    for i in range(field_count):
        ftype, label_idx, fdata = struct.unpack("<III", data[field_off + i * 12:field_off + i * 12 + 12])
        if label_idx >= len(labels):
            continue
        label = labels[label_idx]
        if label not in {"FirstName", "LastName", "Portrait", "Class", "ClassLevel"}:
            continue
        if label in found:
            continue
        if label in {"FirstName", "LastName"}:
            found[label] = read_locstring(fdata)
        elif label == "Portrait":
            found[label] = read_resref(fdata)
        else:
            found[label] = str(fdata)

    first = found.get("FirstName", "")
    last = found.get("LastName", "")
    name = (first + " " + last).strip()
    portrait = found.get("Portrait", "")
    class_id = found.get("Class", "")
    level = found.get("ClassLevel", "")
    class_name = ""
    if class_id.isdigit():
        class_idx = int(class_id)
        if 0 <= class_idx < len(class_map):
            class_name = class_map[class_idx]
    print("\t".join([
        name.replace("\t", " ").replace("\n", " "),
        portrait.replace("\t", " ").replace("\n", " "),
        class_name.replace("\t", " ").replace("\n", " "),
        level.replace("\t", " ").replace("\n", " "),
    ]))
except Exception:
    print("\t\t\t")
PY
}

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
NWN_USERDIR="${NWN_USERDIR:-/home/ark/.local/share/Neverwinter Nights}"
CUSTOM_DIR="$GAMEDIR/custom"

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
echo "NWN_DEBUG=$NWN_DEBUG"
echo "USER=$USER"
echo "HOME=$HOME"
echo "CFW_NAME=$CFW_NAME"
echo "DEVICE_ARCH=$DEVICE_ARCH"
echo "directory=$directory"
echo "GAMEDIR=$GAMEDIR"
echo "BINDIR=$BINDIR"
echo "BIN=$BIN"
echo "NWN_USERDIR=$NWN_USERDIR"
echo "CUSTOM_DIR=$CUSTOM_DIR"
echo "NWN_EXE=$NWN_EXE"
echo "XCONF=$XCONF"
echo "TESTLOG=$TESTLOG"
echo "XLOG=$XLOG"
echo "NWNLOG=$NWNLOG"
echo

if [ "$NWN_DEBUG" = "1" ]; then
  echo "=== X11 checks ==="
  debug_cmd which Xorg
  debug_cmd which X
  debug_cmd which startx
  debug_cmd which xinit
  debug_cmd which xdpyinfo
  debug_cmd which xrandr
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
fi

mkdir -p "$NWN_USERDIR/modules" "$NWN_USERDIR/development" 2>/dev/null || true

if [ -f "$NWN_USERDIR/modules/03_r36s_bootstrap_nui_window.mod" ]; then
  echo "bootstrap module already installed"
else
  if [ -f "$CUSTOM_DIR/modules/03_r36s_bootstrap_nui_window.mod" ]; then
    echo "installing bootstrap module"
    if cp -a "$CUSTOM_DIR/modules/03_r36s_bootstrap_nui_window.mod" "$NWN_USERDIR/modules/03_r36s_bootstrap_nui_window.mod" 2>/dev/null; then
      echo "bootstrap module installed"
    else
      echo "ERROR: failed to install bootstrap module"
    fi
  else
    echo "ERROR: missing source bootstrap module: $CUSTOM_DIR/modules/03_r36s_bootstrap_nui_window.mod"
  fi
fi

if [ -f "$NWN_USERDIR/development/r36s_onenter_nui.ncs" ]; then
  echo "bootstrap NUI script already installed"
else
  if [ -f "$CUSTOM_DIR/development/r36s_onenter_nui.ncs" ]; then
    echo "installing bootstrap NUI script"
    if cp -a "$CUSTOM_DIR/development/r36s_onenter_nui.ncs" "$NWN_USERDIR/development/r36s_onenter_nui.ncs" 2>/dev/null; then
      echo "bootstrap NUI script installed"
    else
      echo "ERROR: failed to install bootstrap NUI script"
    fi
  else
    echo "ERROR: missing source bootstrap NUI script: $CUSTOM_DIR/development/r36s_onenter_nui.ncs"
  fi
fi

if [ -f "$NWN_USERDIR/development/r36s_rsi.ncs" ]; then
  echo "bootstrap RSI script already installed"
else
  if [ -f "$CUSTOM_DIR/development/r36s_rsi.ncs" ]; then
    echo "installing bootstrap RSI script"
    if cp -a "$CUSTOM_DIR/development/r36s_rsi.ncs" "$NWN_USERDIR/development/r36s_rsi.ncs" 2>/dev/null; then
      echo "bootstrap RSI script installed"
    else
      echo "ERROR: failed to install bootstrap RSI script"
    fi
  else
    echo "ERROR: missing source bootstrap RSI script: $CUSTOM_DIR/development/r36s_rsi.ncs"
  fi
fi

if [ "$NWN_DEBUG" = "1" ]; then
  echo "=== User directory diagnostics ==="
  echo "USER=$USER"
  echo "HOME=$HOME"
  debug_cmd pwd
  debug_cmd id
  echo "GAMEDIR=$GAMEDIR"
  echo "BINDIR=$BINDIR"
  echo "BIN=$BIN"
  echo "XDG_DATA_HOME=$XDG_DATA_HOME"
  echo "XDG_CONFIG_HOME=${XDG_CONFIG_HOME:-}"
  echo "XDG_CACHE_HOME=${XDG_CACHE_HOME:-}"
  for path in \
    /home/ark \
    /home/ark/.local \
    /home/ark/.local/share \
    /home/ark/.local/share/Neverwinter\ Nights \
    /home/ark/.local/share/Neverwinter\ Nights/modules \
    /home/ark/.local/share/Neverwinter\ Nights/development \
    "$GAMEDIR/modules" \
    "$GAMEDIR/development" \
    "$GAMEDIR/data/mod"
  do
    echo "--- $path ---"
    ls -ld "$path" 2>/dev/null || true
    find "$path" -maxdepth 1 -mindepth 0 -print 2>/dev/null || true
    find "$path" -maxdepth 2 -mindepth 1 -print 2>/dev/null | sed -n '1,20p' || true
  done
  echo
fi

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

deadline=$((SECONDS + TIMEOUT))
while true; do
  if [ "$LOAD_REQUEST_HANDLED" -eq 0 ] && grep -Rqs -- "$LOAD_SENTINEL" "$NWNLOG" "$TESTLOG" 2>/dev/null; then
    echo "R36S load request detected; scanning saves"
    if [ "$SAVEINDEX_WRITTEN" -eq 0 ]; then
      mkdir -p "$NWN_USERDIR/development" 2>/dev/null || true
      SAVEINDEX_FILE="$NWN_USERDIR/development/r36s_saveindex.txt"
      : > "$SAVEINDEX_FILE"
      SAVES_WRITTEN=0
      FIRST_SAVE_DIR=""
      SAVES_DIR="${R36S_SAVES_DIR:-$NWN_USERDIR/saves}"
      if [ ! -d "$SAVES_DIR" ]; then
        SAVES_DIR="${R36S_SAVES_DIR:-$HOME/.local/share/Neverwinter Nights/saves}"
      fi
      if [ -d "$SAVES_DIR" ]; then
        for save_dir in "$SAVES_DIR"/*; do
          [ -d "$save_dir" ] || continue
          folder="$(basename "$save_dir")"
          save_name="$folder"
          case "$folder" in
            *" - "*) save_name="${folder#* - }" ;;
          esac
          area=""
          if [ -f "$save_dir/savenfo.txt" ]; then
            area="$(tr -d '\r\n' < "$save_dir/savenfo.txt")"
          fi
          mtime="$(stat -c '%y' "$save_dir" 2>/dev/null || true)"
          module_name=""
          for sav_file in "$save_dir"/*.sav; do
            if [ -f "$sav_file" ]; then
              module_name="$(basename "$sav_file" .sav)"
              break
            fi
          done
          character_name=""
          portrait_resref=""
          class_name=""
          level=""
          if [ -f "$save_dir/player.bic" ]; then
            bic_meta="$(extract_bic_meta "$save_dir/player.bic")"
            IFS=$'\t' read -r character_name portrait_resref class_name level <<EOF
$bic_meta
EOF
          fi
          folder="$(sanitize_field "$folder")"
          save_name="$(sanitize_field "$save_name")"
          area="$(sanitize_field "$area")"
          mtime="$(sanitize_field "$mtime")"
          module_name="$(sanitize_field "$module_name")"
          character_name="$(sanitize_field "$character_name")"
          portrait_resref="$(sanitize_field "$portrait_resref")"
          class_name="$(sanitize_field "$class_name")"
          level="$(sanitize_field "$level")"
          save_line="$(printf 'SAVE|%s|%s|%s|%s|%s|%s|%s|%s|%s' "$folder" "$save_name" "$area" "$mtime" "$module_name" "$character_name" "$portrait_resref" "$class_name" "$level")"
          echo "R36S_CHARACTER_META_NAME: $character_name"
          echo "R36S_CHARACTER_META_PORTRAIT: $portrait_resref"
          echo "R36S_CHARACTER_META_CLASS: $class_name"
          echo "R36S_CHARACTER_META_LEVEL: $level"
          echo "R36S_SAVEINDEX_V2_LINE: $save_line"
          printf '%s\n' "$save_line" >> "$SAVEINDEX_FILE"
          if [ -z "$FIRST_SAVE_DIR" ]; then
            FIRST_SAVE_DIR="$save_dir"
            if [ -f "$save_dir/screen.tga" ]; then
              cp -a "$save_dir/screen.tga" "$NWN_USERDIR/development/r36s_preview.tga"
              echo "R36S_RESMAN_COPY_PREVIEW: $NWN_USERDIR/development/r36s_preview.tga"
            else
              rm -f "$NWN_USERDIR/development/r36s_preview.tga"
              echo "R36S_RESMAN_COPY_PREVIEW: missing"
            fi
            if [ -f "$save_dir/portrait.tga" ]; then
              cp -a "$save_dir/portrait.tga" "$NWN_USERDIR/development/r36s_portrait.tga"
              echo "R36S_RESMAN_COPY_PORTRAIT: $NWN_USERDIR/development/r36s_portrait.tga"
            else
              rm -f "$NWN_USERDIR/development/r36s_portrait.tga"
              echo "R36S_RESMAN_COPY_PORTRAIT: missing"
            fi
            if [ -f "$save_dir/player.bic" ]; then
              cp -a "$save_dir/player.bic" "$NWN_USERDIR/development/r36s_character.bic"
              echo "R36S_RESMAN_COPY_CHARACTER: $NWN_USERDIR/development/r36s_character.bic"
            else
              rm -f "$NWN_USERDIR/development/r36s_character.bic"
              echo "R36S_RESMAN_COPY_CHARACTER: missing"
            fi
          fi
          SAVES_WRITTEN=$((SAVES_WRITTEN + 1))
        done
      fi
      if [ "$SAVES_WRITTEN" -eq 0 ]; then
        printf '%s\n' 'EMPTY|No saved games found' > "$SAVEINDEX_FILE"
        rm -f "$NWN_USERDIR/development/r36s_preview.tga" "$NWN_USERDIR/development/r36s_portrait.tga"
        rm -f "$NWN_USERDIR/development/r36s_character.bic"
      fi
      echo "Wrote saveindex resource: $SAVEINDEX_FILE"
      SAVEINDEX_WRITTEN=1
    fi
    LOAD_REQUEST_HANDLED=1
  fi

  if ! kill -0 "$NWPID" 2>/dev/null; then
    break
  fi

  if grep -Rqs -- "$SENTINEL" "$NWNLOG" "$TESTLOG" 2>/dev/null; then
    echo "R36S sentinel exit confirmed; sending SIGINT to nwmain-linux"
    kill -INT "$NWPID" 2>/dev/null || true
    for _ in 1 2 3 4 5; do
      if kill -0 "$NWPID" 2>/dev/null; then
        sleep 1
      else
        break
      fi
    done
    if kill -0 "$NWPID" 2>/dev/null; then
      echo "nwmain-linux still alive after SIGINT; sending SIGKILL"
      kill -KILL "$NWPID" 2>/dev/null || true
    fi
    wait "$NWPID" || true
    break
  fi

  if [ "$SECONDS" -ge "$deadline" ]; then
    echo "ERROR: timeout reached before sentinel exit (${TIMEOUT}s)"
    kill -TERM "$NWPID" 2>/dev/null || true
    sleep 3
    if kill -0 "$NWPID" 2>/dev/null; then
      kill -KILL "$NWPID" 2>/dev/null || true
    fi
    wait "$NWPID" || true
    break
  fi

  sleep 1
done

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

if [ "$NWN_DEBUG" = "1" ]; then
  echo "=== test-nwn.log tail ==="
  tail -200 "$NWNLOG" || true

  echo "=== test-xorg.log tail ==="
  tail -200 "$XLOG" || true
fi

if [ "$NWN_DEBUG" = "1" ]; then
  echo "=== post-run log diagnostics ==="
  for logfile in "$NWNLOG" "$XLOG"; do
    echo "--- $logfile ---"
    grep -n "Working Directory For Game Install Is" "$logfile" 2>/dev/null || true
    grep -n "Working Directory For Your Resources Is" "$logfile" 2>/dev/null || true
    grep -n "Loading Module" "$logfile" 2>/dev/null || true
    grep -n "Could not divine nwn base data directory" "$logfile" 2>/dev/null || true
  done
fi

exit 0
