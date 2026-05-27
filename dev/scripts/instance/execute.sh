#!/bin/bash

# Znuny Instance Execute Functions
# Console, shell and module-tools execution in container (sourced by instance.sh)

set -e

# ========================================
# Console and Shell Functions
# ========================================

# Filter Docker CLI hint from stderr ("What's next: Try Docker Debug...")
filter_docker_stderr() {
    grep -v -e "What's next" -e "Try Docker Debug" -e "Learn more at" || true
}

# Strip Znuny- or Znuny4OTRS- prefix (e.g. Znuny4OTRS-FAQ -> FAQ).
_sopm_module_suffix() {
    local module="$1"

    if [[ "$module" == Znuny4OTRS-* ]]; then
        echo "${module#Znuny4OTRS-}"
    elif [[ "$module" == Znuny-* ]]; then
        echo "${module#Znuny-}"
    else
        echo "$module"
    fi
}

# Candidate SOPM basenames: only Znuny-* and Znuny4OTRS-* (user prefix first when given).
_sopm_module_candidates() {
    local module="$1"
    local suffix
    suffix=$(_sopm_module_suffix "$module")

    if [[ "$module" == Znuny4OTRS-* ]]; then
        echo "$module"
        echo "Znuny-${suffix}"
    elif [[ "$module" == Znuny-* ]]; then
        echo "$module"
        echo "Znuny4OTRS-${suffix}"
    else
        echo "$module"
    fi
}

# Resolve module argument to an existing /opt/znuny/<name>.sopm basename inside the container.
resolve_module_sopm_name() {
    local framework="$1"
    local module="$2"

    if [ -z "$framework" ]; then
        print_error "Framework name is required"
        return 1
    fi

    if [ -z "$module" ]; then
        print_error "Package/module name is required"
        return 1
    fi

    local container_name
    container_name=$(get_instance_container_name "$framework")

    local candidate
    while IFS= read -r candidate; do
        if [ -z "$candidate" ]; then
            continue
        fi
        if docker exec "$container_name" test -f "/opt/znuny/${candidate}.sopm" 2>/dev/null; then
            if [ "$candidate" != "$module" ]; then
                print_status "Resolved package '$module' -> ${candidate}.sopm"
            fi
            echo "$candidate"
            return 0
        fi
    done < <(_sopm_module_candidates "$module")

    print_error "SOPM file not found for package: $module"
    print_status "Checked in /opt/znuny:"
    local checked=""
    while IFS= read -r candidate; do
        if [ -z "$candidate" ]; then
            continue
        fi
        checked="${checked} ${candidate}.sopm"
    done < <(_sopm_module_candidates "$module")
    print_status "${checked# }"
    echo ""
    echo "Available SOPM files in /opt/znuny:"
    docker exec "$container_name" su -s /bin/bash -c 'cd /opt/znuny && ls -1 *.sopm 2>/dev/null' znuny 2>/dev/null \
        | sed 's/^/  /' || print_status "  (none or container not running)"
    return 1
}

# Function to execute console command
execute_console_command() {
    local framework="$1"
    shift

    # Validate framework parameter
    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        echo "Usage:"
        print_command "${ZD_CMD:-./znuny-dev.sh} console <framework> <command>"
        return 1
    fi

    local container_name
    container_name=$(get_instance_container_name "$framework")
    # 6.x has bin/otrs.Console.pl only; 7.x has bin/znuny.Console.pl – choose inside container
    if docker exec -t "$container_name" su -s /bin/bash -c "cd /opt/znuny && CONSOLE_PL=bin/znuny.Console.pl; [ -f bin/otrs.Console.pl ] && [ ! -f bin/znuny.Console.pl ] && CONSOLE_PL=bin/otrs.Console.pl; exec perl \$CONSOLE_PL $*" znuny; then
        return 0
    else
        print_error "Failed to execute command"
        return 1
    fi
}

# Function to start shell session
execute_shell_command() {
    local framework="$1"
    shift

    # Validate framework parameter
    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        echo "Usage:"
        print_command "${ZD_CMD:-./znuny-dev.sh} instance-shell <framework> [options]"
        print_status "Options: --root (start as root user), or specify shell command"
        return 1
    fi

    # Parse shell command arguments
    local shell_command="/bin/zsh"
    local as_root="false"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --root)
                as_root="true"
                shift
                ;;
            *)
                shell_command="$1"
                shift
                ;;
        esac
    done

    local container_name
    container_name=$(get_instance_container_name "$framework")

    # If shell_command contains a space, treat as command line and run via shell (docker exec runs argv[0] as binary otherwise)
    local exec_cmd=("$shell_command")
    if [[ "$shell_command" == *" "* ]]; then
        exec_cmd=(/bin/bash -c "$shell_command")
    fi

    if [ "$as_root" = "true" ]; then
        print_status "Starting shell session as root for framework: $framework"
        print_status "Shell: $shell_command (as root)"

        if ! docker exec -it -w /opt/znuny -e TERM="${TERM:-xterm-256color}" -e LANG="${LANG:-C.UTF-8}" -e LC_ALL="${LC_ALL:-C.UTF-8}" "$container_name" "${exec_cmd[@]}" 2> >(filter_docker_stderr >&2); then
            print_error "Failed to start shell session as root"
            exit 1
        fi
    else
        if ! docker exec -it --user znuny -w /opt/znuny -e HOME=/home/znuny -e TERM="$TERM" -e LANG="${LANG:-C.UTF-8}" -e LC_ALL="${LC_ALL:-C.UTF-8}" "$container_name" "${exec_cmd[@]}" 2> >(filter_docker_stderr >&2); then
            print_error "Failed to start shell ($shell_command) session as znuny user for framework: $framework"
            exit 1
        fi
    fi
}

