#!/bin/bash

# PostgreSQL Configuration Script for Znuny Framework

set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] PostgreSQL Config: $1"
}

# Check if we have the required environment variables
if [ -z "$FRAMEWORK_DIR" ] || [ -z "$FRAMEWORK_DATABASE" ]; then
    log "ERROR: FRAMEWORK_DIR and FRAMEWORK_DATABASE must be set"
    exit 1
fi

# Database connection parameters
DB_HOST="${DB_HOST:-postgresql}"
DB_USER="${DB_USER:-znuny}"  # Instance DB user (created if not exists)
DB_PASSWORD="${DB_PASSWORD:-znuny}"

# For shared DB: use postgres superuser (never fall back to POSTGRES_PASSWORD - that may be instance user's password)
POSTGRES_ROOT_PASSWORD="${POSTGRES_ROOT_PASSWORD:-postgres_shared}"
if [ -n "$POSTGRES_ROOT_PASSWORD" ]; then
    BOOTSTRAP_USER="postgres"
    BOOTSTRAP_PASSWORD="$POSTGRES_ROOT_PASSWORD"
    log "Using postgres superuser for initial setup (shared DB mode)"
else
    BOOTSTRAP_USER="$DB_USER"
    BOOTSTRAP_PASSWORD="$DB_PASSWORD"
fi

log "Configuring PostgreSQL database: $FRAMEWORK_DATABASE"

# Find database schema files
SCHEMA_FILE=$(find "$FRAMEWORK_DIR"/scripts/database -type f -name '*schema.postgresql.sql' 2>/dev/null | head -1)
INITIAL_INSERT_FILE=$(find "$FRAMEWORK_DIR"/scripts/database -type f -name '*initial_insert.postgresql.sql' 2>/dev/null | head -1)
SCHEMA_POST_FILE=$(find "$FRAMEWORK_DIR"/scripts/database -type f -name '*schema-post.postgresql.sql' 2>/dev/null | head -1)

if [ -z "$SCHEMA_FILE" ]; then
    log "ERROR: No PostgreSQL schema file found in $FRAMEWORK_DIR/scripts/database/"
    exit 1
fi

log "Found schema files:"
log "  Schema: $SCHEMA_FILE"
log "  Initial Insert: $INITIAL_INSERT_FILE"
log "  Post Schema: $SCHEMA_POST_FILE"

# Wait for PostgreSQL to be ready (use bootstrap credentials)
log "Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
    if PGPASSWORD="$BOOTSTRAP_PASSWORD" psql -h"$DB_HOST" -U"$BOOTSTRAP_USER" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        log "PostgreSQL is ready!"
        break
    fi
    log "PostgreSQL not ready yet (attempt $attempt/$max_attempts)..."
    sleep 2
    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    log "ERROR: PostgreSQL not available after $max_attempts attempts!"
    exit 1
fi

# When using postgres superuser: create database and role for shared DB mode
if [ "$BOOTSTRAP_USER" = "postgres" ]; then
    log "Creating database and role for shared DB..."
    # Escape single quotes in password for SQL: ' -> ''
    DB_PASSWORD_ESCAPED="${DB_PASSWORD//\'/\'\'}"
    PGPASSWORD="$BOOTSTRAP_PASSWORD" psql -h"$DB_HOST" -U"$BOOTSTRAP_USER" -d postgres -v ON_ERROR_STOP=1 << EOF
-- Create role if not exists (PostgreSQL 9.5+)
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE ROLE "$DB_USER" WITH LOGIN PASSWORD '$DB_PASSWORD_ESCAPED';
    ELSE
        ALTER ROLE "$DB_USER" WITH PASSWORD '$DB_PASSWORD_ESCAPED';
    END IF;
END
\$\$;
EOF
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to create role"
        exit 1
    fi
    # Create database (may fail if exists - that's ok on restart)
    PGPASSWORD="$BOOTSTRAP_PASSWORD" psql -h"$DB_HOST" -U"$BOOTSTRAP_USER" -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$FRAMEWORK_DATABASE\" OWNER \"$DB_USER\" ENCODING 'UTF8' TEMPLATE template0;" 2>/dev/null || true
    # Verify database exists
    if ! PGPASSWORD="$DB_PASSWORD" psql -h"$DB_HOST" -U"$DB_USER" -d"$FRAMEWORK_DATABASE" -c "SELECT 1;" >/dev/null 2>&1; then
        log "ERROR: Database or role setup failed - cannot connect as $DB_USER"
        exit 1
    fi
    log "Database and role created successfully"
fi

# Import schema
log "Importing database schema..."
PGPASSWORD="$DB_PASSWORD" psql -q -h"$DB_HOST" -U"$DB_USER" "$FRAMEWORK_DATABASE" < "$SCHEMA_FILE" || {
    log "ERROR: Failed to import schema"
    exit 1
}

# Import initial data
if [ -n "$INITIAL_INSERT_FILE" ] && [ -f "$INITIAL_INSERT_FILE" ]; then
    log "Importing initial data..."
    PGPASSWORD="$DB_PASSWORD" psql -q -h"$DB_HOST" -U"$DB_USER" "$FRAMEWORK_DATABASE" < "$INITIAL_INSERT_FILE" || {
        log "ERROR: Failed to import initial data"
        exit 1
    }
fi

# Import post-schema data
if [ -n "$SCHEMA_POST_FILE" ] && [ -f "$SCHEMA_POST_FILE" ]; then
    log "Importing post-schema data..."
    PGPASSWORD="$DB_PASSWORD" psql -q -h"$DB_HOST" -U"$DB_USER" "$FRAMEWORK_DATABASE" < "$SCHEMA_POST_FILE" || {
        log "ERROR: Failed to import post-schema data"
        exit 1
    }
fi

# Update Config.pm with PostgreSQL DSN
log "Updating Config.pm with PostgreSQL DSN..."
if [ -f "$FRAMEWORK_DIR/Kernel/Config.pm" ]; then
    # Only replace the DatabaseHost assignment line (not occurrences inside DSN string)
    sed -i "s/^\s*\$Self->{DatabaseHost}\s*=\s*[^;]*;/\$Self->{DatabaseHost}  = \"$DB_HOST\";/" "$FRAMEWORK_DIR/Kernel/Config.pm"
    sed -i "s/^\s*\$Self->{DatabaseUser}\s*=\s*[^;]*;/\$Self->{DatabaseUser}  = \"$DB_USER\";/" "$FRAMEWORK_DIR/Kernel/Config.pm"
    # Replace MySQL DSN with PostgreSQL DSN
    sed -i "s|\$Self->{DatabaseDSN} = \"DBI:mysql:[^\"]*\";|\$Self->{DatabaseDSN} = \"DBI:Pg:dbname=\$Self->{Database};host=\$Self->{DatabaseHost};\";|" "$FRAMEWORK_DIR/Kernel/Config.pm"
    log "Config.pm updated successfully"
else
    log "WARNING: Config.pm not found, skipping DSN update"
fi

log "PostgreSQL configuration completed successfully!"
