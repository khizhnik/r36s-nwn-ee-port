#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="$REPO_ROOT/dev/pc/logs"
STEAM_NWN_DIR="${STEAM_NWN_DIR:-$HOME/.steam/debian-installation/steamapps/common/Neverwinter Nights}"
NWN_BIN="$STEAM_NWN_DIR/bin/linux-x86/nwmain-linux"
TRACE_NWN_BIN="/tmp/nwmain-linux-hardlink"
TRACEFS_UPROBE_EVENTS="/sys/kernel/tracing/uprobe_events"
if [[ ! -e "$TRACEFS_UPROBE_EVENTS" ]]; then
  TRACEFS_UPROBE_EVENTS="/sys/kernel/debug/tracing/uprobe_events"
fi

TRACE_MODE="${TRACE_MODE:-selection}"
case "$TRACE_MODE" in
  selection)
    TRACE_TAG="host-trace-handle-select"
    TRACE_TITLE="selection lifecycle"
    TRACE_FAILURE_CONTEXT="CPanelLoadSave::HandleSelectSaveGame(int)"
    MANUAL_ACTIONS="Open the Load screen, select one save, then press Ctrl+C here to stop tracing."
    PROBE_NAMES=("nwn_handle_select" "nwn_add_res_dir" "nwn_replace_portrait")
    PROBE_LABELS=("CPanelLoadSave::HandleSelectSaveGame" "CExoResMan::AddResourceDirectory" "CNWPortrait::ReplacePortraitTexture")
    PROBE_SPECS=(
      "nwn_handle_select=CPanelLoadSave\\:\\:HandleSelectSaveGame"
      "nwn_add_res_dir=CExoResMan\\:\\:AddResourceDirectory"
      "nwn_replace_portrait=CNWPortrait\\:\\:ReplacePortraitTexture"
    )
    PROBE_ADDRS=()
    ;;
  load-request)
    TRACE_TAG="host-trace-load-request"
    TRACE_TITLE="native load-request lifecycle"
    TRACE_FAILURE_CONTEXT="native load-request probe set"
    MANUAL_ACTIONS="Open the native Load screen, select one save, press the native Load button, then press Ctrl+C here to stop tracing."
    PROBE_NAMES=("nwn_load_ok" "nwn_load_req" "nwn_client_send_load" "nwn_net_load_game" "nwn_server_load_game")
    PROBE_LABELS=("CPanelLoadGame::HandleOkButton" "CPanelLoadGame::SendLoadGameRequest" "CClientExoApp::SendLoadGameRequest" "CNWCMessage::SendPlayerToServerModule_LoadGame" "CServerExoApp::LoadGame")
    PROBE_SPECS=(
      "nwn_load_ok=CPanelLoadGame\\:\\:HandleOkButton"
      "nwn_load_req=CPanelLoadGame\\:\\:SendLoadGameRequest"
      "nwn_client_send_load=CClientExoApp\\:\\:SendLoadGameRequest"
      "nwn_net_load_game=CNWCMessage\\:\\:SendPlayerToServerModule_LoadGame"
      "nwn_server_load_game=CServerExoApp\\:\\:LoadGame"
    )
    PROBE_ADDRS=("0x6f99a0" "0x6fa1d0" "0x637960" "0x8027b0" "0x9fe780")
    ;;
  *)
    echo "ERROR: unsupported TRACE_MODE: $TRACE_MODE" >&2
    exit 1
    ;;
esac

