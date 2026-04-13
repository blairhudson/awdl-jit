#!/usr/bin/env bash

if [ -z "${AWDL_JIT_ROOT:-}" ]; then
  AWDL_JIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

APP_SUPPORT_BASE="${AWDL_JIT_APP_SUPPORT_BASE:-$HOME/Library/Application Support/AWDL-JIT}"
LAUNCH_AGENT_DIR="${AWDL_JIT_LAUNCH_AGENT_DIR:-$HOME/Library/LaunchAgents}"
APPLICATIONS_DIR="${AWDL_JIT_APPLICATIONS_DIR:-$HOME/Applications}"

log() {
  printf '%s\n' "$*"
}

prompt_out() {
  if [ -w /dev/tty ]; then
    printf '%s' "$*" > /dev/tty
  else
    printf '%s' "$*" >&2
  fi
}

prompt_outln() {
  prompt_out "$*"
  prompt_out "\n"
}

prompt_read() {
  local __var_name="$1"
  local __value

  if [ -r /dev/tty ]; then
    IFS= read -r __value < /dev/tty || return 1
  else
    IFS= read -r __value || return 1
  fi

  printf -v "$__var_name" '%s' "$__value"
}

info() {
  printf 'info: %s\n' "$*"
}

warn() {
  printf 'warn: %s\n' "$*" >&2
}

