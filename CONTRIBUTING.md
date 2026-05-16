# Contributing

This project is maintained by a single developer. Contributions are welcome through issues and pull requests.

## Reporting issues

Open an issue if:

- The build fails on your ARM64 system
- A native module crashes at runtime
- A new Kiro release breaks compatibility
- You have a suggestion for the build process

Include your distro, kernel version (`uname -a`), and the full error output.

## Pull requests

Before submitting:

1. Fork the repo and create a branch from `main`
2. Test your changes with a full `make clean && make all`
3. Verify the resulting `.deb` installs and launches correctly
4. Keep commits focused on a single change

### Style

- Shell scripts follow the existing patterns in `scripts/`
- Use `log_info`, `log_ok`, `log_error` from `scripts/lib/common.sh`
- No bashisms that break on bash 4.x
- Run `shellcheck` on any modified `.sh` files if available

### Scope

This project is strictly a repackaging tool. Changes that modify Kiro's application code, inject additional functionality, or alter the IDE's behavior will not be accepted.

## Updating for a new Kiro release

When a new version of Kiro ships:

1. Update `VERSION` with the new version number
2. Update `src/native-rebuild/package.json` if native module versions changed
3. Run `make all` and verify the build completes
4. Test that the resulting `.deb` installs and launches
5. Submit a PR with the version bump

## Code of conduct

Be respectful. Technical disagreements are fine. Personal attacks are not.
