#!/usr/bin/env bash
set -euo pipefail

REPO_OWNER="${AWDL_JIT_REPO_OWNER:-blairhudson}"
REPO_NAME="${AWDL_JIT_REPO_NAME:-awdl-jit}"
ASSET_NAME="${AWDL_JIT_ASSET_NAME:-AWDL-JIT-macos.zip}"

usage() {
  cat <<'EOF'
Usage: run-latest.sh [--version <tag>] [awdl-jit args...]

Examples:
  run-latest.sh
  run-latest.sh install geforcenow
  run-latest.sh uninstall geforcenow
  run-latest.sh --yes install geforcenow
  run-latest.sh --version v0.1.0
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'error: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

if [ "$(uname -s)" != "Darwin" ]; then
  printf 'error: AWDL-JIT only supports macOS.\n' >&2
  exit 1
fi

require_command curl
require_command unzip

VERSION=""
FORWARD_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || {
        printf 'error: --version requires a tag value\n' >&2
        exit 1
      }
      VERSION="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      FORWARD_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ -n "${AWDL_JIT_RELEASE_URL:-}" ]; then
  RELEASE_URL="$AWDL_JIT_RELEASE_URL"
elif [ -n "$VERSION" ]; then
  RELEASE_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$VERSION/$ASSET_NAME"
else
  RELEASE_URL="https://github.com/$REPO_OWNER/$REPO_NAME/releases/latest/download/$ASSET_NAME"
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/awdl-jit.XXXXXX")"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

printf 'Downloading AWDL-JIT release...\n'
curl -fsSL "$RELEASE_URL" -o "$TMP_DIR/$ASSET_NAME"
unzip -q "$TMP_DIR/$ASSET_NAME" -d "$TMP_DIR"

RUNNER="$TMP_DIR/AWDL-JIT/bin/awdl-jit"
[ -x "$RUNNER" ] || {
  printf 'error: release bundle did not contain %s\n' "$RUNNER" >&2
  exit 1
}

if [ "${#FORWARD_ARGS[@]}" -gt 0 ]; then
  exec "$RUNNER" "${FORWARD_ARGS[@]}"
else
  exec "$RUNNER"
fi