TS="$(date +%Y%m%d-%H%M%S)"
TRACE_TXT="$LOG_DIR/$TRACE_TAG-$TS.txt"
PERF_DATA="$LOG_DIR/$TRACE_TAG-$TS.data"
PERF_RECORD_LOG="$LOG_DIR/$TRACE_TAG-$TS.perf-record.log"
SETUP_LOG="$LOG_DIR/$TRACE_TAG-$TS.setup.log"
PROBE_EVENTS=()
PROBE_OFFSETS=()
PROBE_OFFSET_SOURCE=()
PROBE_DEFS=()
PROBE_ADD_OUTPUTS=()
PROBE_ADD_ERRORS=()
PROBE_RECORD_EVENT_LIST=""
PERF_EVENT_NAME=""
PERF_RECORD_PID=""
PROBE_ADDED=()
STOP_REQUESTED=0
SETUP_ONLY="${HOST_TRACE_SETUP_ONLY:-0}"
NO_LAUNCH=0
KILL_ON_EXIT=0
ADD_STDOUT=""
ADD_STDERR=""
ADD_EXIT_CODE=0
ADD_ATTEMPT=""
TRACEFS_ATTEMPT=""
LINK_CREATED=0
LAUNCHER_PID=""
NWN_PID=""
NWN_ACCEPTED_EXE=""
NWN_ACCEPTED_INODE=""
NWN_ORIG_INODE=""
NWN_HARDLINK_INODE=""
LAUNCH_CMD_DESC=""
LAUNCHED_BY_HELPER=0
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

for arg in "$@"; do
  case "$arg" in
    --setup-only|-S)
      SETUP_ONLY=1
      ;;
    --no-launch)
      NO_LAUNCH=1
      ;;
    --kill-on-exit)
      KILL_ON_EXIT=1
      ;;
  esac
done

log_setup() {
  printf '%s\n' "$*" >> "$SETUP_LOG"
}

log_block() {
  local title="$1"
  local file="$2"
  log_setup "----- $title -----"
  if [[ -s "$file" ]]; then
    cat "$file" >> "$SETUP_LOG"
  fi
  log_setup
}

join_by() {
  local IFS="$1"
  shift
  printf '%s' "$*"
}

cleanup() {
  set +e

  if [[ -n "$PERF_RECORD_PID" ]] && kill -0 "$PERF_RECORD_PID" 2>/dev/null; then
    kill -INT "$PERF_RECORD_PID" 2>/dev/null || true
    wait "$PERF_RECORD_PID" 2>/dev/null || true
  fi

  if [[ "$LAUNCHED_BY_HELPER" -eq 1 && "$KILL_ON_EXIT" -eq 1 ]]; then
    if [[ -n "$NWN_PID" ]] && kill -0 "$NWN_PID" 2>/dev/null; then
      kill -INT "$NWN_PID" 2>/dev/null || true
      sleep 1 || true
      kill -TERM "$NWN_PID" 2>/dev/null || true
      log_setup "Cleanup: killed NWN PID $NWN_PID"
    fi
    if [[ -n "$LAUNCHER_PID" ]] && kill -0 "$LAUNCHER_PID" 2>/dev/null; then
      kill -INT "$LAUNCHER_PID" 2>/dev/null || true
      sleep 1 || true
      kill -TERM "$LAUNCHER_PID" 2>/dev/null || true
      log_setup "Cleanup: killed launcher PID $LAUNCHER_PID"
    fi
  elif [[ "$LAUNCHED_BY_HELPER" -eq 1 ]]; then
    log_setup "Cleanup: leaving helper-launched game running by default"
  fi

  if [[ "${#PROBE_ADDED[@]}" -gt 0 ]]; then
    local idx del_line tracefs_del_cmd
    for idx in "${!PROBE_ADDED[@]}"; do
      if [[ "${PROBE_ADDED[$idx]}" -eq 1 && -n "${PROBE_EVENTS[$idx]:-}" ]]; then
        if sudo perf probe --del "${PROBE_EVENTS[$idx]}" >/dev/null 2>&1; then
          log_setup "Cleanup: perf probe --del succeeded for ${PROBE_EVENTS[$idx]}"
        else
          log_setup "Cleanup: perf probe --del failed for ${PROBE_EVENTS[$idx]}"
          del_line="-:${PROBE_EVENTS[$idx]/:/\/}"
          tracefs_del_cmd="sudo sh -c \"printf '%s\\n' '$del_line' > '$TRACEFS_UPROBE_EVENTS'\""
          log_setup "Cleanup fallback CMD: $tracefs_del_cmd"
          sudo sh -c "printf '%s\n' '$del_line' > '$TRACEFS_UPROBE_EVENTS'" >/dev/null 2>&1 || true
        fi
        PROBE_ADDED[$idx]=0
      fi
    done
  fi

  if [[ "$LINK_CREATED" -eq 1 && -e "$TRACE_NWN_BIN" ]]; then
    rm -f "$TRACE_NWN_BIN"
    log_setup "Cleanup: removed hardlink $TRACE_NWN_BIN"
    LINK_CREATED=0
  fi
}

