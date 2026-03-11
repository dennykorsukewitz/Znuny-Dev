#!/bin/bash

# Znuny Development Environment Management Script
# Main script for managing the Znuny development environment

set -e

# Define ZNUNY_DEV_DIR if not already set
if [ -z "${ZNUNY_DEV_DIR:-}" ]; then
    ZNUNY_DEV_DIR="$(dirname "$0")"
fi


# Define directories for easier access
SCRIPTS_DIR="$ZNUNY_DEV_DIR/dev/scripts"
TEST_DIR="$ZNUNY_DEV_DIR/dev/test"

# Load common functions (use ZNUNY_DEV_DIR so script works when called from anywhere)
source "$ZNUNY_DEV_DIR/dev/scripts/common.sh"

load_environment
set_zd_cmd
export ZD_CMD

# Load setup status and usage (sourced after common + env so vars/functions are available)
if [ -f "$ZNUNY_DEV_DIR/dev/scripts/setup_status.sh" ]; then
    source "$ZNUNY_DEV_DIR/dev/scripts/setup_status.sh"
fi
if [ -f "$ZNUNY_DEV_DIR/dev/scripts/usage.sh" ]; then
    source "$ZNUNY_DEV_DIR/dev/scripts/usage.sh"
fi
if [ -f "$ZNUNY_DEV_DIR/dev/scripts/version.sh" ]; then
    source "$ZNUNY_DEV_DIR/dev/scripts/version.sh"
fi

