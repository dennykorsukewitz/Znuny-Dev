#!/bin/bash

# Znuny Development Environment Startup Script
# This script initializes the Znuny development environment

# set -e  # Disabled to prevent script from exiting on errors

echo "Starting Znuny Development Environment..."

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to detect framework
detect_framework() {
    if [ -f "/opt/znuny/RELEASE" ]; then
        FRAMEWORK_VERSION=$(grep VERSION "/opt/znuny/RELEASE" | sed -e 's/VERSION = //')
        log "Detected Znuny version: $FRAMEWORK_VERSION"
    else
        log "No framework detected, using defaults"
    fi

    FRAMEWORK='znuny'
    FRAMEWORK_DIR='/opt/znuny'
    FRAMEWORK_USER='www-data'
    FRAMEWORK_DATABASE="${DB_NAME:-znuny}"
}

# Function to wait for database
wait_for_database() {
    # Check if any database is detected
    if [ "$MYSQL" -ne 1 ] && [ "$POSTGRESQL" -ne 1 ] && [ "$ORACLE" -ne 1 ]; then
        log "No database detected, skipping database wait..."
        return 0
    fi

    local db_type="$1"
    local db_host="$2"
    local db_port="$3"
    local max_attempts=30
    local attempt=1

    log "Waiting for $db_type database at $db_host:$db_port..."

    # For shared MySQL/MariaDB: try root first (app user is created by config-mysql.sh)
    local mysql_user="$DB_USER"
    local mysql_pass="$DB_PASSWORD"
    if [ "$db_type" = "mysql" ] || [ "$db_type" = "mariadb" ]; then
        if [ -n "${MARIADB_ROOT_PASSWORD:-$MYSQL_ROOT_PASSWORD}" ]; then
            mysql_user="root"
            mysql_pass="${MARIADB_ROOT_PASSWORD:-$MYSQL_ROOT_PASSWORD}"
        fi
    fi

    # For PostgreSQL: use postgres superuser (app role is created by config-postgresql.sh)
    local pg_user="$DB_USER"
    local pg_pass="$DB_PASSWORD"
    if [ "$db_type" = "postgresql" ] || [ "$db_type" = "postgres" ]; then
        if [ -n "${POSTGRES_ROOT_PASSWORD:-$POSTGRES_PASSWORD}" ]; then
            pg_user="postgres"
            pg_pass="${POSTGRES_ROOT_PASSWORD:-$POSTGRES_PASSWORD}"
        fi
    fi

    while [ $attempt -le $max_attempts ]; do
        case $db_type in
            mysql|mariadb)
                if mysql -h"$db_host" -P"$db_port" -u"$mysql_user" -p"$mysql_pass" -e "SELECT 1;" >/dev/null 2>&1; then
                    log "MySQL/MariaDB database is ready!"
                    return 0
                fi
                ;;
            postgresql|postgres)
                if PGPASSWORD="$pg_pass" psql -h"$db_host" -p"$db_port" -U"$pg_user" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
                    log "PostgreSQL database is ready!"
                    return 0
                fi
                ;;
            oracle)
                if echo exit | sqlplus64 -L system/oracle@"$db_host:$db_port/xe" >/dev/null 2>&1; then
                    log "Oracle database is ready!"
                    return 0
                fi
                ;;
        esac

        log "Database not ready yet (attempt $attempt/$max_attempts)..."
        sleep 2
        attempt=$((attempt + 1))
    done

    log "ERROR: Database not available after $max_attempts attempts!"
    return 1
}

# Function to detect linked database
detect_database() {
    MYSQL=0
    POSTGRESQL=0
    ORACLE=0

    # Check /etc/hosts for database containers
    grep -q mysql /etc/hosts && MYSQL=1
    grep -q postgresql /etc/hosts && POSTGRESQL=1
    grep -q oracle /etc/hosts && ORACLE=1

    # Also check environment variables
    case "$DB_TYPE" in
        mysql|mariadb)
            MYSQL=1
            ;;
        postgresql|postgres)
            POSTGRESQL=1
            ;;
        oracle)
            ORACLE=1
            ;;
    esac

    log "Database detection: MySQL=$MYSQL, PostgreSQL=$POSTGRESQL, Oracle=$ORACLE"
}

