#!/usr/bin/env bash

cmd_uninstall() {
  local target_id="${1:-}"
  local tool_path launcher_path support_dir launchagent_path label

  if [ -z "$target_id" ]; then
    target_id="$(choose_installed_target)"
  fi

  load_target "$target_id"
  launcher_path="$(target_launcher_path)"
  support_dir="$(target_support_dir "$target_id")"
  launchagent_path="$(target_launchagent_path "$target_id")"
  label="$(target_launchagent_label "$target_id")"

  prompt_confirm "Remove AWDL-JIT artifacts for $TARGET_DISPLAY_NAME?" || return 1

  if [ "${AWDL_JIT_SKIP_HANDLER_REGISTRATION:-0}" != "1" ]; then
    tool_path="$(ensure_launchservices_tool)"
    restore_previous_handlers "$tool_path" || true
  fi

  if [ "${AWDL_JIT_SKIP_LAUNCHAGENT_LOAD:-0}" != "1" ]; then
    launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
  fi
  rm -f "$launchagent_path"
  rm -rf "$launcher_path" "$support_dir"

  log "Removed AWDL-JIT artifacts for $TARGET_DISPLAY_NAME"
}
