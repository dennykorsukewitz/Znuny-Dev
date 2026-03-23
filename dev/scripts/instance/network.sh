#!/bin/bash

# Znuny Network & Port Management
# This script manages network configuration and port allocation for Znuny instances

set -e

# Load common functions
if [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
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
        local port=$(grep "^INSTANCE_PORT=" "$instance_env_file" | cut -d'=' -f2)
        if [ -n "$port" ]; then
            echo "$port"
            return 0
        fi
    fi
}

# Function to get external database port from compose (host-mapped port for tools like Beekeeper)
get_external_db_port() {
    local framework="$1"
    local compose_file
    compose_file="$(get_compose_file "$framework")"
    [ -n "$compose_file" ] || return 1
    [ -f "$compose_file" ] || return 1

    local db_type
    db_type=$(grep "^DB_TYPE=" "$INSTANCES_DIR/$framework/$framework.env" 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    case "$db_type" in
        mysql|mariadb)
            grep -oE '"[0-9]+:3306"' "$compose_file" | head -1 | tr -d '"' | cut -d: -f1
            ;;
        postgresql|postgres)
            grep -oE '"[0-9]+:5432"' "$compose_file" | head -1 | tr -d '"' | cut -d: -f1
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to get database connection URL for external tools (Beekeeper Studio, etc.)
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
        local port=$(grep "^DB_PORT=" "$instance_env_file" | cut -d'=' -f2)
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
        local network=$(grep "^NETWORK_SUBNET=" "$instance_env_file" | cut -d'=' -f2)
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
    local framework_slug=$(get_framework_slug "$framework")
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
            oracle)
                db_container_name="znuny-oracle"
                ;;
        esac
    else
        local framework_slug=$(get_framework_slug "$framework")
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
            oracle)
                db_container_name="znuny-${framework_slug}-oracle"
                ;;
        esac
    fi

    echo "$db_container_name"
}

# Function to create required Docker network for a framework (Docker names lowercase)
create_network() {
    local framework="$1"
    local framework_slug=$(get_framework_slug "$framework")
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
    local framework_slug=$(get_framework_slug "$framework")
    local network_name="znuny-${framework_slug}-network"

    # Check if network exists
    if docker network ls --format "{{.Name}}" | grep -q "^${network_name}$"; then
        print_status "Removing network: $network_name"
        docker network rm "$network_name" 2>/dev/null || true
    else
        print_status "Network does not exist: $network_name"
    fi
}

