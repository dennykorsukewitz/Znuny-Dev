#!/bin/bash

# Znuny instance status: human-readable output and JSON helpers (sourced by instance.sh).
# Dashboard JSON entry: dev/scripts/instance/status-json.sh

set -e

# ========================================
# Instance Status Functions
# ========================================

# Function to handle status command with argument parsing
show_status() {
    # Default values
    local verbose_mode=false
    local show_header=true
    local framework=""
    local json_output=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                verbose_mode=true
                shift
                ;;
            --no-header)
                show_header=false
                shift
                ;;
            --json)
                json_output=true
                shift
                ;;
            *)
                if [ -z "$framework" ]; then
                    framework="$1"
                else
                    print_error "Unknown option: $1"
                    echo ""
                    echo "Usage:"
                    print_command "${ZD_CMD:-./znuny-dev.sh} status [framework] [--verbose|-v] [--no-header] [--json]"
                    return 1
                fi
                shift
                ;;
        esac
    done

    if [[ "$json_output" == "true" ]]; then
        emit_status_json_collection "$framework" "$verbose_mode"
        return 0
    fi

    # Show status for all or specific instance
    if [ -z "$framework" ] || [ "$framework" = "all" ]; then
        show_all_instance_status "$verbose_mode" "$show_header"
    else
        show_instance_status "$framework" "$verbose_mode" "$show_header"
    fi
}

