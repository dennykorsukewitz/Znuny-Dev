#!/bin/bash

# Znuny Instance Manager
# This script manages multiple Znuny framework instances

set -e


# ========================================
# SCRIPT HEADER & INITIALIZATION
# ========================================

# Load common functions
if [ -f "$(dirname "$0")/common.sh" ]; then
    source "$(dirname "$0")/common.sh"
fi

# Load repository functions
if [ -f "$(dirname "$0")/repository.sh" ]; then
    source "$(dirname "$0")/repository.sh"
fi

# Load instance-specific modules
if [ -f "$(dirname "$0")/instance/compose.sh" ]; then
    source "$(dirname "$0")/instance/compose.sh"
fi

if [ -f "$(dirname "$0")/instance/network.sh" ]; then
    source "$(dirname "$0")/instance/network.sh"
fi

if [ -f "$(dirname "$0")/instance/index.sh" ]; then
    source "$(dirname "$0")/instance/index.sh"
fi

if [ -f "$(dirname "$0")/instance/log.sh" ]; then
    source "$(dirname "$0")/instance/log.sh"
fi

if [ -f "$(dirname "$0")/instance/status.sh" ]; then
    source "$(dirname "$0")/instance/status.sh"
fi

if [ -f "$(dirname "$0")/dashboard.sh" ]; then
    source "$(dirname "$0")/dashboard.sh"
fi

if [ -f "$(dirname "$0")/instance/execute.sh" ]; then
    source "$(dirname "$0")/instance/execute.sh"
fi

load_environment
set_zd_cmd

# ========================================
# USAGE & HELP FUNCTIONS
# ========================================

# Function to show usage
show_usage() {
    print_header "Znuny Instance Manager"
    print_header "====================="
    echo ""
    echo "Usage: ./instance.sh <command> [framework] [options]"
    echo ""
    print_subheader "Commands:"
    print_command "  create <framework> [options]           # Create a new framework instance"
    print_command "    --url <url>                          # Repository URL (default: from .env)"
    print_command "    --branch <branch>                    # Branch name (default: dev)"
    print_command "    --db-type <type>                     # Database type: mariadb|mysql|postgresql (default: mariadb)"
    print_command "    --db-name <name>                     # Database name (default: framework name)"
    print_command "    --db-user <user>                     # Database user (default: framework name)"
    print_command "    --db-password <password>             # Database password (default: framework name)"
    print_command "    --db-port <port>                     # Database port (default: 3306/5432)"
    print_command "    --port <port>                        # Instance HTTP port (default: BASE_PORT+index, BASE_PORT=10000)"
    print_command "    --fqdn <hostname>                    # FQDN for instance URL"
    print_command "    --script-alias <path>                # Script alias e.g. /prod/ (default: /dev/)"
    print_command "    --instance-mode <shared|dedicated>   # shared (default) or dedicated"
    print_command "    --start                              # Start instance immediately after creation"
    print_command "    --start-prompt                       # Ask to start instance (interactive)"
    print_command "    --random-data-insert                 # Run RandomDataInsert after start (no prompt)"
    print_command "    --link-fred                          # Run link-fred after start (no prompt)"
    print_command "  start <framework>                      # Start framework instance(s) or all instances"
    print_command "  stop <framework>                       # Stop framework instance(s) or all instances"
    print_command "  restart <framework>                    # Restart framework instance(s) or all instances"
    print_command "  build <framework|all> [--no-cache]     # Build Docker image for instance(s)"
    print_command "  status <framework>                     # Show status of framework(s) or all instances"
    print_command "  log <framework> [log_file]             # Show framework log from container filesystem"
    print_command "  container-log [framework] [lines]      # Show Docker container log (stdout/stderr)"
    print_command "  console <framework> <cmd>              # Execute console command"
    print_command "  random-data-insert <framework> [options]       # Insert random data (RandomDataInsert) into instance"
    print_command "    --generate-tickets <n>               # Number of tickets (default: 10)"
    print_command "    --articles-per-ticket <n>            # Articles per ticket (default: 10)"
    print_command "    --generate-users <n>                 # Number of users (default: 5)"
    print_command "    --generate-customer-users <n>        # Number of customer users (default: 6)"
    print_command "    --generate-customer-companies <n>   # Number of customer companies (default: 2)"
    print_command "    --generate-groups <n>               # Number of groups (default: 3)"
    print_command "    --generate-queues <n>                # Number of queues (default: 5)"
    print_command "  shell <framework> [options]            # Start shell session (default: as znuny user)"
    print_command "    --root                               # Start as root user instead of znuny user"
    print_command "  remove <framework|all> [options]       # Remove a framework instance or all instances"
    print_command "    --force                              # Force removal without confirmation"
    print_command "    --keep-framework                     # Keep framework directory, only remove instance config"
    print_command "  sync-indices                           # Rebuild USED_FRAMEWORK_INDICES from instances/* (fixes stale .env)"
    print_command "  list                                   # List available frameworks"
    print_command "  help                                   # Show this help message"
    echo ""
    print_subheader "Examples:"
    print_command "  ./instance.sh status                   # Show all framework status"
    print_command "  ./instance.sh status dev               # Show specific framework status"
    echo ""
    print_command "  ./instance.sh create dev"
    print_command "  ./instance.sh create prod \\"
    print_command "    --url https://github.com/znuny/znuny.git \\"
    print_command "    --branch develop \\"
    print_command "    --db-type mysql \\"
    print_command "    --db-name prod_db \\"
    print_command "    --db-user prod_user \\"
    print_command "    --db-password secret123 \\"
    print_command "    --db-port 3306 \\"
    print_command "    --start"
    echo ""
    print_command "  ./instance.sh remove dev"
    print_command "  ./instance.sh remove dev --force"
    print_command "  ./instance.sh remove dev --keep-framework"
    print_command "  ./instance.sh remove all --force       # Remove all instances"
    print_command "  ./instance.sh start                    # Start all instances"
    print_command "  ./instance.sh start dev                # Start specific framework"
    print_command "  ./instance.sh stop                     # Stop all instances"
    echo ""
    print_command "  ./instance.sh log dev                  # Show framework log from container"
    print_command "  ./instance.sh log dev /opt/znuny/var/log/apache-error.log   # Show specific log"
    print_command "  ./instance.sh container-log            # Show all Docker container log"
    print_command "  ./instance.sh container-log dev 100    # Show Docker container log for 'dev'"
    print_command "  ./instance.sh console dev db:check"
    print_command "  ./instance.sh random-data-insert dev          # Insert random data (from config)"
    print_command "  ./instance.sh random-data-insert dev --generate-tickets 20 --articles-per-ticket 5"
    print_command "  ./instance.sh shell dev                # Start zsh shell as znuny user"
    print_command "  ./instance.sh shell dev --root         # Start zsh shell as root user"
    print_command "  ./instance.sh shell dev /bin/bash      # Start bash shell as znuny user"
}

show_usage_create() {
    print_header "Znuny Instance Manager"
    print_header "====================="
    echo ""
    echo "Usage: ${ZD_CMD:-./znuny-dev.sh} instance-create [framework] [options]"
    echo ""
    print_subheader "Commands:"
    print_command "  create <framework> [options]           # Create a new framework instance"
    print_command "    --url <url>                          # Repository URL (default: from .env)"
    print_command "    --branch <branch>                    # Branch name (default: dev)"
    print_command "    --db-type <type>                     # Database type: mariadb|mysql|postgresql (default: mariadb)"
    print_command "    --db-name <name>                     # Database name (default: framework name)"
    print_command "    --db-user <user>                     # Database user (default: framework name)"
    print_command "    --db-password <password>             # Database password (default: framework name)"
    print_command "    --db-port <port>                     # Database port (default: 3306/5432)"
    print_command "    --port <port>                        # Instance HTTP port (default: BASE_PORT+index, BASE_PORT=10000)"
    print_command "    --fqdn <hostname>                    # FQDN for instance URL"
    print_command "    --script-alias <path>                # Script alias e.g. /prod/ (default: /dev/)"
    print_command "    --instance-mode <shared|dedicated>   # shared (default) or dedicated"
    print_command "    --start                              # Start instance immediately after creation"
    print_command "    --start-prompt                       # Ask to start instance (interactive)"
    print_command "    --random-data-insert                 # Run RandomDataInsert after start (no prompt)"
    print_command "    --link-fred                          # Run link-fred after start (no prompt)"
    print_command "  list                                   # List available frameworks"
    print_command "  help                                   # Show this help message"
    echo ""
    print_subheader "Examples:"
    print_command "  ./instance.sh create dev"
    print_command "  ./instance.sh create prod \\"
    print_command "    --url https://github.com/znuny/Znuny.git \\"
    print_command "    --branch dev \\"
    print_command "    --port 10000 --fqdn localhost \\"
    print_command "    --db-type mysql --db-port 3306 \\"
    print_command "    --db-name prod_db --db-user prod_user --db-password secret123 \\"
    print_command "    --script-alias /prod/ \\"
    print_command "    --start"
}

show_usage_random_data_insert() {
    print_header "Random Data Insert"
    print_header "=================="
    echo ""
    echo "Usage: ${ZD_CMD:-./znuny-dev.sh} random-data-insert <framework> [options]"
    echo ""
    print_subheader "Description:"
    echo "  Inserts random test data into a Znuny instance via Dev::Tools::Database::RandomDataInsert."
    echo "  Uses config from configs/framework/RandomDataInsert.conf unless options are passed."
    echo ""
    print_subheader "Options:"
    print_command "  --generate-tickets <n>                 # Number of tickets (default: 10)"
    print_command "  --articles-per-ticket <n>              # Articles per ticket (default: 10)"
    print_command "  --generate-users <n>                  # Number of users (default: 5)"
    print_command "  --generate-customer-users <n>         # Number of customer users (default: 6)"
    print_command "  --generate-customer-companies <n>     # Number of customer companies (default: 2)"
    print_command "  --generate-groups <n>                 # Number of groups (default: 3)"
    print_command "  --generate-queues <n>                 # Number of queues (default: 5)"
    print_command "  --help, -h                            # Show this help message"
    echo ""
    print_subheader "Examples:"
    print_command "  ${ZD_CMD:-./znuny-dev.sh} random-data-insert dev"
    print_command "  ${ZD_CMD:-./znuny-dev.sh} random-data-insert dev --generate-tickets 20 --articles-per-ticket 5"
    print_command "  ${ZD_CMD:-./znuny-dev.sh} random-data-insert dev --generate-tickets 2 --generate-users 3"
    echo ""
}

