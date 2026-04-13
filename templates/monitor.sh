#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=runtime.sh
source "$SCRIPT_DIR/runtime.sh"

run_worker() {
  local saw_target=0
  local stop_deadline=""

  ensure_runtime_dirs
  acquire_monitor_lock || exit 0

  while :; do
    if has_events; then
      start_awdl_if_needed launcher || runtime_log "failed to start AWDLControl"
      drain_events
      saw_target=1
      stop_deadline=""
    fi

    if target_running; then
      saw_target=1
      stop_deadline=""
    else
      if [ "$saw_target" = "1" ] && [ -z "$stop_deadline" ]; then
        stop_deadline=$(( $(date +%s) + 4 ))
      fi
      if [ -n "$stop_deadline" ] && [ "$(date +%s)" -ge "$stop_deadline" ]; then
        break
      fi
      if [ "$saw_target" = "0" ] && ! has_events; then
        break
      fi
    fi

    sleep 1
  done

  quit_awdl_if_owned_by launcher
}

main() {
  local mode="${1:-event}"
  shift || true

  case "$mode" in
    worker)
      run_worker
      ;;
    event)
      queue_event "$@"
      ensure_monitor_worker
      ;;
    *)
      runtime_log "unsupported mode: $mode"
      exit 1
      ;;
  esac
}

main "$@"
