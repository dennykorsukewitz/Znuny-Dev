# Installation & Setup

Step-by-step guide for a fresh **Znuny-Dev** environment. Command reference after setup: [usage.md](usage.md).

> **Read this guide completely before you start.** Walk through every section in order (prerequisites → directory structure → checkout → optional configs → `setup-all` steps). Only then run the commands — many prompts depend on decisions you make upfront (paths, repo URLs, WSL vs native, etc.). Skipping ahead often means re-running setup or moving large Git trees later.

---

## Overview

Znuny-Dev runs multiple Znuny framework instances in Docker. Before the first instance exists, you prepare:

1. **Prerequisites** — Git, Docker (with Compose)
2. **Directory structure** — plan where frameworks, packages, and tools live on disk
3. **Project checkout** — clone this repository
4. **Optional config** — `configs/instance/my.env` before `setup-all`
5. **Automated setup** — `zd setup-all` (or `./znuny-dev.sh setup-all`)

---

## 1. Prerequisites

### Git

Required to clone Znuny-Dev, frameworks, tools, and packages.

```bash
git --version
```

On **Windows**, use Git inside **WSL 2** (recommended) or Git for Windows; run all `zd` commands from the same environment (WSL bash).

### Docker & Docker Compose

You need a running Docker engine **and** the Compose plugin (`docker compose`, not legacy `docker-compose`).

#### macOS

