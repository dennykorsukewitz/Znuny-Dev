#!/bin/bash

# Znuny Repository Management Script
# This script handles repository operations: cloning, branch selection, and validation

set -e

# Load common functions
# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

# Load existing environment
load_environment

# Configuration (from global .env, fallback to default path)
FRAMEWORKS_DIR="${FRAMEWORKS_DIR:-$(dirname "$0")/../../frameworks}"

# Function to display usage information
show_usage() {
    print_header "Znuny Repository Management Script"
    print_header "=================================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    print_subheader "Options:"
    print_command "setup-framework [<branch> <directory>]" "Setup Znuny framework (optional: branch, directory name; else interactive)"
    print_command "remove-frameworks" "Remove Znuny framework repositories"
    print_command "setup-tools" "Setup development tools"
    print_command "remove-tools" "Remove development tools"
    print_command "setup-repository-sources" "Setup repository sources"
    print_command "--help" "Show this help message"
    echo ""
    print_subheader "Examples:"
    print_command "$0                              # Setup everything" ""
    print_command "$0 setup-framework              # Interactive: select branch, directory = branch name" ""
    print_command "$0 setup-framework dev          # Clone branch dev to frameworks/dev (no prompt)" ""
    print_command "$0 setup-framework dev Customer # Clone branch dev to frameworks/myprod (no prompt)" ""
    print_command "$0 remove-frameworks            # Remove framework repositories" ""
    print_command "$0 setup-tools                  # Setup development tools only" ""
    print_command "$0 remove-tools                 # Remove development tools" ""
    print_command "$0 setup-repository-sources     # Setup repository sources only" ""
}

# Function to validate framework name
check_framework_name() {
    local name="$1"

    # Check if name is valid (alphanumeric, hyphens, underscores only)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Invalid framework name: $name"
        print_error "Framework name must contain only letters, numbers, hyphens, and underscores"
        return 1
    fi

    # Check if framework already exists
    if [ -d "$FRAMEWORKS_DIR/$name" ]; then
        print_error "Framework '$name' already exists in $FRAMEWORKS_DIR"
        return 1
    fi

    return 0
}