# Function to configure database
configure_database() {
    # Check if any database is detected
    if [ "$MYSQL" -ne 1 ] && [ "$POSTGRESQL" -ne 1 ] && [ "$ORACLE" -ne 1 ]; then
        log "No database detected, skipping database configuration..."
        return 0
    fi

    log "Configuring database..."

    # Set environment variables for DB scripts
    export FRAMEWORK_DIR="$FRAMEWORK_DIR"
    export FRAMEWORK_DATABASE="$FRAMEWORK_DATABASE"
    export DB_HOST="${DB_HOST:-localhost}"
    export DB_USER="${DB_USER:-root}"
    export DB_PASSWORD="${DB_PASSWORD:-znuny}"
    export POSTGRES_ROOT_PASSWORD="${POSTGRES_ROOT_PASSWORD:-postgres_shared}"

    if [ "$MYSQL" -eq 1 ]; then
        log "Configuring MySQL database with UTF8MB4 support..."
        /etc/znuny/configs/mysql/config-mysql.sh
    elif [ "$POSTGRESQL" -eq 1 ]; then
        log "Configuring PostgreSQL database..."
        /etc/znuny/configs/postgresql/config-postgresql.sh
    elif [ "$ORACLE" -eq 1 ]; then
        log "Configuring Oracle database..."
        /etc/znuny/configs/oracle/config-oracle.sh
    else
        log "No database configuration found, skipping..."
    fi
}

# Function to update database configuration in existing Config.pm
update_config_database() {
    log "Updating database configuration in Config.pm..."

    # Update database host
    sed -i "s/\$Self->{DatabaseHost} = '[^']*';/\$Self->{DatabaseHost} = '$DB_HOST';/g" "$FRAMEWORK_DIR/Kernel/Config.pm"

    # Update database name
    sed -i "s/\$Self->{Database} = '[^']*';/\$Self->{Database} = '$DB_NAME';/g" "$FRAMEWORK_DIR/Kernel/Config.pm"

    # Update database user
    sed -i "s/\$Self->{DatabaseUser} = '[^']*';/\$Self->{DatabaseUser} = '$DB_USER';/g" "$FRAMEWORK_DIR/Kernel/Config.pm"

    # Update database password
    sed -i "s/\$Self->{DatabasePw} = '[^']*';/\$Self->{DatabasePw} = '$DB_PASSWORD';/g" "$FRAMEWORK_DIR/Kernel/Config.pm"

    # Update database DSN (MySQL or PostgreSQL based on DB_TYPE)
    if [ "$DB_TYPE" = "postgresql" ] || [ "$DB_TYPE" = "postgres" ]; then
        sed -i "s/\$Self->{DatabaseDSN} = \"[^\"]*\";/\$Self->{DatabaseDSN} = \"DBI:Pg:dbname=\$Self->{Database};host=\$Self->{DatabaseHost};\";/g" "$FRAMEWORK_DIR/Kernel/Config.pm"
    else
        sed -i "s/\$Self->{DatabaseDSN} = \"[^\"]*\";/\$Self->{DatabaseDSN} = \"DBI:mysql:database=\$Self->{Database};host=\$Self->{DatabaseHost};\";/g" "$FRAMEWORK_DIR/Kernel/Config.pm"
    fi

    log "Database configuration updated successfully"
}

