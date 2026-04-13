#!/usr/bin/env bash

TARGET_ID="geforcenow"
TARGET_DISPLAY_NAME="NVIDIA GeForce NOW"
TARGET_SHORT_NAME="GFN"
TARGET_BUNDLE_ID="com.nvidia.gfnpc.mall"
TARGET_PROCESS_NAME="GeForceNOW"
TARGET_LAUNCHER_NAME="NVIDIA GeForce NOW (AWDL)"
TARGET_LAUNCHER_BUNDLE_ID="io.github.blairhudson.awdl-jit.launcher.geforcenow"
TARGET_LEGACY_LAUNCHER_NAMES=(
  "AWDL-JIT for GFN"
)
TARGET_AWDL_BUNDLE_ID="com.jh.AWDLControl"
TARGET_AWDL_PROCESS_NAME="AWDLControl"
TARGET_AWDL_APP_NAME="AWDL Control"
TARGET_DOCUMENT_UTI="io.github.blairhudson.awdl-jit.document.gfnpc"
TARGET_DOCUMENT_DESCRIPTION="NVIDIA GeForce NOW Launch File"
TARGET_APP_CANDIDATES=(
  "/Applications/GeForceNOW.app"
  "$HOME/Applications/GeForceNOW.app"
)
TARGET_AWDL_CANDIDATES=(
  "/Applications/AWDLControl.app"
  "$HOME/Applications/AWDLControl.app"
)
TARGET_URL_SCHEMES=(
  "geforcenow"
)
TARGET_FILE_EXTENSIONS=(
  "gfnpc"
)