# Function to setup everything
setup_all() {
    print_header "Setting up complete development environment..."
    print_header "=============================================="
    print_header "Step 1: Generate global .env           (with backup preservation)."
    print_header "Step 2: Setting up user alias          (zd command)."
    print_header "Step 3: Setting up directories path    (frameworks, packages, tools)."
    print_header "Step 4: Setting up repositories        (Znuny, ZnunyCodePolicy, module-tools, etc.)."
    print_header "Step 5: Creating new instance          (dev|mariadb)."
    print_header "Step 6: Starting new instance          (docker-compose up -d)."

    local step1_completed=false
    local step2_completed=false
    local step3_completed=false
    local step4_completed=false
    local step5_completed=false

    # Step 1: Generate global .env with backup preservation
    echo ''
    if confirm "Step 1: Generate global .env (with backup preservation)" "y"; then
        echo ''
        setup_env
        step1_completed=true
    else
        print_status "Skipping Step 1: Generate global .env"
    fi

    # Step 2: Setup global alias
    echo ''

    if check_zd_alias_configured; then
        print_status "Step 2: User alias (zd command) is already configured"
        step2_completed=true
    elif confirm "Step 2: Setting up user alias (zd command)" "y"; then
        echo ''
        setup_alias
        step2_completed=true
    else
        print_status "Skipping Step 2: Setting up user alias"
    fi

    # Step 3: Setting up directories path
    echo ''
    if confirm "Step 3: Setting up directories path (frameworks, packages, tools)" "y"; then
        echo ''
        setup_directories
        step3_completed=true
    else
        print_status "Skipping Step 3: Setting up directories path"
    fi

    # Step 4: Setup repositories
    echo ''
    if confirm "Step 4: Setting up repositories (Znuny, ZnunyCodePolicy, module-tools, etc.)." "y"; then
        echo ''
        setup_repositories
        step4_completed=true
    else
        print_status "Skipping Step 4: Setting up repositories"
    fi

    # Step 5: Creating framework instance (only if Step 5 is confirmed)
    echo ''
    if confirm "Step 5: Creating new instance" "y"; then
        echo ''

        local existing_instances=($("$SCRIPTS_DIR/instance.sh" get_available_instances))
        if [ ${#existing_instances[@]} -gt 0 ]; then
            if ! confirm "There are already instances (${existing_instances[*]}). Create another one?" "n"; then
                print_status "Step 5 skipped (no new instance requested)."
            else
                step5_do_create=true
            fi
        else
            step5_do_create=true
        fi

        if [ "${step5_do_create:-false}" = true ]; then
            local frameworks=($("$SCRIPTS_DIR/instance.sh" get_available_frameworks))
            if [ ${#frameworks[@]} -eq 0 ]; then
                print_warning "No frameworks found. Please run 'zd setup-framework' first."
                print_status "Step 5 skipped."
            else
                local default_framework="dev"
                if [[ ! " ${frameworks[*]} " =~ " ${default_framework} " ]]; then
                    default_framework="${frameworks[0]}"
                fi
                echo "Available frameworks:"
                for i in "${!frameworks[@]}"; do
                    local marker=""
                    if [ "${frameworks[$i]}" = "$default_framework" ]; then
                        marker=" (default)"
                    fi
                    echo "  $((i + 1))) ${frameworks[$i]}$marker"
                done
                echo ""
                read_input "framework_name" "Select framework number or enter framework name" "$default_framework"
                if [ -z "${framework_name:-}" ]; then
                    framework_name="$default_framework"
                fi
                if [[ "$framework_name" =~ ^[0-9]+$ ]]; then
                    local index=$((framework_name - 1))
                    if [ "$index" -ge 0 ] && [ "$index" -lt ${#frameworks[@]} ]; then
                        framework_name="${frameworks[$index]}"
                    else
                        print_warning "Invalid selection, using default: $default_framework"
                        framework_name="$default_framework"
                    fi
                else
                    if [[ ! " ${frameworks[*]} " =~ " ${framework_name} " ]]; then
                        print_warning "Framework '$framework_name' not found, using default: $default_framework"
                        framework_name="$default_framework"
                    fi
                fi

                "$SCRIPTS_DIR/instance.sh" create "$framework_name" --url "$REPO_SOURCE_ZNUNY" --no-start-prompt
                "$SCRIPTS_DIR/env.sh" --set-var "SETUP_FRAMEWORK_INSTANCE" "true"
                step5_completed=true
                step5_framework_name="$framework_name"
            fi
        fi
    else
        print_status "Skipping Step 5: Creating new instance"
    fi

    # Step 6: Start the development environment (only if Step 5 was completed)
    echo ''
    if [ "$step5_completed" = true ]; then
        print_header "Step 6: Starting new instance          (docker-compose up -d)."
        if confirm "Start the framework instance now?" "y"; then
            echo ''
            local start_framework="${step5_framework_name:-dev}"
            "$SCRIPTS_DIR/instance.sh" start "$start_framework"
        else
            print_status "Skipping Step 6: Starting development environment"
        fi
    fi

    echo ''
    print_success "Setup process completed!"
    if [ "$step2_completed" = true ]; then
        print_status "You can now use 'zd' instead of './znuny-dev.sh' from anywhere"
        print_status "Or run '$ZD_CMD setup-status' to check the current state"
    else
        print_status "You can run '$ZD_CMD setup-status' to check the current state"
    fi
}

# Function to setup environment file only
setup_env() {
    "$SCRIPTS_DIR/env.sh" setup-env
}

# Function to setup alias only
setup_alias() {
    "$SCRIPTS_DIR/env.sh" setup-alias
}

# Function to setup repositories
setup_directories() {
    "$SCRIPTS_DIR/env.sh" setup-directories
}

# Function to setup repositories
setup_repositories() {
    setup_repository_sources
    setup_framework
    setup_tools
    setup_packages

    # Update SETUP_REPOSITORIES in .env
    "$SCRIPTS_DIR/env.sh" --set-var "SETUP_REPOSITORIES" "true"
}

# Function to setup framework only
setup_repository_sources() {
    "$SCRIPTS_DIR/repository.sh" setup-repository-sources
}

# Function to setup framework only
setup_framework() {
    "$SCRIPTS_DIR/repository.sh" setup-framework "$@"
}

# Function to setup tools only
setup_tools() {
    "$SCRIPTS_DIR/repository.sh" setup-tools
}

# Function to setup packages only
setup_packages() {
    "$SCRIPTS_DIR/repository.sh" setup-packages
}

# Function to setup Docker Compose files
setup_compose() {
    echo ""
    print_header "Generating Docker Compose files"
    print_header "==============================="
    echo ""

    "$SCRIPTS_DIR/instance.sh" setup-compose
}

# Function to remove all setup components
setup_remove() {
    print_header "Removing complete development environment..."
    print_header "=============================================="
    echo ""
    print_warning "This will remove alias, frameworks, tools, packages, instances, and Docker resources!"
    echo ""

    print_header "Step 1: Remove instances              (dev, rel-7_3)."
    print_header "Step 2: Remove frameworks             (dev, rel-7_3)."
    print_header "Step 3: Remove tools                  (Fred, ZnunyCodePolicy, module-tools)."
    print_header "Step 4: Remove packages               (Znuny-Package, etc.)."
    print_header "Step 5: Remove global .env            (.env)."
    print_header "Step 6: Remove user alias             (zd command)."

    # Remove instances
    remove_instances

    # Remove frameworks
    remove_frameworks

    # Remove tools
    remove_tools

    # Remove packages
    remove_packages

    # Remove global .env
    remove_env

    # Remove alias
    remove_alias

    print_success "Remove setup completed!"
    echo ""
    print_status "Run '$ZD_CMD setup-status' to verify the current state"
}

remove_alias() {
    "$SCRIPTS_DIR/env.sh" remove-alias
}

remove_frameworks() {
    "$SCRIPTS_DIR/repository.sh" remove-frameworks
}

remove_tools() {
    "$SCRIPTS_DIR/repository.sh" remove-tools
}

remove_packages() {
    "$SCRIPTS_DIR/repository.sh" remove-packages
}

remove_instances() {
    "$SCRIPTS_DIR/instance.sh" remove-instances
}

remove_composes() {
    "$SCRIPTS_DIR/instance.sh" remove-composes
}

remove_env() {
    "$SCRIPTS_DIR/env.sh" remove-env
}

# Main function
main() {
    # Check if global .env exists, if not restrict available commands
    local env_file="$ZNUNY_DEV_DIR/.env"
    if [ ! -f "$env_file" ]; then
        # Only allow setup-all and setup-status if no global .env exists
        case "$1" in
            setup-all|setup-status)
                # Allow these commands
                ;;
            *)
                show_usage_setup
                echo ""
                print_error "Global environment file not found: $env_file"
                print_status "Please run '$ZD_CMD setup-all' first to initialize the environment"
                exit 1
                ;;
        esac
    fi

    # First start of day: check for new version and show message if available (skip when user runs 'zd version')
    if [ "$1" != "version" ] && [ "$1" != "--version" ]; then
        check_version
    fi

    # Parse command line arguments
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi


    # # Get INSTANCE_URL from instance.env file
    # local instance_url=$(get_instance_url "$2" 2>/dev/null)

    # if [ -n "$instance_url" ]; then
    #     print_header "Framework: $2 $instance_url"
    # else
    #     print_header "Framework: $2"
    # fi

    case "$1" in
        # ========================================
        # Setup Commands
        # ========================================
        setup-all)
            setup_all
            ;;
        setup-env)
            setup_env
            ;;
        setup-alias)
            setup_alias
            ;;
        setup-repository-sources)
            setup_repository_sources
            ;;
        setup-framework)
            setup_framework "${@:2}"
            ;;
        setup-tools)
            setup_tools
            ;;
        setup-compose)
            setup_compose
            ;;
        setup-status)
            setup_status "$2"
            ;;
        setup-remove)
            setup_remove
            ;;
        setup-packages)
            setup_packages
            ;;

        # ========================================
        # Remove Commands
        # ========================================
        remove_alias)
            remove_alias
            ;;
        remove_frameworks)
            remove_frameworks
            ;;
        remove_tools)
            remove_tools
            ;;
        remove_instances)
            remove_instances
            ;;
        remove_composes)
            remove_composes
            ;;

        # ========================================
        # Instance Commands
        # ========================================
        instance-create|create)
            "$SCRIPTS_DIR/instance.sh" create "${@:2}"
            ;;
        instance-remove|remove)
            "$SCRIPTS_DIR/instance.sh" remove "${@:2}"
            ;;
        instance-start|start)
            "$SCRIPTS_DIR/instance.sh" start "${@:2}"
            ;;
        instance-stop|stop)
            "$SCRIPTS_DIR/instance.sh" stop "${@:2}"
            ;;
        instance-restart|restart)
            "$SCRIPTS_DIR/instance.sh" restart "${@:2}"
            ;;
        instance-build|build)
            "$SCRIPTS_DIR/instance.sh" build "${@:2}"
            ;;
        instance-status|status)
            "$SCRIPTS_DIR/instance.sh" status "${@:2}"
            ;;
        instance-log|log)
            "$SCRIPTS_DIR/instance.sh" log "${@:2}"
            ;;
        instance-container-log|container-log)
            "$SCRIPTS_DIR/instance.sh" container-log "${@:2}"
            ;;
        instance-shell|shell)
            "$SCRIPTS_DIR/instance.sh" shell "${@:2}"
            ;;
        instance-console|console)
            "$SCRIPTS_DIR/instance.sh" console "${@:2}"
            ;;
        instance-help)
            "$SCRIPTS_DIR/instance.sh" help
            ;;

        # ========================================
        # Common Commands
        # ========================================
        delete-rebuild|delreb)
            "$SCRIPTS_DIR/instance.sh" delete-rebuild "${@:2}"
            ;;
        rebuild|reb)
            "$SCRIPTS_DIR/instance.sh" rebuild "${@:2}"
            ;;
        delete|del)
            "$SCRIPTS_DIR/instance.sh" delete "${@:2}"
            ;;
        unittest|unit)
            "$SCRIPTS_DIR/instance.sh" unittest "${@:2}"
            ;;
        translate|translate)
            "$SCRIPTS_DIR/instance.sh" translate "${@:2}"
            ;;

        # ========================================
        # ModuleTools Commands
        # ========================================
        link)
            "$SCRIPTS_DIR/instance.sh" link "${@:2}"
            ;;
        unlink)
            "$SCRIPTS_DIR/instance.sh" unlink "${@:2}"
            ;;
        rmlinks)
            "$SCRIPTS_DIR/instance.sh" rmlinks "${@:2}"
            ;;
        install)
            "$SCRIPTS_DIR/instance.sh" install "${@:2}"
            ;;
        uninstall)
            "$SCRIPTS_DIR/instance.sh" uninstall "${@:2}"
            ;;
        dbinstall)
            "$SCRIPTS_DIR/instance.sh" dbinstall "${@:2}"
            ;;
        dbupgrade)
            "$SCRIPTS_DIR/instance.sh" dbupgrade "${@:2}"
            ;;
        dbuninstall)
            "$SCRIPTS_DIR/instance.sh" dbuninstall "${@:2}"
            ;;
        codeinstall)
            "$SCRIPTS_DIR/instance.sh" codeinstall "${@:2}"
            ;;
        codereinstall)
            "$SCRIPTS_DIR/instance.sh" codereinstall "${@:2}"
            ;;
        codeuninstall)
            "$SCRIPTS_DIR/instance.sh" codeuninstall "${@:2}"
            ;;
        codeupgrade)
            "$SCRIPTS_DIR/instance.sh" codeupgrade "${@:2}"
            ;;
        module-tools|mt)
            "$SCRIPTS_DIR/instance.sh" module-tools "${@:2}"
            ;;

        # ========================================
        # Fred Commands
        # ========================================
        link-fred)
            "$SCRIPTS_DIR/instance.sh" link-fred "${@:2}"
            ;;
        unlink-fred)
            "$SCRIPTS_DIR/instance.sh" unlink-fred "${@:2}"
            ;;
        # ========================================
        # Test and Release Commands
        # ========================================
        test|tests)
            "$TEST_DIR/run.sh" "${@:2}"
            ;;
        release)
            "$SCRIPTS_DIR/release.sh" "${@:2}"
            ;;

        # ========================================
        # Help and Version Commands
        # ========================================
        help|--help)
            show_usage
            ;;
        examples|example|--examples|--example)
            show_usage_examples
            ;;
        dev|--dev)
            show_usage_dev
            ;;
        version|--version)
            show_versions
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
