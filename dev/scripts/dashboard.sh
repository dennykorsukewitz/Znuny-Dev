#!/bin/bash

# znuny-dev local dashboard (Docker Compose on 127.0.0.1)

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
    stop_opener
}

opener_pidfile() {
    echo "${ZNUNY_DEV_DIR:?}/.opener.pid"
}

stop_opener() {
    local pidfile
    pidfile=$(opener_pidfile)
    if [ -f "$pidfile" ]; then
        local pid
        pid=$(cat "$pidfile" 2>/dev/null || true)
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$pidfile"
    fi
    if [ -n "${ZNUNY_DEV_DIR:-}" ]; then
        pkill -f "${ZNUNY_DEV_DIR}/dev/dashboard/host-opener.mjs" 2>/dev/null || true
    fi
}

opener_health_ok() {
    local port="${1:-9998}"
    if ! check_command curl; then
        return 1
    fi
    curl -sf "http://127.0.0.1:${port}/config" >/dev/null 2>&1
}

start_opener() {
    if [ -f /.dockerenv ]; then
        return 0
    fi
    if ! check_command node; then
        print_warning "node not found — workspace links need opener (install Node.js)"
        return 0
    fi
    local pidfile
    pidfile=$(opener_pidfile)
    rm -f "${ZNUNY_DEV_DIR:?}/.host-opener.pid"
    local port="${OPENER_PORT:-9998}"

    if [ -f "$pidfile" ]; then
        local pid
        pid=$(cat "$pidfile" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && opener_health_ok "$port"; then
            return 0
        fi
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f "$pidfile"
    fi

    if [ -n "${ZNUNY_DEV_DIR:-}" ]; then
        pkill -f "${ZNUNY_DEV_DIR}/dev/dashboard/host-opener.mjs" 2>/dev/null || true
    fi

    if opener_health_ok "$port"; then
        print_warning "Opener port ${port} in use; restarting stale process..."
        if check_command lsof; then
            lsof -ti "tcp:${port}" -sTCP:LISTEN 2>/dev/null | while read -r stale_pid; do
                [ -n "$stale_pid" ] && kill "$stale_pid" 2>/dev/null || true
            done
        fi
        sleep 1
    fi

    export ZNUNY_DEV_DIR OPENER_PORT="$port"
    nohup node "$ZNUNY_DEV_DIR/dev/dashboard/opener.mjs" >/dev/null 2>&1 &
    echo $! >"$pidfile"
    sleep 0.3
    if opener_health_ok "$port"; then
        print_status "Opener: 127.0.0.1:${port}"
    else
        print_warning "Opener failed to start on 127.0.0.1:${port} (IDE / Folder buttons need it)"
    fi
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
        start_opener
        print_success "Dashboard: http://127.0.0.1:${DASHBOARD_PORT:-9999}/"
        ;;
    stop)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Stopping dashboard container..."
        compose_dashboard down
        stop_opener
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
        stop_opener
        start_opener
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
