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
    if [ -z "${HOST_UID:-}" ] || [ "${HOST_UID}" = "0" ]; then
        if [ "$(id -u)" != "0" ]; then
            HOST_UID="$(id -u)"
            HOST_GID="$(id -g)"
        fi
    fi
    export HOST_UID HOST_GID
    (
        cd "$compose_dir" && $dc -f "$(basename "$compose_file")" -p znuny "$@"
    )
}

# Stop dashboard stack and remove fixed-name containers (e.g. leftover after project rename or failed start).
remove_dashboard() {
    compose_dashboard down
    docker rm -f znuny-dashboard znuny-dev-dashboard 2>/dev/null || true
    stop_opener
    uninstall_host_restart_agent
}

supervisor_pidfile() {
    echo "${ZNUNY_DEV_DIR:?}/.supervisor.pid"
}

opener_pidfile() {
    echo "${ZNUNY_DEV_DIR:?}/.opener.pid"
}

kill_pidfile() {
    local pidfile="$1"
    if [ ! -f "$pidfile" ]; then
        return 0
    fi
    local pid
    pid=$(cat "$pidfile" 2>/dev/null || true)
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pidfile"
}

stop_opener() {
    kill_pidfile "$(supervisor_pidfile)"
    kill_pidfile "$(opener_pidfile)"
    rm -f "${ZNUNY_DEV_DIR:?}/.opener-wake" 2>/dev/null || true
    if [ -n "${ZNUNY_DEV_DIR:-}" ]; then
        pkill -f "${ZNUNY_DEV_DIR}/dev/dashboard/supervisor.mjs" 2>/dev/null || true
        pkill -f "${ZNUNY_DEV_DIR}/dev/dashboard/opener.mjs" 2>/dev/null || true
        # Legacy filename from older builds
        pkill -f "${ZNUNY_DEV_DIR}/dev/dashboard/host-opener.mjs" 2>/dev/null || true
    fi
}

host_restart_label() {
    echo "com.znuny-dev.dashboard-host-restart"
}

# Keep a host process that can run `zd dashboard restart` for the GUI button.
# The dashboard container cannot cold-start Finder / IDE on the host.
install_host_restart_agent() {
    if [ -f /.dockerenv ] || [ -n "${ZNUNY_HOST_RESTART_AGENT:-}" ]; then
        return 0
    fi
    if ! check_command node; then
        return 0
    fi
    local node_bin
    node_bin=$(command -v node)
    case "$(uname -s)" in
        Darwin)
            install_host_restart_agent_macos "$node_bin"
            ;;
        Linux)
            install_host_restart_agent_linux "$node_bin"
            ;;
    esac
}

host_restart_path_env() {
    local node_bin="$1"
    local docker_bin path_env
    docker_bin=$(command -v docker 2>/dev/null || true)
    path_env="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    if [ -n "$docker_bin" ]; then
        path_env="$(dirname "$docker_bin"):${path_env}"
    fi
    path_env="$(dirname "$node_bin"):${path_env}"
    echo "$path_env"
}

install_host_restart_agent_macos() {
    local node_bin="$1"
    local label plist uid path_env
    label=$(host_restart_label)
    uid=$(id -u)
    plist="${HOME}/Library/LaunchAgents/${label}.plist"
    path_env=$(host_restart_path_env "$node_bin")
    mkdir -p "${HOME}/Library/LaunchAgents"
    cat >"$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${node_bin}</string>
    <string>${ZNUNY_DEV_DIR}/dev/dashboard/host-restart-agent.mjs</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${ZNUNY_DEV_DIR}</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>ZNUNY_DEV_DIR</key>
    <string>${ZNUNY_DEV_DIR}</string>
    <key>PATH</key>
    <string>${path_env}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF
    launchctl bootout "gui/${uid}/${label}" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/${uid}" "$plist"
    launchctl enable "gui/${uid}/${label}" >/dev/null 2>&1 || true
}

install_host_restart_agent_linux() {
    local node_bin="$1"
    local unit_dir unit path_env
    unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    unit="${unit_dir}/znuny-dev-dashboard-host-restart.service"
    path_env=$(host_restart_path_env "$node_bin")
    mkdir -p "$unit_dir"
    cat >"$unit" <<EOF
[Unit]
Description=Znuny-Dev dashboard host restart helper

[Service]
ExecStart=${node_bin} ${ZNUNY_DEV_DIR}/dev/dashboard/host-restart-agent.mjs
WorkingDirectory=${ZNUNY_DEV_DIR}
Environment=ZNUNY_DEV_DIR=${ZNUNY_DEV_DIR}
Environment=PATH=${path_env}
Restart=always

[Install]
WantedBy=default.target
EOF
    if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
        systemctl --user daemon-reload
        systemctl --user enable --now znuny-dev-dashboard-host-restart.service
        return 0
    fi
    local pidfile="${ZNUNY_DEV_DIR}/.host-restart-agent.pid"
    local pid=""
    if [ -f "$pidfile" ]; then
        pid=$(cat "$pidfile" 2>/dev/null || true)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    local agent_script="${ZNUNY_DEV_DIR}/dev/dashboard/host-restart-agent.mjs"
    local log_file="${ZNUNY_DEV_DIR}/.dashboard-host-restart.log"
    PATH="$path_env" ZNUNY_DEV_DIR="$ZNUNY_DEV_DIR" nohup "$node_bin" "$agent_script" >>"$log_file" 2>&1 &
    echo $! >"$pidfile"
}

uninstall_host_restart_agent() {
    if [ -f /.dockerenv ]; then
        return 0
    fi
    case "$(uname -s)" in
        Darwin)
            local label uid
            label=$(host_restart_label)
            uid=$(id -u)
            launchctl bootout "gui/${uid}/${label}" >/dev/null 2>&1 || true
            ;;
        Linux)
            if command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
                systemctl --user disable --now znuny-dev-dashboard-host-restart.service >/dev/null 2>&1 || true
            fi
            local pidfile="${ZNUNY_DEV_DIR}/.host-restart-agent.pid"
            if [ -f "$pidfile" ]; then
                local pid
                pid=$(cat "$pidfile" 2>/dev/null || true)
                if [ -n "$pid" ]; then
                    kill "$pid" 2>/dev/null || true
                fi
                rm -f "$pidfile"
            fi
            ;;
    esac
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
    install_host_restart_agent
    if ! check_command node; then
        print_warning "node not found — workspace links need opener (install Node.js)"
        return 0
    fi
    local pidfile
    pidfile=$(supervisor_pidfile)
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
        pkill -f "${ZNUNY_DEV_DIR}/dev/dashboard/supervisor.mjs" 2>/dev/null || true
        pkill -f "${ZNUNY_DEV_DIR}/dev/dashboard/opener.mjs" 2>/dev/null || true
        pkill -f "${ZNUNY_DEV_DIR}/dev/dashboard/host-opener.mjs" 2>/dev/null || true
    fi
    kill_pidfile "$(opener_pidfile)"

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
    nohup node "$ZNUNY_DEV_DIR/dev/dashboard/supervisor.mjs" >/dev/null 2>&1 &
    echo $! >"$pidfile"
    sleep 0.5
    if opener_health_ok "$port"; then
        print_status "Opener (supervised): 127.0.0.1:${port}"
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
        uninstall_host_restart_agent
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
