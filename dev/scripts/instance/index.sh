#!/bin/bash

# Znuny Framework Index Management
# This script manages framework index allocation and tracking

set -e

# Load common functions
if [ -f "$(dirname "$0")/../common.sh" ]; then
    # shellcheck source=../common.sh
    source "$(dirname "$0")/../common.sh"
fi

# Load environment
load_environment

# ========================================
# Framework Index Functions
# ========================================

# Function to get framework index from instance .env file
get_instance_index() {
    local framework="$1"
    # INSTANCES_DIR from load_environment
    # shellcheck disable=SC2153
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
    local index=""

    # Try to get index from instance .env file first
    if [ -f "$instance_env_file" ]; then
        index=$(grep "^FRAMEWORK_INDEX=" "$instance_env_file" | cut -d'=' -f2)
        if [ -n "$index" ]; then
            echo "$index"
            return 0
        fi
    fi

    echo ""
}

# Function to get used framework indices from global .env
get_used_instance_indices() {
    local env_file="$ZNUNY_DEV_DIR/.env"

    if [ ! -f "$env_file" ]; then
        echo ""
        return
    fi

    local raw
    raw=$(grep "^USED_FRAMEWORK_INDICES=" "$env_file" | cut -d'=' -f2 | tr -d '"')
    sort_used_indices "$raw"
}

# Output comma-separated list of indices sorted numerically (e.g. "2,0" -> "0,2")
sort_used_indices() {
    local list="$1"
    if [ -z "$list" ]; then
        echo ""
        return
    fi
    echo "$list" | tr ',' '\n' | sort -n | paste -sd ',' -
}

# Function to check if framework index is in use
is_instance_index_in_use() {
    local index="$1"

    # Check if index is used in global .env
    local used_indices
    used_indices=$(get_used_instance_indices)
    if [ -n "$used_indices" ]; then
        for used_index in $(echo "$used_indices" | tr ',' ' '); do
            if [ "$used_index" = "$index" ]; then
                return 0  # Index is in use
            fi
        done
    fi

    # Check if index is used by any existing instance
    # shellcheck disable=SC2153
    local instances_dir="$INSTANCES_DIR"
    if [ -d "$instances_dir" ]; then
        for instance_dir in "$instances_dir"/*/; do
            [ -d "$instance_dir" ] || continue
            local instance_name
            instance_name=$(basename "$instance_dir")
            local env_file="$instance_dir/$instance_name.env"
            if [ -f "$env_file" ]; then
                local used_index
                used_index=$(grep "^FRAMEWORK_INDEX=" "$env_file" | cut -d'=' -f2)
                if [ "$used_index" = "$index" ]; then
                    return 0  # Index is in use
                fi
            fi
        done
    fi

    return 1  # Index is free
}

# Function to find next available framework index
find_next_available_instance_index() {
    # Hardcoded index range (0-99 should be enough for most use cases)
    local start_index=0
    local end_index=99

    # Find first available index in range
    for index in $(seq "$start_index" "$end_index"); do
        if ! is_instance_index_in_use "$index"; then
            echo "$index"
            return 0
        fi
    done

    print_error "No available framework indices in range $start_index-$end_index"
    return 1
}

# Function to set a framework index as used in global .env
set_instance_index_used() {
    local index="$1"
    local env_file="$ZNUNY_DEV_DIR/.env"

    if [ ! -f "$env_file" ]; then
        print_error "Global .env file not found: $env_file"
        return 1
    fi

    # Get current used indices
    local used_indices
    used_indices=$(get_used_instance_indices)

    # Add new index to used list
    if [ -n "$used_indices" ]; then
        used_indices="$used_indices,$index"
    else
        used_indices="$index"
    fi
    used_indices=$(sort_used_indices "$used_indices")

    # Update global .env file
    sed -i.bak "s/^USED_FRAMEWORK_INDICES=.*/USED_FRAMEWORK_INDICES=$used_indices/" "$env_file"

    # Remove backup file
    rm -f "$env_file.bak"

    print_status "Set framework index $index as used in global configuration"
}

# Function to unset a framework index as used in global .env
unset_instance_index_used() {
    local index="$1"
    local env_file="$ZNUNY_DEV_DIR/.env"

    if [ ! -f "$env_file" ]; then
        print_error "Global .env file not found: $env_file"
        return 1
    fi

    # Get current used indices
    local used_indices
    used_indices=$(get_used_instance_indices)

    if [ -n "$used_indices" ]; then
        # Remove index from used list
        local new_used_indices=""
        for used_index in $(echo "$used_indices" | tr ',' ' '); do
            if [ "$used_index" != "$index" ]; then
                if [ -n "$new_used_indices" ]; then
                    new_used_indices="$new_used_indices,$used_index"
                else
                    new_used_indices="$used_index"
                fi
            fi
        done
        new_used_indices=$(sort_used_indices "$new_used_indices")

        # Update global .env file
        sed -i.bak "s/^USED_FRAMEWORK_INDICES=.*/USED_FRAMEWORK_INDICES=$new_used_indices/" "$env_file"

        # Remove backup file
        rm -f "$env_file.bak"

        print_status "Unset framework index $index as used in global configuration"
    fi
}

# Rewrite USED_FRAMEWORK_INDICES in global .env from existing instances only (covers manual deletes / drift).
sync_indices() {
    local env_file="$ZNUNY_DEV_DIR/.env"

    if [ ! -f "$env_file" ]; then
        print_error "Global .env file not found: $env_file"
        return 1
    fi

    local raw_indices=""
    # shellcheck disable=SC2153
    local instances_dir="$INSTANCES_DIR"

    if [ -d "$instances_dir" ]; then
        for instance_dir in "$instances_dir"/*/; do
            [ -d "$instance_dir" ] || continue
            local instance_name
            instance_name=$(basename "$instance_dir")
            local inst_env="$instance_dir/$instance_name.env"
            if [ -f "$inst_env" ]; then
                local idx
                idx=$(grep "^FRAMEWORK_INDEX=" "$inst_env" 2>/dev/null | cut -d'=' -f2- | tr -d ' "')
                if [ -n "$idx" ]; then
                    if [ -n "$raw_indices" ]; then
                        raw_indices="$raw_indices,$idx"
                    else
                        raw_indices="$idx"
                    fi
                fi
            fi
        done
    fi

    local new_list=""
    if [ -n "$raw_indices" ]; then
        new_list=$(echo "$raw_indices" | tr ',' '\n' | grep -v '^$' | sort -nu | paste -sd ',' -)
    fi

    sed -i.bak "s/^USED_FRAMEWORK_INDICES=.*/USED_FRAMEWORK_INDICES=$new_list/" "$env_file"
    rm -f "$env_file.bak"

    print_success "USED_FRAMEWORK_INDICES synced from instances: ${new_list:-<empty>}"
    return 0
}

