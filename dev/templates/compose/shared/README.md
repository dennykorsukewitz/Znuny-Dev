# Shared Compose (default mode)

**Shared** = one shared DB container per type for all instances. Each template includes the shared DB service; the first instance start creates DB + network, further instance starts only add their app (same project `znuny`).

- **compose-mariadb.yml** – Shared MariaDB + app, connects to `znuny-mariadb`
- **compose-mysql.yml** – Shared MySQL + app, connects to `znuny-mysql`
- **compose-postgresql.yml** – Shared PostgreSQL + app, connects to `znuny-postgresql`

Used by `create_instance` when `--instance-mode shared` (default) or when `INSTANCE_MODE=shared` in the instance `.env`. The compose generator (`dev/scripts/instance/compose.sh`) picks this directory when instance mode is `shared`.
