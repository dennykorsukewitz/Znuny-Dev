#!/bin/bash

# Shared Selenium Chrome (WebDriver) for Znuny browser unit tests.
# Default hub is Selenium 3. `selenium start 4` switches the same container to Selenium 4.

set -e

SELENIUM_IMAGE_3='selenium/standalone-chrome:3.141.59-oxygen'
SELENIUM_IMAGE_4='selenium/standalone-chrome:4.49.0'

show_usage_selenium() {
    print_header "znuny-dev selenium"
    echo ""
    print_status "Shared Chrome on znuny-network, hostname selenium:4444"
    print_status "Default image: ${SELENIUM_IMAGE_3} (VNC vnc://127.0.0.1:5900/, password secret)"
    print_status "Optional image: ${SELENIUM_IMAGE_4} (noVNC http://127.0.0.1:7900/)"
    echo ""
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium start      # Start Selenium 3, or the major saved by the last start"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium start 3    # Switch to Selenium 3 and recreate the container"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium start 4    # Switch to Selenium 4 and recreate the container"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium stop       # Stop container"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium restart    # Restart container (keeps the current image)"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium status     # Show container state and image"
    print_command "${ZD_CMD:-./znuny-dev.sh} selenium remove     # Stop and remove container"
    echo ""
    print_status "Instance opt-in: ENABLE_SELENIUM=y in instances/<name>/<name>.env, then recreate the instance."
    print_status "Startup probes the hub and writes SeleniumTestsConfig plus TestHTTPHostname into Kernel/Config.pm."
    print_status "Recreate the instance after switching 3/4 so that block matches the hub."
    print_status "Dedicated instances are not on znuny-network; this hub only reaches shared instances."
    echo ""
}

selenium_major_file() {
    echo "${ZNUNY_DEV_DIR:?}/dev/docker/.selenium-major"
}

# Last explicit major, or 3 when the file is missing.
selenium_saved_major() {
    local major_file
    major_file=$(selenium_major_file)
    local major="3"
    if [ -f "$major_file" ]; then
        major=$(tr -d '[:space:]' < "$major_file")
    fi
    case "$major" in
        3|4) printf '%s' "$major" ;;
        *) printf '3' ;;
    esac
}

selenium_image_for_major() {
    case "$1" in
        4) printf '%s' "$SELENIUM_IMAGE_4" ;;
        *) printf '%s' "$SELENIUM_IMAGE_3" ;;
    esac
}

selenium_save_major() {
    printf '%s\n' "$1" > "$(selenium_major_file)"
}

selenium_running_image() {
    docker inspect -f '{{.Config.Image}}' znuny-selenium 2>/dev/null || true
}

get_selenium_compose_file() {
    echo "${ZNUNY_DEV_DIR:?}/dev/docker/compose-selenium.yml"
}

# Ensure the shared network exists. It is external: instances may have created it
# under another Compose project, and this file must not try to own it.
selenium_ensure_network() {
    if docker network inspect znuny-network >/dev/null 2>&1; then
        return 0
    fi
    print_status "Creating network znuny-network"
    docker network create znuny-network
}

# Run docker compose for Selenium from the compose file directory (relative paths).
# SELENIUM_PLATFORM=linux/amd64 adds the override for the amd64-only Selenium 3 image.
compose_selenium() {
    local compose_file
    compose_file=$(get_selenium_compose_file)
    local compose_dir
    compose_dir=$(dirname "$compose_file")
    local dc
    dc=$(get_compose_cmd 2>/dev/null) || dc="docker compose"
    local -a compose_args
    compose_args=(-f "$(basename "$compose_file")")
    if [ "${SELENIUM_PLATFORM:-}" = "linux/amd64" ]; then
        compose_args+=(-f compose-selenium-amd64.yml)
    fi
    (
        cd "$compose_dir" && $dc "${compose_args[@]}" -p znuny "$@"
    )
}

selenium_parse_major() {
    local requested="${1:-}"
    case "$requested" in
        ""|3|4) ;;
        *)
            print_error "Selenium major must be 3 or 4, not: $requested" >&2
            return 1
            ;;
    esac
    if [ -n "$requested" ]; then
        printf '%s' "$requested"
        return 0
    fi
    selenium_saved_major
}

# Start or recreate znuny-selenium for major 3 or 4. Saves the major for the next plain start.
selenium_ensure_started() {
    local major="$1"
    local image
    image=$(selenium_image_for_major "$major")
    local current=""
    current=$(selenium_running_image)
    selenium_save_major "$major"
    export SELENIUM_IMAGE="$image"
    if [ "$major" = "3" ]; then
        export SELENIUM_PLATFORM="linux/amd64"
    else
        unset SELENIUM_PLATFORM
    fi
    selenium_ensure_network
    if [ -n "$current" ] && [ "$current" != "$image" ]; then
        print_status "Switching Selenium image from $current to $image"
        compose_selenium up -d --force-recreate --no-deps selenium
    else
        compose_selenium up -d --no-deps selenium
    fi
    print_success "Selenium ${major}: ${image}"
    print_success "Hub: http://selenium:4444/wd/hub"
    if [ "$major" = "4" ]; then
        print_success "noVNC: http://127.0.0.1:7900/"
    else
        print_success "VNC: vnc://127.0.0.1:5900/ (password secret)"
    fi
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
        local major
        major=$(selenium_parse_major "${1:-}") || return 1
        print_status "Starting Selenium ${major}..."
        selenium_ensure_started "$major"
        ;;
    stop)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Stopping Selenium container..."
        compose_selenium stop selenium
        print_success "Selenium stopped."
        ;;
    restart)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Restarting Selenium container..."
        if docker ps -a --format '{{.Names}}' | grep -qx 'znuny-selenium'; then
            compose_selenium restart selenium
            local image
            image=$(selenium_running_image)
            print_success "Selenium restarted (${image:-unknown image})."
        else
            local major
            major=$(selenium_saved_major)
            selenium_ensure_started "$major"
        fi
        ;;
    remove)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        print_status "Removing Selenium container..."
        # Stop and delete only this container. Do not `compose down` the shared
        # znuny-network while instance containers are still attached.
        compose_selenium stop selenium || true
        docker rm -f znuny-selenium 2>/dev/null || true
        print_success "Selenium removed. Run: ${ZD_CMD:-./znuny-dev.sh} selenium start"
        ;;
    status)
        if ! check_command docker; then
            print_error "docker not found"
            return 1
        fi
        local image
        image=$(selenium_running_image)
        local major
        major=$(selenium_saved_major)
        if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^znuny-selenium$'; then
            print_success "Selenium container is running (${image:-unknown image}, saved major ${major})."
            print_status "Hub hostname selenium:4444"
            case "$image" in
                *:4.*) print_status "noVNC: http://127.0.0.1:7900/" ;;
                *) print_status "VNC: vnc://127.0.0.1:5900/ (password secret)" ;;
            esac
        else
            print_status "Selenium container is not running (next start uses major ${major})."
            print_status "Use: ${ZD_CMD:-./znuny-dev.sh} selenium start"
        fi
        ;;
    *)
        print_error "Unknown selenium action: $action"
        show_usage_selenium
        return 1
        ;;
    esac
}