show_usage_remove() {
    print_header "Znuny Instance Manager"
    print_header "====================="
    echo ""
    echo "Usage: ${ZD_CMD:-./znuny-dev.sh} instance-remove <framework|all>"
    echo ""
    print_subheader "Commands:"
    print_command "  remove <framework|all> [--force] [--keep-framework]"
}

# ========================================
# List Functions
# ========================================

# Function to list frameworks
show_all_frameworks() {
    local frameworks=()
    read_lines_to_array frameworks < <(get_available_frameworks)
    if [ ${#frameworks[@]} -eq 0 ]; then
        print_warning "No frameworks found"
        return 1
    fi

    print_subheader "Available frameworks:"
    for framework in "${frameworks[@]}"; do
        local port
        port=$(get_instance_port "$framework")
        local container_name
        container_name=$(get_instance_container_name "$framework")

        if docker ps --format "{{.Names}}" | grep -q "$container_name"; then
            local status="Running"
        else
            local status="Stopped"
        fi

        print_list_item "$framework: port $port ($status)"
    done
}

# ========================================
# Command Functions
# ========================================

# Case handlers (snake_case of case name); dispatch to existing instance functions
create() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        show_usage_create
        exit 1
    fi
    create_instance "$@"
}

remove() {
    local framework="$1"
    shift
    if [ "$framework" = "all" ]; then
        remove_instances "$@"
    elif [ -n "$framework" ]; then
        remove_instance "$framework" "$@"
    else
        print_error "Framework name is required for remove command"
        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        print_status "Use 'remove all' to remove all instances or 'remove <framework>' for a specific framework"
        exit 1
    fi
}

setup_compose() {
    create_all_compose_files
}

start() {
    local framework="$1"
    shift
    if [ "$framework" = "all" ]; then
        start_all_instances
    elif [ -n "$framework" ]; then
        start_instance "$framework"
    else
        print_error "Framework name is required for start command"
        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        print_status "Use 'start all' to start all instances or 'start <framework>' for specific framework"
        exit 1
    fi
}

stop() {
    local framework="$1"
    shift
    if [ "$framework" = "all" ]; then
        stop_all_instances
    elif [ -n "$framework" ]; then
        stop_instance "$framework"
    else
        print_error "Framework name is required for stop command"
        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        print_status "Use 'stop all' to stop all instances or 'stop <framework>' for specific framework"
        exit 1
    fi
}

restart() {
    local framework="$1"
    shift
    if [ "$framework" = "all" ]; then
        restart_all_instances
    elif [ -n "$framework" ]; then
        restart_instance "$framework"
    else
        print_error "Framework name is required for restart command"
        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        print_status "Use 'restart all' to restart all instances or 'restart <framework>' for specific framework"
        exit 1
    fi
}

build() {
    local framework="$1"
    shift
    if [ "$framework" = "all" ]; then
        build_instances "$@"
    elif [ -n "$framework" ]; then
        build_instance "$framework" "$@"
    else
        print_error "Framework name is required for build command"
        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        print_status "Use 'build all' to build all instances or 'build <framework>' for specific framework"
        exit 1
    fi
}

delete_rebuild() {
    local framework="$1"
    delete "$framework"
    rebuild "$framework"
}

delete_rebuild_restart() {
    local framework="$1"

    delete_rebuild "$framework"
    restart_instance "$framework"
}

rebuild() {
    local framework="$1"
    execute_console_command "$framework" Maint::Config::Rebuild --cleanup
}

delete() {
    local framework="$1"
    execute_console_command "$framework" Maint::Cache::Delete || return $?
    execute_console_command "$framework" Maint::Loader::CacheCleanup
}

unittest() {
    local framework="$1"
    shift
    execute_console_command "$framework" "Dev::UnitTest::Run --verbose --test $*"
}

translate() {
    local framework="$1"
    execute_console_command "$framework" Maint::Cache::Delete || return $?
    execute_console_command "$framework" Maint::Loader::CacheCleanup
    execute_console_command "$framework" Maint::Config::Sync
    execute_console_command "$framework" Maint::Config::Rebuild --cleanup
    execute_console_command "$framework" Dev::Tools::TranslationsUpdate --generate-po
}

contributors() {
    local framework="$1"
    execute_console_command "$framework" Dev::Code::ContributorsListUpdate --generate
}

sql_schema() {
    local framework="$1"
    local container_name
    container_name=$(get_instance_container_name "$framework")

    local schema_file
    schema_file=$(docker exec "$container_name" su -s /bin/bash -c 'cd /opt/znuny && find scripts/database -type f -name "*schema.xml" 2>/dev/null | head -1' znuny 2>/dev/null | tr -d '\r')

    if [ -z "$schema_file" ]; then
        print_error "No *schema.xml file found in scripts/database"
        return 1
    fi

    local schema_file_name
    schema_file_name=$(basename "${schema_file%.xml}")

    print_status "Source: $schema_file"
    print_status "Target filename: $schema_file_name"

    execute_console_command "$framework" Dev::Tools::Database::XML2SQL --database-type=all --source-path="$schema_file" --target-directory=scripts/database --target-filename="$schema_file_name" --split-files
}

sql_initial_insert() {
    local framework="$1"
    local container_name
    container_name=$(get_instance_container_name "$framework")

    local initial_insert_file
    initial_insert_file=$(docker exec "$container_name" su -s /bin/bash -c 'cd /opt/znuny && find scripts/database -type f -name "*initial_insert.xml" 2>/dev/null | head -1' znuny 2>/dev/null | tr -d '\r')

    if [ -z "$initial_insert_file" ]; then
        print_error "No *initial_insert.xml file found in scripts/database"
        return 1
    fi

    local initial_insert_file_name
    initial_insert_file_name=$(basename "${initial_insert_file%.xml}")

    print_status "Source: $initial_insert_file"
    print_status "Target filename: $initial_insert_file_name"

    execute_console_command "$framework" Dev::Tools::Database::XML2SQL --database-type=all --source-path="$initial_insert_file" --target-directory=scripts/database --target-filename="$initial_insert_file_name"
}

cpanm() {
    local framework="$1"
    shift
    execute_cpanm_command "$framework" "$@"
}

link() {
    local framework="$1"
    shift
    local link_only=false
    local packages=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --only)
                link_only=true
                shift
                ;;
            *)
                packages+=("$1")
                shift
                ;;
        esac
    done

    for pkg in "${packages[@]}"; do
        execute_module_tools_command "$framework" Module::File::Link "/opt/packages/$pkg" "/opt/znuny"
    done

    if [ "$link_only" = true ]; then
        return 0
    fi

    execute_console_command "$framework" Maint::Config::Rebuild --cleanup
    execute_console_command "$framework" Maint::Cache::Delete
    execute_console_command "$framework" Maint::Loader::CacheCleanup

    echo ""
    print_subheader "After linking a package, you can use the following commands:"
    if [ ${#packages[@]} -eq 1 ]; then
        print_command "  zd install $framework ${packages[0]}" "Package Install (dbinstall, codeinstall)"
    else
        for pkg in "${packages[@]}"; do
            print_command "  zd install $framework $pkg" "Package Install (dbinstall, codeinstall)"
        done
    fi
    if [ ${#packages[@]} -gt 0 ]; then
        if [ ${#packages[@]} -eq 1 ]; then
            if confirm "Run 'zd install $framework ${packages[0]}' now?" "y"; then
                install "$framework" "${packages[0]}"
            fi
        else
            if confirm "Run 'zd install $framework <package>' for all linked packages?" "y"; then
                for pkg in "${packages[@]}"; do
                    install "$framework" "$pkg"
                done
            fi
        fi
    fi
}

unlink() {
    local framework="$1"
    shift
    local unlink_only=false
    local packages=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --only)
                unlink_only=true
                shift
                ;;
            *)
                packages+=("$1")
                shift
                ;;
        esac
    done

    if [ "$unlink_only" != true ]; then
        echo ""
        print_subheader "Uninstall must be run before unlinking (dbuninstall, codeuninstall)."
        if [ ${#packages[@]} -eq 1 ]; then
            print_command "  zd uninstall $framework ${packages[0]}" "Package Uninstall"
        else
            for pkg in "${packages[@]}"; do
                print_command "  zd uninstall $framework $pkg" "Package Uninstall"
            done
        fi
        if [ ${#packages[@]} -gt 0 ]; then
            if [ ${#packages[@]} -eq 1 ]; then
                if confirm "Run 'zd uninstall $framework ${packages[0]}' now (before unlink)?" "y"; then
                    uninstall "$framework" "${packages[0]}"
                fi
            else
                if confirm "Run 'zd uninstall $framework <package>' for all packages before unlink?" "y"; then
                    for pkg in "${packages[@]}"; do
                        uninstall "$framework" "$pkg"
                    done
                fi
            fi
        fi
    fi

    for pkg in "${packages[@]}"; do
        execute_module_tools_command "$framework" Module::File::Unlink "/opt/packages/$pkg" "/opt/znuny"
    done

    if [ "$unlink_only" = true ]; then
        return 0
    fi

    execute_console_command "$framework" Maint::Config::Rebuild --cleanup
    execute_console_command "$framework" Maint::Cache::Delete
    execute_console_command "$framework" Maint::Loader::CacheCleanup
}

rmlink() {
    local framework="$1"
    execute_module_tools_command "$framework" Module::File::Unlink --all "/opt/znuny"
    execute_console_command "$framework" Maint::Config::Rebuild --cleanup
    execute_console_command "$framework" Maint::Cache::Delete
    execute_console_command "$framework" Maint::Loader::CacheCleanup
}

# Resolve module to /opt/znuny/<name>.sopm (Znuny-* or Znuny4OTRS-* only).
module_sopm_path() {
    local framework="$1"
    local module="$2"
    local resolved_module

    resolved_module=$(resolve_module_sopm_name "$framework" "$module") || return 1
    echo "/opt/znuny/${resolved_module}.sopm"
}

install() {
    local framework="$1"
    local module="$2"
    local sopm_path

    sopm_path=$(module_sopm_path "$framework" "$module") || return 1
    execute_module_tools_command "$framework" Module::Database::Install "$sopm_path"
    execute_module_tools_command "$framework" Module::Code::Install "$sopm_path"
}

uninstall() {
    local framework="$1"
    local module="$2"
    local sopm_path

    sopm_path=$(module_sopm_path "$framework" "$module") || return 1
    execute_module_tools_command "$framework" Module::Database::Uninstall "$sopm_path"
    execute_module_tools_command "$framework" Module::Code::Uninstall "$sopm_path"
}

dbinstall() {
    local framework="$1"
    local module="$2"
    local sopm_path

    sopm_path=$(module_sopm_path "$framework" "$module") || return 1
    execute_module_tools_command "$framework" Module::Database::Install "$sopm_path"
}

dbupgrade() {
    local framework="$1"
    local module="$2"
    local sopm_path

    sopm_path=$(module_sopm_path "$framework" "$module") || return 1
    execute_module_tools_command "$framework" Module::Database::Upgrade "$sopm_path"
}

dbuninstall() {
    local framework="$1"
    local module="$2"
    local sopm_path

    sopm_path=$(module_sopm_path "$framework" "$module") || return 1
    execute_module_tools_command "$framework" Module::Database::Uninstall "$sopm_path"
}

codeinstall() {
    local framework="$1"
    local module="$2"
    local sopm_path

    sopm_path=$(module_sopm_path "$framework" "$module") || return 1
    execute_module_tools_command "$framework" Module::Code::Install "$sopm_path"
}

codereinstall() {
    local framework="$1"
    local module="$2"
    local sopm_path

    sopm_path=$(module_sopm_path "$framework" "$module") || return 1
    execute_module_tools_command "$framework" Module::Code::Reinstall "$sopm_path"
}

codeuninstall() {
    local framework="$1"
    local module="$2"
    local sopm_path

    sopm_path=$(module_sopm_path "$framework" "$module") || return 1
    execute_module_tools_command "$framework" Module::Code::Uninstall "$sopm_path"
}

codeupgrade() {
    local framework="$1"
    local module="$2"
    local sopm_path

    sopm_path=$(module_sopm_path "$framework" "$module") || return 1
    execute_module_tools_command "$framework" Module::Code::Upgrade "$sopm_path"
}

module_tools() {
    local framework="$1"
    shift
    execute_module_tools_command "$framework" "$@"
}

# Znuny CodePolicy: host Perl from the framework checkout root (not Docker); forwards znuny.CodePolicy.pl options.
code_policy() {
    if [ -z "${FRAMEWORKS_DIR:-}" ] || [ -z "${TOOLS_DIR:-}" ]; then
        print_error "FRAMEWORKS_DIR or TOOLS_DIR not set. Run '${ZD_CMD:-zd} setup-env'."
        return 1
    fi

    local cp_script="${TOOLS_DIR}/ZnunyCodePolicy/bin/znuny.CodePolicy.pl"
    if [ ! -f "$cp_script" ]; then
        print_error "ZnunyCodePolicy not found: $cp_script"
        print_status "Run '${ZD_CMD:-zd} setup-tools' or clone into tools/ZnunyCodePolicy (see ${ZD_CMD:-zd} setup-repository-sources)."
        return 1
    fi

    local framework=""
    if [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; then
        local candidate
        candidate=$(resolve_framework_name "$1")
        if [ -d "$FRAMEWORKS_DIR/$candidate" ]; then
            framework="$candidate"
            shift
        fi
    fi
    framework="${framework:-dev}"

    local fw_dir="$FRAMEWORKS_DIR/$framework"
    if [ ! -d "$fw_dir" ]; then
        print_error "Framework directory not found: $fw_dir"
        return 1
    fi

    local fw_rel="${FRAMEWORKS_DIR_REL:-frameworks}"
    print_status "Znuny CodePolicy (framework: $framework, cwd: $fw_rel/$framework)"
    ( cd "$fw_dir" && perl "$cp_script" "$@" )
}

link_codepolicy() {
    local framework="$1"
    execute_module_tools_command "$framework" Module::File::Link "/opt/tools/ZnunyCodePolicy" "/opt/znuny"
    execute_console_command "$framework" Maint::Config::Rebuild --cleanup
    execute_console_command "$framework" Maint::Cache::Delete
    execute_console_command "$framework" Maint::Loader::CacheCleanup
}

unlink_codepolicy() {
    local framework="$1"
    execute_module_tools_command "$framework" Module::File::Unlink "/opt/tools/ZnunyCodePolicy" "/opt/znuny"
    execute_console_command "$framework" Maint::Config::Rebuild --cleanup
    execute_console_command "$framework" Maint::Cache::Delete
    execute_console_command "$framework" Maint::Loader::CacheCleanup
}

link_fred() {
    local framework="$1"
    execute_module_tools_command "$framework" Module::File::Link "/opt/tools/Fred" "/opt/znuny"
    execute_console_command "$framework" Maint::Config::Rebuild --cleanup
    execute_console_command "$framework" Maint::Cache::Delete
    execute_console_command "$framework" Maint::Loader::CacheCleanup
}

unlink_fred() {
    local framework="$1"
    execute_module_tools_command "$framework" Module::File::Unlink "/opt/tools/Fred" "/opt/znuny"
    execute_console_command "$framework" Maint::Config::Rebuild --cleanup
    execute_console_command "$framework" Maint::Cache::Delete
    execute_console_command "$framework" Maint::Loader::CacheCleanup
}

shell() {
    local framework="$1"
    shift
    execute_shell_command "$framework" "$@"
}

console() {
    local framework="$1"
    shift
    execute_console_command "$framework" "$@"
}

log() {
    local framework="$1"
    local name="${2:-access.log}"
    show_framework_log "$framework" "$name"
}

container_log() {
    local framework="$1"
    local lines="$2"
    if [ -n "$framework" ]; then
        show_container_log "$framework" "${lines:-50}"
    else
        show_all_container_log "${lines:-}"
    fi
}

# ========================================
# Create Instance Functions
# ========================================

# Run Dev::Tools::Database::RandomDataInsert in framework instance
# Uses config from configs/framework/RandomDataInsert.conf unless params passed via --generate-tickets etc.
random_data_insert() {
    local framework="$1"
    shift

    if [ "$framework" = "--help" ] || [ "$framework" = "-h" ]; then
        show_usage_random_data_insert
        return 0
    fi

    if [ -z "$framework" ]; then
        print_error "Framework name is required for random_data_insert"
        return 1
    fi

    # Default values
    local generate_tickets=""
    local articles_per_ticket=""
    local generate_users=""
    local generate_customer_users=""
    local generate_customer_companies=""
    local generate_groups=""
    local generate_queues=""
    local use_config=true

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage_random_data_insert
                return 0
                ;;
            --generate-tickets)
                generate_tickets="$2"
                use_config=false
                shift 2
                ;;
            --articles-per-ticket)
                articles_per_ticket="$2"
                use_config=false
                shift 2
                ;;
            --generate-users)
                generate_users="$2"
                use_config=false
                shift 2
                ;;
            --generate-customer-users)
                generate_customer_users="$2"
                use_config=false
                shift 2
                ;;
            --generate-customer-companies)
                generate_customer_companies="$2"
                use_config=false
                shift 2
                ;;
            --generate-groups)
                generate_groups="$2"
                use_config=false
                shift 2
                ;;
            --generate-queues)
                generate_queues="$2"
                use_config=false
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done


    # Load from config if no params were passed via command line
    if [ "$use_config" = true ]; then
        local config_dir="${ZNUNY_DEV_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}/configs/framework"
        local config_file="$config_dir/RandomDataInsert.conf"

        generate_tickets=10
        articles_per_ticket=10
        generate_users=5
        generate_customer_users=6
        generate_customer_companies=2
        generate_groups=3
        generate_queues=5

        if [ -f "$config_file" ]; then
            while IFS= read -r line; do
                [[ "$line" =~ ^#.*$ ]] && continue
                [[ -z "$line" ]] && continue
                if [[ "$line" =~ ^([A-Za-z0-9_]+)=(.*)$ ]]; then
                    local key="${BASH_REMATCH[1]}"
                    local value="${BASH_REMATCH[2]}"
                    case "$key" in
                        GENERATE_TICKETS) generate_tickets="${value:-10}" ;;
                        ARTICLES_PER_TICKET) articles_per_ticket="${value:-10}" ;;
                        GENERATE_USERS) generate_users="${value:-5}" ;;
                        GENERATE_CUSTOMER_USERS) generate_customer_users="${value:-6}" ;;
                        GENERATE_CUSTOMER_COMPANIES) generate_customer_companies="${value:-2}" ;;
                        GENERATE_GROUPS) generate_groups="${value:-3}" ;;
                        GENERATE_QUEUES) generate_queues="${value:-5}" ;;
                    esac
                fi
            done < "$config_file"
        fi
    fi

    # Build args - only include params that are set
    # Note: Dev::Tools::Database::RandomDataInsert requires --generate-tickets; use 0 when not set
    local random_data_args=("Dev::Tools::Database::RandomDataInsert")
    if [ -n "$generate_tickets" ]; then
        random_data_args+=("--generate-tickets" "$generate_tickets")
    else
        random_data_args+=("--generate-tickets" "0")
    fi
    [ -n "$articles_per_ticket" ] && random_data_args+=("--articles-per-ticket" "$articles_per_ticket")
    [ -n "$generate_users" ] && random_data_args+=("--generate-users" "$generate_users")
    [ -n "$generate_customer_users" ] && random_data_args+=("--generate-customer-users" "$generate_customer_users")
    [ -n "$generate_customer_companies" ] && random_data_args+=("--generate-customer-companies" "$generate_customer_companies")
    [ -n "$generate_groups" ] && random_data_args+=("--generate-groups" "$generate_groups")
    [ -n "$generate_queues" ] && random_data_args+=("--generate-queues" "$generate_queues")

    print_status "Running Dev::Tools::Database::RandomDataInsert in $framework..."
    if execute_console_command "$framework" "${random_data_args[@]}"; then
        print_success "RandomDataInsert completed successfully."
    else
        print_warning "RandomDataInsert failed or module not available."
    fi
}

