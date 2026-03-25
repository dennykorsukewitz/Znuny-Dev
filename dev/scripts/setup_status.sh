#!/bin/bash

# Znuny Development Environment – Setup Status
# Complete setup status overview (sourced by znuny-dev.sh)

set -e

# ========================================
# Setup Status
# ========================================

# Function to show complete setup status
setup_status() {
    local verbose_mode=false

    # Check for verbose flag
    if [[ "$1" == "--verbose" || "$1" == "-v" ]]; then
        verbose_mode=true
    fi

    print_header "Znuny Development Environment Status"
    print_header "===================================="
    echo ""

    # Check Docker environment
    print_subheader "🐳 Docker Environment:"

    # Check Docker status3
    check_docker=false
    if ! check_command docker; then
        print "   ❌ Docker not installed"
    elif ! docker info >/dev/null 2>&1; then
        print "   ❌ Docker is not running"
    else
        local docker_version
        docker_version=$(docker info --format '{{.ServerVersion}}' 2>/dev/null)
        if [ -n "$docker_version" ]; then
            print "   ✅ Docker is running (Version: $docker_version)"
            check_docker=true
        else
            print "   ✅ Docker is running"
            check_docker=true
        fi
    fi

    # Check shared containers (reverse proxy, etc.)
    if check_command docker && docker info >/dev/null 2>&1; then
        local shared_containers
        shared_containers=$(docker ps -a --format "{{.Names}} {{.Status}}" | grep -E "znuny_reverse_proxy|znuny_selenium|znuny-mariadb|znuny-mysql|znuny-postgresql" 2>/dev/null || true)
        if [ -n "$shared_containers" ]; then
            print "   ✅ Shared containers:"
            echo "$shared_containers" | while read -r container_name container_status; do
                if [[ "$container_status" == *"Up"* ]]; then
                    print "      ✅ $container_name ($container_status)"
                else
                    print "      ⏹️  $container_name ($container_status)"
                fi
            done
        else
            print "   ⚠️  No shared containers found"
        fi
    fi
    echo ""

    # Call show_all_instance_status from instance.sh with verbose mode
    print_subheader "🏗️  Instances:"
    # Show directory path in verbose mode
    if [[ "$verbose_mode" == "true" ]]; then
        # shellcheck disable=SC2153
        print_step "   $INSTANCES_DIR"
    fi

    # Count instances
    check_instance_files=false
    local instances_count
    instances_count=$(find "$INSTANCES_DIR" -maxdepth 1 -type d -not -name "instances" -not -name "." | sed 's|.*/||' | sort | wc -l)

    if [ "$instances_count" -gt 0 ]; then
        check_instance_files=true
    fi

    # Call instance.sh with a special flag to skip header
    if [[ "$verbose_mode" == "true" ]]; then
        "$SCRIPTS_DIR/instance.sh" status --no-header --verbose
    else
        "$SCRIPTS_DIR/instance.sh" status --no-header
    fi

    # Check compose files (per-instance in INSTANCES_DIR/NAME/ and reverse-proxy in COMPOSE_DIR)
    print_subheader "🐳 Compose Files:"
    # Show directory path in verbose mode
    if [[ "$verbose_mode" == "true" ]]; then
        print_step "   $INSTANCES_DIR/<name>/compose-<framework_slug>.yml, $COMPOSE_DIR (reverse-proxy)"
    fi

    local compose_files=()
    for instance_dir in "$INSTANCES_DIR"/*/; do
        [ -d "$instance_dir" ] || continue
        local name
        name=$(basename "$instance_dir")
        local framework_slug
        framework_slug=$(get_framework_slug "$name")
        [ -f "$instance_dir/compose-${framework_slug}.yml" ] && compose_files+=("$name/compose-${framework_slug}.yml")
    done
    [ -f "$COMPOSE_DIR/compose-reverse-proxy.yml" ] && compose_files+=("compose-reverse-proxy.yml (shared)")

    # Count compose files
    local check_compose_files=false
    if [ ${#compose_files[@]} -gt 0 ]; then
        check_compose_files=true
    fi

    if [ ${#compose_files[@]} -gt 0 ]; then
        for compose_file in "${compose_files[@]}"; do
            print "   ✅ $compose_file"
        done
    else
        print "   ❌ No compose files found"
    fi
    echo ""

    # Check frameworks
    print_subheader "📁 Frameworks:"

    # Show directory path in verbose mode
    if [[ "$verbose_mode" == "true" ]]; then
        # shellcheck disable=SC2153
        print_step "   $FRAMEWORKS_DIR"
    fi

    local check_frameworks=false
    if [ -d "$FRAMEWORKS_DIR" ]; then
        local frameworks=()
        read_lines_to_array frameworks < <(find "$FRAMEWORKS_DIR" -maxdepth 1 -type d -not -name "frameworks" -not -name "." | sed 's|.*/||' | sort)
        if [ ${#frameworks[@]} -eq 0 ]; then
            print "   ❌ No frameworks found"
        else
            for framework in "${frameworks[@]}"; do
                if [ -d "$FRAMEWORKS_DIR/$framework" ]; then
                    print "   ✅ $framework"
                    check_frameworks=true
                else
                    print_error "   ❌ $framework (directory missing)"
                fi
            done
        fi
    else
        print "   ❌ Frameworks directory not found: $FRAMEWORKS_DIR"
    fi
    echo ""

    # Check development tools
    print_subheader "🛠️  Development Tools:"

    # Show directory path in verbose mode
    if [[ "$verbose_mode" == "true" ]]; then
        # shellcheck disable=SC2153
        print_step "   $TOOLS_DIR"
    fi

    local tools_dir="$ZNUNY_DEV_DIR/tools"
    local tools=("module-tools" "Fred" "ZnunyCodePolicy")

    for tool in "${tools[@]}"; do
        if [ -d "$tools_dir/$tool" ]; then
            print "   ✅ $tool"
        else
            print "   ❌ $tool (not found)"
        fi
    done
    echo ""

    # Check packages
    print_subheader "📦 Packages:"

    # Show directory path in verbose mode
    if [[ "$verbose_mode" == "true" ]]; then
        # shellcheck disable=SC2153
        print_step "   $PACKAGES_DIR"
    fi

    # Count packages
    local packages_count
    packages_count=$(find "$PACKAGES_DIR" -maxdepth 1 -type d -not -name "packages" -not -name "." | sed 's|.*/||' | sort | wc -l)
    if [ "$packages_count" -gt 0 ]; then
        print "   ✅ $packages_count packages"
    else
        print "   ❌ No packages found"
    fi
    echo ""

    if [ "$check_docker" = true ]  && [ "$check_frameworks" = true ] && [ "$check_instance_files" = true ] && [ "$check_compose_files" = true ]; then
        print_success "Environment: Ready"
    else

        echo "check_compose_files: $check_compose_files"
        echo "check_frameworks: $check_frameworks"
        echo "check_docker: $check_docker"
        echo "check_instance_files: $check_instance_files"

        print_header "===================================="
        echo ""
        print_error "Environment:   Not ready"
        echo "=================================="
        if [ "$check_docker" != true ]; then
            print_warning "Docker:        Not installed"
            print_todo "Please install Docker"
        fi
        if [ "$check_frameworks" != true ]; then
            print_warning "Frameworks:    Not setup"
            print_todo "Please run '$ZD_CMD setup-framework'"
        fi
        if [ "$check_instance_files" != true ]; then
            print_warning "Instances:     Not setup"
            print_todo "Please run '$ZD_CMD instance-create'"
        fi
        if [ "$check_compose_files" != true ]; then
            print_warning "Compose files: Not generated"
            print_todo "Please run '$ZD_CMD setup-compose'"
        fi
    fi
}
