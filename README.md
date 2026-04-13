# AWDL-JIT

`AWDL-JIT` is a macOS utility project that generates lightweight launchers and background watchers to make `AWDLControl.app` start and stop alongside supported apps.

<p align="center">
  Sponsored by <a href="https://skillcraft.gg">Skillcraft</a>.
</p>

<p align="center">
  <a href="https://skillcraft.gg/docs/"><img src="https://skillcraft.gg/badges/enabled.svg" alt="Skillcraft Enabled" /></a>
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT License" />
  <img src="https://img.shields.io/badge/platform-macOS-black" alt="macOS" />
</p>

## Current target

- `geforcenow`: NVIDIA GeForce NOW + AWDL Control

## Quick Start

```bash
curl -fsSL https://blairhudson.com/awdl-jit/run-latest.sh | bash
```

That command runs AWDL-JIT temporarily, downloads the latest GitHub release, and guides you through creating or removing the generated integration.

## What it installs

For a supported target, `awdl-jit install` generates:

- a launcher app in `~/Applications/`
- runtime scripts in `~/Library/Application Support/AWDL-JIT/`
- a `launchd` watcher in `~/Library/LaunchAgents/`
- URL and file handler registrations for the generated launcher

For GeForce NOW, the launcher is named `NVIDIA GeForce NOW (AWDL).app`.

## Why both a launcher and a watcher?

- The launcher provides the strict path: start `AWDLControl` first, then launch the target app.
- The watcher is a fallback for direct launches of the original app bundle.

The fallback watcher cannot make a direct launch happen after `AWDLControl` has already started. It can only react immediately after the fact.

## Requirements

- macOS
- installed target app and `AWDLControl.app`
- for source builds: Command Line Tools with `swift`
- for release builds: no Swift requirement

## Automation

The interactive command above is the main path. For automation or scripting, you can still pass commands directly through the bootstrap script:

```bash
curl -fsSL https://blairhudson.com/awdl-jit/run-latest.sh | bash -s -- install geforcenow
curl -fsSL https://blairhudson.com/awdl-jit/run-latest.sh | bash -s -- uninstall geforcenow
curl -fsSL https://blairhudson.com/awdl-jit/run-latest.sh | bash -s -- --yes install geforcenow
```

If you are working from a local checkout instead of the bootstrap script:

```bash
./bin/awdl-jit
./bin/awdl-jit interactive
./bin/awdl-jit doctor
./bin/awdl-jit detect
./bin/awdl-jit install geforcenow
./bin/awdl-jit status geforcenow
./bin/awdl-jit repair geforcenow
./bin/awdl-jit uninstall geforcenow
```

From a downloaded GitHub release bundle, users can usually just run:

```bash
./install.sh
```

If only one supported target is detected, you can omit the target name:

```bash
./bin/awdl-jit install
```

## Development

Build the LaunchServices helper:

```bash
swift build -c release
```

Create a distributable macOS release bundle:

```bash
./scripts/build-release.sh
```

Check detection without modifying handlers or launch agents:

```bash
./bin/awdl-jit doctor
./bin/awdl-jit detect
```

Generate artifacts into a temp location for development testing:

```bash
mkdir -p /tmp/awdl-jit/{apps,support,agents}
AWDL_JIT_APPLICATIONS_DIR=/tmp/awdl-jit/apps \
AWDL_JIT_APP_SUPPORT_BASE=/tmp/awdl-jit/support \
AWDL_JIT_LAUNCH_AGENT_DIR=/tmp/awdl-jit/agents \
AWDL_JIT_SKIP_HANDLER_REGISTRATION=1 \
AWDL_JIT_SKIP_LAUNCHAGENT_LOAD=1 \
./bin/awdl-jit install geforcenow
```

## Generated paths

For `geforcenow`, AWDL-JIT writes to:

- `~/Applications/NVIDIA GeForce NOW (AWDL).app`
- `~/Library/Application Support/AWDL-JIT/geforcenow/`
- `~/Library/LaunchAgents/io.github.blairhudson.awdl-jit.watch.geforcenow.plist`

## Notes

- AWDL-JIT does not modify or replace the original target app bundle.
- AWDL-JIT does not modify or redistribute `AWDLControl.app`.
- GitHub releases can bundle the prebuilt `awdl-jit-ls` helper so end users do not need Swift installed.

## Releases

The intended release artifact is a zip archive built on GitHub Actions from a tagged commit. The archive includes:

- `bin/awdl-jit`
- `install.sh`
- shell libraries and templates
- a prebuilt `tools/awdl-jit-ls` binary

That means end users can download the zip, unpack it, and run `./install.sh` without building anything locally.
