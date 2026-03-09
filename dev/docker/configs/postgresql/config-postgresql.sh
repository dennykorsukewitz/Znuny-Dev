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
DB_USER="${DB_USER:-znuny}"  # PostgreSQL default user
DB_PASSWORD="${DB_PASSWORD:-znuny}"

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

# Wait for PostgreSQL to be ready
log "Waiting for PostgreSQL to be ready..."
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
    if PGPASSWORD="$DB_PASSWORD" psql -h"$DB_HOST" -U"$DB_USER" -d"$FRAMEWORK_DATABASE" -c "SELECT 1;" >/dev/null 2>&1; then
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
    sed -i "s~\$Self->{DatabaseHost}.*~\$Self->{DatabaseHost}  = \"$DB_HOST\";~g" "$FRAMEWORK_DIR/Kernel/Config.pm"
    sed -i "s~\$Self->{DatabaseUser}.*~\$Self->{DatabaseUser}  = \"$DB_USER\";~g" "$FRAMEWORK_DIR/Kernel/Config.pm"
    sed -i "s~DBDSN~DBI:Pg:database=\$Self->{Database};host=\$Self->{DatabaseHost}~g" "$FRAMEWORK_DIR/Kernel/Config.pm"
    log "Config.pm updated successfully"
else
    log "WARNING: Config.pm not found, skipping DSN update"
fi

log "PostgreSQL configuration completed successfully!"