# If flag was not set via CLI, ask once; prints "true" or "false".
prompt_random_data_insert() {
    local flag="$1"
    if [ "$flag" != false ]; then
        printf '%s\n' "$flag"
        return
    fi
    if confirm "Do you want to run Dev::Tools::Database::RandomDataInsert after starting?" "y"; then
        printf '%s\n' "true"
    else
        printf '%s\n' "false"
    fi
}

# If flag was not set via CLI, ask once; prints "true" or "false".
prompt_link_fred() {
    local flag="$1"
    if [ "$flag" != false ]; then
        printf '%s\n' "$flag"
        return
    fi
    if confirm "Do you want to run link-fred (Fred dev tools) after starting?" "y"; then
        printf '%s\n' "true"
    else
        printf '%s\n' "false"
    fi
}

# After create: switch working directory to the new instance (this process; interactive shell unchanged when invoked via znuny-dev.sh).
change_to_instance_directory() {
    local instance_dir="$1"
    local abs_dir
    if ! abs_dir=$(cd "$instance_dir" && pwd); then
        print_warning "Could not resolve $instance_dir"
        return 0
    fi
    if cd "$abs_dir"; then
        print_status "Working directory: $(pwd)"
    else
        print_warning "Could not cd to $abs_dir"
    fi
}

