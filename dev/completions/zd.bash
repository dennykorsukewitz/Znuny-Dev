# bash tab-completion for zd / znuny-dev.sh
# Sourced by setup-alias into ~/.bashrc

_zd_completion_dir() {
    local src="${BASH_SOURCE[0]:-}"
    if [ -n "$src" ]; then
        (cd "$(dirname "$src")" >/dev/null 2>&1 && pwd)
    elif [ -n "${_ZD_COMPLETION_DIR:-}" ]; then
        printf '%s\n' "$_ZD_COMPLETION_DIR"
    fi
}

_zd() {
    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"

    local completion_dir
    completion_dir="$(_zd_completion_dir)"
    local cmd_file="${completion_dir}/commands.txt"
    local znuny_dev_root
    znuny_dev_root="$(cd "${completion_dir}/../.." >/dev/null 2>&1 && pwd)"

    local commands=""
    if [ -f "$cmd_file" ]; then
        commands=$(grep -v '^#' "$cmd_file" | grep -v '^[[:space:]]*$' | tr '\n' ' ')
    fi

    local frameworks_dir="${FRAMEWORKS_DIR:-}"
    if [ -z "$frameworks_dir" ] && [ -n "${ZNUNY_DEV_DIR:-}" ]; then
        frameworks_dir="${ZNUNY_DEV_DIR}/frameworks"
    fi
    if [ -z "$frameworks_dir" ] && [ -f "${znuny_dev_root}/.env" ]; then
        frameworks_dir=$(
            grep -E '^FRAMEWORKS_DIR=' "${znuny_dev_root}/.env" 2>/dev/null \
                | head -1 \
                | sed 's/^FRAMEWORKS_DIR=//' \
                | tr -d "\"'"
        )
    fi
    if [ -z "$frameworks_dir" ]; then
        frameworks_dir="$(cd "${znuny_dev_root}/../frameworks" >/dev/null 2>&1 && pwd)"
    fi

    local frameworks="all"
    if [ -n "$frameworks_dir" ] && [ -d "$frameworks_dir" ]; then
        local d
        for d in "$frameworks_dir"/*; do
            [ -d "$d" ] || continue
            frameworks="$frameworks $(basename "$d")"
        done
    fi

    if [ "${COMP_CWORD}" -eq 1 ]; then
        # shellcheck disable=SC2207
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
        return 0
    fi

    if [ "${COMP_CWORD}" -ge 2 ]; then
        local cmd="${COMP_WORDS[1]}"
        case "$cmd" in
            help|examples|example|version|dev|setup-all|setup-env|setup-alias|setup-tools|setup-compose|setup-remove|setup-packages|setup-repository-sources|setup-status|sync-indices|test|tests|release|dashboard|remove_alias|remove_frameworks|remove_tools|remove_instances|remove_composes)
                return 0
                ;;
            selenium)
                if [ "${COMP_CWORD}" -eq 2 ]; then
                    # shellcheck disable=SC2207
                    COMPREPLY=($(compgen -W "start stop restart status remove" -- "$cur"))
                fi
                return 0
                ;;
            *)
                # shellcheck disable=SC2207
                COMPREPLY=($(compgen -W "$frameworks" -- "$cur"))
                return 0
                ;;
        esac
    fi
}

complete -F _zd zd
complete -F _zd znuny-dev.sh
