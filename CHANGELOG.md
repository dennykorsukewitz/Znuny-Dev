# Changelog

All notable changes to the Znuny Development Environment will be documented in this file.

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
