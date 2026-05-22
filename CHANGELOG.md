# Changelog

All notable changes to this project are documented here.

## [0.12.224] - 2026-05-22

### Changed

- Bumped target Kiro IDE release to 0.12.224.
- Confirmed upstream Linux x64 package still uses Electron 39.6.0.

## [0.12.184] - 2026-05-15

Initial release.

### Added

- Full build pipeline for repackaging Kiro IDE x64 to ARM64
- Staged build scripts (00 through 70) with idempotent execution
- Native module compilation for 11 Node.js addons
- ARM64 Electron 39.6.0 shell integration
- `.deb` package output with desktop entry and icon integration
- TUI installer script with spinner, progress, and color output
- Makefile with help, build, install, clean, and verify targets
- SVG logo asset with automatic PNG rasterization at all standard sizes