on_int() {
  STOP_REQUESTED=1
  if [[ -n "$PERF_RECORD_PID" ]] && kill -0 "$PERF_RECORD_PID" 2>/dev/null; then
    kill -INT "$PERF_RECORD_PID" 2>/dev/null || true
  fi
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $cmd" >&2
    exit 1
  fi
}

add_probe() {
  local idx="$1"
  local tmp_out tmp_err rc
  tmp_out="$(mktemp)"
  tmp_err="$(mktemp)"

  if [[ -z "${PROBE_SPECS[$idx]:-}" ]]; then
    echo "ERROR: probe spec is empty" >&2
    return 1
  fi

  if [[ -z "${PROBE_OFFSETS[$idx]:-}" ]]; then
    echo "ERROR: probe offset is empty" >&2
    return 1
  fi

  log_setup "=== ADD ==="
  log_setup "ADD_ATTEMPT: sudo perf probe -x '$TRACE_NWN_BIN' --add '${PROBE_NAMES[$idx]}=${PROBE_OFFSETS[$idx]}'"

  set +e
  sudo perf probe -x "$TRACE_NWN_BIN" --add "${PROBE_NAMES[$idx]}=${PROBE_OFFSETS[$idx]}" >"$tmp_out" 2>"$tmp_err"
  rc=$?
  set -e

  ADD_EXIT_CODE="$rc"
  ADD_STDOUT="$(cat "$tmp_out")"
  ADD_STDERR="$(cat "$tmp_err")"
  log_setup "EXIT: $rc"
  log_block "STDOUT" "$tmp_out"
  log_block "STDERR" "$tmp_err"

  if [[ "$rc" -eq 0 ]]; then
    ADD_ATTEMPT="perf"
    PROBE_ADD_OUTPUTS[$idx]="$ADD_STDOUT"
    PROBE_ADD_ERRORS[$idx]="$ADD_STDERR"
    rm -f "$tmp_out" "$tmp_err"
    return 0
  fi

  if ! grep -q "Invalid argument" "$tmp_err"; then
    rm -f "$tmp_out" "$tmp_err"
    return "$rc"
  fi

  TRACEFS_ATTEMPT="sudo sh -c \"printf '%s\\n' 'p:probe_nwmain/${PROBE_NAMES[$idx]} $TRACE_NWN_BIN:${PROBE_OFFSETS[$idx]}' > '$TRACEFS_UPROBE_EVENTS'\""
  log_setup "TRACEFS_ATTEMPT: $TRACEFS_ATTEMPT"

  set +e
  sudo sh -c "printf '%s\n' 'p:probe_nwmain/${PROBE_NAMES[$idx]} $TRACE_NWN_BIN:${PROBE_OFFSETS[$idx]}' > '$TRACEFS_UPROBE_EVENTS'" >"$tmp_out" 2>"$tmp_err"
  rc=$?
  set -e

  ADD_EXIT_CODE="$rc"
  ADD_STDOUT="$(cat "$tmp_out")"
  ADD_STDERR="$(cat "$tmp_err")"
  log_setup "TRACEFS_EXIT: $rc"
  log_block "TRACEFS_STDOUT" "$tmp_out"
  log_block "TRACEFS_STDERR" "$tmp_err"
  ADD_ATTEMPT="tracefs"
  PROBE_ADD_OUTPUTS[$idx]="$ADD_STDOUT"
  PROBE_ADD_ERRORS[$idx]="$ADD_STDERR"
  rm -f "$tmp_out" "$tmp_err"

  return "$rc"
}

