# Architecture

## Overview

AWDL-JIT is split into two layers:

1. A repo-local installer CLI.
2. Per-user generated artifacts.

The CLI detects installed apps, generates launchers and runtime scripts, registers handlers, and manages uninstall.

## Repo-local components

- `bin/awdl-jit`: command entrypoint
- `lib/targets/*.sh`: supported target definitions
- `templates/*`: generated runtime artifacts
- `Sources/LaunchServicesTool`: tiny helper for LaunchServices default handlers

## Generated components

Each target gets:

- a launcher app compiled with `osacompile`
- `monitor.sh` for wrapper launches, URL opens, and file opens
- `watcher.sh` as a `launchd` fallback for direct launches of the original app
- a target-specific LaunchAgent plist

## Ownership model

Generated runtime scripts coordinate with a simple owner file.

- `launcher` owner: the monitor started `AWDLControl`
- `watcher` owner: the watcher started `AWDLControl`
- empty owner: AWDL-JIT leaves `AWDLControl` alone

That prevents the watcher and launcher from stopping `AWDLControl` when the other component started it.

## Handler model

For supported targets, AWDL-JIT registers the generated launcher as:

- the default URL scheme handler
- the default document handler for the generated document UTI

The previous handlers are saved in a target-local state file and restored on uninstall when possible.