# After start_instance: optional link-fred, optional RandomDataInsert, then URLs if anything ran.
post_create_instance() {
    local framework="$1"
    local do_link_fred="$2"
    local do_random_data="$3"

    if [ "$do_link_fred" = true ]; then
        link_fred "$framework"
    fi
    if [ "$do_random_data" = true ]; then
        random_data_insert "$framework"
    fi
    if [ "$do_link_fred" = true ] || [ "$do_random_data" = true ]; then
        local db_url
        db_url=$(get_db_connection_url "$framework" 2>/dev/null)
        [ -n "$db_url" ] && print_status "Database URL: $db_url"
        print_status "Access URL: http://localhost:$(get_instance_port "$framework")"
    fi
}

# Function to create framework instance with smart logic
create_instance() {

    local frameworks=()

    read_lines_to_array frameworks < <(get_available_frameworks)
    # Check if framework is available
    if [ ${#frameworks[@]} -eq 0 ]; then
        print_error "No frameworks found"

        echo "Available frameworks:"
        print_list "${frameworks[@]}"
        echo ""
        show_usage_create
        return 1
    fi

    # Validate framework parameter and resolve to actual directory name (case-insensitive)
    local framework="${1:-}"
    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        show_usage_create
        return 1
    fi
    framework=$(resolve_framework_name "$framework")

    shift  # Remove framework from arguments

    # Default values
    local repo_url="${REPO_SOURCE_ZNUNY}"
    local branch=""
    local db_type=""
    local db_name=""
    local db_user=""
    local db_password=""
    local instance_port=""
    local db_port=""
    local fqdn=""
    local script_alias=""
    local auto_start=false
    local start_prompt=true
    local instance_mode="shared"
    local random_data=false
    local link_fred=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --url)
                repo_url="$2"
                shift 2
                ;;
            --branch)
                branch="$2"
                shift 2
                ;;
            --db-type)
                db_type="$2"
                shift 2
                ;;
            --db-name)
                db_name="$2"
                shift 2
                ;;
            --db-user)
                db_user="$2"
                shift 2
                ;;
            --db-password)
                db_password="$2"
                shift 2
                ;;
            --db-port)
                db_port="$2"
                shift 2
                ;;
            --port)
                instance_port="$2"
                shift 2
                ;;
            --fqdn)
                fqdn="$2"
                shift 2
                ;;
            --script-alias)
                script_alias="$2"
                shift 2
                ;;
            --start)
                auto_start=true
                shift
                ;;
            --start-prompt)
                start_prompt=$2 || true
                shift 2
                ;;
            --random-data-insert)
                random_data=true
                shift
                ;;
            --link-fred)
                link_fred=true
                shift
                ;;
            --instance-mode)
                instance_mode="$2"
                shift 2
                ;;
            *)
                # Legacy support: if first argument is not a flag, treat as URL
                if [[ "$1" != --* ]]; then
                    repo_url="$1"
                    shift
                    # If second argument is not a flag, treat as branch
                    if [[ $# -gt 0 && "$1" != --* ]]; then
                        branch="$1"
                        shift
                    fi
                else
                    print_error "Unknown option: $1"
                    show_usage_create
                    return 1
                fi
                ;;
        esac
    done

    # Use default branch if not provided
    if [ -z "$branch" ]; then
        local framework_dir="$FRAMEWORKS_DIR/$framework"
        # Try to find the current branch in the framework directory
        if [ -d "$framework_dir/.git" ]; then
            branch=$(git -C "$framework_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        fi
        # If no branch found, use default branches
        if [ -z "$branch" ]; then
            local available_branches=()
            read_lines_to_array available_branches < <(get_available_branches "$repo_url")
            local branches_space=" ${available_branches[*]} "
            if [[ "$branches_space" =~ " dev " ]]; then
                branch="dev"
            elif [[ "$branches_space" =~ " main " ]]; then
                branch="main"
            elif [[ "$branches_space" =~ " master " ]]; then
                branch="master"
            elif [[ "$branches_space" =~ " develop " ]]; then
                branch="develop"
            else
                branch="dev"
            fi
        fi
    fi

    # Validate compose mode
    if [[ "$instance_mode" != "shared" && "$instance_mode" != "dedicated" ]]; then
        print_error "Invalid instance mode: $instance_mode (use shared or dedicated)"
        return 1
    fi

    print_header "Creating Framework Instance: $framework"
    print_header "====================================="
    echo ""

    # Create framework directory if it doesn't exist
    ensure_directory "$FRAMEWORKS_DIR"

    # Create instances directory if it doesn't exist
    ensure_directory "$INSTANCES_DIR"

    local framework_dir="$FRAMEWORKS_DIR/$framework"
    local instance_dir="$INSTANCES_DIR/$framework"
    local instance_env_file="$instance_dir/$framework.env"

    # Check if framework directory exists
    if [ ! -d "$framework_dir" ]; then
        print_error "Framework directory not found: $framework_dir"
        echo ""

        print_status "Please enter the branch name and directory name to create the framework directory and then it will run 'create instance' again with the new branch and directory name and all other arguments..."

        # Ask user for branch and directory name (initialized for shellcheck; set by read_input)
        branch=""
        directory=""
        read_input "branch"    "Enter branch name    (default: dev)" "dev"
        read_input "directory" "Enter directory name (default: $framework)" "$framework"
        setup_framework "$branch" "$directory"

        echo ""
        print_status "Running 'create instance' again with the new branch and directory name and all other arguments..."
        echo ""
        # Run create_instance again with the new branch and directory name and all other arguments
        create_instance "$framework" "$branch" "$directory" "$db_type" "$db_name" "$db_user" "$db_password" "$db_port" "$instance_port" "$fqdn" "$script_alias" "$instance_mode"
        return 1
    fi

    # Check if environment file exists
    if [ -f "$instance_env_file" ]; then
        print_warning "Framework instance '$framework' already exists!"
        print_status "Environment file: $INSTANCES_DIR_REL/$framework/$framework.env"
        echo ""

        # Ask user what they want to do
        print_todo "What would you like to do?"
        echo "1) Remove everything (framework directory + instance configuration) and start fresh"
        echo "2) Keep existing framework and recreate instance (Docker containers, volumes, env file)"
        echo "3) Cancel and keep everything as is"
        echo ""

        while true; do
            choice=""
            read_input "choice" "Please choose (1/2/3)" "1"
            echo ""
            case "$choice" in
                1)
                    print_subheader "Removing everything and starting fresh..."

                    # Remove instance and framework directory
                    remove_instance "$framework" --force

                    # Continue with normal creation process (clone repository)
                    clone_repository "$repo_url" "$framework_dir" "$branch"
                    break
                    ;;
                2)
                    print_subheader "Keep existing framework and recreate instance (Docker containers, volumes, env file)..."

                    # Remove instance and keep framework directory
                    remove_instance "$framework" --force --keep-framework
                    break
                    ;;
                3)
                    print_subheader "Keeping existing instance. Exiting."
                    return 0
                    ;;
                *)
                    print_error "Invalid choice. Please enter 1, 2, or 3."
                    ;;
            esac
        done
    else
        print_status "Framework directory exists but no instance configuration found."
        print_status "Creating instance configuration..."
    fi

    # Create instance directory and logs subdir
    ensure_directory "$instance_dir"
    ensure_directory "$instance_dir/logs"
    touch "$instance_dir/logs/access.log" "$instance_dir/logs/error.log" 2>/dev/null || true

    # Create instance (pass optional --port, --fqdn, --script-alias)
    create_env_file "$framework" "$repo_url" "$branch" "$db_type" "$db_name" "$db_user" "$db_password" "$db_port" "$instance_mode" "$instance_port" "$fqdn" "$script_alias"

    # Generate docker-compose.yml (after .env file is created)
    print_status "Updating docker-compose.yml (mode: $instance_mode)..."
    create_instance_compose "$framework" "$instance_mode"

    print_success "Framework instance '$framework' created successfully!"

    ensure_dashboard_started

    # Continue from the new instance directory for the rest of this run (when interactive)
    if [ "$start_prompt" = true ]; then
        change_to_instance_directory "$instance_dir"
    fi

    # Ask if user wants to start the instance or start automatically if --start flag was used
    # Skip prompt unless --start-prompt (e.g. setup-all skips; Step 6 will ask instead)
    if [ "$start_prompt" = false ]; then
        return 0
    fi

    local random_data_insert_requested="$random_data"
    local link_fred_requested="$link_fred"

    if [ "$auto_start" = true ]; then
        random_data_insert_requested=$(prompt_random_data_insert "$random_data_insert_requested")
        link_fred_requested=$(prompt_link_fred "$link_fred_requested")

        print_status "Starting framework instance automatically..."
        start_instance "$framework"
        post_create_instance "$framework" "$link_fred_requested" "$random_data_insert_requested"

    else
        echo ""
        print_status "Next steps:"
        print_list_item "1. Review environment configuration: $INSTANCES_DIR_REL/$framework/$framework.env"
        print_list_item "2. Start the framework: ${ZD_CMD:-./znuny-dev.sh} instance-start $framework"
        db_url=$(get_db_connection_url "$framework" 2>/dev/null)
        [ -n "$db_url" ] && print_list_item "3. Database URL: $db_url"
        print_list_item "$([ -n "$db_url" ] && echo "4" || echo "3"). Access the framework at: http://localhost:$(get_instance_port "$framework")"

        echo ""
        if confirm "Do you want to start the framework instance now?" "y"; then
            random_data_insert_requested=$(prompt_random_data_insert "$random_data_insert_requested")
            link_fred_requested=$(prompt_link_fred "$link_fred_requested")
            print_status "Starting framework instance..."
            start_instance "$framework"
            post_create_instance "$framework" "$link_fred_requested" "$random_data_insert_requested"
        else
            print_status "Framework instance created but not started. Use 'instance-start $framework' to start it later."
        fi
    fi
}

