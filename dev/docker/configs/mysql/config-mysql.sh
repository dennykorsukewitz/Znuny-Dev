#!/bin/bash

# MySQL Configuration Script for Znuny Framework
# With full UTF8MB4 support

set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] MySQL UTF8MB4 Config: $1"
}

# Check if we have the required environment variables
if [ -z "$FRAMEWORK_DIR" ] || [ -z "$FRAMEWORK_DATABASE" ]; then
    log "ERROR: FRAMEWORK_DIR and FRAMEWORK_DATABASE must be set"
    exit 1
fi

# Database connection parameters
DB_HOST="${DB_HOST:-mysql}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-znuny}"

# For shared DB: use root to create database and app user (MARIADB_ROOT_PASSWORD or MYSQL_ROOT_PASSWORD)
DB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-$MYSQL_ROOT_PASSWORD}"
if [ -n "$DB_ROOT_PASSWORD" ]; then
    BOOTSTRAP_USER="root"
    BOOTSTRAP_PASSWORD="$DB_ROOT_PASSWORD"
    log "Using root for initial setup (shared DB mode)"
else
    BOOTSTRAP_USER="$DB_USER"
    BOOTSTRAP_PASSWORD="$DB_PASSWORD"
fi

log "Configuring MySQL database with UTF8MB4: $FRAMEWORK_DATABASE"

# Find database schema files
SCHEMA_FILE=$(find "$FRAMEWORK_DIR"/scripts/database -type f -name '*schema.mysql.sql' 2>/dev/null | head -1)
INITIAL_INSERT_FILE=$(find "$FRAMEWORK_DIR"/scripts/database -type f -name '*initial_insert.mysql.sql' 2>/dev/null | head -1)
SCHEMA_POST_FILE=$(find "$FRAMEWORK_DIR"/scripts/database -type f -name '*schema-post.mysql.sql' 2>/dev/null | head -1)

if [ -z "$SCHEMA_FILE" ]; then
    log "ERROR: No MySQL schema file found in $FRAMEWORK_DIR/scripts/database/"
    exit 1
fi

log "Found schema files:"
log "  Schema: $SCHEMA_FILE"
log "  Initial Insert: $INITIAL_INSERT_FILE"
log "  Post Schema: $SCHEMA_POST_FILE"

# Wait for MySQL to be ready (use bootstrap credentials)
log "Waiting for MySQL to be ready..."
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
    if mysql -h"$DB_HOST" -u"$BOOTSTRAP_USER" -p"$BOOTSTRAP_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
        log "MySQL is ready!"
        break
    fi
    log "MySQL not ready yet (attempt $attempt/$max_attempts)..."
    sleep 2
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    log "ERROR: MySQL not available after $max_attempts attempts!"
    exit 1
fi

# When using root: create database and app user for shared DB mode
if [ "$BOOTSTRAP_USER" = "root" ]; then
    log "Creating database and user for shared DB..."
    mysql -h"$DB_HOST" -u"$BOOTSTRAP_USER" -p"$BOOTSTRAP_PASSWORD" -e "
        CREATE DATABASE IF NOT EXISTS \`$FRAMEWORK_DATABASE\` DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
        GRANT ALL PRIVILEGES ON \`$FRAMEWORK_DATABASE\`.* TO '$DB_USER'@'%';
        FLUSH PRIVILEGES;
    " || {
        log "ERROR: Failed to create database or user"
        exit 1
    }
    log "Database and user created successfully"
fi

# Create database with UTF8MB4 charset (full Unicode support) if not done above
if [ "$BOOTSTRAP_USER" != "root" ]; then
    log "Setting database charset to UTF8MB4..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" -e "ALTER DATABASE $FRAMEWORK_DATABASE DEFAULT CHARACTER SET utf8mb4;ALTER DATABASE $FRAMEWORK_DATABASE DEFAULT COLLATE utf8mb4_unicode_ci;" || {
        log "ERROR: Failed to set database charset to UTF8MB4"
        exit 1
    }
fi

# Check if database is already configured
log "Checking if database is already configured..."
TABLE_COUNT=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$FRAMEWORK_DATABASE" -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$FRAMEWORK_DATABASE';" -s -N 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" -gt 0 ]; then
    log "Database already configured with $TABLE_COUNT tables, skipping schema import"
else
    # Import schema
    log "Importing database schema..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$FRAMEWORK_DATABASE" < "$SCHEMA_FILE" || {
        log "ERROR: Failed to import schema"
        exit 1
    }
fi

# Import initial data (only if database was just created)
if [ "$TABLE_COUNT" -eq 0 ] && [ -n "$INITIAL_INSERT_FILE" ] && [ -f "$INITIAL_INSERT_FILE" ]; then
    log "Importing initial data..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$FRAMEWORK_DATABASE" < "$INITIAL_INSERT_FILE" || {
        log "ERROR: Failed to import initial data"
        exit 1
    }
elif [ "$TABLE_COUNT" -gt 0 ]; then
    log "Skipping initial data import (database already configured)"
fi

# Import post-schema data (only if database was just created)
if [ "$TABLE_COUNT" -eq 0 ] && [ -n "$SCHEMA_POST_FILE" ] && [ -f "$SCHEMA_POST_FILE" ]; then
    log "Importing post-schema data..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$FRAMEWORK_DATABASE" < "$SCHEMA_POST_FILE" || {
        log "ERROR: Failed to import post-schema data"
        exit 1
    }
elif [ "$TABLE_COUNT" -gt 0 ]; then
    log "Skipping post-schema data import (database already configured)"
fi

# Update Config.pm with MySQL DSN
log "Updating Config.pm with MySQL DSN..."
if [ -f "$FRAMEWORK_DIR/Kernel/Config.pm" ]; then
    sed -i "s~DBDSN~DBI:mysql:database=\$Self->{Database};host=\$Self->{DatabaseHost};~g" "$FRAMEWORK_DIR/Kernel/Config.pm"
    log "Config.pm updated successfully"
else
    log "WARNING: Config.pm not found, skipping DSN update"
fi

log "MySQL UTF8MB4 configuration completed successfully!"
