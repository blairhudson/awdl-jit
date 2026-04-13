#!/usr/bin/env bash

plist_upsert() {
  local plist_path="$1"
  local key_path="$2"
  local value_type="$3"
  local value="$4"

  if /usr/libexec/PlistBuddy -c "Print $key_path" "$plist_path" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set $key_path $value" "$plist_path" >/dev/null
  else
    /usr/libexec/PlistBuddy -c "Add $key_path $value_type $value" "$plist_path" >/dev/null
  fi
}

configure_launcher_plist() {
  local plist_path="$1"
  local scheme="$2"
  local extension="$3"

  plist_upsert "$plist_path" ':CFBundleIdentifier' string "$TARGET_LAUNCHER_BUNDLE_ID"
  plist_upsert "$plist_path" ':CFBundleName' string "$TARGET_LAUNCHER_NAME"
  plist_upsert "$plist_path" ':CFBundleDisplayName' string "$TARGET_LAUNCHER_NAME"
  plist_upsert "$plist_path" ':LSApplicationCategoryType' string public.app-category.utilities

  /usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "$plist_path" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string $TARGET_LAUNCHER_BUNDLE_ID.url" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $scheme" "$plist_path"

  /usr/libexec/PlistBuddy -c "Delete :UTExportedTypeDeclarations" "$plist_path" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations array" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0 dict" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeIdentifier string $TARGET_DOCUMENT_UTI" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeDescription string $TARGET_DOCUMENT_DESCRIPTION" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeConformsTo array" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeConformsTo:0 string public.data" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification dict" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension array" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.filename-extension:0 string $extension" "$plist_path"

  /usr/libexec/PlistBuddy -c "Delete :CFBundleDocumentTypes" "$plist_path" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes array" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0 dict" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string $TARGET_DOCUMENT_DESCRIPTION" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSHandlerRank string Owner" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$plist_path"
  /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string $TARGET_DOCUMENT_UTI" "$plist_path"
}

copy_target_icon_into_launcher() {
  local target_app_path="$1"
  local launcher_path="$2"
  local target_plist_path target_resources_path launcher_resources_path icon_name source_icon_path dest_icon_path

  target_plist_path="$target_app_path/Contents/Info.plist"
  target_resources_path="$target_app_path/Contents/Resources"
  launcher_resources_path="$launcher_path/Contents/Resources"

  icon_name="$(plist_get "$target_plist_path" ':CFBundleIconFile' || true)"
  if [ -z "$icon_name" ]; then
    return 0
  fi
  case "$icon_name" in
    *.icns) ;;
    *) icon_name="$icon_name.icns" ;;
  esac

  source_icon_path="$target_resources_path/$icon_name"
  if [ ! -f "$source_icon_path" ]; then
    return 0
  fi

  dest_icon_path="$launcher_resources_path/$icon_name"
  cp "$source_icon_path" "$dest_icon_path"
  plist_upsert "$launcher_path/Contents/Info.plist" ':CFBundleIconFile' string "$icon_name"
  /usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' "$launcher_path/Contents/Info.plist" >/dev/null 2>&1 || true
}

save_previous_handlers() {
  local tool_path="$1"
  local support_dir="$2"
  local scheme="$3"

  local existing_scheme existing_content state_path
  state_path="$(target_handler_state_path "$TARGET_ID")"
  if [ -f "$state_path" ]; then
    return 0
  fi

  existing_scheme="$($tool_path get-scheme "$scheme" || true)"
  existing_content="$($tool_path get-content "$TARGET_DOCUMENT_UTI" || true)"
  mkdir -p "$support_dir"
  write_kv_env "$state_path" \
    PREVIOUS_SCHEME_HANDLER "$existing_scheme" \
    PREVIOUS_CONTENT_HANDLER "$existing_content"
}

restore_previous_handlers() {
  local tool_path="$1"
  local state_path
  state_path="$(target_handler_state_path "$TARGET_ID")"

  [ -f "$state_path" ] || return 0
  # shellcheck disable=SC1090
  source "$state_path"

  if [ -n "${PREVIOUS_SCHEME_HANDLER:-}" ]; then
    "$tool_path" set-scheme "${TARGET_URL_SCHEMES[0]}" "$PREVIOUS_SCHEME_HANDLER" >/dev/null
  fi
  if [ -n "${PREVIOUS_CONTENT_HANDLER:-}" ]; then
    "$tool_path" set-content "$TARGET_DOCUMENT_UTI" "$PREVIOUS_CONTENT_HANDLER" >/dev/null
  fi
}

launchagent_service_loaded() {
  local label="$1"
  launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1
}

wait_for_launchagent_unload() {
  local label="$1"
  local attempt=0

  while [ "$attempt" -lt 20 ]; do
    if ! launchagent_service_loaded "$label"; then
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 0.5
  done

  return 1
}

bootstrap_launchagent() {
  local label="$1"
  local launchagent_path="$2"
  local attempt=0
  local output

  launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
  wait_for_launchagent_unload "$label" || true

  while [ "$attempt" -lt 5 ]; do
    if output="$(launchctl bootstrap "gui/$(id -u)" "$launchagent_path" 2>&1)"; then
      return 0
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -lt 5 ]; then
      sleep 1
    fi
  done

  printf '%s\n' "$output" >&2
  return 1
}

remove_legacy_launchers() {
  local current_launcher_path="$1"
  local legacy_path

  while IFS= read -r legacy_path; do
    [ -n "$legacy_path" ] || continue
    if [ "$legacy_path" != "$current_launcher_path" ]; then
      rm -rf "$legacy_path"
    fi
  done <<EOF
$(target_legacy_launcher_paths)
EOF
}

