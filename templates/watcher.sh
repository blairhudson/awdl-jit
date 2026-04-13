#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=runtime.sh
source "$SCRIPT_DIR/runtime.sh"

main() {
  ensure_runtime_dirs
  printf '%s\n' "$$" > "$WATCHER_PID_FILE"
  trap 'rm -f "$WATCHER_PID_FILE"' EXIT INT TERM

  while :; do
    if target_running; then
      if ! awdl_running; then
        start_awdl_if_needed watcher || runtime_log "watcher could not start AWDLControl"
      fi
    else
      quit_awdl_if_owned_by watcher
    fi
    sleep 2
  done
}

main "$@"
