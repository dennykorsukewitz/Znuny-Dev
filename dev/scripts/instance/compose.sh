#!/bin/bash

# Docker Compose Generator for Znuny Multi-Instance Setup
# This script generates individual docker-compose files for each framework

set -e

# Resolve directory of this script (compose.sh is often sourced from instance.sh; BASH_SOURCE points to this file)
COMPOSE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Load common functions
# shellcheck source=../common.sh
source "$COMPOSE_SCRIPT_DIR/../common.sh"

# Load global environment variables (.env then configs/instance/my.env so my.env overrides)
if [ -f "$COMPOSE_SCRIPT_DIR/../../../.env" ]; then
    # shellcheck disable=SC1091
    source "$COMPOSE_SCRIPT_DIR/../../../.env"
fi
if [ -f "$COMPOSE_SCRIPT_DIR/../../../configs/instance/my.env" ]; then
    # shellcheck disable=SC1091
    source "$COMPOSE_SCRIPT_DIR/../../../configs/instance/my.env"
fi

# Set default directories if not configured (all relative to compose.sh location so zd works from any cwd)
FRAMEWORKS_DIR="${FRAMEWORKS_DIR:-$COMPOSE_SCRIPT_DIR/../../../frameworks}"
PACKAGES_DIR="${PACKAGES_DIR:-$COMPOSE_SCRIPT_DIR/../../../packages}"
TOOLS_DIR="${TOOLS_DIR:-$COMPOSE_SCRIPT_DIR/../../../tools}"

# Configuration (COMPOSE_DIR = shared reverse-proxy only; instance compose in INSTANCES_DIR/NAME/)
COMPOSE_DIR="${COMPOSE_DIR:-$COMPOSE_SCRIPT_DIR/../../docker/compose}"
INSTANCES_DIR="${INSTANCES_DIR:-$COMPOSE_SCRIPT_DIR/../../../instances}"
DOCKER_DIR="${DOCKER_DIR:-$COMPOSE_SCRIPT_DIR/../../docker}"
SCRIPTS_DIR="${SCRIPTS_DIR:-$COMPOSE_SCRIPT_DIR/..}"

# Base path for compose templates (shared = default, dedicated = own DB + network)
COMPOSE_TEMPLATES_BASE="$COMPOSE_SCRIPT_DIR/../../templates/compose"

# ========================================
# Utility Functions
# ========================================

# Function to get compose file path for a framework (per-instance dir, filename uses framework_slug)
get_compose_file() {
    local framework="$1"
    local framework_slug
    framework_slug=$(get_framework_slug "$framework")
    echo "$INSTANCES_DIR/$framework/compose-${framework_slug}.yml"
}

# Function to check if compose file exists and generate if missing
# Regenerates if file is empty or too small (e.g. from a failed earlier generation)
check_compose_file() {
    local framework="$1"
    local compose_file
    compose_file="$(get_compose_file "$framework")"

    if [ ! -f "$compose_file" ] || [ ! -s "$compose_file" ]; then
        if [ -f "$compose_file" ]; then
            print_warning "Docker Compose file is empty or invalid: $compose_file"
        else
            print_warning "Docker Compose file not found: $compose_file"
        fi
        print_status "Generating docker-compose.yml..."

        if create_instance_compose "$framework"; then
            return 0
        else
            print_error "Failed to generate Docker Compose file"
            return 1
        fi
    fi
    return 0
}

# ========================================
# Compose File Generation Functions
# ========================================



