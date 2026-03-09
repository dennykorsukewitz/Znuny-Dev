# Dedicated Compose

**Dedicated** = own DB container and own network per instance. Each instance is fully isolated (e.g. `znuny-dev-instance` + `znuny-dev-mariadb` + `znuny-dev-network`).

- **compose-mariadb.yml** – App + MariaDB container + dedicated network
- **compose-mysql.yml** – App + MySQL container + dedicated network
- **compose-postgresql.yml** – App + PostgreSQL container + dedicated network

Used by `create_instance` when `--instance-mode dedicated` or when `INSTANCE_MODE=dedicated` in the instance `.env`. The compose generator (`dev/scripts/instance/compose.sh`) picks this directory when instance mode is `dedicated`.

Container names and networks: see `../CONTAINER_NAMES.md`.