extract_event_name() {
  local text="$1"
  printf '%s\n' "$text" | grep -oE 'probe_[^[:space:]]+:[^[:space:]]+' | head -n1 || true
}

list_created_probe() {
  local event_name="$1"
  local line
  line="$(sudo perf probe -l 2>/dev/null | grep -F "$event_name" | head -n1 || true)"
  if [[ -n "$line" ]]; then
    printf '%s\n' "$line"
    return 0
  fi
  return 1
}

launch_harness() {
  local tmp_out tmp_err rc
  tmp_out="$(mktemp)"
  tmp_err="$(mktemp)"

  LAUNCH_CMD_DESC="HOME=\"$REAL_HOME\" USER=\"$REAL_USER\" LOGNAME=\"$REAL_USER\" DISPLAY=\"${DISPLAY:-:0}\" XAUTHORITY=\"${XAUTHORITY:-$REAL_HOME/.Xauthority}\" \"$REPO_ROOT/dev/pc/scripts/run-nui-bootstrap.sh\" test 03_r36s_bootstrap_nui_window"
  log_setup "LAUNCH_CMD: $LAUNCH_CMD_DESC"
  log_setup "REAL_USER: $REAL_USER"
  log_setup "REAL_HOME: $REAL_HOME"
  log_setup "HARNESS_HOME: $REAL_HOME"
  log_setup "HARNESS_XAUTHORITY: ${XAUTHORITY:-$REAL_HOME/.Xauthority}"

  set +e
  env HOME="$REAL_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" \
    DISPLAY="${DISPLAY:-:0}" XAUTHORITY="${XAUTHORITY:-$REAL_HOME/.Xauthority}" \
    "$REPO_ROOT/dev/pc/scripts/run-nui-bootstrap.sh" test 03_r36s_bootstrap_nui_window \
    >"$tmp_out" 2>"$tmp_err" &
  LAUNCHER_PID=$!
  rc=$?
  set -e

  log_setup "LAUNCHER_PID: $LAUNCHER_PID"
  log_setup "LAUNCH_SPAWN_EXIT: $rc"
  log_block "LAUNCH_STDOUT" "$tmp_out"
  log_block "LAUNCH_STDERR" "$tmp_err"
  rm -f "$tmp_out" "$tmp_err"

  if [[ "$rc" -ne 0 ]]; then
    echo "ERROR: unable to spawn harness launcher" >&2
    log_setup "ERROR: unable to spawn harness launcher"
    return 1
  fi

  LAUNCHED_BY_HELPER=1
  return 0
}

candidate_pid_matches() {
  local pid="$1"
  local exe_path exe_inode

  if [[ ! -e "/proc/$pid/exe" ]]; then
    return 1
  fi

  exe_path="$(readlink -f "/proc/$pid/exe" 2>/dev/null || true)"
  exe_inode="$(stat -Lc '%i' "/proc/$pid/exe" 2>/dev/null || true)"
  log_setup "CANDIDATE_PID: $pid"
  log_setup "CANDIDATE_EXE: $exe_path"
  log_setup "CANDIDATE_INODE: $exe_inode"

  if [[ -n "$exe_inode" && "$exe_inode" == "$NWN_ORIG_INODE" ]]; then
    NWN_ACCEPTED_EXE="$exe_path"
    NWN_ACCEPTED_INODE="$exe_inode"
    return 0
  fi

  return 1
}