install_target() {
  local target_id="$1"
  local repair_mode="${2:-0}"

  load_target "$target_id"

  local target_app_path awdl_app_path support_dir state_dir launcher_path launchagent_path
  local tool_path launcher_source monitor_path watcher_path runtime_path config_path launchagent_source label
  local scheme extension plist_path

  target_app_path="$(find_app_by_bundle_id "$TARGET_BUNDLE_ID" "${TARGET_APP_CANDIDATES[@]}")" || {
    err "$TARGET_DISPLAY_NAME is not installed"
    return 1
  }
  awdl_app_path="$(find_app_by_bundle_id "$TARGET_AWDL_BUNDLE_ID" "${TARGET_AWDL_CANDIDATES[@]}")" || {
    err "$TARGET_AWDL_APP_NAME is not installed"
    return 1
  }

  if [ "$repair_mode" = "0" ]; then
    prompt_confirm "Create $TARGET_LAUNCHER_NAME.app and install the watcher for $TARGET_DISPLAY_NAME?" || return 1
  fi

  mkdir -p "$APPLICATIONS_DIR" "$APP_SUPPORT_BASE" "$LAUNCH_AGENT_DIR"

  support_dir="$(target_support_dir "$target_id")"
  state_dir="$(target_state_dir "$target_id")"
  launcher_path="$(target_launcher_path)"
  launchagent_path="$(target_launchagent_path "$target_id")"
  label="$(target_launchagent_label "$target_id")"
  mkdir -p "$support_dir" "$state_dir/events"

  scheme="${TARGET_URL_SCHEMES[0]}"
  extension="${TARGET_FILE_EXTENSIONS[0]}"

  if [ "${AWDL_JIT_SKIP_HANDLER_REGISTRATION:-0}" != "1" ]; then
    tool_path="$(ensure_launchservices_tool)"
  fi

  config_path="$support_dir/config.sh"
  runtime_path="$support_dir/runtime.sh"
  monitor_path="$support_dir/monitor.sh"
  watcher_path="$support_dir/watcher.sh"
  launcher_source="$support_dir/launcher.applescript"
  launchagent_source="$support_dir/$(basename "$launchagent_path")"

  write_kv_env "$config_path" \
    TARGET_ID "$TARGET_ID" \
    TARGET_DISPLAY_NAME "$TARGET_DISPLAY_NAME" \
    TARGET_PROCESS_NAME "$TARGET_PROCESS_NAME" \
    TARGET_APP_PATH "$target_app_path" \
    AWDL_PROCESS_NAME "$TARGET_AWDL_PROCESS_NAME" \
    AWDL_APP_PATH "$awdl_app_path" \
    STATE_DIR "$state_dir" \
    OWNER_FILE "$state_dir/owner" \
    EVENTS_DIR "$state_dir/events" \
    MONITOR_PID_FILE "$state_dir/monitor.pid" \
    MONITOR_LOCK_DIR "$state_dir/monitor.lock" \
    WATCHER_PID_FILE "$state_dir/watcher.pid" \
    WATCHER_LOG_FILE "$state_dir/watcher.log"

  render_template "$AWDL_JIT_ROOT/templates/runtime.sh" "$runtime_path"
  render_template "$AWDL_JIT_ROOT/templates/monitor.sh" "$monitor_path"
  render_template "$AWDL_JIT_ROOT/templates/watcher.sh" "$watcher_path"
  render_template "$AWDL_JIT_ROOT/templates/launcher.applescript" "$launcher_source" \
    MONITOR_PATH "$monitor_path"
  render_template "$AWDL_JIT_ROOT/templates/launchagent.plist" "$launchagent_source" \
    LABEL "$(target_launchagent_label "$target_id")" \
    WATCHER_PATH "$watcher_path"

  chmod 755 "$runtime_path" "$monitor_path" "$watcher_path"

  rm -rf "$launcher_path"
  osacompile -o "$launcher_path" "$launcher_source" >/dev/null
  plist_path="$launcher_path/Contents/Info.plist"
  configure_launcher_plist "$plist_path" "$scheme" "$extension"
  copy_target_icon_into_launcher "$target_app_path" "$launcher_path"
  remove_legacy_launchers "$launcher_path"
  launcher_registered "$launcher_path"

  if [ "${AWDL_JIT_SKIP_HANDLER_REGISTRATION:-0}" != "1" ]; then
    save_previous_handlers "$tool_path" "$support_dir" "$scheme"
    "$tool_path" set-scheme "$scheme" "$TARGET_LAUNCHER_BUNDLE_ID" >/dev/null
    "$tool_path" set-content "$TARGET_DOCUMENT_UTI" "$TARGET_LAUNCHER_BUNDLE_ID" >/dev/null
  else
    info "Skipping handler registration"
  fi

  cp "$launchagent_source" "$launchagent_path"
  if [ "${AWDL_JIT_SKIP_LAUNCHAGENT_LOAD:-0}" != "1" ]; then
    bootstrap_launchagent "$label" "$launchagent_path"
  else
    info "Skipping LaunchAgent bootstrap"
  fi

  log "Installed $TARGET_LAUNCHER_NAME"
  log "Launcher: $launcher_path"
  log "Watcher:  $launchagent_path"
  log "Support:  $support_dir"
}

cmd_install() {
  local target_id="${1:-}"
  if [ -z "$target_id" ]; then
    target_id="$(choose_default_target)"
  fi
  install_target "$target_id" 0
}

cmd_repair() {
  local target_id="${1:-}"
  if [ -z "$target_id" ]; then
    target_id="$(choose_default_target)"
  fi
  install_target "$target_id" 1
}
