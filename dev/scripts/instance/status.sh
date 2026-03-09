#!/bin/bash

# Znuny Instance Status Functions
# Status display for instances (sourced by instance.sh)

set -e

# ========================================
# Instance Status Functions
# ========================================

# Function to handle status command with argument parsing
show_status() {
    # Default values
    local verbose_mode=false
    local show_header=true
    local framework=""

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                verbose_mode=true
                shift
                ;;
            --no-header)
                show_header=false
                shift
                ;;
            *)
                if [ -z "$framework" ]; then
                    framework="$1"
                else
                    print_error "Unknown option: $1"
                    echo ""
                    echo "Usage:"
                    print_command "${ZD_CMD:-./znuny-dev.sh} status [framework] [--verbose|-v] [--no-header]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    # Show status for all or specific instance
    if [ -z "$framework" ] || [ "$framework" = "all" ]; then
        show_all_instance_status "$verbose_mode" "$show_header"
    else
        show_instance_status "$framework" "$verbose_mode" "$show_header"
    fi
}

# Function to show instance status
show_instance_status() {
    local framework="$1"
    local verbose_mode="${2:-false}"
    local show_header="${3:-true}"
    local container_name=$(get_instance_container_name "$framework")
    local port=$(get_instance_port "$framework")
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"

    # Check if environment file exists first
    if [ ! -f "$instance_env_file" ]; then
        print_error "Framework '$framework' not found"
        print_status "Environment file not found: $instance_env_file"

        echo ""
        show_all_frameworks
        return 1
    fi

    # Show header if requested
    if [[ "$show_header" == "true" ]]; then
        print_header "Instance Status: $framework"
        print_header "=========================="
        echo ""
    fi

    # Check container status first to determine the icon
    local instance_icon="🟡"
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$container_name"; then
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health-check")
        if [[ "$health_status" == "healthy" ]]; then
            instance_icon="✅"
        elif [[ "$health_status" == "unhealthy" ]]; then
            instance_icon="⚠️"
        else
            instance_icon="✅"
        fi
    fi

    print "   $instance_icon $framework $port"
    print "      🚦 Status:"

    # Check container status
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$container_name"; then
        local status=$(docker ps --format "{{.Status}}" --filter "name=$container_name")
        # Check if container is healthy
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health-check")
        if [[ "$health_status" == "healthy" ]]; then
            printf "         %-20s %s\n" "🐳 Instance:" "🟢 $container_name ($status)"
        elif [[ "$health_status" == "unhealthy" ]]; then
            printf "         %-20s %s\n" "🐳 Instance:" "🔴 $container_name ($status)"
        else
            printf "         %-20s %s\n" "🐳 Instance:" "🟢 $container_name ($status)"
        fi
    else
        printf "         %-20s %s\n" "🐳 Instance:" "🟡 $container_name not running"
    fi

    # Check database container status with health check (right after instance status)
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
    if [ -f "$instance_env_file" ]; then
        local db_type=$(grep "^DB_TYPE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
        local instance_mode=$(grep "^INSTANCE_MODE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "shared")
        instance_mode="${instance_mode:-shared}"

        # Get database container name (shared: znuny-mariadb etc., dedicated: znuny-dev-mariadb etc.)
        local db_container_name=$(get_database_container_name "$framework" "$db_type" "$instance_mode")

        if [ -n "$db_container_name" ]; then
            if docker ps --format "{{.Names}}" | grep -q "^${db_container_name}$"; then
                local db_status=$(docker ps --format "{{.Status}}" --filter "name=$db_container_name")
                local db_health_status=$(docker inspect --format='{{.State.Health.Status}}' "$db_container_name" 2>/dev/null || echo "no-health-check")

                if [[ "$db_health_status" == "healthy" ]]; then
                    printf "         %-20s %s\n" "🐳 DB:" "🟢 $db_container_name ($db_status)"
                elif [[ "$db_health_status" == "unhealthy" ]]; then
                    printf "         %-20s %s\n" "🐳 DB:" "🔴 $db_container_name ($db_status)"
                else
                    printf "         %-20s %s\n" "🐳 DB:" "🟢 $db_container_name ($db_status)"
                fi
            else
                printf "         %-20s %s\n" "🐳 DB:" "🟡 $db_container_name not running"
            fi
        fi
    fi

    # Load instance configuration (file exists, checked above)
    local db_type=$(grep "^DB_TYPE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    local http_port=$(grep "^INSTANCE_PORT=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    local db_port=$(grep "^DB_PORT=" "$instance_env_file" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    local framework_name=$(grep "^FRAMEWORK_NAME=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")

    print "      ⚙️  Configuration:"
    printf "         %-20s %s\n" "📁 Framework:" "$framework_name"
    printf "         %-20s %s\n" "🌐 Web Interface:" "http://localhost:$http_port"
    printf "         %-20s %s\n" "🔌 HTTP Port:" "$http_port"
    printf "         %-24s %s\n" "🗄️  Database:" "$db_type (Port: $db_port)"
    printf "         %-20s %s\n" "🔅 Instance mode:" "$instance_mode"
    printf "         %-20s %s\n" "📁 Directory:" "$INSTANCES_DIR/$framework"

    # Show additional verbose information if requested
    if [[ "$verbose_mode" == "true" ]] && check_command docker && docker info >/dev/null 2>&1; then
        # Get containers for this instance (Docker names use lowercase framework_slug)
        local framework_slug=$(get_framework_slug "$framework")
        local instance_containers=$(docker ps -a --format "{{.Names}}|{{.Status}}|{{.Ports}}" | grep -E "znuny-${framework_slug}-|${framework_slug}-" 2>/dev/null || true)
        if [ -n "$instance_containers" ]; then
            print "      📦 Containers:"
            echo "$instance_containers" | while IFS='|' read -r container_name container_status container_ports; do
                if [[ "$container_status" == *"Up"* ]]; then
                    # Check if container is healthy
                    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health-check")
                    if [[ "$health_status" == "healthy" ]]; then
                        print "         ✅ $container_name ($container_status) 🟢"
                    elif [[ "$health_status" == "unhealthy" ]]; then
                        print "         ⚠️  $container_name ($container_status) 🔴"
                    else
                        print "         ✅ $container_name ($container_status)"
                    fi

                    # Show container start time
                    local start_time=$(docker inspect --format='{{.State.StartedAt}}' "$container_name" 2>/dev/null | cut -d'T' -f1,2 | sed 's/T/ /' | cut -d'.' -f1 || echo "unknown")
                    print "            🕐 Started: $start_time"

                    # Show memory usage if available
                    local memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "$container_name" 2>/dev/null || echo "unknown")
                    if [[ "$memory_usage" != "unknown" ]]; then
                        print "            💾 Memory: $memory_usage"
                    fi
                else
                    print "         🟡  $container_name ($container_status)"
                fi
            done
        else
            print "      📦 No containers found for this instance"
        fi

        # Get volumes for this instance (Docker volume names use lowercase framework_slug)
        local instance_volumes=$(docker volume ls --format "{{.Name}}" | grep -E "znuny_${framework_slug}-|${framework_slug}-|znuny-${framework_slug}-" 2>/dev/null || true)
        if [ -n "$instance_volumes" ]; then
            print "      💾 Volumes:"
            echo "$instance_volumes" | while read -r volume_name; do
                # Get volume size (this might not work on all systems)
                local volume_size=$(docker system df -v 2>/dev/null | grep "$volume_name" | awk '{print $3}' || echo "unknown")
                if [[ "$volume_size" != "unknown" ]]; then
                    print "         📁 $volume_name ($volume_size)"
                else
                    print "         📁 $volume_name"
                fi
            done
        else
            print "      💾 No volumes found for this instance"
        fi

        # Show network info (Docker network names use lowercase framework_slug)
        local framework_slug=$(get_framework_slug "$framework")
        local instance_networks=$(docker network ls --format "{{.Name}}" | grep -E "znuny-${framework_slug}-|${framework_slug}-" 2>/dev/null || true)
        if [ -n "$instance_networks" ]; then
            print "      🌐 Networks:"
            echo "$instance_networks" | while read -r network_name; do
                print "         🔗 $network_name"
            done
        fi
    fi
}

# Function to show all instance status
show_all_instance_status() {
    local verbose_mode="${1:-false}"
    local show_header="${2:-true}"

    if [[ "$show_header" == "true" ]]; then
        print_header "Instance Status for All Frameworks"
        print_header "=================================="
        echo ""
    fi

    # Check instances (subdirs with NAME/NAME.env)
    if [ -d "$INSTANCES_DIR" ]; then
        local instances=($(get_available_instances))
        if [ ${#instances[@]} -eq 0 ]; then
            print "   ❌ No instances found"
            echo ""
        else
            for instance in "${instances[@]}"; do
                show_instance_status "$instance" "$verbose_mode" "$show_header"
                echo ""
            done
        fi
    else
        print_warning "Instances directory not found: $INSTANCES_DIR"
        echo ""
        return 1
    fi
}
