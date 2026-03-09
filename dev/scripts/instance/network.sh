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

