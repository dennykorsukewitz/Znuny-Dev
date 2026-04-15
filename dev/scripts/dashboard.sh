#!/bin/bash

# znuny-dev local dashboard (Docker Compose on 127.0.0.1, experimental)

set -e

show_usage_dashboard() {
    print_header "znuny-dev dashboard"
    echo ""
    print_status "http://127.0.0.1:${DASHBOARD_PORT:-9999}/"
    echo ""
    print_command "${ZD_CMD:-./znuny-dev.sh} dashboard start   # Build and start container"
    print_command "${ZD_CMD:-./znuny-dev.sh} dashboard stop    # Stop container"
    print_command "${ZD_CMD:-./znuny-dev.sh} dashboard remove # Stop and remove stack (fixes stuck container_name)"
    print_command "${ZD_CMD:-./znuny-dev.sh} dashboard build [--no-cache]  # Rebuild image (Dockerfile / base packages only; UI is from repo mount)"
    print_command "${ZD_CMD:-./znuny-dev.sh} dashboard restart # Restart running container"
    print_command "${ZD_CMD:-./znuny-dev.sh} dashboard status # Show container state"
    echo ""
}

get_dashboard_compose_file() {
    echo "${ZNUNY_DEV_DIR:?}/dev/docker/compose-dashboard.yml"
}

# Run docker compose for the dashboard from the compose file directory (relative paths).
compose_dashboard() {
    local compose_file
    compose_file=$(get_dashboard_compose_file)
    local compose_dir
    compose_dir=$(dirname "$compose_file")
    local dc
    dc=$(get_compose_cmd 2>/dev/null) || dc="docker compose"
    (
        cd "$compose_dir" && $dc -f "$(basename "$compose_file")" -p znuny "$@"
    )
}

# Stop dashboard stack and remove fixed-name containers (e.g. leftover after project rename or failed start).
remove_dashboard() {
    compose_dashboard down
    docker rm -f znuny-dashboard znuny-dev-dashboard 2>/dev/null || true
}

ensure_dashboard_started() {
    if ! check_command docker; then
        return 0
    fi
    if ! docker info >/dev/null 2>&1; then
        return 0
    fi
    local compose_file
    compose_file=$(get_dashboard_compose_file)
    if [ ! -f "$compose_file" ]; then
        return 0
    fi
    compose_dashboard up -d --build 2>/dev/null || true
}

dashboard() {
    local action="${1:-}"
    shift || true

    case "$action" in
    "")
        show_usage_dashboard
        ;;
    start)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Starting dashboard container..."
        compose_dashboard up -d --build
        print_success "Dashboard: http://127.0.0.1:${DASHBOARD_PORT:-9999}/"
        ;;
    stop)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Stopping dashboard container..."
        compose_dashboard down
        print_success "Dashboard stopped."
        ;;
    remove)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Removing dashboard stack..."
        remove_dashboard
        print_success "Dashboard removed. Run: ${ZD_CMD:-./znuny-dev.sh} dashboard start"
        ;;
    build)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Building dashboard image..."
        compose_dashboard build "$@"
        print_success "Image built. Run: ${ZD_CMD:-./znuny-dev.sh} dashboard start"
        ;;
    restart)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Restarting dashboard container..."
        compose_dashboard restart
        print_success "Dashboard: http://127.0.0.1:${DASHBOARD_PORT:-9999}/"
        ;;
    status)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^znuny-dashboard$'; then
            print_success "Dashboard container is running: http://127.0.0.1:${DASHBOARD_PORT:-9999}/"
        else
            print_status "Dashboard container is not running. Use: ${ZD_CMD:-./znuny-dev.sh} dashboard start"
        fi
        ;;
    *)
        print_error "Unknown dashboard action: $action"
        show_usage_dashboard
        return 1
        ;;
    esac
}