# Function to create environment configuration
create_env_file() {
    local framework="$1"
    local repo_url="$2"
    local branch="$3"
    db_type="${4:-}"
    db_name="${5:-}"
    db_user="${6:-}"
    db_password="${7:-}"
    db_port="${8:-}"
    local instance_mode="${9:-shared}"
    local instance_port_override="${10:-}"
    local fqdn_override="${11:-}"
    local script_alias_override="${12:-}"

    local env_file="$INSTANCES_DIR/$framework/$framework.env"

    # Get configuration from user if not provided via parameters
    echo ""
    print_header "Environment Configuration for $framework"
    print_header "========================================"

    # Create all instance variables and display configuration (sets db_type, db_name, etc. for use below)
    create_instance_variables "$framework" "$repo_url" "$branch" "$db_type" "$db_name" "$db_user" "$db_password" "$db_port" "$instance_mode" "$instance_port_override" "$fqdn_override" "$script_alias_override"

    # Use template to create environment file
    local template_file="${INSTANCE_ENV_TEMPLATE:-$(dirname "$0")/../templates/env/instance.env.template}"
    if [ -f "$template_file" ]; then

        # Replace template variables (handle multi-line variables separately)
        sed -e "s|{{SETUP_DATE}}|$setup_date|g" \
            -e "s|{{INSTANCE_NAME}}|$framework|g" \
            -e "s|{{FRAMEWORK_DIR}}|$framework_dir|g" \
            -e "s|{{FRAMEWORK_NAME}}|$framework|g" \
            -e "s|{{FRAMEWORK_BRANCH}}|$framework_branch|g" \
            -e "s|{{FRAMEWORK_REPO_URL}}|$framework_repo_url|g" \
            -e "s|{{FRAMEWORK_INDEX}}|$framework_index|g" \
            -e "s|{{INSTANCE_PORT}}|$instance_port|g" \
            -e "s|{{FQDN}}|${fqdn:-}|g" \
            -e "s|{{ZNUNY_SCRIPT_ALIAS}}|${znuny_script_alias:-/dev/}|g" \
            -e "s|{{DB_PORT}}|$db_port|g" \
            -e "s|{{NETWORK_SUBNET}}|$network_subnet|g" \
            -e "s|{{DB_TYPE}}|$db_type|g" \
            -e "s|{{DB_HOST}}|$db_host|g" \
            -e "s|{{DB_CONTAINER}}|$db_container|g" \
            -e "s|{{DB_SERVICE}}|$db_service|g" \
            -e "s|{{DB_VOLUME}}|$db_volume|g" \
            -e "s|{{COMPOSE_FILE_FULL_PATH}}|$compose_file_full_path|g" \
            -e "s|{{COMPOSE_FILE}}|$compose_file_full_path|g" \
            -e "s|{{INSTANCE_MODE}}|$instance_mode|g" \
            -e "s|{{SERVICE_NAME}}|znuny_${framework}_instance|g" \
            -e "s|{{CONTAINER_NAME}}|znuny_${framework}_instance|g" \
            -e "s|{{COMPOSE_CMD}}|docker-compose -p znuny -f $compose_file_full_path|g" \
            "$template_file" > "$env_file.tmp"

        # Handle multi-line DB_SPECIFIC_CONFIG replacement (comment marker in template)
        if [ -n "$db_specific_config" ]; then
            sed -e "/{{DB_SPECIFIC_CONFIG}}/r /dev/stdin" -e "/{{DB_SPECIFIC_CONFIG}}/d" "$env_file.tmp" <<< "$db_specific_config" > "$env_file"
        else
            sed -e "/{{DB_SPECIFIC_CONFIG}}/d" "$env_file.tmp" > "$env_file"
        fi

        rm -f "$env_file.tmp"

    else
        print_error "Template file not found: $template_file"
        return 1
    fi

    print_success "Environment configuration created: $env_file"
}

# Function to create all instance variables
# Sets db_type, db_name, db_user, db_password (and other vars) for caller - do not use local for those
create_instance_variables() {

    local framework="$1"
    local repo_url="$2"
    local branch="$3"
    db_type="$4"
    db_name="$5"
    db_user="$6"
    db_password="$7"
    db_port="$8"
    local instance_mode="${9:-shared}"
    local instance_port_override="${10:-}"
    fqdn="${11:-}"
    znuny_script_alias="${12:-}"

    # Set instance-specific variables
    framework_dir="$FRAMEWORKS_DIR/$framework"
    framework_repo_url="$repo_url"

    # Set framework branch or use framework default branch
    framework_branch="${branch:-dev}"

    # Get index from instance .env file or assign a new one
    framework_index=$(get_instance_index "$framework")
    if [ -z "$framework_index" ] || [ "$framework_index" = "0" ]; then
        # No index assigned yet, find and reserve a new one
        if framework_index=$(find_next_available_instance_index); then
            set_instance_index_used "$framework_index"
        else
            print_error "Failed to find available framework index"
            return 1
        fi
    fi

    # Port: use override from --port or calculate from index (BASE_PORT from .env/configs/instance/my.env, default 10000)
    local base_instance_port="${BASE_PORT:-10000}"
    if [ -n "$instance_port_override" ]; then
        instance_port="$instance_port_override"
    else
        instance_port=$((base_instance_port + framework_index))
    fi
    network_subnet="172.20.$((1 + framework_index)).0/24"

    setup_date=$(date)
    compose_file_full_path="$(get_compose_file "$framework")"

    # Get configuration from user if not provided via parameters
    if [ -z "$db_type" ]; then
        echo "Select database type:"
        print_list_item "1) mariadb"
        print_list_item "2) mysql"
        print_list_item "3) postgresql"
        read_input "db_type" "Enter number or type (1-3)" "1"
        case "$db_type" in
            1|mariadb) db_type="mariadb" ;;
            2|mysql) db_type="mysql" ;;
            3|postgresql) db_type="postgresql" ;;
            *) db_type="mariadb" ;;
        esac
    fi
    if [ -z "$db_name" ]; then
        read_input "db_name" "Database name" "$framework"
    fi
    if [ -z "$db_user" ]; then
        read_input "db_user" "Database user" "$framework"
    fi
    if [ -z "$db_password" ]; then
        read_password "db_password" "Database password" "$framework"
    fi

    # For shared mode: one shared DB container per type (znuny-mariadb etc.). For dedicated: own DB per instance.
    local db_host_shared=""
    if [ "$instance_mode" = "shared" ]; then
        case "$db_type" in
            mysql) db_host_shared="znuny-mysql" ;;
            postgresql|postgres) db_host_shared="znuny-postgresql" ;;
            *) db_host_shared="znuny-mariadb" ;;
        esac
    fi

    # Configure database variables based on type
    case "$db_type" in
        mysql)
            db_host="${db_host_shared:-znuny_${framework}_mysql}"
            db_port="${db_port:-3306}"
            db_root_password="root_$framework"
            db_container="znuny_${framework}_mysql"
            db_service="znuny_${framework}_mysql"
            db_volume="znuny_${framework}_mysql_data"
            db_specific_config="DB_NAME=$db_name