# Function to execute module-tools command (bin/znuny.ModuleTools.pl in container at /opt/tools/module-tools)
execute_module_tools_command() {
    local framework="$1"
    local command="$2"
    shift 2

    if [ -z "$framework" ]; then
        print_error "Framework name is required"
        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        echo "Usage:"
        print_command "${ZD_CMD:-./znuny-dev.sh} <module-tools-command> <framework> [arguments...]"
        return 1
    fi

    if [ -z "$command" ]; then
        echo ""
        print_subheader "ModuleTools – verfügbare Befehle (zd module-tools <framework> <command> [args...])"
        echo ""
        print_command "${ZD_CMD:-./znuny-dev.sh} link <framework> <package> [package ...]"   "Module::File::Link (mehrere Pakete möglich)"
        print_command "${ZD_CMD:-./znuny-dev.sh} unlink <framework> <package> [package ...]" "Module::File::Unlink (mehrere Pakete möglich)"
        print_command "${ZD_CMD:-./znuny-dev.sh} rmlinks <framework>"                     "Module::File::Unlink --all"
        echo ""
        print_command "${ZD_CMD:-./znuny-dev.sh} install <framework> <package>"           "Package Install (dbinstall, codeinstall)"
        print_command "${ZD_CMD:-./znuny-dev.sh} uninstall <framework> <package>"        "Package Uninstall (dbuninstall, codeuninstall)"
        echo ""
        print_command "${ZD_CMD:-./znuny-dev.sh} dbinstall <framework> <package>"        "Module::Database::Install"
        print_command "${ZD_CMD:-./znuny-dev.sh} dbupgrade <framework> <package>"        "Module::Database::Upgrade"
        print_command "${ZD_CMD:-./znuny-dev.sh} dbuninstall <framework> <package>"       "Module::Database::Uninstall"
        echo ""
        print_command "${ZD_CMD:-./znuny-dev.sh} codeinstall <framework> <package>"      "Module::Code::Install"
        print_command "${ZD_CMD:-./znuny-dev.sh} codereinstall <framework> <package>"     "Module::Code::Reinstall"
        print_command "${ZD_CMD:-./znuny-dev.sh} codeuninstall <framework> <package>"     "Module::Code::Uninstall"
        print_command "${ZD_CMD:-./znuny-dev.sh} codeupgrade <framework> <package>"      "Module::Code::Upgrade"
        echo ""
        print_command "${ZD_CMD:-./znuny-dev.sh} module-tools <framework> <command> [args...]" "Beliebiger znuny.ModuleTools.pl-Befehl"
        echo ""
        return 1
    fi

    local container_name
    container_name=$(get_instance_container_name "$framework")
    # Run znuny.ModuleTools.pl inside container; framework is always /opt/znuny there
    if docker exec -t "$container_name" su -s /bin/bash -c "cd /opt/znuny && perl /opt/tools/module-tools/bin/znuny.ModuleTools.pl $command $*" znuny; then
        return 0
    else
        print_error "Module-tools command failed: $command"

        # if command is  one of them, show sopm files in /opt/znuny
        if [[ "$command" =~ (Module::Database::Install|Module::Code::Install|Module::Database::Uninstall|Module::Code::Uninstall|Module::Database::Install|Module::Database::Upgrade|Module::Database::Uninstall|Module::Code::Install|Module::Code::Reinstall|Module::Code::Uninstall|Module::Code::Upgrade) ]]; then
            echo ""
            echo "SOPM files in /opt/znuny:"
            execute_shell_command "$framework" "ls -1 *.sopm"
        fi

        return 1
    fi
}

# Function to install CPAN modules via cpanm inside the framework container (runs as root)
execute_cpanm_command() {
    local framework="$1"
    shift

    if [ -z "$framework" ]; then
        print_error "Framework name is required"

        echo "Available frameworks:"
        local available_frameworks=()
        read_lines_to_array available_frameworks < <(get_available_frameworks)
        print_list "${available_frameworks[@]}"
        echo ""
        echo "Usage:"
        print_command "${ZD_CMD:-./znuny-dev.sh} cpanm <framework> [cpanm options] <Module::Name> ..."
        return 1
    fi

    if [ $# -eq 0 ]; then
        print_error "At least one cpanm option or CPAN module is required"
        echo ""
        echo "Usage:"
        print_command "${ZD_CMD:-./znuny-dev.sh} cpanm <framework> [cpanm options] <Module::Name> ..."
        print_command "${ZD_CMD:-./znuny-dev.sh} cpanm dev CGI::Struct" ""
        print_command "${ZD_CMD:-./znuny-dev.sh} cpanm dev --notest CGI::Struct" ""
        return 1
    fi

    local container_name
    container_name=$(get_instance_container_name "$framework")

    print_status "Running cpanm in framework container: $framework"
    if docker exec -t "$container_name" cpanm "$@" 2> >(filter_docker_stderr >&2); then
        return 0
    else
        print_error "cpanm failed"
        return 1
    fi
}
