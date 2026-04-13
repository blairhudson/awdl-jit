#!/usr/bin/env bash

interactive_prompt_choice() {
  local prompt="$1"
  shift
  local options=("$@")
  local index=1
  local answer

  prompt_outln "$prompt"
  for answer in "${options[@]}"; do
    prompt_outln "  $index. $answer"
    index=$((index + 1))
  done

  while :; do
    prompt_out 'Select an option: '
    prompt_read answer || return 1
    case "$answer" in
      ''|*[!0-9]*)
        ;;
      *)
        if [ "$answer" -ge 1 ] && [ "$answer" -le "${#options[@]}" ]; then
          printf '%s\n' "$answer"
          return 0
        fi
        ;;
    esac
    prompt_outln "Enter a number between 1 and ${#options[@]}."
  done
}

target_installed_artifacts() {
  local target_id="$1"
  load_target "$target_id"
  [ -d "$(target_support_dir "$target_id")" ] || [ -f "$(target_launchagent_path "$target_id")" ] || [ -d "$(target_launcher_path)" ]
}

target_ready() {
  target_detected "$1"
}

interactive_choose_target() {
  local target_id
  local candidates=()
  local labels=()
  local choice

  for target_id in $(target_ids); do
    if target_ready "$target_id" || target_installed_artifacts "$target_id"; then
      candidates+=("$target_id")
      load_target "$target_id"
      labels+=("$TARGET_DISPLAY_NAME")
    fi
  done

  if [ "${#candidates[@]}" -eq 0 ]; then
    return 1
  fi
  if [ "${#candidates[@]}" -eq 1 ]; then
    printf '%s\n' "${candidates[0]}"
    return 0
  fi

  choice="$(interactive_prompt_choice 'Supported targets found:' "${labels[@]}")"
  printf '%s\n' "${candidates[$((choice - 1))]}"
}

interactive_target_menu() {
  local target_id="$1"
  local choices=()
  local actions=()
  local choice

  load_target "$target_id"

  prompt_outln ''
  prompt_outln "$TARGET_DISPLAY_NAME detected."
  if target_ready "$target_id"; then
    prompt_outln "$TARGET_AWDL_APP_NAME detected."
  else
    prompt_outln "$TARGET_AWDL_APP_NAME or $TARGET_DISPLAY_NAME is missing."
  fi
  prompt_outln "Existing AWDL-JIT integration: $(target_installed_artifacts "$target_id" && printf yes || printf no)"
  prompt_outln ''

  if target_ready "$target_id"; then
    choices+=("Create or repair $TARGET_LAUNCHER_NAME")
    actions+=("install")
  fi
  if target_installed_artifacts "$target_id"; then
    choices+=("Remove AWDL-JIT integration")
    actions+=("uninstall")
  fi
  choices+=("Quit")
  actions+=("quit")

  choice="$(interactive_prompt_choice 'Choose an action:' "${choices[@]}")"
  printf '%s\n' "${actions[$((choice - 1))]}"
}

cmd_interactive() {
  local target_id action

  if [ "$#" -gt 0 ]; then
    err "Interactive mode does not accept additional arguments."
    return 1
  fi

  target_id="$(interactive_choose_target || true)"
  if [ -z "$target_id" ]; then
    prompt_outln 'No supported app pairing is ready or installed on this Mac.'
    prompt_outln ''
    cmd_detect
    return 1
  fi

  action="$(interactive_target_menu "$target_id")"
  case "$action" in
    install)
      cmd_install "$target_id"
      ;;
    uninstall)
      cmd_uninstall "$target_id"
      ;;
    quit)
      printf 'No changes made.\n'
      ;;
    *)
      err "Unexpected action: $action"
      return 1
      ;;
  esac
}
