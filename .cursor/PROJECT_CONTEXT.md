# Znuny-Dev – Project Context

This document describes the Znuny-Dev project for AI and developers. It is loaded from `.cursor` when needed.

---

## 1. What does the project do?

**Znuny-Dev** is a **Docker-based multi-instance development environment for Znuny**. It provides:

- **Multiple Znuny instances in parallel** (e.g. dev, test, prod), each with its own DB and configuration
- **Automatic creation** of new framework instances (clone + instance config)
- **Supported databases per instance**: MariaDB, MySQL, PostgreSQL (Oracle mentioned in configs)
- **Automatic port assignment** via a framework index (8080, 8081, …; DB ports from 3307/5433)
- **Reverse proxy** (ports 80/443) with URL paths per instance (e.g. `/dev/`, `/prod/`)
- **Developer tools**: Fred, module-tools, ZnunyCodePolicy (in `tools/`)
- **Template-based configuration**: global `.env` plus per-instance `.env` in `instances/<name>/` (instances at project root level, like `dev/`)

---

## 2. Project structure (key paths)

| Purpose | Path (relative to repo root) | Environment variable |
|---------|-----------------------------|----------------------|
| **Main entry** | `znuny-dev.sh` | – |
| **Global config** | `.env` (root) | – |
| **Release info** | `RELEASE` | – |
| **Scripts** | `dev/scripts/` | `SCRIPTS_DIR` |
| **Instance configs** | `instances/<name>/<name>.env` | `INSTANCES_DIR` |
| **Compose (instance)** | `instances/<name>/compose-<name>.yml` | per instance |
| **Compose (reverse proxy)** | `dev/docker/compose/compose-reverse-proxy.yml` | `COMPOSE_DIR` |
| **Templates (env)** | `dev/templates/env/*.template` | – |
| **Templates (compose)** | `dev/templates/compose/dedicated/compose-*.yml` | – |
| **Frameworks (Znuny code)** | `frameworks/<name>/` | `FRAMEWORKS_DIR` |
| **Packages (modules)** | `packages/` | `PACKAGES_DIR` |
| **Tools** | `tools/` (Fred, module-tools, ZnunyCodePolicy) | `TOOLS_DIR` |
| **Tests** | `dev/test/`, data `dev/test/data/` | `TEST_DIR` |

**Project root directory** is used everywhere as `ZNUNY_DEV_DIR` (set in `znuny-dev.sh` or loaded from `.env`).

---

## 3. Where is project-related data?

- **Central configuration**: `.env` in the project root (generated from `dev/templates/env/global.env.template`, e.g. via `setup-env`).
- **Instance configuration**: one subdirectory per instance `instances/<name>/` (project root level, like `dev/`) with `<name>.env`, `compose-<name>.yml`, and `logs/`.
- **Framework indices**: in the global `.env` as `USED_FRAMEWORK_INDICES`; per instance in their `.env` as `FRAMEWORK_INDEX`. The index controls ports and subnets.
- **Version/build**: `RELEASE` (VERSION, BUILD_DATE, BUILD_COMMIT, BUILD_BRANCH).
- **Test data**: `dev/test/data/` (e.g. `sample.env`, `sample-instance.env`).

Actual paths for frameworks, packages, and tools come from `.env` (`FRAMEWORKS_DIR`, `PACKAGES_DIR`, `TOOLS_DIR`) and can be customized.

---

## 4. Flow and important scripts

### 4.1 Entry: `znuny-dev.sh`

- Loads `dev/scripts/common.sh` and calls `load_environment` (sources the root `.env`).
- Forwards all commands to sub-scripts. Without an existing `.env`, only `setup-all` and `setup-status` are allowed.

### 4.2 Setup (initial setup)

- **setup-all**: Runs in sequence: setup-env → setup-alias → setup-directories → setup-repositories (framework + tools + packages) → optional instance-create (dev) → optional instance-start.
- **setup-env**: `dev/scripts/env.sh` generates/updates the global `.env` from the template (with backup).
- **setup-alias**: Alias `zd` for `znuny-dev.sh`.
- **setup-directories**: Creates directories (frameworks, packages, tools, …).
- **setup-repositories**: Uses `repository.sh` (setup-repository-sources, setup-framework, setup-tools, setup-packages).
- **setup-compose**: Generates a `compose-<framework>.yml` per instance via `instance.sh` → `instance/compose.sh`.

### 4.3 Instances (lifecycle)

