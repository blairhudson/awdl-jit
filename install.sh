#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORWARD_FLAGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -y|--yes)
      FORWARD_FLAGS+=("$1")
      shift
      ;;
    *)
      break
      ;;
  esac
done

exec "$ROOT_DIR/bin/awdl-jit" "${FORWARD_FLAGS[@]}" install "$@"
