# Changelog

All notable changes to the Znuny Development Environment will be documented in this file.

## [UNRELEASED] - YYYY-MM-DD

### Added

- Document WSL bind-mount ownership: `zd start` maps container `www-data` to `HOST_UID`/`HOST_GID` so host `git pull` works without a manual `chown`.

### Changed

- Leave the clone target before `rm -rf` / `git clone` so a fresh checkout does not fail with `Unable to read current working directory` when the previous framework directory was the shell cwd.

### Fixed

- Create the container user `znuny` with `useradd --non-unique` so it really shares UID/GID with `www-data`. Previously `useradd` aborted with `UID 33 is not unique` and the `adduser --system` fallback assigned UID 100, which chowned the bind-mounted framework to an unrelated host account (e.g. `syslog` on WSL) until `SetPermissions.pl` switched it to `www-data`. Existing containers are realigned on start.
- Map instance `www-data` to the host developer UID (`HOST_UID`/`HOST_GID` from `zd start`) so Linux/WSL bind mounts stay writable for Git. Existing compose files pick this up via the instance env file; new templates pass the variables explicitly.

## [1.0.0] - 2026-08-14

### Added

- Multi-instance Docker environment: run several Znuny frameworks in parallel via `znuny-dev.sh` / `zd`
- Multi-database support per instance: MariaDB, MySQL, or PostgreSQL
- Instance modes: shared DB (default) or dedicated DB + network per instance
- Automatic HTTP port assignment (`BASE_PORT`, default 10000+) and per-instance Compose generation
- Setup flow: `setup-all`, `setup-status`, `setup-env`, `setup-alias`, framework / tools / packages / Compose
- Instance lifecycle: create, remove, start, stop, restart, build, status (`--json`), logs, shell, console
- Global `zd` alias with shell tab-completion (bash/zsh)
- Host overrides via `configs/` (`instance/my.env`, `framework/Config.pm` injected on container start)
- Module-Tools integration: link/unlink packages and tools, dbinstall/codeinstall, install/uninstall
- Developer tools: Fred, ZnunyCodePolicy (link helpers included)
- `zd random-data-insert` for seed data on new instances
- Local web dashboard (`zd dashboard`, default `http://127.0.0.1:9999/`) with host opener for folder/IDE actions
- Docs: `docs/usage.md`, `docs/dashboard.md`; `zd help` / `zd examples` / `zd version`
- Built-in test suite entry (`zd test`) and GitHub Actions lint/unittest workflows
