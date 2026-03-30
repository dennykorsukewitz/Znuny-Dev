#!/bin/bash

# Znuny Development Environment - Common Functions
# This script contains shared utility functions used across all setup scripts


# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
ORANGE='\033[0;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ========================================
# Bash 3.2 compatibility (macOS /bin/bash has no mapfile/readarray)
# ========================================
# Read newline-separated stdin into the array named $1 (identifier only).
read_lines_to_array() {
    local _r2a_name="$1"
    eval "${_r2a_name}=()"
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        [ -n "$line" ] && eval "${_r2a_name}+=(\"\$line\")"
    done
}

# ========================================
# Print Functions
# ========================================
# Function to print colored output
print() {
    echo -e "${NC}$1"
}

print_list() {
    local items=("$@")

    for item in "${items[@]}"; do
        print_list_item "$item"
    done
}

print_list_item() {
    printf "${NC}- %s\n" "$1"
}

print_table() {
    printf "  %-25s %s\n" "$1" "$2"
}

print_added() {
    printf "${GREEN}[ADDED]${NC} %s\n" "$1"
}

print_updated() {
    printf "${GREEN}[UPDATED]${NC} %s\n" "$1"
}

print_todo() {
    printf "${MAGENTA}[TODO]${NC}    %s\n" "$1"
}

print_status() {
    printf "${BLUE}[INFO]${NC}    %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

print_ok() {
    printf "${GREEN}[OK]${NC}      %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC}   %s\n" "$1"
}

print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_header() {
    echo -e "${CYAN}$1${NC}"
}

print_subheader() {
    echo -e "${ORANGE}$1${NC}"
}

print_command() {
    local command="$1"
    local description="$2"
    printf "  ${GREEN}%-42s${NC} %s\n" "$command" "$description"
}

# ========================================
# Input Functions
# ========================================

# Function to read user input with default value
read_input() {
    local var_name="$1"
    local prompt="$2"
    local default="$3"

    if [ -n "$default" ]; then
        printf "${MAGENTA}[ENTER] %s [%s]: " "$prompt" "$default"
        read -r input
        eval "$var_name=\"\${input:-$default}\""
    else
        printf "${MAGENTA}[ENTER] %s: " "$prompt"
        read -r input
        eval "$var_name=\"$input\""
    fi
}

# Function to read password input
read_password() {
    local var_name="$1"
    local prompt="$2"
    local default="$3"

    if [ -n "$default" ]; then
        printf "${MAGENTA}[ENTER] %s [%s]: " "$prompt" "$default"
        read -r -s password
        password="${password:-$default}"
    else
        printf "${MAGENTA}[ENTER] %s: " "$prompt"
        read -r -s password
    fi
    eval "$var_name=\"$password\""
}

# Function to wait for user confirmation
confirm() {
    local message="$1"
    local default="${2:-y}"

    # Prompts must go to stderr so they stay visible inside $(command_substitution) (stdout is captured).
    if [ "$default" = "y" ]; then
        printf "${MAGENTA}[CONFIRM] %s [Y/n]: " "$message" >&2
        read -r response
        response="${response:-y}"
    else
        printf "${MAGENTA}[CONFIRM] %s [y/N]: " "$message" >&2
        read -r response
        response="${response:-n}"
    fi

    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ========================================
# Check Functions
# ========================================
# Function to check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Prefer Docker Compose V2 (docker compose), fall back to standalone docker-compose
get_compose_cmd() {
    if docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# Get latest version and latest commit from git remote.
# Usage: get_latest_version --repo <owner/repo>   OR   get_latest_version --path <path-to-local-repo>
# Output: two lines (always):
#   Line 1: latest version (tag without 'v') or "undef"
#   Line 2: latest commit (short hash of remote HEAD) or "undef"
get_latest_version() {
    local repo=""
    local path=""
    local latest_version="undef"
    local latest_commit="undef"
    local remote_head

    if ! command -v git >/dev/null 2>&1; then
        echo "undef"
        echo "undef"
        return 1
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            --repo)
                repo="${2:-}"
                shift 2
                ;;
            --path)
                path="${2:-}"
                shift 2
                ;;
            *)
                echo "undef"
                echo "undef"
                return 1
                ;;
        esac
    done

    if [ -n "$path" ]; then
        if [ -d "$path" ] && [ -d "$path/.git" ]; then
            path=$(cd "$path" 2>/dev/null && pwd)
            if [ -n "$path" ]; then
                latest_version=$(git -C "$path" ls-remote --tags origin 2>/dev/null | grep -v '\^{}' | sed 's|.*refs/tags/||' | sed 's/^v//i' | sort -V 2>/dev/null | tail -1)
                remote_head=$(git -C "$path" ls-remote origin HEAD 2>/dev/null | awk '{print $1}')
                [ -n "$remote_head" ] && latest_commit="${remote_head:0:7}"
            fi
        fi
    elif [ -n "$repo" ]; then
        latest_version=$(git ls-remote --tags "https://github.com/${repo}.git" 2>/dev/null | grep -v '\^{}' | sed 's|.*refs/tags/||' | sed 's/^v//i' | sort -V 2>/dev/null | tail -1)
        remote_head=$(git ls-remote "https://github.com/${repo}.git" HEAD 2>/dev/null | awk '{print $1}')
        [ -n "$remote_head" ] && latest_commit="${remote_head:0:7}"
    fi

    echo "${latest_version:-undef}"
    echo "${latest_commit:-undef}"
    return 0
}

