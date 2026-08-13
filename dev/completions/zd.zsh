#compdef zd znuny-dev.sh

# zsh tab-completion for zd / znuny-dev.sh
# Sourced by setup-alias into ~/.zshrc

if ! typeset -f compdef >/dev/null 2>&1; then
    autoload -Uz compinit
    compinit -C
fi

_zd() {
    local completion_dir="${_ZD_COMPLETION_DIR:-}"
    if [ -z "$completion_dir" ]; then
        completion_dir="${${(%):-%x}:A:h}"
    fi

    local -a commands frameworks
    local cmd_file="${completion_dir}/commands.txt"
    if [ -f "$cmd_file" ]; then
        commands=("${(@f)$(<"$cmd_file")}")
        commands=("${(@)commands:#\#*}")
        commands=("${(@)commands:#}")
    fi

    local frameworks_dir="${FRAMEWORKS_DIR:-}"
    local znuny_dev_root="${completion_dir:A:h:h}"
    if [ -z "$frameworks_dir" ] && [ -n "${ZNUNY_DEV_DIR:-}" ]; then
        frameworks_dir="${ZNUNY_DEV_DIR}/frameworks"
    fi
    if [ -z "$frameworks_dir" ] && [ -f "${znuny_dev_root}/.env" ]; then
        frameworks_dir="$(
            grep -E '^FRAMEWORKS_DIR=' "${znuny_dev_root}/.env" 2>/dev/null \
                | head -1 \
                | sed 's/^FRAMEWORKS_DIR=//' \
                | tr -d "\"'"
        )"
    fi
    if [ -z "$frameworks_dir" ]; then
        frameworks_dir="${znuny_dev_root}/../frameworks"
    fi
    frameworks_dir="${frameworks_dir:A}"

    frameworks=(all)
    if [ -d "$frameworks_dir" ]; then
        local d
        for d in "$frameworks_dir"/*(N/); do
            frameworks+=("${d:t}")
        done
    fi

    if (( CURRENT == 2 )); then
        compadd -a -- commands
        return 0
    fi

    if (( CURRENT >= 3 )); then
        local cmd="${words[2]}"
        case "$cmd" in
            help|examples|example|version|dev|setup-all|setup-env|setup-alias|setup-tools|setup-compose|setup-remove|setup-packages|setup-repository-sources|setup-status|sync-indices|test|tests|release|dashboard|remove_alias|remove_frameworks|remove_tools|remove_instances|remove_composes)
                return 0
                ;;
            *)
                compadd -a -- frameworks
                return 0
                ;;
        esac
    fi
}

compdef _zd zd 2>/dev/null || true
compdef _zd znuny-dev.sh 2>/dev/null || true