DB_USER=$db_user
DB_PASSWORD=$db_password
MYSQL_ROOT_PASSWORD=$db_root_password"
            ;;
        mariadb)
            db_host="${db_host_shared:-znuny_${framework}_mariadb}"
            db_port="${db_port:-3306}"
            db_root_password="root_$framework"
            db_container="znuny_${framework}_mariadb"
            db_service="znuny_${framework}_mariadb"
            db_volume="znuny_${framework}_mariadb_data"
            db_specific_config="DB_NAME=$db_name
DB_USER=$db_user
DB_PASSWORD=$db_password
MARIADB_ROOT_PASSWORD=$db_root_password"
            ;;
        postgresql|postgres)
            db_host="${db_host_shared:-znuny_${framework}_postgresql}"
            db_port="${db_port:-5432}"
            db_root_password="root_$framework"
            db_container="znuny_${framework}_postgresql"
            db_service="znuny_${framework}_postgresql"
            db_volume="znuny_${framework}_postgresql_data"
            db_specific_config="DB_NAME=$db_name
DB_USER=$db_user
DB_PASSWORD=$db_password
POSTGRES_DB=$db_name
POSTGRES_USER=$db_user
POSTGRES_PASSWORD=$db_password"
            ;;
        oracle)
            db_host="${db_host_shared:-znuny_${framework}_oracle}"
            db_port="${db_port:-1521}"
            db_root_password="root_$framework"
            db_container="znuny_${framework}_oracle"
            db_service="znuny_${framework}_oracle"
            db_volume="znuny_${framework}_oracle_data"
            db_specific_config="DB_NAME=$db_name
DB_USER=$db_user
DB_PASSWORD=$db_password
ORACLE_PASSWORD=$db_password"
            ;;
        *)
            db_host="${db_host_shared:-znuny_${framework}_mariadb}"
            db_port="${db_port:-3306}"
            db_root_password="root_$framework"
            db_container="znuny_${framework}_mariadb"
            db_service="znuny_${framework}_mariadb"
            db_volume="znuny_${framework}_mariadb_data"
            db_specific_config="DB_NAME=$db_name
DB_USER=$db_user
DB_PASSWORD=$db_password
MARIADB_ROOT_PASSWORD=$db_root_password"
            ;;
    esac

    # Display all configuration as table
    echo ""
    print_subheader "Instance Configuration:"
    printf "  %-20s %-30s\n" "Framework:" "$framework"
    printf "  %-20s %-30s\n" "Framework dir:" "$framework_dir"
    printf "  %-20s %-30s\n" "Framework branch:" "$framework_branch"
    printf "  %-20s %-30s\n" "Framework repo:" "$framework_repo_url"
    printf "  %-20s %-30s\n" "Instance port:" "$instance_port"
    printf "  %-20s %-30s\n" "Network subnet:" "$network_subnet"
    printf "  %-20s %-30s\n" "Setup date:" "$setup_date"
    printf "  %-20s %-30s\n" "Compose file:" "$compose_file_full_path"
    echo ""
    print_subheader "Database Configuration:"
    printf "  %-20s %-30s\n" "Database type:" "$db_type"
    printf "  %-20s %-30s\n" "Database name:" "$db_name"
    printf "  %-20s %-30s\n" "Database user:" "$db_user"
    printf "  %-20s %-30s\n" "Database port:" "$db_port"
    printf "  %-20s %-30s\n" "Database host:" "$db_host"
    printf "  %-20s %-30s\n" "Instance mode:" "$instance_mode"
    printf "  %-20s %-30s\n" "Database container:" "$db_container"
    printf "  %-20s %-30s\n" "Database service:" "$db_service"
    printf "  %-20s %-30s\n" "Database volume:" "$db_volume"

    if [ -n "$db_password" ]; then
        printf "  %-20s %-30s\n" "Database password:" "[SET]"
    else
        printf "  %-20s %-30s\n" "Database password:" "[NOT SET]"
    fi

    echo ""
}

# ========================================
# Instance Management Functions
# ========================================

# Function to check if instance exists
check_instance_exists() {
    local framework="$1"
    local env_file="$INSTANCES_DIR/$framework/$framework.env"

    if [ ! -f "$env_file" ]; then
        return 1
    fi

    return 0
}

# ========================================
# Lifecycle Operations
# ========================================