# Function to create compose file for a single instance
# Usage: create_instance_compose <framework> [instance_mode]
# instance_mode: shared (default) = host network, shared DB; dedicated = own DB + network
create_instance_compose() {
    local framework="$1"
    local instance_mode="${2:-}"
    local framework_slug
    framework_slug=$(get_framework_slug "$framework")
    local instance_dir="$INSTANCES_DIR/$framework"
    local compose_file="$instance_dir/compose-${framework_slug}.yml"
    local env_file="$instance_dir/$framework.env"

    # Resolve instance mode from env file if not passed
    if [ -z "$instance_mode" ] && [ -f "$env_file" ]; then
        instance_mode=$(grep "^INSTANCE_MODE=" "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "shared")
    fi
    instance_mode="${instance_mode:-shared}"

    # Template directory: shared (default) or dedicated
    local templates_dir="$COMPOSE_TEMPLATES_BASE/$instance_mode"
    if [ ! -d "$templates_dir" ]; then
        print_warning "Compose template dir not found: $templates_dir, using shared"
        templates_dir="$COMPOSE_TEMPLATES_BASE/shared"
    fi

    print_status "Generating compose file for framework: $framework (mode: $instance_mode)"

    # Load database type from environment file
    local db_type="mariadb"  # default
    if [ -f "$env_file" ]; then
        db_type=$(grep "^DB_TYPE=" "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "mariadb")
    fi

    # Base ports and network configuration (BASE_PORT overridable via configs/instance/my.env)
    BASE_PORT="${BASE_PORT:-10000}"
    BASE_DB_PORT=3307
    BASE_POSTGRES_PORT=5433
    BASE_NETWORK_SUBNET=172.20

    # Get instance index and optional INSTANCE_PORT (from --port)
    local instance_index=0
    local framework_port=""
    if [ -f "$env_file" ]; then
        instance_index=$(grep "^FRAMEWORK_INDEX=" "$env_file" 2>/dev/null | cut -d'=' -f2 || echo "0")
        framework_port=$(grep "^INSTANCE_PORT=" "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || true)
    fi
    if [ -z "$framework_port" ]; then
        framework_port=$((BASE_PORT + instance_index))
    fi

    # Script alias from instance env (--script-alias)
    local script_alias_sed="/dev/"
    if [ -f "$env_file" ]; then
        local from_env
        from_env=$(grep "^ZNUNY_SCRIPT_ALIAS=" "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || true)
        [ -n "$from_env" ] && script_alias_sed="$from_env"
    fi
    [ -z "$script_alias_sed" ] && script_alias_sed="/dev/"

    # Calculate remaining ports and network
    local mariadb_port=$((BASE_DB_PORT + instance_index * 3))
    local mysql_port=$((BASE_DB_PORT + instance_index * 3 + 1))
    local postgresql_port=$((BASE_POSTGRES_PORT + instance_index))
    local network_subnet="$BASE_NETWORK_SUBNET.$((1 + instance_index)).0/24"

    # Ensure compose output directory exists (instance dir)
    mkdir -p "$(dirname "$compose_file")"

    # Create backup if file exists
    if [ -f "$compose_file" ]; then
        cp "$compose_file" "${compose_file}.backup"
        print_status "Backed up existing compose file"
    fi

    # Select the appropriate template based on database type
    local template_file=""
    case "$db_type" in
        mariadb)
            template_file="$templates_dir/compose-mariadb.yml"
            ;;
        mysql)
            template_file="$templates_dir/compose-mysql.yml"
            ;;
        postgresql)
            template_file="$templates_dir/compose-postgresql.yml"
            ;;
        *)
            print_error "Unsupported database type: $db_type"
            return 1
            ;;
    esac

    if [ ! -f "$template_file" ] || [ ! -s "$template_file" ]; then
        print_error "Compose template not found or empty: $template_file"
        return 1
    fi

    # Absolute path to docker configs (mysql/mariadb/postgresql scripts)
    local CONFIGS_DIR
    CONFIGS_DIR="$(cd "$DOCKER_DIR" && pwd)/configs"
    if [ ! -d "$CONFIGS_DIR" ]; then
        print_error "Configs directory not found: $CONFIGS_DIR"
        return 1
    fi

    # Absolute path to project configs/framework/ (Config.pm snippet; configs/instance/my.env is host-only)
    local FRAMEWORK_CONFIGS_DIR
    FRAMEWORK_CONFIGS_DIR="$(cd "$COMPOSE_SCRIPT_DIR/../../.." && pwd)/configs/framework"
    if [ ! -d "$FRAMEWORK_CONFIGS_DIR" ]; then
        mkdir -p "$FRAMEWORK_CONFIGS_DIR"
    fi

    # Absolute path to instances dir: derive from compose file path so logs always land next to this instance
    # (compose_file is in .../instances/<framework>/; parent = instances dir)
    local INSTANCES_DIR
    INSTANCES_DIR="$(cd "$(dirname "$compose_file")/.." && pwd)"

    # Ensure instance log directory exists on host (Apache + Znuny logs in one folder)
    mkdir -p "$INSTANCES_DIR/$framework/logs"

    # Docker identifiers use lowercase (FRAMEWORK_SLUG); paths and env file use actual name (FRAMEWORK_NAME)
    local framework_slug
    framework_slug=$(get_framework_slug "$framework")
    sed -e "s/\${FRAMEWORK_SLUG}/$framework_slug/g" \
        -e "s|{{FRAMEWORK_SLUG}}|$framework_slug|g" \
        -e "s/\${FRAMEWORK_NAME}/$framework/g" \
        -e "s|{{FRAMEWORK_NAME}}|$framework|g" \
        -e "s/\${FRAMEWORK_PORT}/$framework_port/g" \
        -e "s/\${MARIADB_PORT}/$mariadb_port/g" \
        -e "s/\${MYSQL_PORT}/$mysql_port/g" \
        -e "s/\${POSTGRESQL_PORT}/$postgresql_port/g" \
        -e "s|\${NETWORK_SUBNET}|$network_subnet|g" \
        -e "s|\${ZNUNY_SCRIPT_ALIAS}|$script_alias_sed|g" \
        -e "s|{{FRAMEWORKS_DIR}}|$FRAMEWORKS_DIR|g" \
        -e "s|{{PACKAGES_DIR}}|$PACKAGES_DIR|g" \
        -e "s|{{TOOLS_DIR}}|$TOOLS_DIR|g" \
        -e "s|{{CONFIGS_DIR}}|$CONFIGS_DIR|g" \
        -e "s|{{FRAMEWORK_CONFIGS_DIR}}|$FRAMEWORK_CONFIGS_DIR|g" \
        -e "s|{{INSTANCES_DIR}}|$INSTANCES_DIR|g" \
        "$template_file" > "$compose_file"

    print_success "Generated: $compose_file (mode: $instance_mode, $db_type)"

    echo ""
    print_subheader "Directory Configuration:"
    printf "  %-20s %s\n" "Framework:" " $framework (port: $framework_port)"
    printf "  %-20s %s\n" "Instance mode:" " $instance_mode"
    printf "  %-20s %s\n" "Database:" " $db_type"
    printf "  %-20s %s\n" "Network:" " $network_subnet"
    echo ""
}

