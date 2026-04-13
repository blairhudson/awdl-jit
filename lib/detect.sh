#!/usr/bin/env bash

detect_target() {
  local target_id="$1"
  load_target "$target_id"

  local target_path=""
  local awdl_path=""

  target_path="$(find_app_by_bundle_id "$TARGET_BUNDLE_ID" "${TARGET_APP_CANDIDATES[@]}" || true)"
  awdl_path="$(find_app_by_bundle_id "$TARGET_AWDL_BUNDLE_ID" "${TARGET_AWDL_CANDIDATES[@]}" || true)"

  printf 'target=%s\n' "$TARGET_ID"
  printf 'display_name=%s\n' "$TARGET_DISPLAY_NAME"
  printf 'target_found=%s\n' "$( [ -n "$target_path" ] && printf yes || printf no )"
  printf 'target_path=%s\n' "$target_path"
  printf 'awdl_found=%s\n' "$( [ -n "$awdl_path" ] && printf yes || printf no )"
  printf 'awdl_path=%s\n' "$awdl_path"
}

print_detect_summary() {
  local target_id="$1"
  local target_path=""
  local awdl_path=""

  load_target "$target_id"
  target_path="$(find_app_by_bundle_id "$TARGET_BUNDLE_ID" "${TARGET_APP_CANDIDATES[@]}" || true)"
  awdl_path="$(find_app_by_bundle_id "$TARGET_AWDL_BUNDLE_ID" "${TARGET_AWDL_CANDIDATES[@]}" || true)"

  printf '%s (%s)\n' "$TARGET_DISPLAY_NAME" "$TARGET_ID"
  printf '  app:  %s\n' "${target_path:-missing}"
  printf '  awdl: %s\n' "${awdl_path:-missing}"
  if [ -n "$target_path" ] && [ -n "$awdl_path" ]; then
    printf '  ready: yes\n'
  else
    printf '  ready: no\n'
  fi
}

cmd_detect() {
  local target_id
  for target_id in $(target_ids); do
    print_detect_summary "$target_id"
  done
}

cmd_doctor() {
  printf 'Tools\n'
  printf '  osacompile: %s\n' "$(command_exists osacompile && printf yes || printf no)"
  printf '  plutil: %s\n' "$(command_exists plutil && printf yes || printf no)"
  printf '  launchctl: %s\n' "$(command_exists launchctl && printf yes || printf no)"
  printf '  swift: %s\n' "$(command_exists swift && printf yes || printf no)"
  printf '\n'
  cmd_detect
}

print_target_status() {
  local target_id="$1"
  load_target "$target_id"

  local support_dir launchagent_path launcher_path label
  support_dir="$(target_support_dir "$target_id")"
  launchagent_path="$(target_launchagent_path "$target_id")"
  launcher_path="$(target_launcher_path)"
  label="$(target_launchagent_label "$target_id")"

  printf '%s (%s)\n' "$TARGET_DISPLAY_NAME" "$target_id"
  printf '  launcher: %s\n' "$( [ -d "$launcher_path" ] && printf '%s' "$launcher_path" || printf missing )"
  printf '  support:  %s\n' "$( [ -d "$support_dir" ] && printf '%s' "$support_dir" || printf missing )"
  printf '  watcher:  %s\n' "$( [ -f "$launchagent_path" ] && printf '%s' "$launchagent_path" || printf missing )"
  if launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1; then
    printf '  watcher_loaded: yes\n'
  else
    printf '  watcher_loaded: no\n'
  fi
}

cmd_status() {
  local target_id="${1:-}"
  if [ -n "$target_id" ]; then
    print_target_status "$target_id"
    return 0
  fi

  for target_id in $(target_ids); do
    print_target_status "$target_id"
  done
}