Install [Docker Desktop](https://www.docker.com/products/docker-desktop/). Start the daemon:

```bash
open -a Docker
docker info
docker compose version
```

#### Windows (WSL 2 — recommended)

1. Install **WSL 2** and a Linux distro (e.g. Ubuntu).
2. Install **Docker Desktop** and enable **Use the WSL 2 based engine**.
3. In Docker Desktop → **Settings → Resources → WSL Integration**, enable your distro.
4. Clone and run Znuny-Dev **inside WSL**, not in `C:\` via cmd alone:

```bash
# Inside WSL
docker info
docker compose version
```

**Notes for WSL 2:**

- Project path should be on the Linux filesystem (`~/...`), not `/mnt/c/...`, for better I/O and file watching.
- Docker Desktop must be running on Windows before `docker` works in WSL.
- Line endings: clone with Linux checkout (`git config core.autocrlf input` in WSL).

#### Linux

Example (Debian/Ubuntu):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
# Install Docker Engine — follow https://docs.docker.com/engine/install/ for your distro

# Compose plugin (required)
sudo apt-get install -y docker-compose-plugin

docker compose version
```

Optional: run Docker without `sudo`:

```bash
sudo usermod -aG docker "$USER"
# Log out and back in, then:
docker info
```

---

## 2. Directory structure — plan before checkout

During **Step 3** of `setup-all`, you define three paths. They are stored in the global `.env` as `FRAMEWORKS_DIR`, `PACKAGES_DIR`, and `TOOLS_DIR`.

**Read and decide these paths before you clone** — especially if repositories should live outside the project tree (e.g. on a fast disk or a shared drive). You can still use defaults under `znuny-dev/` after checkout.

| Directory | Variable | Purpose |
| --- | --- | --- |
| **frameworks/** | `FRAMEWORKS_DIR` | Git clones of Znuny (one folder per branch/checkout, e.g. `dev`, `rel-7_3-dev`). Each instance uses one framework directory. |
| **packages/** | `PACKAGES_DIR` | Your Znuny packages (OPM modules). Linked into containers at `/opt/packages/` for live development (`zd link`, `zd install`). |
| **tools/** | `TOOLS_DIR` | Developer tools cloned by setup: `module-tools`, `Fred`, `ZnunyCodePolicy`. Mounted at `/opt/tools/` in containers. |

**Why plan this early?**

- **frameworks** — large Git repos; moving them later means updating paths in `.env` and instance configs.
- **packages** — your module sources; stable path simplifies IDE projects and `zd link <framework> <package>`.
- **tools** — cloned once by `setup-tools`; path must match Docker volume mounts.

**Defaults** (inside the project root after clone):

```text
znuny-dev/frameworks/
znuny-dev/packages/
znuny-dev/tools/
```

During `setup-all`, press Enter at the prompts to keep defaults, or enter absolute paths (e.g. `/data/znuny/frameworks`).

**Related paths** (created automatically, not asked in Step 3 of `setup-all`):

| Path | Purpose |
| --- | --- |
| `instances/` | Per-instance `.env`, generated Compose files, logs |
| `configs/` | Optional overrides — see [configs/README.md](../configs/README.md) |
| `.env` | Global configuration (ports, repo URLs, directory paths) |

---

## 3. Clone repository (project checkout)

```bash
git clone https://github.com/dennykorsukewitz/Znuny-Dev.git znuny-dev
cd znuny-dev
```

Make scripts executable:

```bash
chmod -R +x dev/scripts
chmod +x znuny-dev.sh
```

---

## 4. Optional: pre-configure overrides

Before `setup-all`, you can prepare host-side settings (not overwritten by setup):

| File | When to create |
| --- | --- |
| `configs/instance/my.env` | Override repo URLs, `BASE_PORT`, `DEFAULT_IDE`, etc. — loaded after `.env` |
| `configs/framework/Config.pm` | Perl snippet injected into each instance’s `Kernel/Config.pm` on start |

Example `configs/instance/my.env`:

```bash
REPO_SOURCE_ZNUNY=git@git.znuny.com:Znuny/Public/Znuny.git
BASE_PORT=10000
DEFAULT_IDE=cursor
```

See [configs/README.md](../configs/README.md).

---

## 5. Run full setup: `zd setup-all`

From the project root:

```bash
./znuny-dev.sh setup-all
```

After Step 2, you can use `zd setup-all` instead (same command).

The wizard runs **six interactive steps**. You can skip individual steps with `n` at the prompt.

### Step 1 — Generate global `.env`

**Command:** `setup-env`

**What it does:**

- Creates or updates `.env` from `dev/templates/env/global.env.template`
- Sets `ZNUNY_DEV_DIR`, script paths, template paths, default repo URLs
- Preserves existing `.env` unless you confirm overwrite
- Records setup flags (`SETUP_DATE`, etc.)

If Step 3 ran first, directory paths from that step are included.

### Step 2 — `zd` alias & tab completion

**Command:** `setup-alias`

**What it does:**

- Adds `alias zd='…/znuny-dev.sh'` to your shell config (`~/.zshrc` or `~/.bashrc`)
- Installs tab completion (`dev/completions/zd.zsh` / `zd.bash`)

Reload the shell:

```bash
source ~/.zshrc   # or ~/.bashrc
```

Verify:

```bash
zd version
```

### Step 3 — Directory paths (frameworks, packages, tools)

**Command:** `setup-directories`

**What it does:**

- Prompts for `FRAMEWORKS_DIR`, `PACKAGES_DIR`, `TOOLS_DIR`
- Saves values to `.env` immediately
- Sets `SETUP_DIRECTORIES=true`

Creates nothing yet — only configures where Step 4 will clone repositories.

### Step 4 — Repositories

**Commands:** `setup-repository-sources` → `setup-framework` → `setup-tools` → `setup-packages`

**What it does:**

1. **Repository sources** — confirm or edit Git URLs (`REPO_SOURCE_ZNUNY`, `REPO_SOURCE_FRED`, `REPO_SOURCE_MODULE_TOOLS`, `REPO_SOURCE_CODE_POLICY`). Values from `configs/instance/my.env` are used as defaults if present.
2. **Framework** — interactive branch selection, then clone into `$FRAMEWORKS_DIR/<branch>/` (e.g. `frameworks/dev/`).
3. **Tools** — clone into `$TOOLS_DIR/`:
   - `module-tools`
   - `Fred`
   - `ZnunyCodePolicy`
4. **Packages** — create `$PACKAGES_DIR/`; clone repos listed as `PACKAGE_SOURCE_LIST*` in `.env` (if any). Empty list is OK — directory is ready for your own packages.

Sets `SETUP_REPOSITORIES=true`.

### Step 5 — Create first instance

**Command:** `instance.sh create <framework>`

**What it does:**

- Picks a framework from `$FRAMEWORKS_DIR` (default: `dev`)
- Creates `instances/<framework>/` with instance `.env`, port assignment, DB settings
- Generates Docker Compose file for the instance
- Sets `SETUP_FRAMEWORK_INSTANCE=true`

Skipped if no framework was cloned in Step 4.

### Step 6 — Start instance

**Command:** `instance.sh start <framework>`

**What it does:**

- Runs `docker compose up -d` for the new instance
- Starts app and database containers (depending on instance mode)

Only offered if Step 5 completed.

---

## 6. Verify setup

```bash
zd setup-status
zd setup-status --verbose
zd status
```

Expected after a full first-time setup:

- Global `.env` exists
- `zd` alias works (or use `./znuny-dev.sh`)
- Framework under `frameworks/`
- Tools under `tools/`
- Instance under `instances/<name>/`
- Containers running (`zd status`)

---

## 7. Next steps

Typical workflow:

```bash
zd create dev          # another instance (if needed)
zd start dev
zd shell dev
zd dashboard start     # optional UI — http://127.0.0.1:9999/
```

- Full command list: [usage.md](usage.md) or `zd help`
- Dashboard: [dashboard.md](dashboard.md)
- Configuration: [README.md](../README.md#configuration)

---

## Individual setup commands

If you skipped steps or need to re-run parts:

| Command | Purpose |
| --- | --- |
| `zd setup-env` | Regenerate global `.env` |
| `zd setup-alias` | Install/update `zd` alias |
| `zd setup-directories` | Reconfigure frameworks/packages/tools paths |
| `zd setup-repository-sources` | Edit repo URLs only |
| `zd setup-framework [branch] [dir]` | Clone framework (optional args skip prompts) |
| `zd setup-tools` | Clone Fred, module-tools, ZnunyCodePolicy |
| `zd setup-packages` | Clone packages from `PACKAGE_SOURCE_LIST*` |
| `zd setup-compose` | Regenerate Compose files for all instances |
| `zd setup-remove` | Remove frameworks, tools, instances (destructive) |

---

## Troubleshooting

| Problem | Hint |
| --- | --- |
| `Cannot connect to the Docker daemon` | Start Docker Desktop (macOS/Windows) or `sudo systemctl start docker` (Linux) |
| `docker compose: command not found` | Install `docker-compose-plugin` (Linux) or update Docker Desktop |
| WSL: slow I/O | Use Linux path under `~` (not `/mnt/c/...`), enable WSL integration in Docker Desktop |
| WSL: `git pull` fails, files owned by `www-data` | Instance must receive `HOST_UID` (your WSL user). See [WSL: Git ownership (`www-data`)](#wsl-git-ownership-www-data). |
| `zd: command not found` | Run `source ~/.zshrc` or use `./znuny-dev.sh` |
| No frameworks in Step 5 | Run `zd setup-framework` first |
| SSH clone fails | Configure SSH keys / use HTTPS URLs in `configs/instance/my.env` |

### WSL: Git ownership (`www-data`)

Bind mounts on Linux/WSL keep container UIDs. Apache still runs as www-data, but `zd start` maps that account to HOST_UID/HOST_GID (your WSL user). Host `git pull` then works without chown.

Recreate the instance once: `zd setup-compose && zd start <framework>` (or just `zd start` — instance env gets HOST_UID).

Override: `HOST_UID` / `HOST_GID` in `.env` or `configs/instance/my.env`. Skip mapping when HOST_UID is 0 (e.g. dashboard as root without forwarded IDs).

On **WSL 2**, Docker uses real Linux UIDs. macOS Docker often remaps anyway.

If files are still UID 33: start did not receive HOST_UID. From WSL run `zd start <framework>` (not as root). Dashboard: `zd dashboard restart` so the dashboard container gets HOST_UID.

For development contributions, see [CONTRIBUTING.md](../CONTRIBUTING.md).
