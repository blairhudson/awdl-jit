#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"

ensure_runtime_dirs() {
  mkdir -p "$STATE_DIR" "$EVENTS_DIR"
}

runtime_log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

target_running() {
  pgrep -x "$TARGET_PROCESS_NAME" >/dev/null 2>&1
}

awdl_running() {
  pgrep -x "$AWDL_PROCESS_NAME" >/dev/null 2>&1
}

read_owner() {
  [ -f "$OWNER_FILE" ] || return 0
  tr -d '\n' < "$OWNER_FILE"
}

set_owner() {
  printf '%s' "$1" > "$OWNER_FILE"
}

clear_owner() {
  rm -f "$OWNER_FILE"
}

wait_for_process() {
  local process_name="$1"
  local retries="${2:-20}"
  local i=0
  while [ "$i" -lt "$retries" ]; do
    if pgrep -x "$process_name" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 1
  done
  return 1
}

start_awdl_if_needed() {
  local owner
  if awdl_running; then
    return 0
  fi

  owner="$(read_owner || true)"
  if [ -z "$owner" ]; then
    set_owner "$1"
  fi

  open -a "$AWDL_APP_PATH"
  wait_for_process "$AWDL_PROCESS_NAME" 15
}

start_target_if_needed() {
  if ! target_running; then
    open -a "$TARGET_APP_PATH"
  fi
}

quit_awdl_if_owned_by() {
  local expected_owner="$1"
  local actual_owner
  actual_owner="$(read_owner || true)"

  if [ "$actual_owner" != "$expected_owner" ]; then
    return 0
  fi
  if ! awdl_running; then
    clear_owner
    return 0
  fi

  osascript -e "tell application id \"com.jh.AWDLControl\" to quit" >/dev/null 2>&1 || true
  sleep 2
  if awdl_running; then
    pkill -TERM -x "$AWDL_PROCESS_NAME" >/dev/null 2>&1 || true
  fi
  sleep 1
  if ! awdl_running; then
    clear_owner
  fi
}

queue_event() {
  local kind="$1"
  shift || true
  local event_path
  ensure_runtime_dirs
  event_path="$EVENTS_DIR/event.$$.${RANDOM:-0}.$(date +%s)"
  {
    printf '%s\n' "$kind"
    while [ "$#" -gt 0 ]; do
      printf '%s\n' "$1"
      shift
    done
  } > "$event_path"
}

has_events() {
  [ -n "$(find "$EVENTS_DIR" -maxdepth 1 -type f 2>/dev/null)" ]
}

dispatch_event_file() {
  local event_path="$1"
  local kind
  local payload
  kind="$(sed -n '1p' "$event_path")"
  payload="$(sed -n '2p' "$event_path")"

  case "$kind" in
    run)
      start_target_if_needed
      ;;
    url)
      open -a "$TARGET_APP_PATH" "$payload"
      ;;
    file)
      open -a "$TARGET_APP_PATH" "$payload"
      ;;
    *)
      runtime_log "unknown event kind: $kind"
      ;;
  esac

  rm -f "$event_path"
}

drain_events() {
  local event_path
  for event_path in "$EVENTS_DIR"/*; do
    [ -e "$event_path" ] || continue
    dispatch_event_file "$event_path"
  done
}

ensure_monitor_worker() {
  if [ -f "$MONITOR_PID_FILE" ] && kill -0 "$(cat "$MONITOR_PID_FILE")" >/dev/null 2>&1; then
    return 0
  fi
  nohup "$SCRIPT_DIR/monitor.sh" worker >/dev/null 2>&1 &
}

acquire_monitor_lock() {
  local pid
  if mkdir "$MONITOR_LOCK_DIR" >/dev/null 2>&1; then
    printf '%s\n' "$$" > "$MONITOR_PID_FILE"
    printf '%s\n' "$$" > "$MONITOR_LOCK_DIR/pid"
    trap 'rm -f "$MONITOR_PID_FILE"; rm -rf "$MONITOR_LOCK_DIR"' EXIT INT TERM
    return 0
  fi

  if [ -f "$MONITOR_LOCK_DIR/pid" ]; then
    pid="$(cat "$MONITOR_LOCK_DIR/pid")"
    if ! kill -0 "$pid" >/dev/null 2>&1; then
      rm -rf "$MONITOR_LOCK_DIR"
      mkdir "$MONITOR_LOCK_DIR"
      printf '%s\n' "$$" > "$MONITOR_PID_FILE"
      printf '%s\n' "$$" > "$MONITOR_LOCK_DIR/pid"
      trap 'rm -f "$MONITOR_PID_FILE"; rm -rf "$MONITOR_LOCK_DIR"' EXIT INT TERM
      return 0
    fi
  fi

  return 1
}