# Function to show instance status
show_instance_status() {
    local framework="$1"
    local verbose_mode="${2:-false}"
    local show_header="${3:-true}"
    local container_name
    container_name=$(get_instance_container_name "$framework")
    local port
    port=$(get_instance_port "$framework")
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"

    # Check if environment file exists first
    if [ ! -f "$instance_env_file" ]; then
        print_error "Framework '$framework' not found"
        print_status "Environment file not found: $instance_env_file"

        echo ""
        show_all_frameworks
        return 1
    fi

    # Show header if requested
    if [[ "$show_header" == "true" ]]; then
        print_header "Instance Status: $framework"
        print_header "=========================="
        echo ""
    fi

    # Check container status first to determine the icon
    local instance_icon="🟡"
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$container_name"; then
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health-check")
        if [[ "$health_status" == "healthy" ]]; then
            instance_icon="✅"
        elif [[ "$health_status" == "unhealthy" ]]; then
            instance_icon="⚠️"
        else
            instance_icon="✅"
        fi
    fi

    print "   $instance_icon $framework $port"
    print "      🚦 Status:"

    # Check container status
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "$container_name"; then
        local status
        status=$(docker ps --format "{{.Status}}" --filter "name=$container_name")
        # Check if container is healthy
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health-check")
        if [[ "$health_status" == "healthy" ]]; then
            printf "         %-20s %s\n" "🐳 Instance:" "🟢 $container_name ($status)"
        elif [[ "$health_status" == "unhealthy" ]]; then
            printf "         %-20s %s\n" "🐳 Instance:" "🔴 $container_name ($status)"
        else
            printf "         %-20s %s\n" "🐳 Instance:" "🟢 $container_name ($status)"
        fi
    else
        printf "         %-20s %s\n" "🐳 Instance:" "🟡 $container_name not running"
    fi

    # Check database container status with health check (right after instance status)
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
    if [ -f "$instance_env_file" ]; then
        local db_type
        db_type=$(grep "^DB_TYPE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
        local instance_mode
        instance_mode=$(grep "^INSTANCE_MODE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "shared")
        instance_mode="${instance_mode:-shared}"

        # Get database container name (shared: znuny-mariadb etc., dedicated: znuny-dev-mariadb etc.)
        local db_container_name
        db_container_name=$(get_database_container_name "$framework" "$db_type" "$instance_mode")

        if [ -n "$db_container_name" ]; then
            if docker ps --format "{{.Names}}" | grep -q "^${db_container_name}$"; then
                local db_status
                db_status=$(docker ps --format "{{.Status}}" --filter "name=$db_container_name")
                local db_health_status
                db_health_status=$(docker inspect --format='{{.State.Health.Status}}' "$db_container_name" 2>/dev/null || echo "no-health-check")

                if [[ "$db_health_status" == "healthy" ]]; then
                    printf "         %-20s %s\n" "🐳 DB:" "🟢 $db_container_name ($db_status)"
                elif [[ "$db_health_status" == "unhealthy" ]]; then
                    printf "         %-20s %s\n" "🐳 DB:" "🔴 $db_container_name ($db_status)"
                else
                    printf "         %-20s %s\n" "🐳 DB:" "🟢 $db_container_name ($db_status)"
                fi
            else
                printf "         %-20s %s\n" "🐳 DB:" "🟡 $db_container_name not running"
            fi
        fi
    fi

    # Load instance configuration (file exists, checked above)
    db_type=$(grep "^DB_TYPE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    local http_port
    http_port=$(grep "^INSTANCE_PORT=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    local db_port
    db_port=$(grep "^DB_PORT=" "$instance_env_file" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    local framework_name
    framework_name=$(grep "^FRAMEWORK_NAME=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    local db_url
    db_url=$(get_db_connection_url "$framework" 2>/dev/null || true)

    print "      ⚙️  Configuration:"
    printf "         %-20s %s\n" "📁 Framework:" "$framework_name"
    printf "         %-20s %s\n" "🌐 Web Interface:" "http://localhost:$http_port"
    printf "         %-20s %s\n" "🔌 HTTP Port:" "$http_port"
    printf "         %-24s %s\n" "🗄️  Database:" "$db_type (Port: $db_port)"
    printf "         %-20s %s\n" "🔗 Database URL:" "$db_url"
    printf "         %-20s %s\n" "🔅 Instance mode:" "$instance_mode"
    printf "         %-20s %s\n" "📁 Directory:" "$INSTANCES_DIR/$framework"

    # Show additional verbose information if requested
    if [[ "$verbose_mode" == "true" ]] && check_command docker && docker info >/dev/null 2>&1; then
        # Get containers for this instance (Docker names use lowercase framework_slug)
        local framework_slug
        framework_slug=$(get_framework_slug "$framework")
        local instance_containers
        instance_containers=$(docker ps -a --format "{{.Names}}|{{.Status}}|{{.Ports}}" | grep -E "znuny-${framework_slug}-|${framework_slug}-" 2>/dev/null || true)
        if [ -n "$instance_containers" ]; then
            print "      📦 Containers:"
            echo "$instance_containers" | while IFS='|' read -r container_name container_status _unused_ports; do
                if [[ "$container_status" == *"Up"* ]]; then
                    # Check if container is healthy
                    local health_status
                    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no-health-check")
                    if [[ "$health_status" == "healthy" ]]; then
                        print "         ✅ $container_name ($container_status) 🟢"
                    elif [[ "$health_status" == "unhealthy" ]]; then
                        print "         ⚠️  $container_name ($container_status) 🔴"
                    else
                        print "         ✅ $container_name ($container_status)"
                    fi

                    # Show container start time
                    local start_time
                    start_time=$(docker inspect --format='{{.State.StartedAt}}' "$container_name" 2>/dev/null | cut -d'T' -f1,2 | sed 's/T/ /' | cut -d'.' -f1 || echo "unknown")
                    print "            🕐 Started: $start_time"

                    # Show memory usage if available
                    local memory_usage
                    memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" "$container_name" 2>/dev/null || echo "unknown")
                    if [[ "$memory_usage" != "unknown" ]]; then
                        print "            💾 Memory: $memory_usage"
                    fi
                else
                    print "         🟡  $container_name ($container_status)"
                fi
            done
        else
            print "      📦 No containers found for this instance"
        fi

        # Get volumes for this instance (Docker volume names use lowercase framework_slug)
        local instance_volumes
        instance_volumes=$(docker volume ls --format "{{.Name}}" | grep -E "znuny_${framework_slug}-|${framework_slug}-|znuny-${framework_slug}-" 2>/dev/null || true)
        if [ -n "$instance_volumes" ]; then
            print "      💾 Volumes:"
            echo "$instance_volumes" | while read -r volume_name; do
                # Get volume size (this might not work on all systems)
                local volume_size
                volume_size=$(docker system df -v 2>/dev/null | grep "$volume_name" | awk '{print $3}' || echo "unknown")
                if [[ "$volume_size" != "unknown" ]]; then
                    print "         📁 $volume_name ($volume_size)"
                else
                    print "         📁 $volume_name"
                fi
            done
        else
            print "      💾 No volumes found for this instance"
        fi

        # Show network info (Docker network names use lowercase framework_slug)
        framework_slug=$(get_framework_slug "$framework")
        local instance_networks
        instance_networks=$(docker network ls --format "{{.Name}}" | grep -E "znuny-${framework_slug}-|${framework_slug}-" 2>/dev/null || true)
        if [ -n "$instance_networks" ]; then
            print "      🌐 Networks:"
            echo "$instance_networks" | while read -r network_name; do
                print "         🔗 $network_name"
            done
        fi
    fi
}

# Function to show all instance status
show_all_instance_status() {
    local verbose_mode="${1:-false}"
    local show_header="${2:-true}"

    if [[ "$show_header" == "true" ]]; then
        print_header "Instance Status for All Frameworks"
        print_header "=================================="
        echo ""
    fi

    # Check instances (subdirs with NAME/NAME.env)
    if [ -d "$INSTANCES_DIR" ]; then
        local instances=()
        read_lines_to_array instances < <(get_available_instances)
        if [ ${#instances[@]} -eq 0 ]; then
            print "   ❌ No instances found"
            echo ""
        else
            for instance in "${instances[@]}"; do
                show_instance_status "$instance" "$verbose_mode" "$show_header"
                echo ""
            done
        fi
    else
        print_warning "Instances directory not found: $INSTANCES_DIR"
        echo ""
        return 1
    fi
}

# --- JSON export for dashboard / zd status --json ---
# shellcheck disable=SC2034

json_escape_string() {
    local Input="$1"
    local Output=""
    local I Len Char Ord
    Len=${#Input}
    for ((I = 0; I < Len; I++)); do
        Char="${Input:I:1}"
        case "$Char" in
        \\) Output+="\\\\" ;;
        \") Output+="\\\"" ;;
        $'\n') Output+="\\n" ;;
        $'\r') Output+="\\r" ;;
        $'\t') Output+="\\t" ;;
        *)
            printf -v Ord '%d' "'$Char"
            if [ "${Ord:-0}" -lt 32 ]; then
                Output+=$(printf '\\u%04x' "'$Char")
            else
                Output+="$Char"
            fi
            ;;
        esac
    done
    printf '%s' "$Output"
}

_emit_bool_json() {
    if [ "$1" = "true" ] || [ "$1" = "1" ]; then
        printf 'true'
    else
        printf 'false'
    fi
}

# Populate once per dashboard / JSON status request (avoids N× docker ps / volume ls / network ls).
_status_json_docker_cache_load() {
    local verbose="$1"
    _SJC_PS_NAMES=$(docker ps --format '{{.Names}}' 2>/dev/null || true)
    _SJC_PS_NAME_STATUS=$(docker ps --format '{{.Names}}\t{{.Status}}' 2>/dev/null || true)
    _SJC_PS_ALL_NAMES=$(docker ps -a --format '{{.Names}}' 2>/dev/null || true)
    if [ "$verbose" = "true" ]; then
        _SJC_PS_ALL_LINES=$(docker ps -a --format '{{.Names}}|{{.Status}}|{{.Ports}}' 2>/dev/null || true)
        _SJC_VOL_ALL=$(docker volume ls --format '{{.Name}}' 2>/dev/null || true)
        _SJC_NET_ALL=$(docker network ls --format '{{.Name}}' 2>/dev/null || true)
    else
        _SJC_PS_ALL_LINES=""
        _SJC_VOL_ALL=""
        _SJC_NET_ALL=""
    fi
}

_status_json_docker_cache_clear() {
    unset _SJC_PS_NAMES _SJC_PS_NAME_STATUS _SJC_PS_ALL_NAMES _SJC_PS_ALL_LINES _SJC_VOL_ALL _SJC_NET_ALL
}

_sjc_ps_running_status() {
    local n="$1"
    printf '%s\n' "$_SJC_PS_NAME_STATUS" | awk -F'\t' -v name="$n" '$1 == name { print $2; exit }'
}

# Emit one instance as JSON object to stdout (no newline before/after; caller adds comma separation)
_emit_one_instance_json() {
    local framework="$1"
    local verbose_mode="${2:-false}"
    local container_name
    container_name=$(get_instance_container_name "$framework")
    local port
    port=$(get_instance_port "$framework")
    local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"

    local inst_running=false
    local inst_status=""
    local inst_health="unknown"
    local inst_started_at=""
    local inst_created_at=""

    if printf '%s\n' "$_SJC_PS_NAMES" | grep -qxF "$container_name"; then
        inst_running=true
        inst_status=$(_sjc_ps_running_status "$container_name")
        inst_status=$(printf '%s' "$inst_status" | tr -d '\n\r')
    else
        inst_health="stopped"
    fi
    if printf '%s\n' "$_SJC_PS_ALL_NAMES" | grep -qxF "$container_name"; then
        local _inst_triple
        _inst_triple=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health-check{{end}}|{{.State.StartedAt}}|{{.Created}}' "$container_name" 2>/dev/null | tr -d '\n\r' || true)
        IFS='|' read -r _inst_h inst_started_at inst_created_at <<< "$_inst_triple"
        if [ "$inst_running" = true ]; then
            inst_health="$_inst_h"
            [ -z "$inst_health" ] && inst_health="no-health-check"
        fi
    fi

    local db_type=""
    local instance_mode="shared"
    local db_container_name=""
    local db_running=false
    local db_status=""
    local db_health="unknown"

    if [ -f "$instance_env_file" ]; then
        db_type=$(grep "^DB_TYPE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
        instance_mode=$(grep "^INSTANCE_MODE=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "shared")
        instance_mode="${instance_mode:-shared}"
        db_container_name=$(get_database_container_name "$framework" "$db_type" "$instance_mode")
        if [ -n "$db_container_name" ]; then
            if printf '%s\n' "$_SJC_PS_NAMES" | grep -qxF "$db_container_name"; then
                db_running=true
                db_status=$(_sjc_ps_running_status "$db_container_name")
                db_status=$(printf '%s' "$db_status" | tr -d '\n\r')
                if printf '%s\n' "$_SJC_PS_ALL_NAMES" | grep -qxF "$db_container_name"; then
                    db_health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health-check{{end}}' "$db_container_name" 2>/dev/null | tr -d '\n\r' || echo "no-health-check")
                    [ -z "$db_health" ] && db_health="no-health-check"
                fi
            else
                db_health="stopped"
            fi
        fi
    fi

    local http_port=""
    local db_port=""
    local framework_name=""
    local db_url=""
    local db_label=""
    http_port=$(grep "^INSTANCE_PORT=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    db_port=$(grep "^DB_PORT=" "$instance_env_file" 2>/dev/null | head -1 | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    framework_name=$(grep "^FRAMEWORK_NAME=" "$instance_env_file" 2>/dev/null | cut -d'=' -f2- | tr -d '"' || echo "unknown")
    db_url=$(get_db_connection_url "$framework" 2>/dev/null || true)
    db_label="${db_type:-unknown} (Port: ${db_port:-unknown})"

    printf '{'
    printf '"framework":"%s",' "$(json_escape_string "$framework")"
    printf '"port":"%s",' "$(json_escape_string "${port:-}")"
    printf '"container_name":"%s",' "$(json_escape_string "$container_name")"
    printf '"instance":{'
    printf '"running":%s,' "$(_emit_bool_json "$inst_running")"
    printf '"docker_status":"%s",' "$(json_escape_string "${inst_status:-}")"
    printf '"started_at":"%s",' "$(json_escape_string "${inst_started_at:-}")"
    printf '"created_at":"%s",' "$(json_escape_string "${inst_created_at:-}")"
    printf '"health":"%s"' "$(json_escape_string "${inst_health:-}")"
    printf '},'
    printf '"database":{'
    if [ -n "$db_container_name" ]; then
        printf '"container":"%s",' "$(json_escape_string "$db_container_name")"
    else
        printf '"container":null,'
    fi
    printf '"running":%s,' "$(_emit_bool_json "$db_running")"
    printf '"docker_status":"%s",' "$(json_escape_string "${db_status:-}")"
    printf '"health":"%s"' "$(json_escape_string "${db_health:-}")"
    printf '},'
    printf '"configuration":{'
    printf '"framework_name":"%s",' "$(json_escape_string "$framework_name")"
    printf '"web_interface":"%s",' "$(json_escape_string "http://localhost:${http_port:-}")"
    printf '"http_port":"%s",' "$(json_escape_string "${http_port:-}")"
    printf '"database":"%s",' "$(json_escape_string "$db_label")"
    printf '"database_url":"%s",' "$(json_escape_string "${db_url:-}")"
    printf '"instance_mode":"%s",' "$(json_escape_string "${instance_mode:-}")"
    printf '"directory":"%s"' "$(json_escape_string "${INSTANCES_DIR}/${framework}")"
    printf '}'

    if [[ "$verbose_mode" == "true" ]] && check_command docker && docker info >/dev/null 2>&1; then
        local framework_slug
        framework_slug=$(get_framework_slug "$framework")
        printf ','
        printf '"verbose":{'
        printf '"containers":['
        local first_c=true
        local instance_containers
        instance_containers=$(printf '%s\n' "$_SJC_PS_ALL_LINES" | grep -E "znuny-${framework_slug}-|${framework_slug}-" 2>/dev/null || true)
        if [ -n "$instance_containers" ]; then
            local stats_map=""
            local names
            names=()
            while IFS='|' read -r cname0 _c0 _c1; do
                [ -z "$cname0" ] && continue
                names+=("$cname0")
            done <<<"$instance_containers"
            if [ ${#names[@]} -gt 0 ]; then
                stats_map=$(docker stats --no-stream --format '{{.Name}}\t{{.MemUsage}}' "${names[@]}" 2>/dev/null || true)
            fi
            while IFS='|' read -r cname cstatus _ports; do
                [ -z "$cname" ] && continue
                [ "$first_c" = true ] || printf ','
                first_c=false
                local ch started mem
                local _verb_ins
                _verb_ins=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-health-check{{end}}|{{.State.StartedAt}}' "$cname" 2>/dev/null | tr -d '\n\r' || true)
                IFS='|' read -r ch started <<< "$_verb_ins"
                [ -z "$ch" ] && ch="no-health-check"
                started=$(printf '%s' "$started" | cut -d'T' -f1,2 | sed 's/T/ /' | cut -d'.' -f1 | tr -d '\n\r')
                mem=$(printf '%s\n' "$stats_map" | awk -F'\t' -v n="$cname" '$1 == n { print $2; exit }')
                if [ -z "$mem" ]; then
                    mem=$(printf '%s\n' "$stats_map" | awk -F'\t' -v n="/$cname" '$1 == n { print $2; exit }')
                fi
                printf '{'
                printf '"name":"%s",' "$(json_escape_string "$cname")"
                printf '"status":"%s",' "$(json_escape_string "$cstatus")"
                printf '"health":"%s",' "$(json_escape_string "$ch")"
                printf '"started_at":"%s",' "$(json_escape_string "$started")"
                printf '"memory":"%s"' "$(json_escape_string "$mem")"
                printf '}'
            done <<<"$instance_containers"
        fi
        printf '],'
        printf '"volumes":['
        local first_v=true
        local instance_volumes
        instance_volumes=$(printf '%s\n' "$_SJC_VOL_ALL" | grep -E "znuny_${framework_slug}-|${framework_slug}-|znuny-${framework_slug}-" 2>/dev/null || true)
        if [ -n "$instance_volumes" ]; then
            while read -r vname; do
                [ -z "$vname" ] && continue
                [ "$first_v" = true ] || printf ','
                first_v=false
                printf '{"name":"%s"}' "$(json_escape_string "$vname")"
            done <<<"$instance_volumes"
        fi
        printf '],'
        printf '"networks":['
        local first_n=true
        local instance_networks
        instance_networks=$(printf '%s\n' "$_SJC_NET_ALL" | grep -E "znuny-${framework_slug}-|${framework_slug}-" 2>/dev/null || true)
        if [ -n "$instance_networks" ]; then
            while read -r nname; do
                [ -z "$nname" ] && continue
                [ "$first_n" = true ] || printf ','
                first_n=false
                printf '{"name":"%s"}' "$(json_escape_string "$nname")"
            done <<<"$instance_networks"
        fi
        printf ']'
        printf '}'
    else
        printf ','
        printf '"verbose":null'
    fi
    printf '}'
}

emit_status_json_collection() {
    local framework="${1:-}"
    local verbose_mode="${2:-false}"

    if ! check_command docker || ! docker info >/dev/null 2>&1; then
        printf '{"error":"%s","instances":[]}' "$(json_escape_string "Docker is not available or not running")"
        printf '\n'
        return 0
    fi

    if [ -z "$INSTANCES_DIR" ] || [ ! -d "$INSTANCES_DIR" ]; then
        printf '{"error":"%s","instances":[]}' "$(json_escape_string "Instances directory not found")"
        printf '\n'
        return 0
    fi

    local generated_at
    generated_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [ -n "$framework" ] && [ "$framework" != "all" ]; then
        local instance_env_file="$INSTANCES_DIR/$framework/$framework.env"
        if [ ! -f "$instance_env_file" ]; then
            printf '{"error":"%s","framework":"%s","instances":[]}' "$(json_escape_string "Framework not found")" "$(json_escape_string "$framework")"
            printf '\n'
            return 1
        fi
        printf '{"generated_at":"%s","instances":[' "$generated_at"
        _status_json_docker_cache_load "$verbose_mode"
        _emit_one_instance_json "$framework" "$verbose_mode"
        printf ']}\n'
        _status_json_docker_cache_clear
        return 0
    fi

    local instances=()
    read_lines_to_array instances < <(get_available_instances)
    _status_json_docker_cache_load "$verbose_mode"
    printf '{"generated_at":"%s","instances":[' "$generated_at"
    local first=true
    local inst
    for inst in "${instances[@]}"; do
        [ "$first" = true ] || printf ','
        first=false
        _emit_one_instance_json "$inst" "$verbose_mode"
    done
    printf ']}\n'
    _status_json_docker_cache_clear
}
