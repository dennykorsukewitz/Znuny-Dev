# Znuny Multi-Instance Development Environment

<img alt="Znuny Dev Logo" align="right" width="150" height="150" src="doc/images/icon.png">

A comprehensive Docker-based development environment for Znuny that enables working on multiple Znuny Framework instances simultaneously, each with its own database and configuration.

| Repository| GitHub                                                                                                                                                                                                                         |
|-----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Release   | ![GitHub release (latest by date)](https://img.shields.io/github/v/release/dennykorsukewitz/Znuny-Dev)                                                                                                                         |
| Issues    | ![GitHub open issues](https://img.shields.io/github/issues/dennykorsukewitz/Znuny-Dev) ![GitHub closed issues](https://img.shields.io/github/issues-closed/dennykorsukewitz/Znuny-Dev?color=#44CC44)                           |
| PRs       | ![GitHub pull requests](https://img.shields.io/github/issues-pr/dennykorsukewitz/Znuny-Dev?label=PR) ![GitHub closed pull requests](https://img.shields.io/github/issues-pr-closed/dennykorsukewitz/Znuny-Dev?color=g&label=PR)|
| Languages | ![GitHub language count](https://img.shields.io/github/languages/count/dennykorsukewitz/Znuny-Dev?style=flat&label=language) ![GitHub contributors](https://img.shields.io/github/contributors/dennykorsukewitz/Znuny-Dev)     |
| Code size | ![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/dennykorsukewitz/Znuny-Dev) ![GitHub downloads](https://img.shields.io/github/downloads/dennykorsukewitz/Znuny-Dev/total?style=flat)            |

| Versions| Status                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
|---------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| dev     | ![GitHub label version](https://img.shields.io/github/labels/dennykorsukewitz/dennykorsukewitz/dev) [![GitHub commits since tagged version](https://img.shields.io/github/commits-since/dennykorsukewitz/Znuny-Dev/0.0.1/dev)](https://github.com/dennykorsukewitz/Znuny-Dev/compare/0.0.1...dev) ![GitHub Workflow Lint](https://github.com/dennykorsukewitz/Znuny-Dev/actions/workflows/lint.yml/badge.svg?branch=dev&style=flat&label=Lint) ![GitHub Workflow UnitTest](https://github.com/dennykorsukewitz/Znuny-Dev/actions/workflows/unittest.yml/badge.svg?branch=dev&style=flat&label=UnitTest) ![GitHub Workflow Pages](https://github.com/dennykorsukewitz/Znuny-Dev/actions/workflows/pages.yml/badge.svg?branch=dev&style=flat&label=GitHub%20Pages)|

## 🚀 Features

- **Multi-Instance Support**: Run multiple Znuny framework instances in parallel
- **Dynamic Framework Creation**: Automatically create new framework instances
- **Multi-Database Support**: MySQL, PostgreSQL, MariaDB per instance (choose one per instance)
- **Automatic Port Assignment**: Dynamic port allocation (default: 10000, 10001, 10002, etc.; configurable via `BASE_PORT`)
- **Individual Configuration**: Each instance has its own environment file
- **Dynamic Docker Compose**: Automatic generation of docker-compose.yml
- **Complete Isolation**: Separate volumes and containers for each instance
- **Live-Linking**: Module-Tools for live synchronization between Framework and Packages
- **Developer Tools**: Fred for debugging, ZnunyCodePolicy for code quality
- **Environment Variables Management**: Template-based configuration with automatic backup system
- **Bash Scripts**: Cross-platform compatibility

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

# Setup complete environment
./znuny-dev.sh setup-all (zd setup-all)
```

## 🎯 Usage

All operations go through the main script `zd`. Run commands from the project root; if the `zd` alias is not set (e.g. before `setup-all`), use `./znuny-dev.sh` instead. An optional instance name (e.g. `my_instance`) applies the command to that instance.

### Framework Instances

```bash
zd status

# Create new instance
zd create <framework>

# With custom repository and branch
zd create <framework> https://github.com/myorg/znuny.git develop

# Start, stop, restart, or remove instance
zd start <framework>
zd stop <framework>
zd restart <framework>
zd remove <framework>

# Build Docker image for framework instance or all instances
zd build <framework>

# Start shell session in framework container (default: as znuny user)
zd shell <framework>
...
```

### Znuny Console

```bash
zd console <framework> Maint::Cache::Delete
zd console <framework> Maint::Config::Rebuild
zd console <framework> Dev::Tools::TranslationsUpdate
...
```

### Logs

```bash
# Framework log from instance volume (default: error.log)
zd log <framework>
zd log <framework> access.log
zd log <framework> error.log

# Container log (stdout/stderr); optional line count
zd container-log <framework>
zd container-log <framework> 100

# All container logs (reverse-proxy stack)
zd container-log
```

### Module-Tools

Module-Tools provide live linking between packages and the framework and package install/uninstall operations. Commands are run inside the instance container via `znuny.ModuleTools.pl`. Replace `<framework>` with your instance name (e.g. `dev`) and `<package>` with the package name (e.g. `FAQ`).

**File linking (live sync):**

```bash
zd link <framework> <package>           # Link package into framework
zd unlink <framework> <package>         # Unlink package
zd rmlinks <framework>                  # Unlink all packages
```

**Package install/uninstall:**

```bash
zd install <framework> <package>        # DB + code install
zd uninstall <framework> <package>      # DB + code uninstall
zd dbinstall <framework> <package>      # Database install only
zd dbupgrade <framework> <package>      # Database upgrade
zd dbuninstall <framework> <package>
zd codeinstall <framework> <package>
zd codereinstall <framework> <package>
zd codeuninstall <framework> <package>
zd codeupgrade <framework> <package>
```

**Direct module-tools (any command):**

```bash
zd module-tools <framework>             # List available commands
zd module-tools <framework> <command> [args...]
```

**Fred (debugging):**
Link or unlink the Fred tool into a framework.

```bash
zd link-fred <framework>
zd unlink-fred <framework>
```

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
3. **Reverse Proxy**: All instances are accessible via Port 80/443 with URL-based routing
4. **Port conflicts**: The system automatically assigns free ports (internal only)
5. **Volumes**: Each instance has separate Docker volumes for data and logs
6. **Isolation**: Complete separation between instances
7. **Apache configuration**: Automatically generated based on available frameworks

## 📁 Directory Structure

```text
Znuny-Dev/
├── znuny-dev.sh                     # Main script
├── .env                             # Global config (from dev/templates/env/)
├── RELEASE                          # Version and build information
├── instances/                       # Instance configs (same level as dev/)
│   ├── my_instance/        # Per-instance: .env, compose, logs/
│   │   ├── my_instance.env
│   │   ├── compose-<framework_slug>.yml  # Auto-generated
│   │   └── logs/
│   ├── dev/
│   └── test/
├── dev/                             # Development configuration
│   ├── docker/                      # Docker configuration
│   │   ├── compose/                 # Shared reverse-proxy only
│   │   │   └── compose-reverse-proxy.yml
│   │   ├── Dockerfile               # Docker image definition
│   │   ├── startup-instance.sh     # Instance startup script
│   │   ├── startup-reverse-proxy.sh
│   │   └── configs/                 # Database configurations
│   ├── templates/                   # Templates
│   │   └── env/                     # Environment templates
│   │       ├── global.env.template  # Global .env template
│   │       ├── instance.env.template
│   │       └── docker.env.template
│   ├── scripts/                     # Management scripts
│   │   ├── common.sh                # Common functions and utilities
│   │   ├── env.sh                   # Environment management
│   │   ├── repository.sh            # Repository operations
│   │   ├── release.sh               # Version & release management
│   │   ├── instance.sh              # Framework & instance CRUD + Lifecycle
│   │   └── instance/                # Instance-specific modules
│   │       ├── compose.sh           # Compose generation & execution
│   │       ├── network.sh           # Port & network management
│   │       └── index.sh             # Framework index allocation
│   └── test/                        # Test suite
│       ├── run.sh                   # Run all tests (entry point)
│       ├── tests/                   # Test scripts
│       └── utils/                   # Test utilities (assertions.sh)
├── frameworks/                      # Znuny frameworks (path from .env)
│   ├── my_instance/         # Custom framework repository
│   ├── dev/                         # Development version
│   ├── test/                        # Test version
│   └── prod/                        # Production version
├── packages/                        # Znuny packages
│   └── [Your packages]
├── tools/                           # Developer tools
│   ├── module-tools/                # Module tools for linking
│   ├── Fred/                        # Fred debugging tool
│   └── ZnunyCodePolicy/             # Code quality checker
└── README.md                        # This file
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a pull request

## 📄 License

This project is licensed under the GNU AFFERO GENERAL PUBLIC LICENSE Version 3.

## 🔄 Updates

```bash
# Update repositories
zd setup-framework
# or full repo setup: run repository.sh via dev/scripts/repository.sh

# Rebuild containers for an instance or all
zd build my_instance
zd build all --no-cache

# Restart environment
zd restart
```

---

Happy developing with Znuny! 🎉

This multi-instance system provides maximum flexibility for development with different Znuny versions and configurations simultaneously.
