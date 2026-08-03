# Changelog

All notable changes to the Znuny Development Environment will be documented in this file.

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

- Dashboard `start`/`stop` failed with HTTP 500 when frameworks live outside `znuny-dev` (host `FRAMEWORKS_DIR` invisible in container). Mount sibling `frameworks`/`packages`/`tools` and realign paths in `load_environment`.
- Dashboard readiness probe used `localhost:<port>` inside the container (hang/timeout); probe via `host.docker.internal` when running in Docker.

### Security

## [1.0.0] - 2026-XX-XX

### Added

- Complete Znuny development environment automation via `znuny-dev.sh`
- Setup commands: `setup-all`, `setup-status`, `setup-env`, `setup-remove`, framework, tools, packages, Docker Compose generation
- Instance management: create, remove, start, stop, restart, build, status, logs (framework and container)
- Console command execution and shell access to containers
- Global `zd` alias for common tasks (cache rebuild, unit tests, translations, ModuleTools)
- ModuleTools integration: link/unlink packages, dbinstall/codeinstall, Fred link
- Framework repository cloning and configuration
- Development tools: Fred, ZnunyCodePolicy, module-tools
- Interactive setup with user prompts, environment configuration management
- Backup and restore functionality, comprehensive status reporting
- Built-in help, examples, and version commands

- Experimental local web dashboard for development (Docker Compose on `127.0.0.1`, default port `9999`): `zd dashboard start|stop|remove|build|restart|status`; UI served from the repo mount (`dev/dashboard`)

---

## Release Notes Format

### Added

- New features

### Changed

- Changes in existing functionality

### Deprecated

- Soon-to-be removed features

### Removed

- Removed features

### Fixed

- Bug fixes

### Security

- Security improvements
