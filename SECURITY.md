# Security Policy

## Scope

This project contains build scripts and packaging metadata only. It does not modify the Kiro IDE application code. Security issues in Kiro IDE itself should be reported directly to Amazon at [kiro.dev](https://kiro.dev).

## Supported versions

Only the latest release is supported with security fixes.

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| Older   | No        |

## Reporting a vulnerability

If you find a security issue in the build scripts or packaging (for example, a way to inject malicious code during the build process), please report it privately through GitHub's security advisory feature on this repository.

Do not open a public issue for security vulnerabilities.

## What this project does

- Downloads Electron binaries from `github.com/electron/electron` (official releases)
- Downloads native module source from `npmjs.com` (official registry)
- Compiles native modules locally on your machine
- Packages the result into a `.deb`

All downloads use HTTPS. No third-party mirrors or unofficial sources are used.
