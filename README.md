<p align="center">
  <img src="assets/kiro-logo.svg" width="128" height="128" alt="Kiro IDE logo">
</p>

<h1 align="center">Kiro IDE for ARM64 Linux</h1>

<p align="center">
  Community repackage of <a href="https://kiro.dev">Kiro IDE</a> for aarch64 Debian/Ubuntu systems.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Kiro-0.12.184-9046FF?style=flat-square" alt="Kiro version">
  <img src="https://img.shields.io/badge/Electron-39.6.0-47848F?style=flat-square" alt="Electron version">
  <img src="https://img.shields.io/badge/arch-arm64-blue?style=flat-square" alt="Architecture">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License">
</p>

---

## What is this?

Kiro IDE is an AI-powered development environment built by Amazon. Official releases target x86-64 Linux only. This project repackages the official release for ARM64 (aarch64) hardware by:

1. Extracting the architecture-independent app resources from the official x64 `.deb`
2. Pairing them with a native ARM64 Electron shell (same version Kiro ships)
3. Recompiling all 11 native Node.js modules from source for ARM64
4. Producing a standard `.deb` package with desktop integration and the official icon

No source code from Kiro is modified. The JavaScript, HTML, and extension bundles are used as-is.

## Quick install

Download the latest `.deb` from [Releases](../../releases), then:

```bash
sudo dpkg -i kiro-ide-0.12.184-arm64.deb
```

Or use the TUI installer:

```bash
bash install.sh --local kiro-ide-0.12.184-arm64.deb
```

After installation, launch from your application menu or run `kiro` in a terminal.

## Build from source

Requires: Debian/Ubuntu ARM64, Node.js 20+, build-essential, ~4GB disk space.

```bash
git clone https://github.com/ChloeVPin/kiro-arm64.git
cd kiro-arm64
```

Place the official Kiro x64 `.deb` in `~/Downloads/` (download from [kiro.dev](https://kiro.dev)), then:

```bash
make all
```

The output `.deb` lands in `build/dist/`. The full build takes about 2 minutes.

### Individual stages

Each build step can be run independently:

```bash
make prereqs     # install apt/node dependencies
make fetch       # locate the upstream x64 .deb
make extract     # extract app resources, detect Electron version
make electron    # download arm64 Electron
make natives     # rebuild native .node modules for arm64
make assemble    # combine everything into the app tree
make icons       # generate PNG icons from SVG
make deb         # package the final .deb
```

### Other targets

```bash
make verify      # list architecture of every .node binary
make install     # install the built .deb (sudo)
make uninstall   # remove the installed package
make clean       # wipe all build artifacts
make clean-soft  # clean but keep cached downloads
```

## Project structure

```
kiro-arm64/
  assets/              SVG logo (PNGs generated at build time)
  packaging/
    debian/            control template, postinst, postrm
    desktop/           freedesktop .desktop entry
  scripts/
    lib/common.sh      shared helpers and logging
    00-prereqs.sh      install build dependencies
    10-fetch-source.sh locate upstream .deb
    20-extract-source  extract and detect versions
    30-fetch-electron  download arm64 Electron
    40-rebuild-natives compile native modules
    50-assemble.sh     combine shell + app + modules
    60-generate-icons  SVG to PNG rasterization
    70-build-deb.sh    produce the .deb
    build-all.sh       orchestrator (supports --from/--to)
    clean.sh           cleanup (supports --soft/--dist)
  src/
    native-rebuild/    pinned native module versions
  config.sh            tunable build variables
  install.sh           TUI installer script
  Makefile             convenience targets
  VERSION              target Kiro version
```

## Native modules rebuilt

These 11 native Node.js addons are compiled from source for ARM64:

| Module | Purpose |
|--------|---------|
| `@parcel/watcher` | Filesystem watching |
| `native-keymap` | Keyboard layout detection |
| `native-watchdog` | Process watchdog |
| `native-is-elevated` | Privilege detection |
| `node-pty` | Terminal emulation |
| `kerberos` | Kerberos authentication |
| `windows-foreground-love` | Window focus (Linux stub) |
| `@vscode/spdlog` | Structured logging |
| `@vscode/sqlite3` | Local database |
| `@vscode/deviceid` | Device identification |
| `@vscode/policy-watcher` | Policy file monitoring |

Additionally, `@lancedb/vectordb-linux-arm64-gnu` is installed from its published ARM64 package, and `onnxruntime-node` already ships ARM64 binaries upstream.

## Tested on

- Ubuntu 26.04 on Snapdragon X Elite (Dell XPS 13 9345)

Other ARM64 Debian/Ubuntu systems should work. If you test on additional hardware, open an issue or PR to update this list.

## Disclaimer

This is an **unofficial** community project. Kiro IDE is a proprietary product of Amazon. This repository contains only build tooling and packaging scripts. The Kiro IDE software itself is not included and must be downloaded separately from [kiro.dev](https://kiro.dev).

The Kiro logo is a trademark of Amazon, included solely for reproducing the official application icon. No endorsement by Amazon is implied.

## License

Build scripts and tooling: [MIT](LICENSE)

Kiro IDE: governed by its own [terms of service](https://kiro.dev)
