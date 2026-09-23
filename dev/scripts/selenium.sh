#!/bin/bash

# Shared Selenium Chrome (WebDriver) for Znuny browser unit tests.

set -e

show_usage_selenium() {
    print_header "znuny-dev selenium"
    echo ""
    print_status "Shared Chrome on znuny-network, hostname selenium:4444"
    print_status "noVNC: http://127.0.0.1:7900/ (password: secret)"
    echo ""
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium start    # Start shared Chrome"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium stop     # Stop container"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium restart  # Restart container"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium status   # Show container state"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium remove   # Stop and remove container"
    echo ""
    print_status "Instance opt-in: ENABLE_SELENIUM=y in instances/<name>/<name>.env, then recreate the instance."
    print_status "Startup then writes SeleniumTestsConfig and TestHTTPHostname into Kernel/Config.pm."
    print_status "Dedicated instances are not on znuny-network; this hub only reaches shared instances."
    echo ""
}

get_selenium_compose_file() {
    echo "${ZNUNY_DEV_DIR:?}/dev/docker/compose-selenium.yml"
}

# Run docker compose for Selenium from the compose file directory (relative paths).
compose_selenium() {
    local compose_file
    compose_file=$(get_selenium_compose_file)
    local compose_dir
    compose_dir=$(dirname "$compose_file")
    local dc
    dc=$(get_compose_cmd 2>/dev/null) || dc="docker compose"
    (
        cd "$compose_dir" && $dc -f "$(basename "$compose_file")" -p znuny "$@"
    )
}

selenium() {
    local action="${1:-}"
    shift || true

    case "$action" in
    "")
        show_usage_selenium
        ;;
    start)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Starting Selenium container..."
        compose_selenium up -d
        print_success "Selenium: http://selenium:4444/wd/hub (noVNC http://127.0.0.1:7900/)"
        ;;
    stop)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Stopping Selenium container..."
        compose_selenium stop
        print_success "Selenium stopped."
        ;;
    restart)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Restarting Selenium container..."
        if docker ps -a --format '{{.Names}}' | grep -qx 'znuny-selenium'; then
            compose_selenium restart
        else
            compose_selenium up -d
        fi
        print_success "Selenium: http://selenium:4444/wd/hub (noVNC http://127.0.0.1:7900/)"
        ;;
    remove)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Removing Selenium container..."
        # Stop and delete only this container. Do not `compose down` the shared
        # znuny-network while instance containers are still attached.
        compose_selenium stop || true
        docker rm -f znuny-selenium 2>/dev/null || true
        print_success "Selenium removed. Run: ${ZD_CMD:-./znuny-dev.sh} selenium start"
        ;;
    status)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^znuny-selenium$'; then
            print_success "Selenium container is running (hostname selenium:4444, noVNC http://127.0.0.1:7900/)"
        else
            print_status "Selenium container is not running. Use: ${ZD_CMD:-./znuny-dev.sh} selenium start"
        fi
        ;;
    *)
        print_error "Unknown selenium action: $action"
        show_usage_selenium
        return 1
        ;;
    esac
}