- **instance-create** / **instance-remove** / **instance-start** / **instance-stop** / **instance-restart** are implemented in `dev/scripts/instance.sh`.
- `instance.sh` uses:
  - `instance/compose.sh`: Generate compose files, `docker_compose()` for up/down/logs.
  - `instance/network.sh`: Ports, network (e.g. `get_instance_port`, `get_instance_container_name`-related info).
  - `instance/index.sh`: Framework index (assign, check, maintain `USED_FRAMEWORK_INDICES` in `.env`).

On **instance-create**:

1. Determine framework index (next free index in `instance/index.sh`).
2. Create directory `FRAMEWORKS_DIR/<framework>` and clone repo (via `repository.sh` logic/calls).
3. Create `instances/<name>/` including `logs/`; generate `<name>.env` from `dev/templates/env/instance.env.template`.
4. Generate compose file `instances/<name>/compose-<name>.yml` from `dev/templates/compose/dedicated/` (`instance/compose.sh`).

### 4.4 Other commands

- **instance-status**, **instance-logs**, **instance-container-logs**, **instance-shell**, **instance-console**: all in `instance.sh` (read instance `.env` and call e.g. `docker_compose` or `get_instance_port`/`get_instance_container_name`).
- **test**: `dev/test/run.sh`.
- **release**: `dev/scripts/release.sh` (works with `RELEASE`).

---

## 5. Technical details

### 5.1 Loading the environment

- `load_environment()` in `dev/scripts/common.sh`: sets `ZNUNY_DEV_DIR` if needed, then `source "$ZNUNY_DEV_DIR/.env"`.
- All scripts that need paths or configuration call `load_environment` (or are run after sourcing `common.sh` from `znuny-dev.sh`, which has already loaded `.env`).

### 5.2 Port and index logic

- **FRAMEWORK_INDEX**: 0, 1, 2, … per instance. In `instance/compose.sh`: `BASE_PORT=8080`, HTTP port = `8080 + index`; DB ports (MariaDB/MySQL/PostgreSQL) from BASE_DB_PORT/BASE_POSTGRES_PORT + index-based.
- **USED_FRAMEWORK_INDICES** in the global `.env`: comma-separated list of used indices; read/written in `instance/index.sh`.

### 5.3 Docker

- One compose file per instance: `instances/<name>/compose-<name>.yml`; reverse proxy: `COMPOSE_DIR/compose-reverse-proxy.yml`.
- Project name: `znuny` (`DOCKER_COMPOSE_PROJECT`).
- Container/service names e.g. `znuny_<framework>_instance`, DB container per template (mariadb/mysql/postgresql).
- `docker_compose()` in `instance/compose.sh` changes into `INSTANCES_DIR/<name>/` and runs commands with `-f compose-<name>.yml`.

### 5.4 Repository setup

- `repository.sh`: setup-framework (Znuny clone in `FRAMEWORKS_DIR`), setup-tools (Fred, module-tools, ZnunyCodePolicy in `TOOLS_DIR`), setup-packages, setup-repository-sources.
- Branch selection with priority: dev, rel-*_*-dev, rel-*_*, others (sort_branches).

---

## 6. Conventions for this project

- **Bash**: `set -e` in scripts; consistent output via functions from `common.sh` (print_status, print_error, print_success, …).
- **Paths**: Always via variables from `.env` (INSTANCES_DIR, FRAMEWORKS_DIR, COMPOSE_DIR, …); fallbacks in some scripts relative to `dirname "$0"`.
- **Instance name**: Framework name = instance name (e.g. `dev`, `prod`); alphanumeric, hyphens, underscores (see `repository.sh` check_framework_name).

---

## 7. Quick reference: important files

| File | Role |
|------|------|
| `znuny-dev.sh` | Entry point; loads common.sh + .env; dispatches all commands |
| `dev/scripts/common.sh` | Shared functions, `load_environment`, ensure_directory, confirm, print_* |
| `dev/scripts/env.sh` | Generate/update global `.env`, setup-alias, setup-directories |
| `dev/scripts/repository.sh` | Clone and manage framework/tools/packages |
| `dev/scripts/instance.sh` | Instance CRUD, start/stop/restart, logs, shell, console, status |
| `dev/scripts/instance/compose.sh` | Generate compose files, `docker_compose()` |
| `dev/scripts/instance/network.sh` | Port/network (get_instance_port, …) |
| `dev/scripts/instance/index.sh` | Manage FRAMEWORK_INDEX, USED_FRAMEWORK_INDICES |
| `dev/scripts/release.sh` | RELEASE file and version |
| `dev/templates/env/global.env.template` | Template for root `.env` |
| `dev/templates/env/instance.env.template` | Template for `instances/<name>/<name>.env` |

---

*Based on analysis of the Znuny-Dev repository. Update this file when structure or workflows change.*