discover_nwn_pid() {
  local deadline candidates pid current_inode current_exe
  local prev_pid="" prev_inode=""
  deadline=$((SECONDS + 30))
  while (( SECONDS < deadline )); do
    candidates=""
    if [[ -n "$LAUNCHER_PID" ]]; then
      candidates="$(pgrep -P "$LAUNCHER_PID" -f 'nwmain-linux' 2>/dev/null || true)"
    fi
    if [[ -z "$candidates" ]]; then
      candidates="$(pgrep -f 'nwmain-linux' 2>/dev/null || true)"
    fi

    if [[ -n "$candidates" ]]; then
      log_setup "PID_CANDIDATES: $(printf '%s ' $candidates)"
      for pid in $candidates; do
        if candidate_pid_matches "$pid"; then
          current_exe="$NWN_ACCEPTED_EXE"
          current_inode="$NWN_ACCEPTED_INODE"
          if [[ "$prev_pid" == "$pid" && "$prev_inode" == "$current_inode" ]]; then
            NWN_PID="$pid"
            log_setup "ACCEPTED_PID: $NWN_PID"
            log_setup "ACCEPTED_EXE: $NWN_ACCEPTED_EXE"
            log_setup "ACCEPTED_INODE: $NWN_ACCEPTED_INODE"
            return 0
          fi
          prev_pid="$pid"
          prev_inode="$current_inode"
          log_setup "PID_STABILIZING: pid=$pid inode=$current_inode exe=$current_exe"
          continue
        fi
      done
    else
      log_setup "PID_CANDIDATES: (none)"
    fi

    sleep 1
  done

  echo "ERROR: timed out waiting for nwmain-linux PID" >&2
  log_setup "ERROR: timed out waiting for nwmain-linux PID"
  return 1
}

