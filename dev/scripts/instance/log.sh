#!/bin/bash

# Znuny Instance Log Functions
# Log display for container logs and framework logs (sourced by instance.sh)

set -e

# ========================================
# Logs Functions
# ========================================

# Function to show Docker logs for a specific framework container
# Shows stdout/stderr from Docker (docker-compose logs)
show_container_log() {
    local framework="$1"
    local lines="${2:-50}"

    # Validate framework parameter
    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo "Available frameworks:"
        local available_frameworks=($(get_available_frameworks))
        print_list "${available_frameworks[@]}"
        echo ""
        echo "Usage:"
        print_command "${ZD_CMD:-./znuny-dev.sh} container-log <framework> [lines]"
        return 1
    fi

    print_subheader "Showing Docker container logs for: $framework (last $lines lines)"

    local service_name=$(get_instance_container_name "$framework")

    # Use centralized docker_compose function for Docker stdout/stderr
    docker_compose "$framework" logs --tail="$lines" -f "$service_name"
}

# Function to show Docker logs for all containers
# Shows stdout/stderr from Docker across all containers or specific service
show_all_container_log() {
    local service="${1:-}"

    if [ -n "$service" ]; then
        print_header "Showing Docker container logs for service: $service"
    else
        print_header "Showing Docker container logs for all services"
    fi

    local compose_cmd
    compose_cmd=$(get_compose_cmd 2>/dev/null) || compose_cmd="docker compose"

    if [ -d "$COMPOSE_DIR" ] && [ -f "$COMPOSE_DIR/compose-reverse-proxy.yml" ]; then
        cd "$COMPOSE_DIR" && $compose_cmd -p znuny logs -f $service
        return $?
    fi

    # No central reverse-proxy compose: show last N lines from each znuny container
    local containers
    containers=$(docker ps -a --format "{{.Names}}" | grep -E "^znuny-" || true)
    if [ -z "$containers" ]; then
        print_status "No znuny containers running. Start an instance with: ${ZD_CMD:-./znuny-dev.sh} instance-start <framework>"
        return 0
    fi
    local lines="${service:-50}"
    print_status "Showing last $lines lines per container. Use: ${ZD_CMD:-./znuny-dev.sh} container-log <framework> [lines] for one instance with -f"
    echo "$containers" | while read -r name; do
        [ -z "$name" ] && continue
        print_subheader "$name"
        docker logs --tail="$lines" "$name" 2>&1
        echo ""
    done
}

# Function to show framework log from instance volume (instances/<framework>/logs/)
# log_file: filename (e.g. access.log, error.log, STDERR.log) or path under instances/<framework>/logs/
show_framework_log() {
    local framework="$1"
    local log_file="${2:-access.log}"

    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo "Available frameworks:"
        local available_frameworks=($(get_available_frameworks))
        print_list "${available_frameworks[@]}"
        echo ""
        echo "Usage:"
        print_command "${ZD_CMD:-./znuny-dev.sh} log <framework> [log_file]" "access.log|error.log|STDERR.log|znuny.log (default: error.log)"
        print_status "  "
        return 1
    fi

    local logs_dir="$INSTANCES_DIR/$framework/logs"
    local path_to_log
    if [[ "$log_file" == /* ]] && [ -f "$log_file" ]; then
        path_to_log="$log_file"
    else
        path_to_log="$logs_dir/$log_file"
    fi

    print_subheader "Showing framework log: $framework"
    print_status "Log file: $path_to_log"

    if [ -f "$path_to_log" ]; then
        tail -f "$path_to_log"
    else
        print_error "Log file not found: $path_to_log"
        if [ -d "$logs_dir" ]; then
            print_status "Available logs in $logs_dir:"
            ls -lh "$logs_dir" 2>/dev/null || true
        else
            print_status "Logs directory does not exist: $logs_dir"
        fi
        return 1
    fi
}
