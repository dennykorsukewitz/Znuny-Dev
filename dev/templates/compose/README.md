# Docker Container Names by Instance Mode

Names are derived from the **framework name** (e.g. `dev`, `prod`, `rel-7_3`) and the **instance mode** (shared/dedicated).

---

## Instance mode: **shared** (default)

**One** shared DB container per type (`znuny-mariadb`, `znuny-mysql`, `znuny-postgresql`) for all instances. **One** app container per instance; the DB container is defined in the same compose and created on first start.

| Framework name | Container name   |
|----------------|------------------|
| `dev`          | `znuny-dev-instance`   |
| `prod`         | `znuny-prod-instance` |
| `rel-7_3`      | `znuny-rel-7_3-instance` |
| `test`         | `znuny-test-instance`  |

**Example with two instances (dev + prod):**
```
znuny-dev-instance
znuny-prod-instance
```
→ Both use the same shared DB container (`znuny-mariadb`, `znuny-mysql`, or `znuny-postgresql` depending on DB type).

---

## Instance mode: **dedicated**

Own DB and own network per instance. **Two** containers per instance: Znuny app + database.

### MariaDB

| Framework name | App container         | DB container          |
|----------------|-----------------------|------------------------|
| `dev`          | `znuny-dev-instance`  | `znuny-dev-mariadb`   |
| `prod`         | `znuny-prod-instance` | `znuny-prod-mariadb`  |
| `rel-7_3`      | `znuny-rel-7_3-instance` | `znuny-rel-7_3-mariadb` |

### MySQL

| Framework name | App container         | DB container        |
|----------------|-----------------------|----------------------|
| `dev`          | `znuny-dev-instance`  | `znuny-dev-mysql`   |
| `prod`         | `znuny-prod-instance` | `znuny-prod-mysql`  |

### PostgreSQL

| Framework name | App container         | DB container             |
|----------------|-----------------------|---------------------------|
| `dev`          | `znuny-dev-instance`  | `znuny-dev-postgresql`   |
| `prod`         | `znuny-prod-instance` | `znuny-prod-postgresql`  |

**Example with two instances (dev + prod, both MariaDB, dedicated):**
```
znuny-dev-instance
znuny-dev-mariadb
znuny-prod-instance
znuny-prod-mariadb
```

**Networks (dedicated):**
- `znuny-dev-network`
- `znuny-prod-network`

---

## Summary

| Mode              | Per instance | Container names (example for `dev`)                    |
|-------------------|--------------|----------------------------------------------------------|
| **shared**        | 1 container  | `znuny-dev-instance`                                    |
| **dedicated** (MariaDB)    | 2 containers | `znuny-dev-instance`, `znuny-dev-mariadb`       |
| **dedicated** (MySQL)     | 2 containers | `znuny-dev-instance`, `znuny-dev-mysql`        |
| **dedicated** (PostgreSQL)| 2 containers | `znuny-dev-instance`, `znuny-dev-postgresql` |

**Naming scheme:** `znuny-<FRAMEWORK_NAME>-<instance|mariadb|mysql|postgresql>`