create_probe() {
  local listing definition_out definition_line event_from_output orig_inode link_inode
  local trimmed_listing
  local tracefs_line idx

  : > "$SETUP_LOG"
  log_setup "Setup log for host-side perf tracing"
  log_setup "Timestamp: $TS"
  log_setup "Binary: $NWN_BIN"
  log_setup "Hardlink: $TRACE_NWN_BIN"
  log_setup "Tracefs file: $TRACEFS_UPROBE_EVENTS"
  log_setup "Trace mode: $TRACE_MODE"
  log_setup "Trace title: $TRACE_TITLE"
  log_setup "Probe specs: $(join_by ', ' "${PROBE_SPECS[@]}")"
  if [[ "${#PROBE_ADDRS[@]}" -gt 0 ]]; then
    log_setup "Probe fallback addresses: $(join_by ', ' "${PROBE_ADDRS[@]}")"
  fi
  log_setup

  if [[ ! -f "$NWN_BIN" ]]; then
    echo "ERROR: missing NWN binary: $NWN_BIN" >&2
    log_setup "ERROR: missing NWN binary"
    return 1
  fi

  orig_inode="$(stat -c '%i' "$NWN_BIN")"
  NWN_ORIG_INODE="$orig_inode"
  log_setup "Original inode: $orig_inode"

  rm -f "$TRACE_NWN_BIN"
  if ! ln "$NWN_BIN" "$TRACE_NWN_BIN"; then
    echo "ERROR: unable to create hardlink: $TRACE_NWN_BIN" >&2
    log_setup "ERROR: unable to create hardlink"
    return 1
  fi
  LINK_CREATED=1
  link_inode="$(stat -c '%i' "$TRACE_NWN_BIN")"
  NWN_HARDLINK_INODE="$link_inode"
  log_setup "Hardlink inode: $link_inode"

  for idx in "${!PROBE_SPECS[@]}"; do
    definition_out="$(perf probe -n -x "$NWN_BIN" --definition "${PROBE_SPECS[$idx]}" 2>/dev/null || true)"
    definition_line="$(printf '%s\n' "$definition_out" | sed -n '1p' | tr -d '\r')"
    if [[ -n "$definition_line" ]]; then
      PROBE_DEFS[$idx]="$definition_line"
      log_setup "DEFINITION[$idx]: ${PROBE_DEFS[$idx]}"
      PROBE_OFFSETS[$idx]="$(printf '%s\n' "${PROBE_DEFS[$idx]}" | grep -oE '0x[0-9a-fA-F]+' | head -n1 || true)"
      if [[ -n "${PROBE_OFFSETS[$idx]}" ]]; then
        PROBE_OFFSET_SOURCE[$idx]="perf"
        log_setup "Resolved offset[$idx] from perf: ${PROBE_OFFSETS[$idx]}"
      fi
    fi

    if [[ -z "${PROBE_OFFSETS[$idx]}" ]]; then
      if [[ -n "${PROBE_ADDRS[$idx]:-}" ]]; then
        PROBE_OFFSETS[$idx]="${PROBE_ADDRS[$idx]}"
        PROBE_OFFSET_SOURCE[$idx]="address"
        log_setup "Definition unavailable for ${PROBE_LABELS[$idx]}; using known address fallback: ${PROBE_OFFSETS[$idx]}"
      else
        echo "ERROR: unable to resolve probe definition for ${PROBE_LABELS[$idx]}" >&2
        log_setup "DEFINITION_OUT[$idx]:"
        log_setup "$definition_out"
        return 1
      fi
    fi
    log_setup "Resolved offset[$idx]: ${PROBE_OFFSETS[$idx]}"
  done

  for idx in "${!PROBE_NAMES[@]}"; do
    sudo perf probe --del "probe_nwmain:${PROBE_NAMES[$idx]}" >/dev/null 2>&1 || true
  done

  for idx in "${!PROBE_NAMES[@]}"; do
    if ! add_probe "$idx"; then
      return 1
    fi

    event_from_output="$(extract_event_name "${PROBE_ADD_OUTPUTS[$idx]:-}")"
    if [[ -z "$event_from_output" ]]; then
      event_from_output="$(extract_event_name "${PROBE_ADD_ERRORS[$idx]:-}")"
    fi

    listing="$(list_created_probe "probe_nwmain:${PROBE_NAMES[$idx]}" || true)"
    if [[ -z "$listing" ]]; then
      if [[ -n "$event_from_output" ]]; then
        listing="$event_from_output (from perf probe output)"
      else
        echo "ERROR: probe was added but could not be found in perf probe -l for ${PROBE_NAMES[$idx]}" >&2
        log_setup "ADD_STDOUT[$idx]:"
        log_setup "${PROBE_ADD_OUTPUTS[$idx]:-}"
        log_setup "ADD_STDERR[$idx]:"
        log_setup "${PROBE_ADD_ERRORS[$idx]:-}"
        return 1
      fi
    fi

    trimmed_listing="$(printf '%s\n' "$listing" | sed -E 's/^[[:space:]]+//' | awk '{print $1; exit}')"
    if [[ -z "$trimmed_listing" ]]; then
      echo "ERROR: perf probe listed the probe but event name parsing failed for ${PROBE_NAMES[$idx]}" >&2
      log_setup "ERROR: perf probe listed the probe but event name parsing failed for ${PROBE_NAMES[$idx]}"
      log_setup "PROBE_LIST[$idx]: $listing"
      return 1
    fi
    PROBE_EVENTS[$idx]="$trimmed_listing"
    PROBE_ADDED[$idx]=1
    log_setup "PROBE_LIST[$idx]: $listing"
    log_setup "CREATED_PROBE[$idx]: ${PROBE_EVENTS[$idx]}"
  done

  if [[ "$SETUP_ONLY" == "1" ]]; then
    log_setup "SETUP_ONLY: verified probe creation and listing"
  fi

  return 0
}

start_recording() {
  local perf_cmd
  perf_cmd=(sudo perf record -o "$PERF_DATA")
  for event_name in "${PROBE_EVENTS[@]}"; do
    perf_cmd+=(-e "$event_name")
  done
  perf_cmd+=(-p "$NWN_PID")
  "${perf_cmd[@]}" >"$PERF_RECORD_LOG" 2>&1 &
  PERF_RECORD_PID=$!
  log_setup "PERF_RECORD_CMD: sudo perf record -o '$PERF_DATA'$(printf " -e '%s'" "${PROBE_EVENTS[@]}") -p '$NWN_PID'"
  log_setup "PERF_RECORD_PID: $PERF_RECORD_PID"
}

