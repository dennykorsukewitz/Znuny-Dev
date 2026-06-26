#!/bin/bash

# Script to generate global .env file from template
# This script is called during setup-all and setup-env

set -e

# Load common functions
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

# Load environment variables
load_environment

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --force, -f    Force regeneration even if .env exists"
    echo "  --set-var KEY VALUE  Set or update a single environment variable"
    echo ""
    echo "This script generates a global .env file from the env.template"
    echo "with all project paths and configuration variables."
    echo ""
    echo "Examples:"
    echo "  $0 --force                    # Regenerate .env from template"
    echo "  $0 --set-var FRAMEWORKS_DIR /custom/frameworks  # Set single variable"
}

# Function to generate .env file from template
setup_env() {

    echo ""
    print_header "Generating global .env file"
    print_header "==========================="
    echo ""

    local znuny_dev_root
    znuny_dev_root="$(cd "$(dirname "$0")/../.." && pwd)"
    local env_file="$znuny_dev_root/.env"
    local template_file="$znuny_dev_root/dev/templates/env/global.env.template"

    # Check if .env already exists
    if [ -f "$env_file" ]; then
        print_warning ".env file already exists"
        if [ "${ZNUNY_ENV_FORCE_REGENERATE:-0}" = 1 ]; then
            print_status "Overwriting .env file (--force)..."
        elif confirm "Do you want to overwrite the existing .env file?" "n"; then
            print_status "Overwriting .env file..."
        else
            print_status "Keeping existing .env file"
            return 0
        fi
    else
        print_status "Creating new .env file..."
    fi

    # Check if template exists
    if [ ! -f "$template_file" ]; then
        print_error "Template file not found: $template_file"
        exit 1
    fi

    # Get current date
    local setup_date
    setup_date=$(date)

    # Define all path variables (Full Paths)
    local dev_dir="$znuny_dev_root/dev"
    local dev_docker_dir="$znuny_dev_root/dev/docker"
    local dev_scripts_dir="$znuny_dev_root/dev/scripts"
    local dev_env_dir="$znuny_dev_root/dev/env"
    local dev_instances_dir="$znuny_dev_root/instances"
    local dev_compose_dir="$znuny_dev_root/dev/docker/compose"

    # Use configured directories if available, otherwise use defaults
    local frameworks_dir="${CONFIGURED_FRAMEWORKS_DIR:-$znuny_dev_root/frameworks}"
    local packages_dir="${CONFIGURED_PACKAGES_DIR:-$znuny_dev_root/packages}"
    local tools_dir="${CONFIGURED_TOOLS_DIR:-$znuny_dev_root/tools}"

    # Define relative path variables
    local dev_dir_rel="dev"
    local dev_docker_dir_rel="dev/docker"
    local dev_scripts_dir_rel="dev/scripts"
    local dev_env_dir_rel="dev/env"
    local dev_instances_dir_rel="instances"
    local dev_compose_dir_rel="dev/docker/compose"
    local frameworks_dir_rel="frameworks"
    local packages_dir_rel="packages"
    local tools_dir_rel="tools"

    # Define template file paths
    local global_env_template="$znuny_dev_root/dev/templates/env/global.env.template"
    local instance_env_template="$znuny_dev_root/dev/templates/env/instance.env.template"
    local docker_env_template="$znuny_dev_root/dev/templates/env/docker.env.template"

    # Define relative template file paths
    local global_env_template_rel="dev/templates/env/global.env.template"
    local instance_env_template_rel="dev/templates/env/instance.env.template"
    local docker_env_template_rel="dev/templates/env/docker.env.template"

    print_subheader "Configuration Summary:"
    printf "  %-20s %s\n" "ZNUNY_DEV_DIR:" "$znuny_dev_root"
    printf "  %-20s %s\n" "ENV Template file:" "$global_env_template_rel"
    printf "  %-20s %s\n" "ENV file:" ".env"
    echo ""
    print_subheader "Directory Configuration:"
    printf "  %-20s %s\n" "DEV_DIR:" "$dev_dir_rel"
    printf "  %-20s %s\n" "DOCKER_DIR:" "$dev_docker_dir_rel"
    printf "  %-20s %s\n" "SCRIPTS_DIR:" "$dev_scripts_dir_rel"
    printf "  %-20s %s\n" "ENV_DIR:" "$dev_env_dir_rel"
    printf "  %-20s %s\n" "FRAMEWORKS_DIR:" "$frameworks_dir_rel"
    printf "  %-20s %s\n" "PACKAGES_DIR:" "$packages_dir_rel"
    printf "  %-20s %s\n" "TOOLS_DIR:" "$tools_dir_rel"
    echo ""

    # Validate directory structure
    check_directory_structure "$znuny_dev_root"

    # Create backup of existing .env if it exists
    local backup_file="$env_file.backup"
    if [ -f "$env_file" ]; then
        print_status "Creating backup of existing .env file..."
        cp "$env_file" "$backup_file"
    fi

    # Step 1: Generate new .env from template (completely replace current .env)
    print_status "Generating .env file from template (replacing current .env if exists)..."

    # Use sed to replace template variables
    sed -e "s|{{ZNUNY_DEV_DIR}}|$znuny_dev_root|g" \
        -e "s|{{DEV_DIR}}|$dev_dir|g" \
        -e "s|{{DOCKER_DIR}}|$dev_docker_dir|g" \
        -e "s|{{SCRIPTS_DIR}}|$dev_scripts_dir|g" \
        -e "s|{{ENV_DIR}}|$dev_env_dir|g" \
        -e "s|{{INSTANCES_DIR}}|$dev_instances_dir|g" \
        -e "s|{{COMPOSE_DIR}}|$dev_compose_dir|g" \
        -e "s|{{FRAMEWORKS_DIR}}|$frameworks_dir|g" \
        -e "s|{{PACKAGES_DIR}}|$packages_dir|g" \
        -e "s|{{TOOLS_DIR}}|$tools_dir|g" \
        -e "s|{{DEV_DIR_REL}}|$dev_dir_rel|g" \
        -e "s|{{DOCKER_DIR_REL}}|$dev_docker_dir_rel|g" \
        -e "s|{{SCRIPTS_DIR_REL}}|$dev_scripts_dir_rel|g" \
        -e "s|{{ENV_DIR_REL}}|$dev_env_dir_rel|g" \
        -e "s|{{INSTANCES_DIR_REL}}|$dev_instances_dir_rel|g" \
        -e "s|{{COMPOSE_DIR_REL}}|$dev_compose_dir_rel|g" \
        -e "s|{{FRAMEWORKS_DIR_REL}}|$frameworks_dir_rel|g" \
        -e "s|{{PACKAGES_DIR_REL}}|$packages_dir_rel|g" \
        -e "s|{{TOOLS_DIR_REL}}|$tools_dir_rel|g" \
        -e "s|{{GLOBAL_ENV_TEMPLATE}}|$global_env_template|g" \
        -e "s|{{INSTANCE_ENV_TEMPLATE}}|$instance_env_template|g" \
        -e "s|{{DOCKER_ENV_TEMPLATE}}|$docker_env_template|g" \
        -e "s|{{GLOBAL_ENV_TEMPLATE_REL}}|$global_env_template_rel|g" \
        -e "s|{{INSTANCE_ENV_TEMPLATE_REL}}|$instance_env_template_rel|g" \
        -e "s|{{DOCKER_ENV_TEMPLATE_REL}}|$docker_env_template_rel|g" \
        -e "s|{{SETUP_DATE}}|$setup_date|g" \
        "$template_file" > "$env_file"

    # Step 2: Apply all saved variables from backup
    if [ -f "$backup_file" ]; then
        print_status "Applying saved variables from backup..."

        # Read backup file and apply all variables
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

            # Apply variable using the new function
            set_env_variable "$key" "$value"
        done < "$backup_file"

        # Clean up backup
        rm -f "$backup_file"
    fi

    # Verify the file was created
    if [ -f "$env_file" ]; then
        echo ""
        print_status "Location: $env_file"

        # Check if .env is in .gitignore
        local gitignore_file="$znuny_dev_root/.gitignore"
        if [ -f "$gitignore_file" ]; then
            if grep -q "^\.env$" "$gitignore_file"; then
                print_status ".env file is properly ignored by git"
            else
                print_warning ".env file is NOT in .gitignore - consider adding it"
            fi
        else
            print_warning ".gitignore file not found - consider creating one with .env"
        fi

    else
        print_error "Failed to create .env file"
        exit 1
    fi

    print_success "Environment file generation completed!"
}

