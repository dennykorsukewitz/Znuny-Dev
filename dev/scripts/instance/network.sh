#!/bin/bash

# Znuny Network & Port Management
# This script manages network configuration and port allocation for Znuny instances

set -e

# Load common functions (common.sh lives in dev/scripts/, not in instance/)
if [ -f "$(dirname "$0")/../common.sh" ]; then
    # shellcheck source=../common.sh
    source "$(dirname "$0")/../common.sh"
fi

# Load environment
load_environment

# ========================================
# Port Management Functions
# ========================================

# Function to get instance port for a framework
get_instance_port() {
    local framework="$1"
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"

    # Try to get port from instance .env file first
    if [ -f "$instance_env_file" ]; then
        local port
        port=$(grep "^INSTANCE_PORT=" "$instance_env_file" | cut -d'=' -f2)
        if [ -n "$port" ]; then
            echo "$port"
            return 0
        fi
    fi
}

# Function to get external database port from compose (host-mapped port for tools like DBeaver).
# Falls back to docker port when compose is missing or port lines use a different format.
get_external_db_port() {
    local framework="$1"
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
    local compose_file=""
    local db_type
    local port=""
    local internal_port=3306

    [ -f "$instance_env_file" ] || {
        echo ""
        return 0
    }

    db_type=$(grep "^DB_TYPE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    case "$db_type" in
        mysql|mariadb)
            internal_port=3306
            ;;
        postgresql|postgres)
            internal_port=5432
            ;;
        *)
            echo ""
            return 0
            ;;
    esac

    if command -v get_compose_file >/dev/null 2>&1; then
        compose_file="$(get_compose_file "$framework")"
    fi

    if [ -n "$compose_file" ] && [ -f "$compose_file" ]; then
        case "$db_type" in
            mysql|mariadb)
                port=$(grep -oE '"[0-9]+:3306"' "$compose_file" | head -1 | tr -d '"' | cut -d: -f1)
                [ -z "$port" ] && port=$(grep -oE "'[0-9]+:3306'" "$compose_file" | head -1 | tr -d "'" | cut -d: -f1)
                [ -z "$port" ] && port=$(grep -oE '[0-9]+:3306' "$compose_file" | head -1 | cut -d: -f1)
                ;;
            postgresql|postgres)
                port=$(grep -oE '"[0-9]+:5432"' "$compose_file" | head -1 | tr -d '"' | cut -d: -f1)
                [ -z "$port" ] && port=$(grep -oE "'[0-9]+:5432'" "$compose_file" | head -1 | tr -d "'" | cut -d: -f1)
                [ -z "$port" ] && port=$(grep -oE '[0-9]+:5432' "$compose_file" | head -1 | cut -d: -f1)
                ;;
        esac
    fi

    if [ -z "$port" ]; then
        local instance_mode
        instance_mode=$(grep "^INSTANCE_MODE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "shared")
        instance_mode="${instance_mode:-shared}"
        local cname
        cname=$(get_database_container_name "$framework" "$db_type" "$instance_mode")
        if [ -n "$cname" ] && docker inspect "$cname" >/dev/null 2>&1; then
            port=$(docker port "$cname" "${internal_port}/tcp" 2>/dev/null | head -1 | grep -oE '[0-9]+$' || true)
        fi
    fi

    printf '%s' "${port:-}"
    return 0
}

# Function to get database connection URL for external tools
get_db_connection_url() {
    local framework="$1"
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
    [ -f "$instance_env_file" ] || return 1

    local db_type db_user db_password db_name external_port scheme
    db_type=$(grep "^DB_TYPE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    db_user=$(grep "^DB_USER=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    db_password=$(grep "^DB_PASSWORD=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    db_name=$(grep "^DB_NAME=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    external_port=$(get_external_db_port "$framework")

    [ -n "$db_type" ] || return 1
    [ -n "$external_port" ] || return 1

    case "$db_type" in
        mysql|mariadb)
            scheme="mysql"
            ;;
        postgresql|postgres)
            scheme="postgres"
            ;;
        *)
            echo ""
            return 1
            ;;
    esac

    echo "${scheme}://${db_user}:${db_password}@127.0.0.1:${external_port}/${db_name}"
}

# Function to get database port for a framework
get_database_port() {
    local framework="$1"
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"

    # Try to get port from instance .env file first
    if [ -f "$instance_env_file" ]; then
        local port
        port=$(grep "^DB_PORT=" "$instance_env_file" | cut -d'=' -f2)
        if [ -n "$port" ]; then
            echo "$port"
            return 0
        fi
    fi

    # Fallback: no database port configured
    echo ""
}

# ========================================
# Network Management Functions
# ========================================

# Function to get network subnet for a framework
get_network_subnet() {
    local framework="$1"
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"

    # Try to get network from instance .env file first
    if [ -f "$instance_env_file" ]; then
        local network
        network=$(grep "^NETWORK_SUBNET=" "$instance_env_file" | cut -d'=' -f2)
        if [ -n "$network" ]; then
            echo "$network"
            return 0
        fi
    fi
}

# ========================================
# Container Name Functions
# ========================================

# Function to get container name for framework (Docker requires lowercase)
get_instance_container_name() {
    local framework="$1"
    local framework_slug
    framework_slug=$(get_framework_slug "$framework")
    echo "znuny-${framework_slug}-instance"
}

# Function to get database container name for a framework
# For shared mode: znuny-mariadb, znuny-mysql, znuny-postgresql (one per type).
# For dedicated mode: znuny-${framework}-mariadb etc.
get_database_container_name() {
    local framework="$1"
    local db_type="$2"
    local instance_mode="${3:-dedicated}"
    local db_container_name=""

    if [ "$instance_mode" = "shared" ]; then
        case "$db_type" in
            mysql)
                db_container_name="znuny-mysql"
                ;;
            mariadb)
                db_container_name="znuny-mariadb"
                ;;
            postgresql|postgres)
                db_container_name="znuny-postgresql"
                ;;
        esac
    else
        local framework_slug
        framework_slug=$(get_framework_slug "$framework")
        case "$db_type" in
            mysql)
                db_container_name="znuny-${framework_slug}-mysql"
                ;;
            mariadb)
                db_container_name="znuny-${framework_slug}-mariadb"
                ;;
            postgresql|postgres)
                db_container_name="znuny-${framework_slug}-postgresql"
                ;;
        esac
    fi

    echo "$db_container_name"
}

# Function to create required Docker network for a framework (Docker names lowercase)
create_network() {
    local framework="$1"
    local framework_slug
    framework_slug=$(get_framework_slug "$framework")
    local network_name="znuny-${framework_slug}-network"

    # Check if network exists, create if not
    if ! docker network ls --format "{{.Name}}" | grep -q "^${network_name}$"; then
        print_status "Creating network: $network_name"
        docker network create "$network_name" 2>/dev/null || true
    fi
}

# Function to remove Docker network for a framework (Docker names lowercase)
remove_network() {
    local framework="$1"
    local framework_slug
    framework_slug=$(get_framework_slug "$framework")
    local network_name="znuny-${framework_slug}-network"

    # Check if network exists
    if docker network ls --format "{{.Name}}" | grep -q "^${network_name}$"; then
        print_status "Removing network: $network_name"
        docker network rm "$network_name" 2>/dev/null || true
    else
        print_status "Network does not exist: $network_name"
    fi
}