# Function to check if Docker is running
check_docker() {
    if ! check_command docker; then
        print_error "Docker is not installed."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running or not accessible. Please start Docker first."
        exit 1
    fi

    # Get Docker daemon status
    local docker_status
    docker_status=$(docker info --format '{{.ServerVersion}}' 2>/dev/null)
    if [ -n "$docker_status" ]; then
        print_success "Docker is running (Version: $docker_status)"
    else
        print_warning "Docker daemon is not responding properly."
        exit 1
    fi
}

# Function to load environment variables from .env file
load_environment() {
    # Define ZNUNY_DEV_DIR if not already set
    if [ -z "${ZNUNY_DEV_DIR:-}" ]; then
        # Get absolute path to project root (common.sh is in dev/scripts/, so go up 2 levels)
        local script_dir
        script_dir="$(cd "$(dirname "$0")" && pwd)"
        ZNUNY_DEV_DIR="$(dirname "$(dirname "$script_dir")")"
    fi

    local env_file="$ZNUNY_DEV_DIR/.env"

    if [ -f "$env_file" ]; then
        # shellcheck disable=SC1090
        source "$env_file"
    fi

    # Load configs/instance/my.env last so it overrides global .env
    local my_env="$ZNUNY_DEV_DIR/configs/instance/my.env"
    if [ -f "$my_env" ]; then
        # shellcheck disable=SC1090
        source "$my_env"
    fi
}

# Set ZD_CMD for help/examples: "zd" when alias is set, else "./znuny-dev.sh". Only set if not already set.
set_zd_cmd() {
    if [ -z "${ZD_CMD:-}" ]; then
        if [ "${SETUP_ZD_ALIAS:-}" = "true" ]; then
            ZD_CMD="zd"
        elif check_zd_alias_configured; then # check_zd_alias_configured to see if the alias is already set
            ZD_CMD="zd"
        else
            ZD_CMD="./znuny-dev.sh"
        fi
    fi
}

# Function to detect current shell and return config file path
detect_shell() {
    local shell_name=""
    local config_file=""

    # Detect current shell - prioritize SHELL environment variable
    case "$SHELL" in
        *zsh*)
            shell_name="zsh"
            config_file="$HOME/.zshrc"
            ;;
        *bash*)
            shell_name="bash"
            config_file="$HOME/.bashrc"
            ;;
        *)
            # Fallback to shell version detection
            if [ -n "$ZSH_VERSION" ]; then
                shell_name="zsh"
                config_file="$HOME/.zshrc"
            elif [ -n "$BASH_VERSION" ]; then
                shell_name="bash"
                config_file="$HOME/.bashrc"
            else
                shell_name="unknown"
                config_file=""
            fi
            ;;
    esac

    # Return shell name and config file (space-separated)
    echo "$shell_name $config_file"
}

# Function to check if zd alias/function is already configured in shell config
check_zd_alias_configured() {
    local shell_line shell_info
    shell_line=$(detect_shell)
    read -r -a shell_info <<< "$shell_line"
    local config_file="${shell_info[1]}"

    if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
        return 1
    fi

    if grep -q "alias zd=" "$config_file" 2>/dev/null || grep -q "zd()" "$config_file" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Function to create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        print_status "Creating directory: $dir"
        mkdir -p "$dir"
    fi
}