start_instance() {
    local framework="$1"
    local skip_ready_wait="${2:-}"

    # Validate framework parameter
    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo ""
        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        echo "Usage:"
        print_command "${ZD_CMD:-./znuny-dev.sh} start <framework|all>"
        return 1
    fi

    # Check compose file exists, generate if missing
    check_compose_file "$framework" || return 1

    local compose_file
    compose_file=$(get_compose_file "$framework")

    # Check if instance exists
    if ! check_instance_exists "$framework"; then
        print_error "Framework instance '$framework' does not exist"
        print_status "Environment file not found: $INSTANCES_DIR_REL/$framework/$framework.env"
        echo ""
        # No TTY — never prompt to create (would block or mislead)
        if [ ! -t 0 ]; then
            print_status "On the host, create the instance first, e.g.: ${ZD_CMD:-zd} create $framework"
            return 1
        fi

        if confirm "Do you want to create the framework instance '$framework' now?" "y"; then
            print_status "Creating framework instance: $framework"
            create_instance "$framework" "$REPO_SOURCE_ZNUNY" "$framework"
            return $?
        else
            print_status "Framework instance creation cancelled"
            return 1
        fi
    fi

    if [ ! -f "$compose_file" ]; then
        print_error "Compose file not found: $compose_file"
        print_status "Please run the compose generator first: ${ZD_CMD:-./znuny-dev.sh} setup-compose"
        return 1
    fi

    print_status "Starting framework instance: $framework"

    # Check if framework directory exists (cloned Znuny repo)
    if [ ! -d "$FRAMEWORKS_DIR/$framework" ]; then
        print_error "Framework '$framework' not found"

        echo "Available frameworks:"
        local frameworks=()
        read_lines_to_array frameworks < <(get_available_frameworks)
        print_list "${frameworks[@]}"

        print_status "Expected directory: $FRAMEWORKS_DIR/$framework"
        print_status "Run first: ${ZD_CMD:-./znuny-dev.sh} repository setup-framework (or clone the framework manually)"
        return 1
    fi

    # Create required networks only for dedicated mode (shared mode uses znuny-network from compose)
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
    local instance_mode="shared"
    if [ -f "$instance_env_file" ]; then
        instance_mode=$(grep "^INSTANCE_MODE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "shared")
    fi
    instance_mode="${instance_mode:-shared}"
    if [ "$instance_mode" = "dedicated" ]; then
        if create_network "$framework"; then
            print_success "Network created successfully!"
        else
            print_error "Failed to create network"
            return 1
        fi
    fi

    # Start the framework using docker-compose
    if docker_compose "$framework" "up"; then
        local port
        port=$(get_instance_port "$framework")
        print_success "Framework '$framework' started successfully!"

        if [ "$skip_ready_wait" != "1" ] && [ "$skip_ready_wait" != "true" ]; then
            wait_for_url "http://localhost:$port" "$framework"
        fi
        db_url=$(get_db_connection_url "$framework" 2>/dev/null)
        [ -n "$db_url" ] && print_status "Database URL: $db_url"
        print_status "Access URL: http://localhost:$port"
    else
        print_error "Failed to start framework '$framework'"
        return 1
    fi
}

# Function to start all instances
start_all_instances() {
    echo ""
    print_header "Starting all instances"
    print_header "====================="
    echo ""

    check_docker

    print_status "Starting all Znuny instances..."

    # One row per real instance (instances/<name>/<name>.env), not only frameworks/* checkouts
    local available_frameworks=()
    read_lines_to_array available_frameworks < <(get_available_instances)
    for framework in "${available_frameworks[@]}"; do
        print_status "Starting instance: $framework"
        start_instance "$framework" "1"
    done

    echo ""
    print_success "All instances have been started (containers up)."
    print_status "HTTP readiness was not waited for; use ${ZD_CMD:-zd} status to see when each is reachable."
    echo ""
    # print_subheader "Available commands:"
    # print_command "  ${ZD_CMD:-./znuny-dev.sh} setup-status    - Check setup status"
    # print_command "  ${ZD_CMD:-./znuny-dev.sh} status          - Show instance status"
    # print_command "  ${ZD_CMD:-./znuny-dev.sh} stop            - Stop all instances"
    # echo ""
}

# Function to stop framework instance
stop_instance() {
    local framework="$1"

    # Validate framework parameter
    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo "Usage: "
        print_command "${ZD_CMD:-./znuny-dev.sh} stop <framework7all>"
        return 1
    fi

    check_compose_file "$framework" || return 1
    if ! check_instance_exists "$framework"; then
        print_error "Framework instance '$framework' does not exist"
        print_status "Environment file not found: $INSTANCES_DIR_REL/$framework/$framework.env"
        return 1
    fi

    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
    local instance_mode="shared"
    if [ -f "$instance_env_file" ]; then
        instance_mode=$(grep "^INSTANCE_MODE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "shared")
    fi
    instance_mode="${instance_mode:-shared}"

    print_status "Stopping framework instance: $framework"

    if [ "$instance_mode" = "shared" ]; then
        local _slug
        _slug=$(get_framework_slug "$framework")
        print_status "Shared mode: stopping only znuny-${_slug}-instance; shared database containers (e.g. znuny-mariadb) keep running."
        if docker_compose_app_service "$framework" "stop"; then
            print_success "Framework '$framework' stopped successfully!"
        else
            print_error "Failed to stop framework '$framework'"
            return 1
        fi
    else
        if docker_compose "$framework" "down"; then
            print_success "Framework '$framework' stopped successfully!"
        else
            print_error "Failed to stop framework '$framework'"
            return 1
        fi
    fi
}

# Function to stop all instances
stop_all_instances() {
    print_header "Stopping all instances"
    print_header "====================="

    check_docker

    print_status "Stopping all Znuny instances..."

    local available_frameworks=()
    read_lines_to_array available_frameworks < <(get_available_instances)
    for framework in "${available_frameworks[@]}"; do
        stop_instance "$framework"
    done

    print_success "All instances stopped!"
}

# Function to build Docker image for a framework instance
build_instance() {
    local framework="$1"
    shift

    if [ -z "$framework" ]; then
        print_error "Framework name is required"
        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        echo "Usage: ${ZD_CMD:-./znuny-dev.sh} build <framework|all> [--no-cache]"
        return 1
    fi

    check_compose_file "$framework" || return 1
    if ! check_instance_exists "$framework"; then
        print_error "Framework instance '$framework' does not exist"
        return 1
    fi

    print_status "Building Docker image for framework instance: $framework"
    if docker_compose "$framework" "build" "$@"; then
        print_success "Framework '$framework' image built successfully!"
        print_status "Restart the instance to use the new image: ${ZD_CMD:-zd} restart $framework"
    else
        print_error "Failed to build framework '$framework' image"
        return 1
    fi
}

# Build Docker images for all framework instances
build_instances() {
    echo ""
    print_header "Building all instances"
    print_header "======================"
    echo ""

    check_docker

    print_status "Building Docker images for all Znuny instances..."
    local available_frameworks=()
    read_lines_to_array available_frameworks < <(get_available_instances)
    for framework in "${available_frameworks[@]}"; do
        build_instance "$framework" "$@"
    done

    print_success "All instances built successfully!"
}

# Function to restart framework instance
restart_instance() {
    local framework="$1"

    # Validate framework parameter
    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        echo "Usage:"
        print_command "${ZD_CMD:-./znuny-dev.sh} restart <framework|all>"
        return 1
    fi

    # Check compose file exists, generate if missing
    check_compose_file "$framework" || return 1

    # Check if instance exists
    if ! check_instance_exists "$framework"; then
        print_error "Framework instance '$framework' does not exist"
        print_status "Environment file not found: $INSTANCES_DIR_REL/$framework/$framework.env"
        echo ""
        if [ ! -t 0 ]; then
            print_status "On the host, create the instance first, e.g.: ${ZD_CMD:-zd} create $framework"
            return 1
        fi

        if confirm "Do you want to create the framework instance '$framework' now?" "y"; then
            print_status "Creating framework instance: $framework"
            create_instance "$framework" "$REPO_SOURCE_ZNUNY" "dev"
            return $?
        else
            print_status "Framework instance creation cancelled"
            return 1
        fi
    fi

    print_status "Restarting framework instance: $framework"

    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
    local instance_mode="shared"
    if [ -f "$instance_env_file" ]; then
        instance_mode=$(grep "^INSTANCE_MODE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "shared")
    fi
    instance_mode="${instance_mode:-shared}"

    local restart_ok=1
    if [ "$instance_mode" = "shared" ]; then
        print_status "Shared mode: restarting only the app container (shared database stays running)."
        if docker_compose_app_service "$framework" "restart"; then
            restart_ok=0
        fi
    else
        if docker_compose "$framework" "restart"; then
            restart_ok=0
        fi
    fi

    if [ "$restart_ok" -eq 0 ]; then
        local port
        port=$(get_instance_port "$framework")
        print_success "Framework '$framework' restarted successfully!"

        wait_for_url "http://localhost:$port" "$framework"
        db_url=$(get_db_connection_url "$framework" 2>/dev/null)
        [ -n "$db_url" ] && print_status "Database URL: $db_url"
        print_status "Access URL: http://localhost:$port"
    else
        print_error "Failed to restart framework '$framework'"
        return 1
    fi
}

# Function to restart all instances
restart_all_instances() {
    print_header "Restarting all instances"
    print_header "======================="

    print_status "Restarting all Znuny instances..."

    stop_all_instances
    start_all_instances
}

# Remove compose file for a single framework (compose-<framework_slug>.yml)
remove_compose() {
    local framework="${1:-}"
    if [ -z "$framework" ]; then
        return 1
    fi
    local compose_file
    compose_file=$(get_compose_file "$framework")
    if [ -f "$compose_file" ]; then
        print_status "Removing compose file: $(basename "$compose_file")"
        rm -f "$compose_file"
    fi
}

# Remove compose files: per-instance (in INSTANCES_DIR/NAME/)
remove_composes() {

    echo ""
    print_header "Remove Compose Files"
    print_header "====================="
    echo ""

    local count=0
    local instance
    for instance in $(get_available_instances); do
        local instance_slug
        instance_slug=$(get_framework_slug "$instance")
        local f="${INSTANCES_DIR:?}/$instance/compose-${instance_slug}.yml"
        for suffix in "" ".backup" ".bak"; do
            local file="${f}${suffix}"
            if [ -f "$file" ]; then
                if confirm "Do you want to remove $(basename "$file")?" "n"; then
                    print_status "Removing: $(basename "$file")"
                    rm -f "$file"
                    count=$((count + 1))
                fi
            fi
        done
    done
    if [ "$count" -eq 0 ]; then
        print_status "No compose files to remove"
    fi
}

# Drop only this instance's database on the shared DB server (MySQL/MariaDB/PostgreSQL).
# Called when removing a shared instance so only that schema is removed, not the shared container.
remove_database() {
    local framework="$1"
    local instance_env_file="$2"
    [ ! -f "$instance_env_file" ] && return 0

    local db_name
    db_name=$(grep "^DB_NAME=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    local db_type
    db_type=$(grep "^DB_TYPE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    [ -z "$db_name" ] && db_name="$framework"
    [ -z "$db_type" ] && db_type="mariadb"

    local db_container
    db_container=$(get_database_container_name "$framework" "$db_type" "shared")
    if ! docker ps -a --format "{{.Names}}" 2>/dev/null | grep -q "^${db_container}$"; then
        print_status "Shared DB container '$db_container' not found, skipping database drop"
        return 0
    fi

    case "$db_type" in
        mysql|mariadb)
            local root_pass="${MARIADB_ROOT_PASSWORD:-$MYSQL_ROOT_PASSWORD}"
            if [ -z "$root_pass" ] && [ -n "${ZNUNY_DEV_DIR:-}" ] && [ -f "$ZNUNY_DEV_DIR/.env" ]; then
                root_pass=$(grep -E "^MARIADB_ROOT_PASSWORD=|^MYSQL_ROOT_PASSWORD=" "$ZNUNY_DEV_DIR/.env" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"')
            fi
            if [ -z "$root_pass" ]; then
                print_warning "Could not get MySQL/MariaDB root password; skipping DROP DATABASE for '$db_name'"
                return 0
            fi
            print_status "Dropping database '$db_name' from shared $db_type..."
            if docker exec "$db_container" mysql -uroot -p"$root_pass" -e "DROP DATABASE IF EXISTS \`$db_name\`;" 2>/dev/null; then
                print_status "Database '$db_name' dropped."
            else
                print_warning "Failed to drop database '$db_name' (or it did not exist)."
            fi
            ;;
        postgresql|postgres)
            local pg_pass="${POSTGRES_ROOT_PASSWORD:-${POSTGRES_PASSWORD:-}}"
            if [ -z "$pg_pass" ] && [ -n "${ZNUNY_DEV_DIR:-}" ] && [ -f "$ZNUNY_DEV_DIR/.env" ]; then
                pg_pass=$(grep -E "^POSTGRES_ROOT_PASSWORD=|^POSTGRES_PASSWORD=" "$ZNUNY_DEV_DIR/.env" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"')
            fi
            [ -z "$pg_pass" ] && pg_pass="postgres_shared"
            print_status "Dropping database '$db_name' from shared PostgreSQL..."
            if docker exec -e PGPASSWORD="$pg_pass" "$db_container" psql -U postgres -c "DROP DATABASE IF EXISTS \"$db_name\";" 2>/dev/null; then
                print_status "Database '$db_name' dropped."
            else
                print_warning "Failed to drop database '$db_name' (or it did not exist)."
            fi
            ;;
        *)
            print_status "Database type '$db_type' not supported for drop; skipping."
            ;;
    esac
    return 0
}

# Function to remove framework instance
remove_instance() {
    # Validate framework parameter
    local framework="${1:-}"

    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        show_usage_remove
        return 1

    fi

    shift  # Remove framework from arguments

    # Default values
    local force="false"
    local keep_framework="false"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force="true"
                shift
                ;;
            --keep-framework)
                keep_framework="true"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                print_status "Available options: --force, --keep-framework"
                return 1
                ;;
        esac
    done

    if [ "$force" != "true" ]; then

        print_warning "This will remove the framework instance: $framework"
        print_warning "This includes:"
        print_list_item "Stopping and removing Docker containers and volumes"
        print_list_item "Removing Docker image (if present)"
        print_list_item "Removing Docker networks"
        print_list_item "Removing compose files"
        print_list_item "Removing environment configuration"
        print_list_item "Removing framework directory (optional)"

        if ! confirm "Are you sure you want to remove this framework instance?" "n"; then
            print_status "Operation cancelled"
            return 0
        fi
    fi

    print_status "Removing framework instance: $framework"

    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
    local instance_mode="shared"
    if [ -f "$instance_env_file" ]; then
        instance_mode=$(grep "^INSTANCE_MODE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "shared")
    fi
    instance_mode="${instance_mode:-shared}"

    local compose_file
    compose_file=$(get_compose_file "$framework")

    if [ "$instance_mode" = "dedicated" ] && [ -f "$compose_file" ]; then
        # Dedicated: full compose down (own DB + app + network)
        print_status "Stopping and removing Docker containers and volumes for '$framework' (dedicated)..."
        docker_compose "$framework" "down" 2>/dev/null || true
    elif [ "$instance_mode" = "shared" ]; then
        # Shared: only stop/remove the app container, do NOT touch shared DB (znuny-mariadb etc.)
        print_status "Stopping and removing app container for '$framework' (shared mode, keeping shared DB)..."
        local app_container
        app_container=$(get_instance_container_name "$framework")
        docker rm -f "$app_container" 2>/dev/null || true
        # Drop only this instance's database on the shared server (not the whole DB container)
        remove_database "$framework" "$instance_env_file"
    fi

    # Remove only this instance's resources (Docker names use lowercase framework_slug)
    # Containers: znuny-<framework_slug>-instance and (dedicated only) znuny-<framework_slug>-mariadb etc.
    local framework_slug
    framework_slug=$(get_framework_slug "$framework")
    print_status "Removing Docker resources for '$framework'..."
    docker ps -a --format "{{.Names}}" | grep -E "^znuny-${framework_slug}-" | while read -r container; do
        if [ -n "$container" ]; then
            print_status "Removing container: $container"
            docker rm -f "$container" 2>/dev/null || true
        fi
    done

    # Volumes: znuny_<framework_slug>-* (compose project prefix + volume name)
    docker volume ls --format "{{.Name}}" | grep -E "^znuny_${framework_slug}-|^${framework_slug}-" | while read -r volume; do
        if [ -n "$volume" ]; then
            print_status "Removing volume: $volume"
            docker volume rm "$volume" 2>/dev/null || true
        fi
    done

    # Networks: only dedicated instance network znuny-<framework_slug>-network (not shared znuny-network)
    docker network ls --format "{{.Name}}" | grep -E "^znuny-${framework_slug}-network$" | while read -r network; do
        if [ -n "$network" ]; then
            print_status "Removing network: $network"
            docker network rm "$network" 2>/dev/null || true
        fi
    done

    # Image: znuny-<framework_slug>-instance (built for this instance)
    local instance_image="znuny-${framework_slug}-instance"
    if docker image inspect "$instance_image" &>/dev/null; then
        print_status "Removing Docker image: $instance_image"
        docker rmi "$instance_image" 2>/dev/null || true
    fi

    remove_compose "$framework"

    # Release framework index and remove entire instance directory
    if [ -f "$instance_env_file" ]; then
        local framework_index
        framework_index=$(grep "^FRAMEWORK_INDEX=" "$instance_env_file" | cut -d'=' -f2)
        if [ -n "$framework_index" ]; then
            unset_instance_index_used "$framework_index"
        fi
    fi

    if [ -d "$INSTANCES_DIR/$framework" ]; then
        print_status "Removing instance directory: $INSTANCES_DIR/$framework"
        rm -rf "${INSTANCES_DIR:?}/$framework"
    fi

    # Remove framework directory only if not --keep-framework
    if [ -d "$FRAMEWORKS_DIR/$framework" ]; then
        if [ "$keep_framework" = "true" ]; then
            print_status "Keeping framework directory (--keep-framework)"
        elif [ "$force" != "true" ]; then
            if confirm "Do you also want to remove the framework directory '$framework'?" "n"; then
                rm -rf "${FRAMEWORKS_DIR:?}/$framework"
                print_status "Removed framework directory"
            else
                print_status "Framework directory preserved"
            fi
        else
            rm -rf "${FRAMEWORKS_DIR:?}/$framework"
            print_status "Removed framework directory"
        fi
    fi

    print_success "Framework instance '$framework' and all associated resources removed successfully!"
    if [ "$keep_framework" = "true" ]; then
        print_status "Framework directory '$framework' kept (--keep-framework)"
    fi
}
# Function to remove instances
remove_instances() {
    # Default values
    local force="false"
    local keep_framework="false"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force="true"
                shift
                ;;
            --keep-framework)
                keep_framework="true"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                print_status "Available options: --force, --keep-framework"
                return 1
                ;;
        esac
    done

    # Remove instances and environments
    echo ""
    print_header "Remove Instances"
    print_header "================"
    echo ""

    local instances_dir="${INSTANCES_DIR:-$ZNUNY_DEV_DIR/instances}"
    if [ -d "$instances_dir" ]; then
        local instances=()
        read_lines_to_array instances < <(get_available_instances)
        if [ ${#instances[@]} -gt 0 ]; then
            print_status "Found instances:"
            print_list "${instances[@]}"

            if [ "$force" = "true" ]; then
                print_status "Force mode: removing all instances without confirmation"
                for instance in "${instances[@]}"; do
                    local args=("$instance" --force)
                    [ "$keep_framework" = "true" ] && args+=(--keep-framework)
                    remove_instance "${args[@]}"
                done
                print_success "Instance removal completed!"
            else
                if confirm "Do you want to remove instances?" "n"; then
                    for instance in "${instances[@]}"; do
                        if confirm "Remove instance '$instance'?" "n"; then
                            # Use the remove_instance function from instance.sh
                            local args=("$instance")
                            [ "$keep_framework" = "true" ] && args+=(--keep-framework)
                            remove_instance "${args[@]}" --force
                        else
                            print_status "Skipping instance '$instance'"
                        fi
                    done
                    print_success "Instance removal completed!"
                else
                    print_status "Skipping instances removal"
                fi
            fi
        else
            print_status "No framework instances found"
        fi
    else
        print_status "Instances directory not found"
    fi
    echo ""
}

# Main function
main() {
    # Simple command router - validation is done in functions
    local framework="${2:-}"
    if [ -n "$framework" ] && [ "$framework" != "all" ]; then
        framework=$(resolve_framework_name "$framework")
    fi

    case "${1:-}" in

        # ========================================
        # Status Operations
        # ========================================

        status)
            show_status "${@:2}"
            ;;
        dashboard)
            dashboard "${@:2}"
            exit 0
            ;;

        # ========================================
        # Create / Remove Instance Operations
        # ========================================

        create)
            create "${@:2}"
            exit 0
            ;;
        remove)
            remove "$framework" "${@:3}"
            ;;
        remove-instances)
            remove_instances "${@:2}"
            exit 0
            ;;
        remove-composes)
            remove_composes "${@:2}"
            exit 0
            ;;
        setup-compose)
            setup_compose
            exit 0
            ;;
        sync-indices)
            sync_indices
            exit 0
            ;;
        # ========================================
        # Lifecycle Operations
        # ========================================

        start)
            start "$framework" "${@:3}"
            ;;
        stop)
            stop "$framework" "${@:3}"
            ;;
        restart)
            restart "$framework" "${@:3}"
            ;;
        build)
            build "$framework" "${@:3}"
            ;;

        # ========================================
        # Common Commands
        # ========================================
        delete-rebuild|delreb)
            delete_rebuild "$framework"
            ;;
        delete-rebuild-restart|delrebres)
            delete_rebuild_restart "$framework"
            ;;
        rebuild|reb)
            rebuild "$framework"
            ;;
        delete|del)
            delete "$framework"
            ;;
        unittest|unit)
            unittest "$framework" "${@:4}"
            ;;
        translate)
            translate "$framework"
            ;;
        contributors)
            contributors "$framework"
            ;;
        sql-schema)
            sql_schema "$framework"
            ;;
        sql-initial-insert)
            sql_initial_insert "$framework"
            ;;
        cpanm)
            cpanm "$framework" "${@:3}"
            ;;
        random-data-insert)
            if [ "${2:-}" = "--help" ] || [ "${2:-}" = "-h" ]; then
                show_usage_random_data_insert
                exit 0
            fi
            random_data_insert "$framework" "${@:3}"
            ;;
        # ========================================
        # ModuleTools Commands (via /opt/tools/module-tools/bin/znuny.ModuleTools.pl in container)
        # ========================================
        link)
            link "$framework" "${@:3}"
            ;;
        unlink)
            unlink "$framework" "${@:3}"
            ;;
        rmlink|rmlinks)
            rmlink "$framework"
            ;;
        install)
            install "$framework" "${3:-}"
            ;;
        uninstall)
            uninstall "$framework" "${3:-}"
            ;;
        dbinstall)
            dbinstall "$framework" "${3:-}"
            ;;
        dbupgrade)
            dbupgrade "$framework" "${3:-}"
            ;;
        dbuninstall)
            dbuninstall "$framework" "${3:-}"
            ;;
        codeinstall)
            codeinstall "$framework" "${3:-}"
            ;;
        codereinstall)
            codereinstall "$framework" "${3:-}"
            ;;
        codeuninstall)
            codeuninstall "$framework" "${3:-}"
            ;;
        codeupgrade)
            codeupgrade "$framework" "${3:-}"
            ;;
        module-tools|mt)
            module_tools "$framework" "${@:3}"
            ;;
        codepolicy|cp|cc)
            code_policy "${@:2}"
            ;;

        # ========================================
        # Link/Unlink CodePolicy
        # ========================================
        link-codepolicy)
            link_codepolicy "$framework"
            ;;
        unlink-codepolicy)
            unlink_codepolicy "$framework"
            ;;

        # ========================================
        # Link/Unlink Fred
        # ========================================
        link-fred)
            link_fred "$framework"
            ;;
        unlink-fred)
            unlink_fred "$framework"
            ;;

        # ========================================
        # Console and Shell Operations
        # ========================================
        shell)
            shell "$framework" "${@:3}"
            ;;
        console)
            console "$framework" "${@:3}"
            ;;
        log)
            log "$framework" "${3:-access.log}"
            ;;
        container-log)
            container_log "$framework" "${3:-50}"
            ;;
        show-usage-create)
            show_usage_create
            exit 0
            ;;
        help|--help)
            show_usage
            exit 0
            ;;
        get_available_frameworks)
            get_available_frameworks
            exit 0
            ;;
        get_available_instances)
            get_available_instances
            exit 0
            ;;
        "")
            show_usage
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