# Function to generate all compose files
create_all_compose_files() {
    print_status "Generating separate Docker Compose files for all frameworks..."

    # Get available frameworks using instance.sh function
    local frameworks=()
    read_lines_to_array frameworks < <("$SCRIPTS_DIR/instance.sh" get_available_frameworks 2>/dev/null)

    if [ ${#frameworks[@]} -eq 0 ]; then
        print_warning "No frameworks found. Please run setup-framework first."
        return 1
    fi

    print_status "Found frameworks: ${frameworks[*]}"

    # Generate compose file for each framework
    for framework in "${frameworks[@]}"; do
        create_instance_compose "$framework"
    done

    # Generate main reverse proxy compose file
    create_reverse_proxy_compose "${frameworks[@]}"

    print_success "All Docker Compose files generated successfully!"
}

# Function to generate reverse proxy compose file
create_reverse_proxy_compose() {
    local frameworks=("$@")
    local compose_file="$COMPOSE_DIR/compose-reverse-proxy.yml"

    print_status "Generating reverse proxy compose file with multi-network setup..."

    # Start building the compose file
    cat > "$compose_file" << 'EOF'
# Znuny Reverse Proxy Docker Compose Configuration
# This file manages the reverse proxy for all framework instances

services:
  # Reverse Proxy (Apache) - Main entry point for all frameworks
  reverse-proxy:
    build:
      context: ../../..
      dockerfile: dev/docker/Dockerfile
    image: reverse-proxy
    container_name: reverse-proxy
    command: ["/usr/local/bin/startup-reverse-proxy.sh"]
    ports:
      - "80:80"
      - "443:443"
    volumes:
      # Apache configuration
      - ./configs:/etc/znuny/configs:ro
    environment:
      - APACHE_SERVER_NAME=localhost
      - APACHE_DOCUMENT_ROOT=/var/www/html
    networks:
      - znuny_reverse_proxy_network
EOF

    # Add all framework networks to the reverse proxy (Docker network names use lowercase framework_slug)
    for framework in "${frameworks[@]}"; do
        local framework_slug
        framework_slug=$(get_framework_slug "$framework")
        echo "      - znuny-${framework_slug}-network" >> "$compose_file"
    done

    # Continue with the rest of the configuration
    cat >> "$compose_file" << 'EOF'
    restart: unless-stopped

# Network configuration
networks:
  znuny_reverse_proxy_network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.21.0.0/16
EOF

    # Add external network references for all framework networks (framework_slug for Docker)
    for framework in "${frameworks[@]}"; do
        local framework_slug
        framework_slug=$(get_framework_slug "$framework")
        cat >> "$compose_file" << EOF
  znuny-${framework_slug}-network:
    external: true
EOF
    done

    print_success "Generated: $compose_file"
}

# ========================================
# Compose File Removal Functions
# ========================================

# Function to remove instance compose files (from instance dir)
remove_instance_compose() {
    local framework="$1"
    local compose_file
    compose_file="$(get_compose_file "$framework")"

    if [ -f "$compose_file" ]; then
        rm -f "$compose_file"
        print_status "Removed: $(basename "$compose_file")"
    fi
}

# Function to remove reverse proxy compose files
remove_reverse_proxy_compose() {
    local compose_file="$COMPOSE_DIR/compose-reverse-proxy.yml"

    if [ -f "$compose_file" ]; then
        rm -f "$compose_file"
        print_status "Removed: $(basename "$compose_file")"
    fi
}

# Function to remove all instance compose files (one per instance dir)
remove_all_compose() {
    print_status "Cleaning generated compose files..."

    local count=0
    for instance_dir in "$INSTANCES_DIR"/*/; do
        [ -d "$instance_dir" ] || continue
        local instance_name
        instance_name=$(basename "$instance_dir")
        local framework_slug
        framework_slug=$(get_framework_slug "$instance_name")
        local compose_file="$instance_dir/compose-${framework_slug}.yml"
        if [ -f "$compose_file" ]; then
            rm -f "$compose_file"
            print_status "Removed: $(basename "$compose_file")"
            count=$((count + 1))
        fi
    done

    if [ "$count" -eq 0 ]; then
        print_warning "No compose files found to clean"
    else
        print_success "All generated compose files removed"
    fi
}

# ========================================
# Docker Compose Execution
# ========================================

# Function to execute docker-compose commands (supports "docker compose" and "docker-compose")
docker_compose() {
    local framework="$1"
    local action="$2"
    shift 2  # Remove first two arguments

    local compose_file compose_dir compose_basename
    compose_file="$(get_compose_file "$framework")"
    local compose_cmd
    compose_cmd=$(get_compose_cmd 2>/dev/null) || compose_cmd="docker compose"

    if [ ! -f "$compose_file" ]; then
        print_error "Compose file not found: $compose_file"
        return 1
    fi

    compose_dir="$(dirname "$compose_file")"
    compose_basename="$(basename "$compose_file")"
    cd "$compose_dir"

    case "$action" in
        up)
            # --build: build image if missing (avoids "pull access denied" for local image names)
            $compose_cmd -p znuny -f "$compose_basename" up -d --build
            ;;
        down)
            $compose_cmd -p znuny -f "$compose_basename" down -v
            ;;
        restart)
            $compose_cmd -p znuny -f "$compose_basename" restart
            ;;
        build)
            # Usage: docker_compose framework build [--no-cache] [service_name]
            $compose_cmd -p znuny -f "$compose_basename" build "$@"
            ;;
        logs)
            # Pass all remaining arguments to logs command
            # Usage: docker_compose framework logs [--tail N] [-f] [service_name]
            $compose_cmd -p znuny -f "$compose_basename" logs "$@"
            ;;
        *)
            print_error "Unknown action: $action"
            return 1
            ;;
    esac
}
