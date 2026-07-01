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
LOAD_SENTINEL="R36S_BOOTSTRAP_LOAD_REQUESTED"
LOAD_REQUEST_HANDLED=0
SAVEINDEX_WRITTEN=0
IMAGE_TEST=0
ORIG_BOOTSTRAP_NCS_EXISTS=0

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

if [ "${NUI_IMAGE_TEST:-0}" = "1" ] || [ "$MODULE_NAME" = "nui-image-test" ]; then
  IMAGE_TEST=1
  MODULE_NAME="03_r36s_bootstrap_nui_window"
fi

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
echo "IMAGE_TEST=$IMAGE_TEST"
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
  if [ "$IMAGE_TEST" -eq 1 ] && [ -f "${ORIG_BOOTSTRAP_NCS:-}" ]; then
    if [ "$ORIG_BOOTSTRAP_NCS_EXISTS" -eq 1 ]; then
      cp -a "$ORIG_BOOTSTRAP_NCS" "$USER_DIR/development/r36s_onenter_nui.ncs" 2>/dev/null || true
    else
      rm -f "$USER_DIR/development/r36s_onenter_nui.ncs" 2>/dev/null || true
    fi
    rm -f "$ORIG_BOOTSTRAP_NCS" 2>/dev/null || true
  fi
}

if [ "$IMAGE_TEST" -eq 1 ]; then
  mkdir -p "$USER_DIR/development"
  ORIG_BOOTSTRAP_NCS="$LOG_DIR/r36s_onenter_nui.ncs.backup"
  if [ -f "$USER_DIR/development/r36s_onenter_nui.ncs" ]; then
    cp -a "$USER_DIR/development/r36s_onenter_nui.ncs" "$ORIG_BOOTSTRAP_NCS"
    ORIG_BOOTSTRAP_NCS_EXISTS=1
  else
    : > "$ORIG_BOOTSTRAP_NCS"
  fi
  IMAGE_TEST_SRC="$REPO_ROOT/dev/bootstrap/scripts/r36s_nimgtest.nss"
  if [ ! -f "$IMAGE_TEST_SRC" ]; then
    echo "ERROR: missing image test source: $IMAGE_TEST_SRC"
    exit 1
  fi
  echo "=== Compiling NuiImage test overlay ==="
  IMAGE_TEST_NCS="/tmp/r36s_nimgtest.ncs"
  "$REPO_ROOT/dev/external/nwn_script_comp/bin/nwn_script_comp" \
    --root "$STEAM_NWN_DIR" \
    --userdirectory "$USER_DIR" \
    --no-ovr \
    -o "$IMAGE_TEST_NCS" \
    "$IMAGE_TEST_SRC"
  cp -a "$IMAGE_TEST_NCS" "$USER_DIR/development/r36s_onenter_nui.ncs"
fi

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
  if [ "$LOAD_REQUEST_HANDLED" -eq 0 ] && grep -Rqs -- "$LOAD_SENTINEL" "$USER_DIR/logs" "$RUN_LOG"; then
    echo "R36S load request detected; scanning saves"
    if [ "$SAVEINDEX_WRITTEN" -eq 0 ]; then
      mkdir -p "$USER_DIR/development"
      SAVEINDEX_FILE="$USER_DIR/development/r36s_saveindex.txt"
      : > "$SAVEINDEX_FILE"
      SAVES_WRITTEN=0
      FIRST_SAVE_DIR=""
      SAVES_DIR="${R36S_SAVES_DIR:-$HOME/.local/share/Neverwinter Nights/saves}"
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
              cp -a "$save_dir/screen.tga" "$USER_DIR/development/r36s_preview.tga"
              echo "R36S_RESMAN_COPY_PREVIEW: $USER_DIR/development/r36s_preview.tga"
            else
              rm -f "$USER_DIR/development/r36s_preview.tga"
              echo "R36S_RESMAN_COPY_PREVIEW: missing"
            fi
            if [ -f "$save_dir/portrait.tga" ]; then
              cp -a "$save_dir/portrait.tga" "$USER_DIR/development/r36s_portrait.tga"
              echo "R36S_RESMAN_COPY_PORTRAIT: $USER_DIR/development/r36s_portrait.tga"
            else
              rm -f "$USER_DIR/development/r36s_portrait.tga"
              echo "R36S_RESMAN_COPY_PORTRAIT: missing"
            fi
            if [ -f "$save_dir/player.bic" ]; then
              cp -a "$save_dir/player.bic" "$USER_DIR/development/r36s_character.bic"
              echo "R36S_RESMAN_COPY_CHARACTER: $USER_DIR/development/r36s_character.bic"
            else
              rm -f "$USER_DIR/development/r36s_character.bic"
              echo "R36S_RESMAN_COPY_CHARACTER: missing"
            fi
          fi
          SAVES_WRITTEN=$((SAVES_WRITTEN + 1))
        done
      fi
      if [ "$SAVES_WRITTEN" -eq 0 ]; then
        printf '%s\n' 'EMPTY|No saved games found' > "$SAVEINDEX_FILE"
        rm -f "$USER_DIR/development/r36s_preview.tga" "$USER_DIR/development/r36s_portrait.tga"
        rm -f "$USER_DIR/development/r36s_character.bic"
      fi
      echo "Wrote saveindex resource: $SAVEINDEX_FILE"
      SAVEINDEX_WRITTEN=1
    fi
    SAVES_DIR="${R36S_SAVES_DIR:-$HOME/.local/share/Neverwinter Nights/saves}"
    if [ ! -d "$SAVES_DIR" ]; then
      echo "ERROR: saves directory missing: $SAVES_DIR"
    fi
    LOAD_REQUEST_HANDLED=1
  fi

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