# Function to backup file before modification
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak"
        print_status "Backed up $file to ${file}.bak"
    fi
}

# Function to validate URL format
check_url() {
    local url="$1"
    if [[ $url =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Wait until URL is reachable (e.g. after starting a container)
# Usage: wait_for_url <url> [label] [max_attempts]
wait_for_url() {
    local url="$1"
    local label="${2:-service}"
    local max_attempts="${3:-60}"
    local attempt=1
    local code

    if ! command -v curl >/dev/null 2>&1; then
        print_warning "curl not found, skipping wait_for_url."
        return 0
    fi

    print_status "Waiting for $label to be ready at $url..."
    while [ $attempt -le "$max_attempts" ]; do
        code=$(curl -s -o /dev/null -w "%{http_code}" -L --connect-timeout 2 --max-time 5 "$url" 2>/dev/null || echo "000")
        code="${code//[^0-9]/}"
        if [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
            print_success "$label is ready."
            return 0
        fi
        sleep 2
        attempt=$((attempt + 1))
    done
    print_warning "Timeout waiting for $label at $url (tried ${max_attempts} times, last code: ${code:-none})."
    return 1
}

# Function to validate email format
check_email() {
    local email="$1"
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to show progress bar
show_progress() {
    local current="${1:-0}"
    local total="${2:-0}"
    local description="${3:-Progress}"

    if [ "$total" -le 0 ] 2>/dev/null; then
        return 0
    fi

    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))

    printf "\r${BLUE}[INFO]${NC} %s: [" "$description"
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' ' '
    printf "] %d%% (%d/%d)" "$percent" "$current" "$total"
}



# Function to detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            echo "macos"
            ;;
        Linux*)
            echo "linux"
            ;;
        CYGWIN*|MINGW32*|MSYS*|MINGW*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to get available frameworks
get_available_frameworks() {
    local frameworks=()

    if [ -d "$FRAMEWORKS_DIR" ]; then
        for framework_dir in "$FRAMEWORKS_DIR"/*; do
            if [ -d "$framework_dir" ]; then
                local framework_name
                framework_name=$(basename "$framework_dir")
                frameworks+=("$framework_name")
            fi
        done
    fi

    printf '%s\n' "${frameworks[@]}"
}

# Resolve user input to actual framework directory name (case-insensitive).
# Echoes the real directory name (e.g. TSystems) or the input if no match.
resolve_framework_name() {
    local input="$1"
    local frameworks=()
    read_lines_to_array frameworks < <(get_available_frameworks)
    local input_lc
    input_lc=$(echo "$input" | tr '[:upper:]' '[:lower:]')
    for f in "${frameworks[@]}"; do
        if [ "$(echo "$f" | tr '[:upper:]' '[:lower:]')" = "$input_lc" ]; then
            echo "$f"
            return 0
        fi
    done
    echo "$input"
}

# Lowercase framework name for Docker (image/container/service names must be lowercase).
get_framework_slug() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Function to get available instances (subdirs of INSTANCES_DIR with NAME.env)
get_available_instances() {
    local instances=()
    # INSTANCES_DIR from load_environment / .env
    # shellcheck disable=SC2153
    local instances_dir="$INSTANCES_DIR"

    if [ -d "$instances_dir" ]; then
        for d in "$instances_dir"/*/; do
            [ -d "$d" ] || continue
            local instance_name
            instance_name=$(basename "$d")
            [ -f "$d/$instance_name.env" ] || continue
            instances+=("$instance_name")
        done
    fi

    printf '%s\n' "${instances[@]}" | sort
}

# Export functions for use in other scripts
export -f load_environment
export -f set_zd_cmd

export -f print_updated
export -f print_added
export -f print_todo
export -f print_status
export -f print_success
export -f print_warning
export -f print_error
export -f read_input
export -f read_password
export -f confirm

export -f check_command
export -f check_docker
export -f check_url
export -f check_email
export -f wait_for_url

export -f ensure_directory
export -f backup_file
export -f show_progress

export -f detect_os
export -f detect_shell
export -f read_lines_to_array

export -f get_available_frameworks
export -f get_available_instances
export -f resolve_framework_name
export -f get_framework_slug
export -f get_compose_cmd
export -f get_latest_version