# Replace in Kernel/Config.pm only the default placeholder lines between
#   the opening block "# insert your own config settings \"here\" ... # ---" and
#   the next "# ---------------------------------------------------- #" (before "# data inserted by installer").
# Insert content of configs/framework/Config.pm (mounted as /opt/framework-config/Config.pm).
# Keep the blocks "# data inserted by installer" and "# end of your own config options!!!".
update_config_custom() {
    local config_pm="$FRAMEWORK_DIR/Kernel/Config.pm"
    local snippet_file="/opt/framework-config/Config.pm"

    if [ ! -f "$config_pm" ]; then
        log "Config.pm not found, skipping custom snippet"
        return 0
    fi
    if [ ! -f "$snippet_file" ]; then
        log "Snippet not found at $snippet_file (volume configs/framework mounted?). Skipping custom config."
        return 0
    fi

    if ! grep -q "insert your own config settings" "$config_pm"; then
        log "Config.pm has no custom config block; skipping snippet injection"
        return 0
    fi

    # Replace placeholders in snippet: {{FRAMEWORK_DIR}}{{FRAMEWORK}} (first), {{FRAMEWORK}}, {{PORT}} with actual values
    local snippet_processed
    snippet_processed="$(mktemp)"
    trap 'rm -f -- "$snippet_processed"' RETURN
    local instance_port="${INSTANCE_PORT:-10000}"
    sed 's|{{FRAMEWORK_DIR}}{{FRAMEWORK}}|'"$FRAMEWORK_DIR"'|g; s|{{FRAMEWORK}}|'"$FRAMEWORK"'|g; s|{{PORT}}|'"$instance_port"'|g' "$snippet_file" > "$snippet_processed"

    local tmp_file
    tmp_file="$(mktemp)"
    if ! awk -v snippet="$snippet_processed" '
        /insert your own config settings/ {
            print
            while ((getline) > 0) {
                print
                if ($0 ~ /^[[:space:]]*#[[:space:]]*-+[[:space:]]*#/) break
            }
            while ((getline line < snippet) > 0) print line
            close(snippet)
            print ""
            skip = 1
            next
        }
        skip && /^[[:space:]]*#[[:space:]]*-+[[:space:]]*#/ { print; skip = 0; next }
        skip { next }
        { print }
    ' "$config_pm" > "$tmp_file"; then
        log "WARNING: Failed to build Config.pm with snippet (awk failed). Custom config not applied."
        rm -f "$tmp_file"
        return 1
    fi
    if ! mv "$tmp_file" "$config_pm"; then
        log "WARNING: Failed to replace Config.pm. Custom config not applied."
        rm -f "$tmp_file"
        return 1
    fi
    log "Config.pm: block replaced with configs/framework/Config.pm"
}

# Function to setup znuny user
setup_znuny_user() {
    log "Setting up znuny user..."

    # Check if znuny user already exists
    if id "znuny" >/dev/null 2>&1; then
        log "User 'znuny' already exists"
    else
        log "Creating user 'znuny'..."

        # Get www-data user info
        local www_data_uid www_data_gid
        www_data_uid=$(id -u www-data 2>/dev/null || echo "33")
        www_data_gid=$(id -g www-data 2>/dev/null || echo "33")

        # Create znuny user with same UID/GID as www-data
        useradd -u "$www_data_uid" -g "$www_data_gid" -d /home/znuny -s /usr/bin/zsh -m znuny 2>/dev/null || {
            # If useradd fails, try with adduser
            adduser --system --group --home /opt/znuny --shell /usr/bin/zsh znuny 2>/dev/null || {
                log "WARNING: Could not create znuny user, continuing with www-data"
                return 0
            }
        }

        # Ensure znuny user has proper home directory and permissions
        mkdir -p /home/znuny
        chown znuny:znuny /home/znuny

        log "User 'znuny' created successfully"
    fi

    # Ensure znuny user has access to framework directory
    chown -R znuny:znuny "$FRAMEWORK_DIR" 2>/dev/null || true

    # Add znuny user to www-data group for web server access
    usermod -a -G www-data znuny 2>/dev/null || true

    # Create basic zsh configuration for znuny user
    if [ -f "/home/znuny/.zshrc" ]; then
        log "zsh configuration already exists"
    else
        log "Creating zsh configuration for znuny user..."
        cat > /home/znuny/.zshrc << 'EOF'
# Znuny Development Environment - zsh configuration
# Basic zsh configuration for znuny user
FRAMEWORK_DIR=/opt/znuny

# Enable colors
autoload -U colors && colors

# History configuration
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_SAVE_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt SHARE_HISTORY

# Auto-completion
autoload -U compinit && compinit
setopt AUTO_LIST
setopt AUTO_MENU
setopt COMPLETE_IN_WORD

# Directory navigation
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Prompt configuration
PROMPT='%F{green}znuny%f@%F{blue}%m%f:%F{yellow}%~%f$ '

# Aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Znuny specific aliases (6.x: otrs.Console.pl, 7.x: znuny.Console.pl)
znuny-console() { cd /opt/znuny && if [ -f bin/znuny.Console.pl ]; then exec perl bin/znuny.Console.pl "$@"; else exec perl bin/otrs.Console.pl "$@"; fi; }
alias znuny-logs='tail -f /opt/znuny/var/log/znuny.log'
alias znuny-config='vim /opt/znuny/Kernel/Config.pm'
alias znuny-help='znuny-welcome'

# Welcome message (run "znuny-welcome" or "znuny-help" to show again)
znuny-welcome() {
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                              ║"
echo "║               🚀 Welcome to Znuny Development Environment! 🚀                ║"
echo "║                                                                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "                                                                                "

if [ -f "$FRAMEWORK_DIR/RELEASE" ]; then
    local znuny_version=$(grep "^VERSION" "$FRAMEWORK_DIR/RELEASE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "Unknown")
    local znuny_product=$(grep "^PRODUCT" "$FRAMEWORK_DIR/RELEASE" 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "Znuny")
    local version_info="$znuny_product $znuny_version"
else
    local version_info="Unknown (RELEASE file not found)"
fi

if [ -f "$FRAMEWORK_DIR/Kernel/Config.pm" ]; then
    local db_host=$(grep "DatabaseHost" "$FRAMEWORK_DIR/Kernel/Config.pm" 2>/dev/null | head -1 | sed "s/.*= '\([^']*\)'.*/\1/" || echo "Unknown")
    local db_name=$(grep "Database" "$FRAMEWORK_DIR/Kernel/Config.pm" 2>/dev/null | head -1 | sed "s/.*= '\([^']*\)'.*/\1/" || echo "Unknown")
    local db_type="Unknown"
    if [[ "$db_host" == *"mariadb"* ]]; then
        db_type="MariaDB"
    elif [[ "$db_host" == *"mysql"* ]]; then
        db_type="MySQL"
    elif [[ "$db_host" == *"postgres"* ]]; then
        db_type="PostgreSQL"
    elif [[ "$db_host" == *"oracle"* ]]; then
        db_type="Oracle"
    fi
    local database_info="$db_type ($db_name)"
else
    local database_info="Unknown (Config.pm not found)"
fi

printf "  %-23s %s\n" "📦 Framework:" "$(basename "$FRAMEWORK_DIR")"
printf "  %-23s %s\n" "🔖 Version:" "$version_info"
printf "  %-25s %s\n" "🗄️  Database:"  "$database_info"
printf "  %-23s %s\n" "🏠 Directory:" "/opt/znuny"
echo " "
printf "  %-23s %s\n" "👤 User:" "znuny"
printf "  %-23s %s\n" "🐚 Shell:" "$(getent passwd znuny 2>/dev/null | cut -d: -f7 || echo '/usr/bin/zsh')"
echo ""
printf "  %-25s %s\n" "🛠️  Available Commands:" "znuny-console, znuny-logs, znuny-config"
printf "  %-25s %s\n" "    znuny-console" "- Znuny console commands"
printf "  %-25s %s\n" "    znuny-logs" "- View Znuny logs"
printf "  %-25s %s\n" "    znuny-config" "- Edit Znuny configuration"
printf "  %-25s %s\n" "    znuny-help" "- Show Welcome message and available commands"
echo ""
echo "                                                                                "
printf "  %-23s %s\n" "🌐 Web Interface:" "http://localhost:${INSTANCE_PORT:-10000}"
echo "                                                                                "
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
}

znuny-welcome
EOF
        chown znuny:znuny /home/znuny/.zshrc 2>/dev/null || true
        log "zsh configuration created"
    fi

    log "Znuny user setup completed"
}

# Git: /opt/znuny is a bind mount (different owner) – mark safe so git does not warn.
# Use --system so /etc/gitconfig is used; avoids creating .gitconfig in the framework (e.g. when HOME is /opt/znuny).
setup_git_safe_directory() {
    git config --system --add safe.directory /opt/znuny 2>/dev/null || true
}

# Function to setup Znuny configuration
setup_framework_config() {
    log "Setting up Znuny configuration..."

    # Create Config.pm from Config.pm.dist if missing or forced
    if [ ! -f "$FRAMEWORK_DIR/Kernel/Config.pm" ] || [ "$FORCE_CONFIG_UPDATE" = "true" ]; then
        if [ ! -f "$FRAMEWORK_DIR/Kernel/Config.pm.dist" ]; then
            log "ERROR: Kernel/Config.pm.dist not found. Framework incomplete?"
            return 1
        fi
        log "Creating Kernel/Config.pm from Config.pm.dist..."
        cp "$FRAMEWORK_DIR/Kernel/Config.pm.dist" "$FRAMEWORK_DIR/Kernel/Config.pm"
    fi

    # Always update database configuration with environment variables
    log "Updating database configuration with environment variables..."
    update_config_database

    # Update optional custom config snippet from configs/framework/Config.pm (project root)
    if [ -f /opt/framework-config/Config.pm ]; then
        log "Updating configs/framework/Config.pm snippet into Kernel/Config.pm..."
        update_config_custom
    fi

    # Set proper permissions
    chmod 644 "$FRAMEWORK_DIR/Kernel/Config.pm"
}

# Function to setup Znuny permissions
setup_framework_permissions() {
    log "Setting up Znuny permissions..."

    if [ -f "$FRAMEWORK_DIR/bin/znuny.SetPermissions.pl" ]; then
        perl "$FRAMEWORK_DIR/bin/znuny.SetPermissions.pl" --web-group=www-data --znuny-user=www-data
        log "Znuny permissions set successfully"
    else
        log "WARNING: SetPermissions.pl not found, setting basic permissions..."
        chown -R www-data:www-data "$FRAMEWORK_DIR"
        chmod -R 755 "$FRAMEWORK_DIR"
    fi
}

# Function to rebuild Znuny configuration
rebuild_framework_config() {
    log "Rebuilding Znuny configuration..."

    su -s /bin/bash -c "perl '$CONSOLE_PL' Maint::Config::Rebuild" "$FRAMEWORK_USER"

    log "Znuny configuration rebuilt successfully"
}

# Function to set initial password
set_initial_password() {
    log "Setting initial password for root user..."

    su -s /bin/bash -c "perl '$CONSOLE_PL' Admin::User::SetPassword root@localhost root" "$FRAMEWORK_USER"

    log "Initial password set successfully"
}

# Function to initialize database
initialize_database() {
    log "Initializing database..."

    # Check if database is already initialized
    if [ -f "/var/lib/znuny/.database_initialized" ]; then
        log "Database already initialized, skipping..."
        return 0
    fi

    # Run Znuny database setup
    if [ -f "/opt/znuny/scripts/database/znuny-schema.xml" ]; then
        log "Creating database schema..."
        cd /opt/znuny || return 1
        perl "$CONSOLE_PL" Maint::Database::Check || true
        perl "$CONSOLE_PL" Maint::Database::Check::Tables || true
    fi

    # Mark database as initialized
    touch /var/lib/znuny/.database_initialized
    log "Database initialization completed!"
}

# Function to setup module-tools (tools are mounted at /opt/tools, same pattern as docker-el9-znuny bootstrap)
setup_module_tools() {
    if [ -d "/opt/tools/module-tools" ]; then
        log "Setting up module-tools..."

        chmod +x /opt/tools/module-tools/bin/znuny.ModuleTools.pl 2>/dev/null || true

        if [ -f "/opt/tools/module-tools/cpanfile" ]; then
            log "Installing module-tools CPAN dependencies (cpanfile)..."
            cd /opt/tools/module-tools || return 0
            if cpanm --notest --installdeps .; then
                log "Module-tools dependencies installed."
            else
                log "WARNING: module-tools installdeps failed (e.g. String::Similarity needs build-essential). Some commands may not work."
            fi
        fi

        log "Module-tools setup completed!"
    else
        log "Module-tools not found, skipping..."
    fi
}

# Function to setup ZnunyCodePolicy (tools are mounted at /opt/tools)
setup_code_policy() {
    if [ -d "/opt/tools/ZnunyCodePolicy" ]; then
        log "Setting up ZnunyCodePolicy..."

        # Make ZnunyCodePolicy scripts executable (ignore errors if files don't exist)
        chmod +x /opt/tools/ZnunyCodePolicy/*.pl 2>/dev/null || true

        cpanm -i Algorithm::Diff Code::TidyAll Perl::Critic Perl::Tidy Pod::POM XML::Parser Text::PO::Gettext 2>/dev/null || true

        /opt/tools/ZnunyCodePolicy/bin/znuny.CodePolicy.pl --install-eslint

        log "ZnunyCodePolicy setup completed!"
    else
        log "ZnunyCodePolicy not found, skipping..."
    fi
}

# Function to setup Apache configuration for Znuny
setup_apache_config() {
    log "Setting up Apache configuration for Znuny..."

    # Suppress AH00558: set ServerName globally if not already set
    if ! grep -q '^ServerName ' /etc/apache2/apache2.conf 2>/dev/null; then
        echo "ServerName localhost" >> /etc/apache2/apache2.conf
    fi

    # Check if Znuny is mounted and has the Apache configuration
    if [ -f "$FRAMEWORK_DIR/scripts/apache2-httpd.include.conf" ]; then
        log "Using Znuny's Apache configuration..."

        # Only adapt URL paths: /otrs/ -> /znuny/ (install paths stay /opt/otrs, resolved via symlink)
        sed -e "s|/otrs/|/znuny/|g" \
           -e "s|/otrs-web/|/znuny-web/|g" \
           -e "s|<Location /otrs>|<Location /znuny>|g" \
           -e "s|<Location /otrs |<Location /znuny |g" \
           "$FRAMEWORK_DIR/scripts/apache2-httpd.include.conf" > "/etc/apache2/conf-available/zzz_znuny.conf"

        a2enconf "zzz_znuny"

        # Add redirect for root
        echo "RedirectMatch ^/$ /znuny/index.pl" >> /etc/apache2/apache2.conf

        # Set proper permissions for Znuny directories
        if [ -d "$FRAMEWORK_DIR/var/httpd" ]; then
            find "$FRAMEWORK_DIR/var/httpd" -type d -exec chmod 775 {} \;
            find "$FRAMEWORK_DIR/var/httpd" -type f -exec chmod 664 {} \;
        fi

        log "Znuny's Apache configuration applied!"
    else
        log "Znuny not found, using fallback configuration..."

        # Create fallback Znuny Apache configuration
        cat > "/etc/apache2/sites-available/znuny.conf" << EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot $FRAMEWORK_DIR/var/httpd/htdocs

    # Znuny CGI configuration
    ScriptAlias /znuny/ $FRAMEWORK_DIR/bin/cgi-bin/
    <Directory "$FRAMEWORK_DIR/bin/cgi-bin/">
        AllowOverride None
        Options +ExecCGI
        AddHandler cgi-script .cgi .pl
        Require all granted
    </Directory>

    # Znuny static files
    Alias /znuny-web/ $FRAMEWORK_DIR/var/httpd/htdocs/
    <Directory "$FRAMEWORK_DIR/var/httpd/htdocs/">
        AllowOverride None
        Require all granted
    </Directory>

    # Redirect root to Znuny
    RedirectMatch ^/$ /znuny/

    ErrorLog \${APACHE_LOG_DIR}/znuny_error.log
    CustomLog \${APACHE_LOG_DIR}/znuny_access.log combined
</VirtualHost>
EOF

        # Enable Znuny site and disable default
        a2ensite "znuny" > /dev/null 2>&1
        a2dissite 000-default > /dev/null 2>&1

        log "Fallback Apache configuration applied!"
    fi

    log "Apache configuration for Znuny completed!"
}

# Function to start Apache
start_apache() {
    log "Starting Apache web server..."
    exec apache2ctl -D FOREGROUND
}

# Main execution
main() {
    log "Znuny Development Environment Startup Script"
    log "=============================================="

    # Detect framework
    detect_framework

    # Znuny 6.x ships /opt/otrs paths; symlink so they resolve without changing framework config
    if [ "$FRAMEWORK_DIR" = "/opt/znuny" ] && [ ! -e /opt/otrs ]; then
        ln -sf /opt/znuny /opt/otrs
        log "Symlink /opt/otrs -> /opt/znuny created (6.x compatibility)"
    fi

    # 6.x has bin/otrs.Console.pl only – choose console script for this run (no symlink in git)
    CONSOLE_PL="$FRAMEWORK_DIR/bin/znuny.Console.pl"
    if [ ! -f "$CONSOLE_PL" ] && [ -f "$FRAMEWORK_DIR/bin/otrs.Console.pl" ]; then
        CONSOLE_PL="$FRAMEWORK_DIR/bin/otrs.Console.pl"
    fi
    export CONSOLE_PL

    # Set default database configuration if not provided
    DB_TYPE="${DB_TYPE:-mysql}"
    DB_HOST="${DB_HOST:-mysql}"
    DB_NAME="${DB_NAME:-$FRAMEWORK_DATABASE}"
    DB_USER="${DB_USER:-root}"
    DB_PASSWORD="${DB_PASSWORD:-znuny}"

    # Set default database port if not specified
    if [ -z "$DB_PORT" ]; then
        case $DB_TYPE in
            mysql|mariadb)
                DB_PORT="3306"
                ;;
            postgresql|postgres)
                DB_PORT="5432"
                ;;
            oracle)
                DB_PORT="1521"
                ;;
            *)
                DB_PORT="3306"
                ;;
        esac
    fi

    log "Znuny configuration:"
    log "  Version: $FRAMEWORK_VERSION"
    log "  Directory: $FRAMEWORK_DIR"
    log "  User: $FRAMEWORK_USER"
    log "  Database: $FRAMEWORK_DATABASE"

    log "Database configuration:"
    log "  Type: $DB_TYPE"
    log "  Host: $DB_HOST"
    log "  Port: $DB_PORT"
    log "  Database: $DB_NAME"
    log "  User: $DB_USER"

    # Detect database type
    detect_database

    # Wait for database to be ready
    wait_for_database "$DB_TYPE" "$DB_HOST" "$DB_PORT"

    # Setup znuny user
    setup_znuny_user

    # Git safe.directory for bind-mounted /opt/znuny (avoids "dubious ownership" in STDERR)
    setup_git_safe_directory

    # Configure database
    configure_database

    # Setup framework permissions
    setup_framework_permissions

    # Setup framework configuration
    setup_framework_config

    # Rebuild framework configuration
    rebuild_framework_config

    # Set initial password
    set_initial_password

    # Setup development tools (module-tools: cpanfile deps + symlinks)
    setup_module_tools
    setup_code_policy

    # Setup Apache configuration for framework
    setup_apache_config

    # Start Apache
    start_apache
}

# Run main function
main "$@"