err() {
  printf 'error: %s\n' "$*" >&2
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

prompt_confirm() {
  local prompt="${1:-Continue?}"
  local answer

  if [ "${AWDL_JIT_ASSUME_YES:-0}" = "1" ]; then
    return 0
  fi

  prompt_out "$prompt [Y/n] "
  prompt_read answer || return 1
  case "$answer" in
    n|N|no|NO)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

target_ids() {
  local file
  for file in "$AWDL_JIT_ROOT"/lib/targets/*.sh; do
    [ -e "$file" ] || continue
    basename "$file" .sh
  done
}

clear_target_context() {
  unset TARGET_ID TARGET_DISPLAY_NAME TARGET_SHORT_NAME TARGET_BUNDLE_ID
  unset TARGET_PROCESS_NAME TARGET_LAUNCHER_NAME TARGET_LAUNCHER_BUNDLE_ID
  unset TARGET_AWDL_BUNDLE_ID TARGET_AWDL_PROCESS_NAME TARGET_AWDL_APP_NAME
  unset TARGET_DOCUMENT_UTI TARGET_DOCUMENT_DESCRIPTION
  unset TARGET_APP_CANDIDATES TARGET_AWDL_CANDIDATES TARGET_URL_SCHEMES TARGET_FILE_EXTENSIONS
}

load_target() {
  local target_id="$1"
  local target_file="$AWDL_JIT_ROOT/lib/targets/$target_id.sh"
  clear_target_context

  if [ ! -f "$target_file" ]; then
    err "Unknown target: $target_id"
    return 1
  fi

  # shellcheck disable=SC1090
  source "$target_file"
}

plist_get() {
  local plist_path="$1"
  local key_path="$2"
  /usr/libexec/PlistBuddy -c "Print $key_path" "$plist_path" 2>/dev/null
}

find_app_by_bundle_id() {
  local bundle_id="$1"
  shift || true
  local candidate
  local found
  local candidate_bundle

  for candidate in "$@"; do
    [ -d "$candidate" ] || continue
    candidate_bundle="$(plist_get "$candidate/Contents/Info.plist" ':CFBundleIdentifier' || true)"
    if [ "$candidate_bundle" = "$bundle_id" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if command_exists mdfind; then
    while IFS= read -r found; do
      [ -d "$found" ] || continue
      candidate_bundle="$(plist_get "$found/Contents/Info.plist" ':CFBundleIdentifier' || true)"
      if [ "$candidate_bundle" = "$bundle_id" ]; then
        printf '%s\n' "$found"
        return 0
      fi
    done <<EOF
$(mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null)
EOF
  fi

  return 1
}

process_running() {
  local process_name="$1"
  pgrep -x "$process_name" >/dev/null 2>&1
}

target_support_dir() {
  printf '%s/%s\n' "$APP_SUPPORT_BASE" "$1"
}

target_state_dir() {
  printf '%s/state\n' "$(target_support_dir "$1")"
}

target_launcher_path() {
  printf '%s/%s.app\n' "$APPLICATIONS_DIR" "$TARGET_LAUNCHER_NAME"
}

target_launchagent_label() {
  printf 'io.github.blairhudson.awdl-jit.watch.%s\n' "$1"
}

target_launchagent_path() {
  printf '%s/%s.plist\n' "$LAUNCH_AGENT_DIR" "$(target_launchagent_label "$1")"
}

target_handler_state_path() {
  printf '%s/handlers.env\n' "$(target_support_dir "$1")"
}

target_detected() {
  load_target "$1"
  TARGET_APP_PATH="$(find_app_by_bundle_id "$TARGET_BUNDLE_ID" "${TARGET_APP_CANDIDATES[@]}")" || return 1
  TARGET_AWDL_APP_PATH="$(find_app_by_bundle_id "$TARGET_AWDL_BUNDLE_ID" "${TARGET_AWDL_CANDIDATES[@]}")" || return 1
  return 0
}

choose_default_target() {
  local detected=""
  local target_id

  for target_id in $(target_ids); do
    if target_detected "$target_id"; then
      if [ -n "$detected" ]; then
        err "Multiple supported targets detected. Pass a target explicitly."
        return 1
      fi
      detected="$target_id"
    fi
  done

  if [ -z "$detected" ]; then
    err "No supported targets detected on this Mac."
    return 1
  fi

  printf '%s\n' "$detected"
}

choose_installed_target() {
  local installed=""
  local target_id

  for target_id in $(target_ids); do
    if [ -d "$(target_support_dir "$target_id")" ] || [ -f "$(target_launchagent_path "$target_id")" ]; then
      if [ -n "$installed" ]; then
        err "Multiple AWDL-JIT targets are installed. Pass a target explicitly."
        return 1
      fi
      installed="$target_id"
    fi
  done

  if [ -n "$installed" ]; then
    printf '%s\n' "$installed"
    return 0
  fi

  choose_default_target
}

launchservices_tool_path() {
  if [ -x "$AWDL_JIT_ROOT/tools/awdl-jit-ls" ]; then
    printf '%s/tools/awdl-jit-ls\n' "$AWDL_JIT_ROOT"
  else
    printf '%s/.build/release/awdl-jit-ls\n' "$AWDL_JIT_ROOT"
  fi
}

ensure_launchservices_tool() {
  local tool_path
  tool_path="$(launchservices_tool_path)"

  if [ -x "$tool_path" ]; then
    printf '%s\n' "$tool_path"
    return 0
  fi

  if ! command_exists swift; then
    err "Swift is required to build the LaunchServices helper."
    return 1
  fi

  info "Building LaunchServices helper"
  swift build -c release --product awdl-jit-ls --package-path "$AWDL_JIT_ROOT" >/dev/null
  printf '%s\n' "$tool_path"
}

write_kv_env() {
  local output_path="$1"
  shift
  : > "$output_path"

  while [ "$#" -gt 0 ]; do
    local key="$1"
    local value="$2"
    shift 2
    printf '%s=%q\n' "$key" "$value" >> "$output_path"
  done
}

render_template() {
  local template_path="$1"
  local destination_path="$2"
  shift 2
  local data
  local key
  local value

  data="$(<"$template_path")"
  while [ "$#" -gt 0 ]; do
    key="$1"
    value="$2"
    shift 2
    data="${data//__${key}__/$value}"
  done
  printf '%s' "$data" > "$destination_path"
}

launcher_registered() {
  local app_path="$1"
  local lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

  if [ -x "$lsregister" ]; then
    "$lsregister" -f "$app_path" >/dev/null 2>&1 || true
  fi
}