wait_for_stop() {
  local rc=0
  while [[ "$STOP_REQUESTED" -eq 0 ]] && kill -0 "$PERF_RECORD_PID" 2>/dev/null; do
    sleep 1 || true
  done

  if [[ "$STOP_REQUESTED" -eq 0 ]]; then
    log_setup "PERF_RECORD_EARLY_EXIT: perf record ended before Ctrl+C"
  fi

  if [[ -n "$PERF_RECORD_PID" ]] && kill -0 "$PERF_RECORD_PID" 2>/dev/null; then
    kill -INT "$PERF_RECORD_PID" 2>/dev/null || true
  fi

  wait "$PERF_RECORD_PID" 2>/dev/null || rc=$?
  log_setup "PERF_RECORD_WAIT_RC: $rc"
}

postprocess() {
  if [[ -f "$PERF_DATA" ]]; then
    sudo perf script -i "$PERF_DATA" > "$TRACE_TXT"
  fi
  log_setup "PERF_RECORD_EXIT: $(test -f "$PERF_RECORD_LOG" && tail -n 1 "$PERF_RECORD_LOG" | tr -d '\r' || true)"

  if [[ -n "${SUDO_USER:-}" ]]; then
    sudo chown "$SUDO_USER:$SUDO_USER" "$PERF_DATA" "$TRACE_TXT" "$PERF_RECORD_LOG" "$SETUP_LOG" 2>/dev/null || true
  fi
}

main() {
  trap cleanup EXIT
  trap on_int INT TERM

  require_cmd sudo
  require_cmd perf

  if [[ ! -f "$NWN_BIN" ]]; then
    echo "ERROR: missing NWN binary: $NWN_BIN" >&2
    exit 1
  fi

  mkdir -p "$LOG_DIR"
  if ! create_probe; then
    echo "ERROR: unable to create perf probe for $TRACE_FAILURE_CONTEXT" >&2
    echo "See setup log: $SETUP_LOG" >&2
    exit 1
  fi

  if [[ "$SETUP_ONLY" == "1" ]]; then
    echo "Setup-only validation succeeded:"
    printf '  %s\n' "${PROBE_EVENTS[@]}"
    echo
    echo "Setup log:"
    echo "  $SETUP_LOG"
    return 0
  fi

  if [[ "$NO_LAUNCH" -eq 0 ]]; then
    log_setup "MODE: default launch"
    if ! launch_harness; then
      echo "ERROR: unable to launch harness" >&2
      exit 1
    fi
    if ! discover_nwn_pid; then
      echo "ERROR: unable to find nwmain-linux PID" >&2
      exit 1
    fi
  else
    log_setup "MODE: no-launch attach"
    if ! discover_nwn_pid; then
      echo "ERROR: unable to find nwmain-linux PID in no-launch mode" >&2
      exit 1
    fi
  fi

  echo "Perf uprobe installed:"
  printf '  %s\n' "${PROBE_EVENTS[@]}"
  echo
  echo "NWN PID:"
  echo "  $NWN_PID"
  echo "NWN exe:"
  echo "  $NWN_ACCEPTED_EXE"
  echo "$MANUAL_ACTIONS"
  echo
  echo "Setup log:"
  echo "  $SETUP_LOG"
  echo "Tracing output will be written to:"
  echo "  $TRACE_TXT"
  echo "Perf data will be written to:"
  echo "  $PERF_DATA"
  if [[ "$KILL_ON_EXIT" -eq 0 ]]; then
    echo "Game cleanup: leave running (default)"
  else
    echo "Game cleanup: kill on exit enabled"
  fi
  echo

  start_recording
  wait_for_stop
  postprocess

  echo
  echo "Done."
  echo "Trace text: $TRACE_TXT"
  echo "Perf data:  $PERF_DATA"
  echo "Perf log:   $PERF_RECORD_LOG"
  echo "Setup log:  $SETUP_LOG"
}

main "$@"