# Function to setup directories
setup_directories() {

    echo ""
    print_header "Setup Directories"
    print_header "================="
    echo ""

    local env_file="$ZNUNY_DEV_DIR/.env"

    # Default directories
    local default_frameworks_dir="$ZNUNY_DEV_DIR/frameworks"
    local default_packages_dir="$ZNUNY_DEV_DIR/packages"
    local default_tools_dir="$ZNUNY_DEV_DIR/tools"

    # Try to load existing configuration from .env file
    local existing_frameworks_dir=""
    local existing_packages_dir=""
    local existing_tools_dir=""

    if [ -f "$env_file" ]; then
        print_status "Loading existing directory configuration from .env file..."
        existing_frameworks_dir=$(grep "^FRAMEWORKS_DIR=" "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"')
        existing_packages_dir=$(grep "^PACKAGES_DIR=" "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"')
        existing_tools_dir=$(grep "^TOOLS_DIR=" "$env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"')
    fi

    # Use existing values if available, otherwise use defaults
    local current_frameworks_dir="${existing_frameworks_dir:-$default_frameworks_dir}"
    local current_packages_dir="${existing_packages_dir:-$default_packages_dir}"
    local current_tools_dir="${existing_tools_dir:-$default_tools_dir}"

    # Check if we loaded any existing configuration
    local has_existing_config=false
    if [ -n "$existing_frameworks_dir" ] || [ -n "$existing_packages_dir" ] || [ -n "$existing_tools_dir" ]; then
        has_existing_config=true
    fi

    echo ""
    if [ "$has_existing_config" = true ]; then
        print_subheader "Current directory configuration:"
    else
        print_subheader "Default directory configuration:"
    fi

    printf "  %-12s %s\n" "Frameworks:" "$current_frameworks_dir"
    printf "  %-12s %s\n" "Packages" "$current_packages_dir"
    printf "  %-12s %s\n" "Tools:" "$current_tools_dir"
    echo ""

    # Ask user for directory configuration
    read_input "FRAMEWORKS_DIR" "Frameworks directory" "$current_frameworks_dir"
    read_input "PACKAGES_DIR" "Packages directory" "$current_packages_dir"
    read_input "TOOLS_DIR" "Tools directory" "$current_tools_dir"

    # Store configuration for later use in .env generation (FRAMEWORKS_DIR etc. set by read_input)
    # shellcheck disable=SC2153
    export CONFIGURED_FRAMEWORKS_DIR="$FRAMEWORKS_DIR"
    # shellcheck disable=SC2153
    export CONFIGURED_PACKAGES_DIR="$PACKAGES_DIR"
    # shellcheck disable=SC2153
    export CONFIGURED_TOOLS_DIR="$TOOLS_DIR"

    # Save configurations immediately to .env file
    print_status "Saving directory configurations..."
    set_env_variable "FRAMEWORKS_DIR" "$FRAMEWORKS_DIR"
    set_env_variable "PACKAGES_DIR" "$PACKAGES_DIR"
    set_env_variable "TOOLS_DIR" "$TOOLS_DIR"

    set_env_variable "SETUP_DIRECTORIES" "true"

    print_success "Directory configuration completed and saved!"
}

# Function to setup znuny-dev alias
setup_alias() {

    echo ""
    print_header "Setup Global Alias"
    print_header "==================="
    echo ""

    local script_path
    script_path="$(cd "$(dirname "$0")/../.." && pwd)/znuny-dev.sh"

    # Detect current shell using common function
    local -a shell_info=()
    local shell_name=""
    local config_file=""
    read -r -a shell_info <<< "$(detect_shell)"
    shell_name="${shell_info[0]:-}"
    config_file="${shell_info[1]:-}"

    if [ -z "$config_file" ]; then
        print_warning "Could not detect shell type. Skipping alias setup."
        return 1
    fi

    print_status "Setting up 'zd' alias for $shell_name..."

    # Check if alias or function already exists
    if [ -f "$config_file" ] && (grep -q "alias zd=" "$config_file" ); then
        print_warning "Alias 'zd' already exists in $config_file"
        print_status "Updating existing alias..."

        # Remove existing alias, function lines and related comments
        sed -i.bak '/alias zd=/d' "$config_file"
        sed -i.bak '/# Znuny Development Environment/d' "$config_file"
        sed -i.bak '/# Added by znuny environment setup/d' "$config_file"

        # Remove empty lines at the end of the file
        sed -i.bak '/^$/d' "$config_file"
    fi

    # Add alias with absolute path (script works from any CWD via ZNUNY_DEV_DIR)
    {
        echo ""
        echo "# Znuny Development Environment"
        echo "# Added by znuny environment setup on $(date)"
        echo "alias zd='$script_path'"
        echo "alias zd-frameworks='cd $FRAMEWORKS_DIR'"
        echo "alias zd-packages='cd $PACKAGES_DIR'"
        echo "alias zd-tools='cd $TOOLS_DIR'"
    } >> "$config_file"

    print_success "Alias 'zd' added to $config_file"
    print_success "Alias 'zd-frameworks' added to $config_file"
    print_success "Alias 'zd-packages' added to $config_file"
    print_success "Alias 'zd-tools' added to $config_file"
    print_status "You can now use 'zd' instead of './znuny-dev.sh' from anywhere"

    # Store alias status in .env file using env.sh
    set_env_variable "SETUP_ZD_ALIAS" "true"
    print_status "Alias status saved to .env file"
}

# Function to remove global .env
remove_env() {
    echo ""
    print_header "Remove Global .env"
    print_header "==================="
    echo ""
    local env_file="$ZNUNY_DEV_DIR/.env"
    if [ -f "$env_file" ]; then
        if confirm "Do you want to remove the global .env file?" "n"; then
            print_status "Removing global .env file..."
            rm -f "$env_file"
            print_success "Global .env file removed"
        else
            print_status "Skipping .env file removal"
        fi
    else
        print_status "Global .env file not found"
    fi
}

# Function to remove znuny-dev alias
remove_alias() {

    echo ""
    print_header "Remove ZD Alias"
    print_header "==============="
    echo ""

    # Detect current shell using common function
    local -a shell_info=()
    local shell_name=""
    local config_file=""
    read -r -a shell_info <<< "$(detect_shell)"
    shell_name="${shell_info[0]:-}"
    config_file="${shell_info[1]:-}"

    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        if grep -q "zd()" "$config_file" || grep -q "alias zd=" "$config_file"; then
            print_status "Found ZD alias in $config_file"
            if confirm "Do you want to remove the ZD alias?" "n"; then
                # Remove existing alias, function lines and related comments
                sed -i.bak '/alias zd=/d' "$config_file"
                sed -i.bak '/zd()/d' "$config_file"
                sed -i.bak '/# Znuny Development Environment/d' "$config_file"
                sed -i.bak '/# Added by znuny environment setup/d' "$config_file"
                print_success "ZD alias removed from $config_file"

                # Update .env file
                set_env_variable "SETUP_ZD_ALIAS" "false"
            else
                print_status "Skipping ZD alias removal"
            fi
        else
            print_status "No ZD alias found in $config_file"
        fi
    else
        print_status "Shell config file not found: $config_file"
    fi
    echo ""
}

# Function to validate directory structure
check_directory_structure() {
    local znuny_dev_root="$1"
    local dev_dir="$znuny_dev_root/dev"

    print_status "Validating directory structure..."

    # Check for forbidden directories under dev/
    local forbidden_dirs=("packages" "frameworks" "tools")
    local issues_found=false

    for dir in "${forbidden_dirs[@]}"; do
        local forbidden_path="$dev_dir/$dir"
        if [ -d "$forbidden_path" ]; then
            if [ "$issues_found" = false ]; then
                print_warning "Directory structure issues found:"
                issues_found=true
            fi
            print_warning "   ❌ Found forbidden directory: $forbidden_path"
            print_warning "      This directory should be at project root level, not under dev/"
            print_warning "      Expected location: $znuny_dev_root/$dir"
        fi
    done

    if [ "$issues_found" = true ]; then
        echo ""
        print_warning "RECOMMENDATION:"
        print_warning "   Move these directories to the project root level:"
        for dir in "${forbidden_dirs[@]}"; do
            local forbidden_path="$dev_dir/$dir"
            if [ -d "$forbidden_path" ]; then
                print_warning "   mv '$forbidden_path' '$znuny_dev_root/$dir'"
            fi
        done
        echo ""
        print_warning "This will ensure proper project structure and avoid conflicts."
        echo ""
    else
        print_success "Directory structure validation passed."
    fi
}

# Function to set or update a single environment variable in .env file
set_env_variable() {
    local key="$1"
    local value="$2"
    local env_file="$ZNUNY_DEV_DIR/.env"

    # Ensure .env file exists
    if [ ! -f "$env_file" ]; then
        print_error ".env file not found: $env_file"
        return 1
    fi

    # Check if variable already exists (including commented out ones)
    if grep -q "^${key}=" "$env_file" || grep -q "^# ${key}=" "$env_file"; then
        # Replace existing variable (including commented out ones)
        sed -i.bak "s|^#* *${key}=.*|${key}=${value}|" "$env_file"
        rm -f "$env_file.bak"
        print_updated "$key=$value"
    else
        # Add new variable at the end
        echo "${key}=${value}" >> "$env_file"
        print_added "$key=$value"
    fi
}

# Main function
main() {
    local force_regenerate=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --force|-f)
                force_regenerate=true
                shift
                ;;
            --set-var)
                if [ $# -lt 3 ]; then
                    print_error "Usage: --set-var <KEY> <VALUE>"
                    exit 1
                fi
                set_env_variable "$2" "$3"
                exit 0
                ;;
            setup-env)
                if [ "$force_regenerate" = true ]; then
                    ZNUNY_ENV_FORCE_REGENERATE=1 setup_env
                else
                    setup_env
                fi
                exit 0
                ;;
            setup-alias)
                setup_alias
                exit 0
                ;;
            setup-directories)
                setup_directories
                exit 0
                ;;
            remove-env)
                remove_env
                exit 0
                ;;
            remove-alias)
                remove_alias
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

}

# Run main function
main "$@"
