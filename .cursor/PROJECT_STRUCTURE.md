# Znuny-Dev – Directory Structure

Current project structure (as of the restructuring: `instances/` at project root level, templates under `dev/templates/env/` and `dev/templates/compose/`).

---

## Project Root

```
ZNUNY_DEV_DIR/
├── .env                          # Global config (from dev/templates/env/global.env.template)
├── znuny-dev.sh                  # Main entry point
├── RELEASE                       # Version/build info (optional)
│
├── dev/                          # Development environment (scripts, Docker, templates)
│   ├── docker/
│   │   ├── compose/              # Reverse proxy only (COMPOSE_DIR)
│   │   │   └── compose-reverse-proxy.yml
│   │   ├── configs/
│   │   ├── Dockerfile
│   │   └── *.sh
│   ├── scripts/
│   │   ├── common.sh
│   │   ├── env.sh
│   │   ├── instance.sh
│   │   ├── repository.sh
│   │   ├── release.sh
│   │   └── instance/
│   │       ├── compose.sh
│   │       ├── network.sh
│   │       └── index.sh
│   ├── templates/
│   │   ├── apache/
│   │   │   └── apache-config-template.conf
│   │   ├── env/
│   │   │   ├── docker.env.template
│   │   │   ├── global.env.template
│   │   │   └── instance.env.template
│   │   └── compose/
│   │       ├── dedicated/
│   │       │   ├── compose-mariadb.yml
│   │       │   ├── compose-mysql.yml
│   │       │   └── compose-postgresql.yml
│   │       └── shared/
│   │           ├── compose-mariadb.yml
│   │           ├── compose-mysql.yml
│   │           └── compose-postgresql.yml
│   ├── test/
│   │   ├── data/
│   │   └── utils/
│   └── STRUCTURE_PLAN.md
│
├── instances/                    # Instances (same level as dev/, INSTANCES_DIR)
│   ├── .gitkeep
│   └── <INSTANCE_NAME>/
│       ├── <INSTANCE_NAME>.env
│       ├── compose-<INSTANCE_NAME>.yml
│       └── logs/
│           ├── access.log
│           ├── error.log
│           └── STDERR.log
│
├── frameworks/                   # Znuny repositories (FRAMEWORKS_DIR)
├── packages/                     # Modules/packages (PACKAGES_DIR)
└── tools/                        # Fred, module-tools, ZnunyCodePolicy (TOOLS_DIR)
```

---

## Key Variables (.env)

| Variable | Typical value (relative) | Meaning |
|----------|--------------------------|---------|
| `ZNUNY_DEV_DIR` | (absolute) | Project root |
| `DEV_DIR` | `dev` | Development environment |
| `DOCKER_DIR` | `dev/docker` | Docker build, Compose (reverse proxy) |
| `SCRIPTS_DIR` | `dev/scripts` | Bash scripts |
| `INSTANCES_DIR` | `instances` | Instance directories (project root level) |
| `COMPOSE_DIR` | `dev/docker/compose` | Reverse proxy Compose only |
| `FRAMEWORKS_DIR` | `frameworks` | Znuny code |
| `PACKAGES_DIR` | `packages` | Packages/modules |
| `TOOLS_DIR` | `tools` | Fred, module-tools, ZnunyCodePolicy |

---

## Instance Paths

- **Instance env**: `instances/<name>/<name>.env`
- **Instance Compose**: `instances/<name>/compose-<name>.yml`
- **Instance logs**: `instances/<name>/logs/` (access.log, error.log, STDERR.log)

Instances are detected as subdirectories of `INSTANCES_DIR` that contain `<name>/<name>.env`.
