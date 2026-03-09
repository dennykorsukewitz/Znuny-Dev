#!/bin/bash

# Oracle Configuration Script for Znuny Framework

set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Oracle Config: $1"
}

# Check if we have the required environment variables
if [ -z "$FRAMEWORK_DIR" ] || [ -z "$FRAMEWORK_DATABASE" ]; then
    log "ERROR: FRAMEWORK_DIR and FRAMEWORK_DATABASE must be set"
    exit 1
fi

# Oracle connection parameters
DB_HOST="${DB_HOST:-oracle}"
DB_PORT="${DB_PORT:-1521}"
DB_SID="${DB_SID:-xe}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-znuny}"

log "Configuring Oracle database: $FRAMEWORK_DATABASE"

# Wait for Oracle to be ready
log "Waiting for Oracle to be ready..."
DBOK=1
attempt=1
max_attempts=60
while [ "$DBOK" -eq 1 ] && [ $attempt -le $max_attempts ]; do
    echo exit | sqlplus64 -L system/oracle@"$DB_HOST:$DB_PORT/$DB_SID" >/dev/null 2>&1
    DBOK=$?
    if [ "$DBOK" -eq 0 ]; then
        log "Oracle is ready!"
        break
    fi
    log "Oracle not ready yet (attempt $attempt/$max_attempts)..."
    sleep 30
    attempt=$((attempt + 1))
done

if [ "$DBOK" -ne 0 ]; then
    log "ERROR: Oracle not available after $max_attempts attempts!"
    exit 1
fi

# Create Oracle database user
log "Creating Oracle database user..."
sqlplus64 -S system/oracle@"$DB_HOST:$DB_PORT/$DB_SID" > /dev/null << EOSQL
ALTER DATABASE datafile 1 AUTOEXTEND ON MAXSIZE 5G;
CREATE USER $DB_USER IDENTIFIED by $DB_PASSWORD;
GRANT CONNECT TO $DB_USER;
GRANT ALL PRIVILEGES TO $DB_USER;
EXIT;
EOSQL

# Find database schema files
SCHEMA_FILE=$(find "$FRAMEWORK_DIR"/scripts/database -type f -name '*schema.oracle.sql' 2>/dev/null | head -1)
INITIAL_INSERT_FILE=$(find "$FRAMEWORK_DIR"/scripts/database -type f -name '*initial_insert.oracle.sql' 2>/dev/null | head -1)
SCHEMA_POST_FILE=$(find "$FRAMEWORK_DIR"/scripts/database -type f -name '*schema-post.oracle.sql' 2>/dev/null | head -1)

if [ -z "$SCHEMA_FILE" ]; then
    log "ERROR: No Oracle schema file found in $FRAMEWORK_DIR/scripts/database/"
    exit 1
fi

log "Found schema files:"
log "  Schema: $SCHEMA_FILE"
log "  Initial Insert: $INITIAL_INSERT_FILE"
log "  Post Schema: $SCHEMA_POST_FILE"

# Import schema
log "Importing database schema..."
echo exit | sqlplus64 -S "$DB_USER/$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_SID" @"$SCHEMA_FILE" > /dev/null || {
    log "ERROR: Failed to import schema"
    exit 1
}

# Import initial data
if [ -n "$INITIAL_INSERT_FILE" ] && [ -f "$INITIAL_INSERT_FILE" ]; then
    log "Importing initial data..."
    echo exit | sqlplus64 -S "$DB_USER/$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_SID" @"$INITIAL_INSERT_FILE" > /dev/null || {
        log "ERROR: Failed to import initial data"
        exit 1
    }
fi

# Import post-schema data
if [ -n "$SCHEMA_POST_FILE" ] && [ -f "$SCHEMA_POST_FILE" ]; then
    log "Importing post-schema data..."
    echo exit | sqlplus64 -S "$DB_USER/$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_SID" @"$SCHEMA_POST_FILE" > /dev/null || {
        log "ERROR: Failed to import post-schema data"
        exit 1
    }
fi

# Update Config.pm with Oracle DSN
log "Updating Config.pm with Oracle DSN..."
if [ -f "$FRAMEWORK_DIR/Kernel/Config.pm" ]; then
    sed -i "s~DBDSN~DBI:Oracle://$DB_HOST:$DB_PORT/$DB_SID~g" "$FRAMEWORK_DIR/Kernel/Config.pm"
    log "Config.pm updated successfully"
else
    log "WARNING: Config.pm not found, skipping DSN update"
fi

log "Oracle configuration completed successfully!"
