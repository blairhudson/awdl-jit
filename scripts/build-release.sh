#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
STAGE_DIR="$DIST_DIR/AWDL-JIT"
ARCHIVE_PATH="$DIST_DIR/AWDL-JIT-macos.zip"

mkdir -p "$DIST_DIR"
rm -rf "$STAGE_DIR" "$ARCHIVE_PATH"

swift build -c release --package-path "$ROOT_DIR"
cp "$ROOT_DIR/.build/release/awdl-jit-ls" "$ROOT_DIR/tools/awdl-jit-ls"
chmod 755 "$ROOT_DIR/bin/awdl-jit" "$ROOT_DIR/install.sh" "$ROOT_DIR/scripts/build-release.sh" "$ROOT_DIR/tools/awdl-jit-ls"

mkdir -p "$STAGE_DIR"
cp -R \
  "$ROOT_DIR/bin" \
  "$ROOT_DIR/lib" \
  "$ROOT_DIR/templates" \
  "$ROOT_DIR/tools" \
  "$ROOT_DIR/docs" \
  "$ROOT_DIR/LICENSE" \
  "$ROOT_DIR/README.md" \
  "$ROOT_DIR/install.sh" \
  "$STAGE_DIR/"

(cd "$DIST_DIR" && /usr/bin/zip -qry "$(basename "$ARCHIVE_PATH")" "$(basename "$STAGE_DIR")")

printf 'Created %s\n' "$ARCHIVE_PATH"
