# Znuny Multi-Instance Development Environment

A comprehensive Docker-based development environment for Znuny that enables working on multiple Znuny Framework instances simultaneously, each with its own database and configuration.

## 🚀 Features

- **Multi-Instance Support**: Run multiple Znuny framework instances in parallel
- **Dynamic Framework Creation**: Automatically create new framework instances
- **Multi-Database Support**: MySQL, PostgreSQL, Oracle, MariaDB per instance
- **Automatic Port Assignment**: Dynamic port allocation (8080, 8081, 8082, etc.)
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
git clone https://github.com/dennykorsukewitz/Znuny-Dev/ Znuny-Dev
cd Znuny-Dev
```

### 2. Quick Start

```bash
# Make all scripts executable
chmod +x dev/scripts/*.sh
chmod +x znuny-dev.sh

# Setup complete environment
./znuny-dev.sh setup-all

# Start development environment
./znuny-dev.sh start
```

### 3. Manual Installation

```bash

# Start development environment
./znuny-dev.sh start
```

## 🎯 Usage

### Main Script

The main script `./znuny-dev.sh` provides a unified interface for all operations:

```bash
# Show help
./znuny-dev.sh help

# Show status
./znuny-dev.sh status

# Start/stop containers
./znuny-dev.sh start
./znuny-dev.sh stop
./znuny-dev.sh restart
```

### Framework Management

```bash
# Create new framework instance
./dev/scripts/instance.sh create my_custom_framework

# Create with specific repository and branch
./dev/scripts/instance.sh create znuny_custom https://github.com/myorg/znuny.git develop

# List all framework instances
./dev/scripts/instance.sh list

# Start specific framework instance
./dev/scripts/instance.sh start my_custom_framework

# Stop specific framework instance
./dev/scripts/instance.sh stop my_custom_framework

# Restart specific framework instance
./dev/scripts/instance.sh restart my_custom_framework

# Remove framework instance
./dev/scripts/instance.sh remove my_custom_framework
```

### Database Status

```bash
# Show database status for all instances
./znuny-dev.sh db-status
```

### Znuny Console

```bash
# Check database
./znuny-dev.sh console db:check

# Install package
./znuny-dev.sh console package:install MyPackage

# Clear cache
./znuny-dev.sh console cache:clear

# Execute console command on specific framework
./dev/scripts/instance.sh console my_custom_framework db:check
```

### Logs and Debugging

```bash
# Show logs for specific framework
./dev/scripts/instance.sh logs my_custom_framework

# Show last 100 log lines
./dev/scripts/instance.sh logs my_custom_framework 100

# All container logs
docker-compose logs

# Specific service
./znuny-dev.sh logs mysql
./znuny-dev.sh logs znuny
```

## 📁 Directory Structure

```
Znuny-Dev/
├── znuny-dev.sh                     # Main script
├── RELEASE                          # Version and build information
├── dev/                             # Development configuration
│   ├── docker/                      # Docker configuration
│   │   ├── compose/                # Generated Docker Compose files
│   │   │   ├── compose-*.yml       # Auto-generated per framework
│   │   │   └── compose-reverse-proxy.yml
│   │   ├── Dockerfile              # Docker image definition
│   │   ├── startup-instance.sh     # Instance startup script
│   │   ├── startup-reverse-proxy.sh
│   │   └── configs/                # Database configurations
│   ├── instances/                   # Framework instance configurations
│   │   ├── my_custom_framework.env # Framework-specific configs
│   │   ├── dev.env
│   │   └── test.env
│   ├── templates/                   # Environment templates
│   │   ├── global.env.template     # Global environment template
│   │   ├── instance.env.template   # Instance environment template
│   │   └── docker.env.template     # Docker environment template
│   ├── scripts/                     # Management scripts
│   │   ├── common.sh               # Common functions and utilities
│   │   ├── env.sh                  # Environment management
│   │   ├── repository.sh           # Repository operations
│   │   ├── release.sh              # Version & release management
│   │   ├── instance.sh             # Framework & instance CRUD + Lifecycle
│   │   └── instance/               # Instance-specific modules
│   │       ├── compose.sh          # Docker Compose generation & execution
│   │       ├── network.sh          # Port & network management
│   │       └── index.sh            # Framework index allocation
│   └── test/                        # Test suite
│       ├── run.sh                  # Run all tests (entry point)
│       ├── tests/                  # Test scripts
│       └── utils/                  # Test utilities (assertions.sh)
├── frameworks/                      # Znuny frameworks
│   ├── my_custom_framework/        # Custom framework repository
│   ├── dev/                        # Development version
│   ├── test/                       # Test version
│   └── prod/                       # Production version
├── packages/                        # Znuny packages
│   └── [Your packages]
├── tools/                           # Developer tools
│   ├── module-tools/               # Module tools for linking
│   ├── Fred/                       # Fred debugging tool
│   └── ZnunyCodePolicy/            # Code quality checker
└── README.md                        # This file
```

## ⚙️ Configuration

## 🔧 Environment Configuration

### Template-Based System

The Znuny Development Environment uses an optimized template-based system for environment configuration:

- **Global `.env`**: Generated from `dev/templates/env/global.env.template`
- **Instance `.env`**: Generated from `dev/templates/env/instance.env.template`
- **Automatic Backup**: Existing configurations are preserved during updates
- **Optimized Templates**: Only contains actually used variables

### Environment Files

#### Global Environment (`.env`)
```bash
# Root-level .env file (auto-generated)
ZNUNY_DEV_DIR=/path/to/znuny
FRAMEWORKS_DIR=/path/to/znuny/frameworks
PACKAGES_DIR=/path/to/znuny/packages
TOOLS_DIR=/path/to/znuny/tools
# ... other global variables
```

#### Framework-Specific Environment Files

Each framework instance has its own `.env` file in `instances/` (project root, same level as `dev/`):

```bash
# instances/<name>/<name>.env
INSTANCE_NAME=my_custom_framework
DB_TYPE=mariadb
DB_HOST=mariadb-my_custom_framework
DB_NAME=znuny_my_custom_framework
DB_USER=znuny_my_custom_framework
DB_PASSWORD=my_custom_framework_password
ZNUNY_SCRIPT_ALIAS=/my_custom_framework/
ZNUNY_DEBUG=1
```

### Environment Management Commands

```bash
# Generate global .env from template
./dev/scripts/env.sh

# Force regeneration (overwrites existing .env)
./dev/scripts/env.sh --force

# Set individual variable
./dev/scripts/env.sh --set-var FRAMEWORKS_DIR /custom/frameworks

# Show help
./dev/scripts/env.sh --help
```

### Important Environment Variables

#### Project Paths
- `ZNUNY_DEV_DIR`: Main directory of Znuny Development Environment
- `DEV_DIR`: Development directory (`dev/`)
- `DOCKER_DIR`: Docker configuration (`dev/docker/`)
- `SCRIPTS_DIR`: Scripts directory (`dev/scripts/`)

#### Core Directories
- `FRAMEWORKS_DIR`: Frameworks directory (`frameworks/`)
- `PACKAGES_DIR`: Packages directory (`packages/`)
- `TOOLS_DIR`: Tools directory (`tools/`)

#### Docker Configuration
- `DOCKER_COMPOSE_PROJECT`: Docker Compose project name (`znuny`)

#### Tool-Specific Paths
- `FRED_DIR`: Fred debugging tool (`tools/Fred/`)
- `MODULE_TOOLS_DIR`: Module-Tools (`tools/module-tools/`)
- `CODE_POLICY_DIR`: Code-Policy (`tools/ZnunyCodePolicy/`)

### Backup System

The environment system includes an automatic backup mechanism:

- **Automatic Backups**: Created during each `.env` generation
- **Configuration Preservation**: Existing variables are restored from backup
- **Template Updates**: New template variables are added
- **Data Safety**: Old, unused variables remain preserved (from backup)

```bash
# Example: Template is updated
./dev/scripts/env.sh --force

# 1. Backup of existing .env is created
# 2. New .env is generated from template
# 3. Variables from backup are restored
# 4. Only new/changed variables are updated
```

> **📖 Detailed Documentation**: For comprehensive information about the environment system, see [ENV_SETUP.md](ENV_SETUP.md)

### Automatic Port Assignment

Ports are automatically assigned based on the order of frameworks:

- **Framework 1**: HTTP 8080, HTTPS 8480, MariaDB 3307, MySQL 3308, PostgreSQL 5433
- **Framework 2**: HTTP 8081, HTTPS 8481, MariaDB 3310, MySQL 3311, PostgreSQL 5434
- **Framework 3**: HTTP 8082, HTTPS 8482, MariaDB 3313, MySQL 3314, PostgreSQL 5435

### Database Configuration

#### MySQL
```yaml
services:
  mysql:
    image: mysql:8.0
    ports:
      - "3306:3306"
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_DATABASE=znuny
      - MYSQL_USER=znuny
      - MYSQL_PASSWORD=znuny
```

#### PostgreSQL
```yaml
services:
  postgresql:
    image: postgres:15
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=znuny
      - POSTGRES_USER=znuny
      - POSTGRES_PASSWORD=znuny
```

## 🌐 Access

After starting the development environment:

### **Unified Access via Port 80/443:**
- **my_custom_framework**: http://localhost/my_custom_framework/
- **znuny_dev**: http://localhost/znuny_dev/
- **znuny_rel-6_5**: http://localhost/znuny_rel-6_5/
- **znuny_rel-7_2**: http://localhost/znuny_rel-7_2/

### **Direct Access (for debugging):**
- **my_custom_framework**: http://localhost:8080/ (internal)
- **znuny_dev**: http://localhost:8081/ (internal)
- **znuny_rel-6_5**: http://localhost:8082/ (internal)
- **znuny_rel-7_2**: http://localhost:8083/ (internal)

### **HTTPS Access:**
- **All Frameworks**: https://localhost/framework_name/

### **Additional Services:**
- **Fred Debugging**: http://localhost:3000/ (when enabled)
- **Selenium Hub**: http://localhost:4444/ (when enabled)
- **Kibana**: http://localhost:5601/ (when enabled)

## 🧪 Testing

### Selenium Tests

```bash
# Start Selenium containers
docker-compose up -d selenium-hub selenium-chrome selenium-firefox

# Run tests (example)
docker exec -it znuny_dev python /opt/znuny/scripts/test/selenium_tests.py
```

## 🔧 Advanced Features

### Backup and Restore

```bash
# Backup framework instance
./dev/scripts/instance.sh backup my_custom_framework ./backups

# Creates:
# - ./backups/my_custom_framework_backup_20250114_143022/
#   ├── my_custom_framework/          # Framework directory
#   ├── my_custom_framework.env       # Environment configuration
#   ├── znuny_my_custom_framework_data.tar.gz
#   └── znuny_my_custom_framework_logs.tar.gz
```

### Database Switching per Instance

Each instance can use its own database:

```bash
# Change in the framework-specific .env file (instances/<name>/):
DB_TYPE=postgresql
DB_HOST=postgresql-my_custom_framework
```

### Repository Management

```bash
# Setup repositories
./dev/scripts/repository.sh

# Setup only framework repositories
./dev/scripts/repository.sh --framework-only

# Setup only development tools
./dev/scripts/repository.sh --tools-only

# Setup without configuration prompts
./dev/scripts/repository.sh --no-config
```

## 🔍 Troubleshooting

### Common Issues

1. **Container won't start**
   ```bash
   # Show logs
   ./znuny-dev.sh logs

   # Restart container
   ./znuny-dev.sh restart
   ```

2. **Database connection failed**
   ```bash
   # Check database status
   ./znuny-dev.sh db-status

   # Check database container
   docker ps | grep mariadb
   ```

3. **Framework instance doesn't start**
   ```bash
   # Check instance status
   ./dev/scripts/instance.sh status my_custom_framework

   # Check instance logs
   ./dev/scripts/instance.sh logs my_custom_framework

   # Restart instance
   ./dev/scripts/instance.sh restart my_custom_framework
   ```

### Port Conflicts

```bash
# Check available ports
netstat -tulpn | grep :808

# Regenerate Docker Compose
./dev/scripts/instance/compose.sh
```

### Database Connection Issues

```bash
# Check database container
docker ps | grep mariadb

# Show database logs
docker logs znuny_mariadb_my_custom_framework
```

## 🚨 Important Notes

1. **Template-based .env**: Global `.env` generated from templates, each instance has its own configuration
2. **Automatic generation**: docker-compose.yml is automatically updated when changes occur
3. **Reverse Proxy**: All instances are accessible via Port 80/443 with URL-based routing
4. **Port conflicts**: The system automatically assigns free ports (internal only)
5. **Volumes**: Each instance has separate Docker volumes for data and logs
6. **Isolation**: Complete separation between instances
7. **Apache configuration**: Automatically generated based on available frameworks

## 📚 Additional Commands

```bash
# Show help
./znuny-dev.sh help

# Show all available commands
./znuny-dev.sh

# Repository setup help
./dev/scripts/repository.sh --help

# Instance manager help
./dev/scripts/instance.sh help

# Setup alias for easy access
./dev/scripts/instance.sh alias
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a pull request

## 📄 License

This project is licensed under the GNU AFFERO GENERAL PUBLIC LICENSE Version 3.

## 🆘 Support

For problems or questions:

1. Check the [Troubleshooting section](#-troubleshooting)
2. Look at the logs: `./znuny-dev.sh logs`
3. Create an issue in the repository

## 🔄 Updates

```bash
# Update repositories
./dev/scripts/repository.sh

# Rebuild containers
docker-compose build --no-cache

# Restart environment
./znuny-dev.sh restart
```

---

**Happy developing with Znuny! 🎉**

This multi-instance system provides maximum flexibility for development with different Znuny versions and configurations simultaneously.