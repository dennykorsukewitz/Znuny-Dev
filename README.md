# Znuny Multi-Instance Development Environment

<img alt="Znuny Dev Logo" align="right" width="150" height="150" src="doc/images/icon.png">

A comprehensive Docker-based development environment for Znuny that enables working on multiple Znuny Framework instances simultaneously, each with its own database and configuration.

| Repository | GitHub |
| --- | --- |
| Release | ![GitHub release (latest by date)](https://img.shields.io/github/v/release/dennykorsukewitz/Znuny-Dev) |
| Issues | ![GitHub open issues](https://img.shields.io/github/issues/dennykorsukewitz/Znuny-Dev) ![GitHub closed issues](https://img.shields.io/github/issues-closed/dennykorsukewitz/Znuny-Dev?color=#44CC44) |
| PRs | ![GitHub pull requests](https://img.shields.io/github/issues-pr/dennykorsukewitz/Znuny-Dev?label=PR) ![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/dennykorsukewitz/Znuny-Dev?color=g&label=PR) |
| Languages | ![GitHub language count](https://img.shields.io/github/languages/count/dennykorsukewitz/Znuny-Dev?style=flat&label=language) ![GitHub contributors](https://img.shields.io/github/contributors/dennykorsukewitz/Znuny-Dev) |
| Code size | ![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/dennykorsukewitz/Znuny-Dev) ![GitHub downloads](https://img.shields.io/github/downloads/dennykorsukewitz/Znuny-Dev/total?style=flat) |
| License | [![GitHub license](https://img.shields.io/github/license/dennykorsukewitz/Znuny-Dev)](LICENSE) |

| Versions | Status |
| --- | --- |
| dev | ![GitHub label version](https://img.shields.io/github/labels/dennykorsukewitz/dennykorsukewitz/dev) [![GitHub commits since tagged version](https://img.shields.io/github/commits-since/dennykorsukewitz/Znuny-Dev/0.0.1/dev)](https://github.com/dennykorsukewitz/Znuny-Dev/compare/0.0.1...dev) ![GitHub Workflow Lint](https://github.com/dennykorsukewitz/Znuny-Dev/actions/workflows/lint.yml/badge.svg?branch=dev&style=flat&label=Lint) ![GitHub Workflow UnitTest](https://github.com/dennykorsukewitz/Znuny-Dev/actions/workflows/unittest.yml/badge.svg?branch=dev&style=flat&label=UnitTest) ![GitHub Workflow Pages](https://github.com/dennykorsukewitz/Znuny-Dev/actions/workflows/pages.yml/badge.svg?branch=dev&style=flat&label=GitHub%20Pages) |

## 🚀 Features

- **Multi-Instance Support**: Run multiple Znuny framework instances in parallel
- **Dynamic Framework Creation**: Automatically create new framework instances
- **Multi-Database Support**: MySQL, PostgreSQL, MariaDB per instance (choose one per instance)
- **Automatic Port Assignment**: Dynamic port allocation (default: 10000, 10001, 10002, etc.; configurable via `BASE_PORT`)
- **Individual Configuration**: Each instance has its own environment file
- **Dynamic Docker Compose**: Automatic generation of docker-compose.yml
- **Complete Isolation**: Separate volumes and containers for each instance
- **Live-Linking**: Module-Tools for live synchronization between framework, packages (`/opt/packages/`), and developer tools (`/opt/tools/`)
- **Developer Tools**: Fred for debugging, ZnunyCodePolicy for code quality
- **Environment Variables Management**: Template-based configuration with automatic backup system
- **Bash Scripts**: Cross-platform compatibility
- **Optional local dashboard**: instance overview at `http://127.0.0.1:9999/` — see [docs/dashboard.md](docs/dashboard.md)

## 📋 Prerequisites

- Docker and Docker Compose
- Git
- Bash (available on all platforms)

## 🛠️ Installation

### 1. Clone Repository

```bash
git clone https://github.com/dennykorsukewitz/Znuny-Dev/ znuny-dev
cd znuny-dev
```

### 2. Setup-All

```bash
# Make all scripts executable
chmod -R +x dev/scripts
chmod +x znuny-dev.sh

# Setup complete environment (or: zd setup-all after alias is configured)
./znuny-dev.sh setup-all
```

## 🎯 Usage

All operations go through `zd`. Run from the project root; if the alias is missing, use `./znuny-dev.sh`. Full reference: [docs/usage.md](docs/usage.md) (`zd help` / `zd examples` stay authoritative).

### Everyday commands

```bash
zd status
zd create <framework>
zd start <framework>
zd stop <framework>
zd restart <framework>
zd shell <framework>
zd console <framework> Maint::Cache::Delete
zd log <framework>
zd link <framework> <package>
zd link-fred <framework>
zd dashboard start
```

Typical flow after install:

```bash
./znuny-dev.sh setup-all
zd create dev
zd start dev
zd status
zd dashboard start   # optional — http://127.0.0.1:9999/
```

More commands (setup, Module-Tools install/uninstall, CodePolicy, tests, release): [docs/usage.md](docs/usage.md).  
Dashboard details: [docs/dashboard.md](docs/dashboard.md).

## ⚙️ Configuration

### Project configs (`configs/`)

Optional host-side configuration lives in the **`configs/`** directory at the project root. These files override or extend defaults and are not overwritten by setup.

| Path                          | Purpose                                                                                                                                                                                      |
|-------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `configs/instance/my.env`     | Loaded after the global `.env`; overrides variables (e.g. `BASE_PORT`, repository URLs like `REPO_SOURCE_ZNUNY`, `REPO_SOURCE_FRED`, `REPO_SOURCE_MODULE_TOOLS`, `REPO_SOURCE_CODE_POLICY`). |
| `configs/framework/Config.pm` | Optional Perl snippet injected into each instance’s `Kernel/Config.pm` on container start.                                                                                                   |

**Load order:** Global `.env` is loaded first, then `configs/instance/my.env`, so values in `my.env` take precedence.

**`configs/framework/Config.pm`:** Only add valid `$Self->{...} = ...;` lines (as in `Kernel/Config/Defaults.pm`). The content is inserted between the markers `# insert your own config settings "here"` and `# end of your own config options!!!` in the framework’s `Kernel/Config.pm`. Changes apply on the next container start (or when the startup script runs the config injection).

## 🚨 Important Notes

1. **Template-based .env**: Global `.env` generated from templates, each instance has its own configuration
2. **Automatic generation**: docker-compose.yml is automatically updated when changes occur
3. **Port conflicts**: The system automatically assigns free ports for each instance (see instance `.env`)
4. **Volumes**: Each instance has separate Docker volumes for data and logs
5. **Isolation**: Complete separation between instances
6. **Apache**: CGI mode by default (`ZNUNY_USE_MOD_PERL=false` in instance `.env`). Znuny’s `apache2-httpd.include.conf` is used, but `mod_perl` stays disabled so each request runs fresh Perl (stable after `git checkout`). Set `ZNUNY_USE_MOD_PERL=true` only if you explicitly want mod_perl.

## 📁 Directory Structure

```text
Znuny-Dev/
├── znuny-dev.sh                          # Main script
├── .env                                  # Global config (from dev/templates/env/)
├── RELEASE                               # Version and build information
├── docs/                                 # Extra documentation
│   ├── usage.md                          # Full zd command reference
│   └── dashboard.md                      # Local dashboard
├── configs/                              # Optional host overrides (see Configuration)
│   ├── instance/my.env                   # Overrides global .env
│   └── framework/Config.pm               # Snippet injected into Kernel/Config.pm
├── instances/                            # Instance configs (same level as dev/)
│   ├── my_instance/                      # Per-instance: .env, compose, logs/
│   │   ├── my_instance.env
│   │   ├── compose-<framework_slug>.yml  # Auto-generated
│   │   └── logs/
│   ├── dev/
│   └── test/
├── dev/                                  # Development configuration
│   ├── dashboard/                        # Local web UI (zd dashboard)
│   │   ├── public/                       # HTML, CSS, JS (repo mount)
│   │   ├── server.mjs                    # API server
│   │   └── Dockerfile                    # Dashboard container image
│   ├── docker/                           # Docker configuration
│   │   ├── compose-dashboard.yml         # Dashboard compose stack
│   │   ├── compose/                      # Optional extra compose snippets
│   │   ├── Dockerfile                    # Instance image definition
│   │   ├── startup-instance.sh           # Instance startup script
│   │   └── configs/                      # Database configurations
│   ├── templates/                        # Templates
│   │   └── env/                          # Environment templates
│   │       ├── global.env.template       # Global .env template
│   │       ├── instance.env.template
│   │       └── docker.env.template
│   ├── scripts/                          # Management scripts
│   │   ├── common.sh                     # Common functions and utilities
│   │   ├── dashboard.sh                  # zd dashboard commands
│   │   ├── env.sh                        # Environment management
│   │   ├── repository.sh                 # Repository operations
│   │   ├── release.sh                    # Version & release management
│   │   ├── version.sh                    # zd version / update check
│   │   ├── instance.sh                   # Framework & instance CRUD + Lifecycle
│   │   └── instance/                     # Instance-specific modules
│   │       ├── compose.sh                # Compose generation & execution
│   │       ├── network.sh                # Port & network management
│   │       ├── index.sh                  # Framework index allocation
│   │       ├── status.sh                 # zd status (text + JSON)
│   │       └── status-json.sh            # JSON status entry point
│   └── test/                             # Test suite
│       ├── run.sh                        # Run all tests (entry point)
│       ├── tests/                        # Test scripts
│       └── utils/                        # Test utilities (assertions.sh)
├── frameworks/                           # Znuny frameworks (path from .env)
│   ├── my_instance/                      # Custom framework repository
│   ├── dev/                              # Development version
│   ├── test/                             # Test version
│   └── prod/                             # Production version
├── packages/                             # Znuny packages
│   └── [Your packages]
├── tools/                                # Developer tools
│   ├── module-tools/                     # Module tools CLI (not linked into framework)
│   ├── Fred/                             # Fred debugging tool
│   └── ZnunyCodePolicy/                  # Code quality checker
└── README.md                             # This file
```

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, coding guidelines, tests, and the pull request process.

## 📄 License

This project is licensed under the GNU GENERAL PUBLIC LICENSE Version 3 — see [LICENSE](LICENSE).

---

Happy developing with Znuny! 🎉

This multi-instance system provides maximum flexibility for development with different Znuny versions and configurations simultaneously.
