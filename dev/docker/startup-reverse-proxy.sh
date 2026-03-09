#!/bin/bash

# Znuny Reverse Proxy Startup Script
# Minimal startup script for Apache reverse proxy

# Don't exit on errors to prevent container restart loops
# set -e

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Znuny Reverse Proxy..."

# Enable required Apache modules
log "Enabling Apache modules..."
a2enmod proxy proxy_http rewrite headers deflate filter substitute 2>/dev/null || true

# Disable default site
a2dissite 000-default 2>/dev/null || true

# Stop any running Apache instance first
log "Stopping any running Apache instances..."
apache2ctl stop 2>/dev/null || true

# Generate Apache configuration
log "Generating Apache configuration..."
if [ -f "/usr/local/bin/generate-apache-config.sh" ]; then
    /usr/local/bin/generate-apache-config.sh
    log "Apache configuration generated successfully"
else
    log "WARNING: Apache config generator not found, using default configuration"
fi

# Enable the site
log "Enabling Apache site..."
a2ensite 000-default 2>/dev/null || true

# Start Apache in foreground
log "Starting Apache web server..."
exec apache2ctl -D FOREGROUND