# Function to sort branches according to priority
sort_branches() {
    local branches=("$@")
    local dev_branches=()
    local rel_dev_branches=()
    local rel_branches=()
    local other_branches=()

    # Categorize branches
    for branch in "${branches[@]}"; do
        if [ "$branch" = "dev" ]; then
            dev_branches+=("$branch")
        elif [[ "$branch" =~ ^rel-[0-9]+_[0-9]+-dev$ ]]; then
            rel_dev_branches+=("$branch")
        elif [[ "$branch" =~ ^rel-[0-9]+_[0-9]+$ ]]; then
            rel_branches+=("$branch")
        else
            other_branches+=("$branch")
        fi
    done

    # Sort rel-dev branches descending (newest first)
    local rel_dev_sorted=()
    if [ ${#rel_dev_branches[@]} -gt 0 ]; then
        read_lines_to_array rel_dev_sorted < <(printf '%s\n' "${rel_dev_branches[@]}" | sort -V -r)
    fi
    rel_dev_branches=("${rel_dev_sorted[@]}")

    # Sort rel branches descending (newest first)
    local rel_sorted=()
    if [ ${#rel_branches[@]} -gt 0 ]; then
        read_lines_to_array rel_sorted < <(printf '%s\n' "${rel_branches[@]}" | sort -V -r)
    fi
    rel_branches=("${rel_sorted[@]}")

    # Sort other branches alphabetically
    local other_sorted=()
    if [ ${#other_branches[@]} -gt 0 ]; then
        read_lines_to_array other_sorted < <(printf '%s\n' "${other_branches[@]}" | sort)
    fi
    other_branches=("${other_sorted[@]}")

    # Combine in desired order
    local sorted_branches=()
    sorted_branches+=("${dev_branches[@]}")
    sorted_branches+=("${rel_dev_branches[@]}")
    sorted_branches+=("${rel_branches[@]}")
    sorted_branches+=("${other_branches[@]}")

    printf "%s\n" "${sorted_branches[@]}"
}

# Function to get available branches for repository
get_available_branches() {
    local repo_source="$1"
    local branches=()

    # Try to get branches using git ls-remote
    if check_command git; then
        local remote_branches
        remote_branches=$(git ls-remote --heads "$repo_source" 2>/dev/null | sed 's/.*refs\/heads\///' | sort -u)

        if [ -n "$remote_branches" ]; then
            while IFS= read -r branch; do
                if [ -n "$branch" ]; then
                    branches+=("$branch")
                fi
            done <<< "$remote_branches"
        fi
    fi

    # Add common branches if none found
    if [ ${#branches[@]} -eq 0 ]; then
        branches=("dev" "main" "develop" "rel-7_2" "rel-6_5")
    fi

    # Sort branches according to priority and return as newline-separated string
    sort_branches "${branches[@]}"
}

# Function to select branch interactively
select_branch() {
    local repo_source="$1"
    local default_branch="$2"

    print_status "Fetching available branches from $repo_source..."
    local branches=()
    read_lines_to_array branches < <(get_available_branches "$repo_source")
    if [ ${#branches[@]} -eq 0 ]; then
        print_warning "No branches found, using default: $default_branch"
        echo "$default_branch"
        return
    fi

    print_status "Available branches for $repo_source:"
    for i in "${!branches[@]}"; do
        local marker=""
        if [ "${branches[$i]}" = "$default_branch" ]; then
            marker=" (default)"
        fi
        print_list_item "$((i+1)). ${branches[$i]}$marker"
    done

    local selected_branch=""
    read_input "selected_branch" "Select branch number or enter branch name" "dev"

    # Check if it's a number
    if [[ "$selected_branch" =~ ^[0-9]+$ ]]; then
        local index=$((selected_branch - 1))
        if [ $index -ge 0 ] && [ $index -lt ${#branches[@]} ]; then
            echo "${branches[$index]}"
        else
            print_warning "Invalid selection, using default: $default_branch"
            echo "$default_branch"
        fi
    else
        # Check if the entered branch exists
        for branch in "${branches[@]}"; do
            if [ "$branch" = "$selected_branch" ]; then
                echo "$selected_branch"
                return
            fi
        done

        print_warning "Branch '$selected_branch' not found, using default: $default_branch"
        echo "$default_branch"
    fi
}

# Function to clone repository
clone_repository() {
    local repo_source="$1"
    local target_dir="$2"
    local branch="$3"

    echo ''
    print_status "Cloning repository: $repo_source"
    print_status "Target directory: $FRAMEWORKS_DIR_REL/$(basename "$target_dir")"
    print_status "Branch: $branch"

    # git clone fails with "Unable to read current working directory" if cwd is
    # inside the target (e.g. after rm -rf of an existing checkout you stood in).
    local parent_dir
    parent_dir="$(dirname "$target_dir")"
    case "$(pwd)" in
        "$target_dir"|"$target_dir"/*)
            print_warning "Working directory is inside clone target; switching to $parent_dir"
            cd "$parent_dir" || cd "${ZNUNY_DEV_DIR:-.}" || return 1
            ;;
    esac

    # Check if target directory already exists
    if [ -d "$target_dir" ]; then
        if [ "$(ls -A "$target_dir" 2>/dev/null)" ]; then
            print_warning "Directory $FRAMEWORKS_DIR_REL/$(basename "$target_dir") already exists and is not empty"
            if confirm "Do you want to remove the existing directory and clone fresh?" "n"; then
                print_status "Removing existing directory: $FRAMEWORKS_DIR_REL/$(basename "$target_dir")"
                rm -rf "$target_dir"
            else
                print_status "Skipping clone for $target_dir"
                return 0
            fi
        else
            print_status "Directory $target_dir exists but is empty, proceeding with clone"
        fi
    fi

    # Create target directory
    ensure_directory "$(dirname "$target_dir")"

    # Clone repository. With --depth 1 only the chosen branch exists locally; use CLONE_DEPTH=0 for full clone (all branches).
    local depth_args=()
    if [ -n "${CLONE_DEPTH:-}" ] && [ "${CLONE_DEPTH}" = "0" ]; then
        print_status "Full clone (all branches) – CLONE_DEPTH=0"
    else
        depth_args=(--depth 1)
    fi
    if git clone --branch "$branch" "${depth_args[@]}" "$repo_source" "$target_dir"; then
        # Allow fetching all branches (clone only sets fetch for the checked-out branch)
        git -C "$target_dir" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
        print_success "Repository cloned successfully"
    else
        print_error "Failed to clone repository"
        return 1
    fi
}

# Function to setup repository sources
setup_repository_sources() {

    echo ""
    print_header "Setting up repository sources"
    print_header "=============================="
    echo ""

    # Use existing values if available, otherwise use defaults
    local znuny_source="${REPO_SOURCE_ZNUNY}"
    local module_tools_source="${REPO_SOURCE_MODULE_TOOLS}"
    local fred_source="${REPO_SOURCE_FRED}"
    local code_policy_source="${REPO_SOURCE_CODE_POLICY}"

    echo "Please configure the repository sources for each component."
    echo ""

    # Framework repositories
    print_subheader "Framework Repositories:"
    read_input "REPO_SOURCE_ZNUNY" "Znuny Framework URL" "$znuny_source"

    # Development tools (FRED first)
    print_subheader "Development Tools:"
    read_input "REPO_SOURCE_FRED" "Fred URL" "$fred_source"
    read_input "REPO_SOURCE_MODULE_TOOLS" "Module-Tools URL" "$module_tools_source"
    read_input "REPO_SOURCE_CODE_POLICY" "ZnunyCodePolicy URL" "$code_policy_source"
    echo ""


    echo ""
    print_subheader "Repository sources configuration:"
    printf "  %-20s %s\n" "Fred:" "$REPO_SOURCE_FRED"
    printf "  %-20s %s\n" "Module-Tools:" "$REPO_SOURCE_MODULE_TOOLS"
    printf "  %-20s %s\n" "ZnunyCodePolicy:" "$REPO_SOURCE_CODE_POLICY"
    printf "  %-20s %s\n" "Znuny Framework:" "$REPO_SOURCE_ZNUNY"
    echo ""

    # Save to environment file
    print_status "Saving repository sources to environment file..."

    # Call env.sh with --set-var for each repository source variable
    for var in "${!REPO_SOURCE_@}"; do
        local value="${!var}"

        # Use env.sh --set-var to set the variable
        "$(dirname "$0")/env.sh" --set-var "$var" "$value" 2>/dev/null || {
            print_warning "Could not set variable $var using env.sh"
        }
    done

    print_success "Repository sources saved successfully!"
}

# Function to setup Znuny framework repositories
# Optional: $1 = branch, $2 = directory name (in FRAMEWORKS_DIR); if both given: no prompt
setup_framework() {

    local branch="$1"
    local dir="$2"

    echo ""
    print_header "Setting up Znuny Framework repositories"
    print_header "======================================="

    # Use configured URL or fallback to default
    local znuny_source="${REPO_SOURCE_ZNUNY:-https://github.com/znuny/znuny.git}"

    # Create frameworks directory if it doesn't exist
    mkdir -p "$FRAMEWORKS_DIR"

    # Branch + directory given: clone once, no branch selection
    if [ -n "$branch" ] && [ -n "$dir" ]; then
        if ! check_framework_name "$dir"; then
            return 1
        fi
        local target_dir
        target_dir=${dir//[^a-zA-Z0-9._-]/_}
        clone_repository "$znuny_source" "$FRAMEWORKS_DIR/$target_dir" "$branch"
        print_success "Znuny Framework repositories setup completed!"
        return 0
    fi

    # Branch only given: clone that branch, directory = sanitized branch name, no branch selection
    if [ -n "$branch" ]; then
        local target_dir
        target_dir=${branch//[^a-zA-Z0-9._-]/_}
        if [ -d "$FRAMEWORKS_DIR/$target_dir" ]; then
            print_warning "Directory $FRAMEWORKS_DIR/$target_dir already exists, skipping."
            return 0
        fi
        clone_repository "$znuny_source" "$FRAMEWORKS_DIR/$target_dir" "$branch"
        print_success "Znuny Framework repositories setup completed!"
        return 0
    fi

    # No branch given: interactive – fetch and show branches
    local common_branches=("dev" "rel-7_3-dev" "rel-6_5-dev"  )
    print_status "Fetching available branches from $znuny_source..."
    local available_branches
    available_branches=$(get_available_branches "$znuny_source")

    if [ -z "$available_branches" ]; then
        print_warning "Could not fetch branches from remote. Using common branches."
        available_branches=$(printf "%s\n" "${common_branches[@]}")
    fi

    echo "Available branches:"
    local branch_array=()
    local i=1
    local b
    while IFS= read -r b; do
        if [ -n "$b" ]; then
            echo "  $i) $b"
            branch_array+=("$b")
            ((i++))
        fi
    done <<< "$available_branches"
    echo ""

    # Interactive: select branch(es), directory = branch name
    local selected_branches=()
    local selected_dirs=()

    echo "Select branch:"
    read_input "dev_branch_num" "Branch number" "1"
    local dev_branch="${branch_array[$((dev_branch_num-1))]:-dev}"
    selected_branches+=("$dev_branch")
    selected_dirs+=("${dev_branch//[^a-zA-Z0-9._-]/_}")

    echo ""
    if confirm "Do you want to clone additional Znuny versions?" "n"; then
        local additional_count="0"
        read_input "additional_count" "How many additional versions?" "0"
        for ((i=1; i<=additional_count; i++)); do
            echo "Select branch for additional version $i:"
            read_input "additional_branch_num" "Branch number" ""
            local additional_branch="${branch_array[$((additional_branch_num-1))]}"
            if [ -n "$additional_branch" ]; then
                selected_branches+=("$additional_branch")
                selected_dirs+=("${additional_branch//[^a-zA-Z0-9._-]/_}")
            fi
        done
    fi

    # Clone repositories
    local clone_total=${#selected_branches[@]}
    local clone_step=0
    for i in "${!selected_branches[@]}"; do
        local branch="${selected_branches[$i]}"
        local target_dir="${selected_dirs[$i]}"
        clone_step=$((clone_step + 1))
        show_progress "$clone_step" "$clone_total" "Clone framework"
        if [ -d "$FRAMEWORKS_DIR/$target_dir" ]; then
            print_warning "Directory $FRAMEWORKS_DIR/$target_dir already exists, skipping."
            continue
        fi
        clone_repository "$znuny_source" "$FRAMEWORKS_DIR/$target_dir" "$branch"
    done
    printf '\n'

    print_success "Znuny Framework repositories setup completed!"
}

# Function to setup development tools
setup_tools() {

    echo ""
    print_header "Setting up development tools"
    print_header "============================"
    echo ""

    # Use configured URLs or fallback to defaults
    local module_tools_source="${REPO_SOURCE_MODULE_TOOLS:-https://github.com/znuny/module-tools.git}"
    local fred_source="${REPO_SOURCE_FRED:-https://github.com/znuny/Fred.git}"
    local code_policy_source="${REPO_SOURCE_CODE_POLICY:-https://github.com/znuny/ZnunyCodePolicy.git}"

    # Create tools directory if it doesn't exist
    mkdir -p "$TOOLS_DIR"

    # Clone development tools using configured URLs (use default branches)
    local tools_total=3
    show_progress 1 "$tools_total" "Cloning tools"
    print_subheader "Cloning module-tools..."
    clone_repository "$module_tools_source" "$TOOLS_DIR/module-tools" "dev"
    echo ""

    show_progress 2 "$tools_total" "Cloning tools"
    print_subheader "Cloning Fred..."
    clone_repository "$fred_source" "$TOOLS_DIR/Fred" "dev"
    echo ""

    show_progress 3 "$tools_total" "Cloning tools"
    print_subheader "Cloning ZnunyCodePolicy..."
    clone_repository "$code_policy_source" "$TOOLS_DIR/ZnunyCodePolicy" "dev"
    echo ""

    printf '\n'
    print_success "Development tools setup completed!"
}

setup_packages() {

    echo ""
    print_header "Setting up packages"
    print_header "==================="
    echo ""

    # Create packages directory if it doesn't exist
    mkdir -p "$PACKAGES_DIR"

    # TODO: PACKAGE_SOURCE_LIST needs to be a list of packages


    # Clone packages using PACKAGE_SOURCE_LIST* variables from .env (default branch: dev)
    local package_vars=()
    for var in "${!PACKAGE_SOURCE_LIST@}"; do
        package_vars+=("$var")
    done

    if [ ${#package_vars[@]} -gt 0 ]; then
        print_subheader "Cloning packages..."
        echo ""
        local pkg_total=${#package_vars[@]}
        local pkg_step=0
        for var in "${package_vars[@]}"; do
            pkg_step=$((pkg_step + 1))
            show_progress "$pkg_step" "$pkg_total" "Cloning packages"
            local package_name="${var#PACKAGE_SOURCE_LIST}"
            local package_url="${!var}"
            if [ -n "$package_url" ]; then
                print_subheader "Cloning package: $package_name"
                clone_repository "$package_url" "$PACKAGES_DIR/$package_name" "dev"
                echo ""
            else
                print_warning "Skipping package '$package_name': URL is empty"
            fi
        done
        printf '\n'
    else
        print_status "No PACKAGE_SOURCE_LIST variables found in .env – no packages to clone"
    fi

    print_success "Packages setup completed!"
}

# Function to remove packages
remove_packages() {

    echo ""
    print_header "Remove Packages"
    print_header "==============="
    echo ""

    if [ -d "$PACKAGES_DIR" ]; then
        local packages=()
        read_lines_to_array packages < <(find "$PACKAGES_DIR" -maxdepth 1 -type d -not -name "packages" -not -name "." | sed 's|.*/||' | sort)
        if [ ${#packages[@]} -gt 0 ]; then
            print_status "Found packages"
            for package in "${packages[@]}"; do
                print_list_item "$package"
            done
            echo ""
            local rm_total=${#packages[@]}
            local rm_step=0
            for package in "${packages[@]}"; do
                rm_step=$((rm_step + 1))
                show_progress "$rm_step" "$rm_total" "Remove packages"
                if confirm "Remove package '$package'?" "n"; then
                    print_status "Removing package: $package"
                    rm -rf "${PACKAGES_DIR:?}/$package"
                    print_success "Package '$package' removed!"
                else
                    print_status "Skipping package '$package'"
                fi
            done
            printf '\n'
            print_success "Package removal completed!"
        else
            print_status "No packages found in $PACKAGES_DIR"
        fi
    else
        print_status "Packages directory not found: $PACKAGES_DIR"
    fi
    echo ""
}

# Function to remove development tools
remove_tools() {

    echo ""
    print_header "Remove Development Tools"
    print_header "========================"
    echo ""

    if [ -d "$TOOLS_DIR" ]; then
        local tools=()
        read_lines_to_array tools < <(find "$TOOLS_DIR" -maxdepth 1 -type d -not -name "tools" -not -name "." | sed 's|.*/||' | sort)
        if [ ${#tools[@]} -gt 0 ]; then
            print_status "Found tools"
            for tool in "${tools[@]}"; do
                print_list_item "$tool"
            done
            echo ""
            local rm_total=${#tools[@]}
            local rm_step=0
            for tool in "${tools[@]}"; do
                rm_step=$((rm_step + 1))
                show_progress "$rm_step" "$rm_total" "Remove tools"
                if confirm "Remove tool '$tool'?" "n"; then
                    print_status "Removing tool: $tool"
                    rm -rf "${TOOLS_DIR:?}/$tool"
                    print_success "Tool '$tool' removed!"
                else
                    print_status "Skipping tool '$tool'"
                fi
            done
            printf '\n'
            print_success "Tool removal completed!"
        else
            print_status "No tools found in $TOOLS_DIR"
        fi
    else
        print_status "Tools directory not found: $TOOLS_DIR"
    fi
    echo ""
}

# Function to remove frameworks
remove_frameworks() {

    echo ""
    print_header "Remove Frameworks"
    print_header "========================"
    echo ""

    local frameworks_dir="${FRAMEWORKS_DIR:-$ZNUNY_DEV_DIR/frameworks}"
    if [ -d "$frameworks_dir" ]; then
        local frameworks=()
        read_lines_to_array frameworks < <(find "$frameworks_dir" -maxdepth 1 -type d -not -name "frameworks" -not -name "." | sed 's|.*/||' | sort)
        if [ ${#frameworks[@]} -gt 0 ]; then
            print_status "Found frameworks:"
            for framework in "${frameworks[@]}"; do
                print_list_item "$framework"
            done
            echo ""
            local rm_total=${#frameworks[@]}
            local rm_step=0
            for framework in "${frameworks[@]}"; do
                rm_step=$((rm_step + 1))
                show_progress "$rm_step" "$rm_total" "Remove frameworks"
                if confirm "Remove framework '$framework'?" "n"; then
                    print_status "Removing framework: $framework"
                    rm -rf "${frameworks_dir:?}/$framework"
                    print_success "Framework '$framework' removed!"
                else
                    print_status "Skipping framework '$framework'"
                fi
            done
            printf '\n'
            print_success "Framework removal completed!"
        else
            print_status "No frameworks found in $frameworks_dir"
        fi
    else
        print_status "Frameworks directory not found: $frameworks_dir"
    fi
    echo ""
}

# Main function
main() {
    # Check if Git is installed
    if ! check_command git; then
        print_error "Git is not installed. Please install Git first."
        exit 1
    fi

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            setup-repository-sources)
                setup_repository_sources
                exit 0
                ;;
            setup-framework)
                shift
                setup_framework "$@"
                exit 0
                ;;
            setup-tools)
                setup_tools
                exit 0
                ;;
            setup-packages)
                setup_packages
                exit 0
                ;;
            remove-frameworks)
                remove_frameworks
                exit 0
                ;;
            remove-tools)
                remove_tools
                exit 0
                ;;
            remove-packages)
                remove_packages
                exit 0
                ;;
            --help)
                show_usage
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

# Run main function only if script is called directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi