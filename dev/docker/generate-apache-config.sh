#!/bin/bash

# Apache Configuration Generator for Znuny Multi-Instance Setup
# This script generates Apache virtual host configuration based on available frameworks

# Don't exit on errors to prevent stopping on non-critical issues
# set -e

# Load common functions (in the image common.sh is beside this script; in-repo copy for ShellCheck: dev/scripts/common.sh)
# shellcheck source=../scripts/common.sh
source "$(dirname "$0")/common.sh"

# Configuration
APACHE_CONFIG_FILE="/etc/apache2/sites-available/000-default.conf"
APACHE_CONFIG_TEMPLATE="/etc/apache2/sites-available/000-default.conf.template"

# Function to generate instance dashboard
generate_instance_dashboard() {
    local frameworks=()
    read_lines_to_array frameworks < <(get_available_frameworks)
    # Create dashboard directory
    mkdir -p /var/www/html/znuny-dev

    # Create dashboard HTML
    cat > /var/www/html/znuny-dev/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Znuny Development Instances</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        .header {
            text-align: center;
            color: #2c3e50;
            margin-bottom: 40px;
            background: white;
            padding: 40px;
            border-radius: 15px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }

        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            color: #e67e22;
            font-weight: 700;
        }

        .header p {
            font-size: 1.2rem;
            color: #7f8c8d;
        }

        .instances-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin-bottom: 40px;
        }

        .instance-card {
            background: white;
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            text-decoration: none;
            color: inherit;
            border-left: 4px solid #e67e22;
        }

        .instance-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(0,0,0,0.15);
        }

        .instance-name {
            font-size: 1.8rem;
            font-weight: bold;
            color: #2c3e50;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }

        .instance-name::before {
            content: "🚀";
            margin-right: 10px;
            font-size: 1.5rem;
        }

        .instance-description {
            color: #7f8c8d;
            margin-bottom: 20px;
            line-height: 1.6;
        }

        .instance-details {
            background: #f8f9fa;
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 20px;
            font-size: 0.9rem;
        }

        .detail-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
            padding: 5px 0;
            border-bottom: 1px solid #e9ecef;
        }

        .detail-row:last-child {
            border-bottom: none;
            margin-bottom: 0;
        }

        .detail-label {
            font-weight: 600;
            color: #495057;
        }

        .detail-value {
            color: #6c757d;
            font-family: 'Courier New', monospace;
        }

        .instance-links {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }

        .instance-link {
            display: inline-block;
            background: #e67e22;
            color: white;
            padding: 10px 20px;
            border-radius: 20px;
            text-decoration: none;
            font-weight: bold;
            transition: all 0.3s ease;
            font-size: 0.9rem;
        }

        .instance-link:hover {
            background: #d35400;
            transform: scale(1.05);
        }

        .instance-link.secondary {
            background: #95a5a6;
        }

        .instance-link.secondary:hover {
            background: #7f8c8d;
        }

        .footer {
            text-align: center;
            color: #7f8c8d;
            margin-top: 40px;
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }

        .footer a {
            color: #e67e22;
            text-decoration: none;
        }

        .footer a:hover {
            text-decoration: underline;
        }

        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            background: #27ae60;
            animation: pulse 2s infinite;
        }

        .status-indicator.warning {
            background: #f39c12;
        }

        .status-indicator.error {
            background: #e74c3c;
        }

        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }

        .no-instances {
            text-align: center;
            color: #7f8c8d;
            background: white;
            padding: 40px;
            border-radius: 15px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }

        .no-instances h2 {
            margin-bottom: 20px;
            font-size: 2rem;
            color: #2c3e50;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Znuny Development</h1>
            <p>Available Development Instances</p>
        </div>

        <div class="instances-grid" id="instances-grid">
            <!-- Instances will be populated by JavaScript -->
        </div>

        <div class="footer">
            <p>Znuny Development Environment | Powered by <a href="https://www.docker.com/" target="_blank">Docker</a></p>
            <p>Created by <a href="https://github.com/dennykorsukewitz" target="_blank">@dennykorsukewitz</a></p>
        </div>
    </div>

    <script>
        // Dynamic instances data - generated by Apache config generator
        const instances = [
EOF

    # Generate dynamic instances data based on available frameworks (BASE_PORT default 10000)
    local base_port="${BASE_PORT:-10000}"
    local port_index=0
    for framework in "${frameworks[@]}"; do
        local port=$((base_port + port_index))
        local db_port="3307"
        local db_type="MariaDB"
        ((port_index++))

        cat >> /var/www/html/znuny-dev/index.html << EOF
            {
                name: '$framework',
                description: '${framework^} Instance - ${framework^} environment for Znuny development',
                url: '/$framework/',
                directUrl: 'http://localhost:$port/',
                port: $port,
                dbPort: $db_port,
                dbType: '$db_type',
                dbName: '$framework',
                status: 'running',
                lastUpdated: new Date().toISOString()
            },
EOF
    done

    # Remove trailing comma from last instance
    if [ ${#frameworks[@]} -gt 0 ]; then
        sed -i 's/,$//' /var/www/html/znuny-dev/index.html
    fi

    cat >> /var/www/html/znuny-dev/index.html << 'EOF'
        ];

        const grid = document.getElementById('instances-grid');

        if (instances.length === 0) {
            grid.innerHTML = `
                <div class="no-instances">
                    <h2>No Instances Available</h2>
                    <p>Create a new instance using the instance.sh script</p>
                </div>
            `;
        } else {
            instances.forEach(instance => {
                const card = document.createElement('div');
                card.className = 'instance-card';

                const statusClass = instance.status === 'running' ? '' :
                                  instance.status === 'warning' ? 'warning' : 'error';

                card.innerHTML = `
                    <div class="instance-name">
                        ${instance.name.toUpperCase()}
                        <span class="status-indicator ${statusClass}"></span>
                    </div>
                    <div class="instance-description">
                        ${instance.description}
                    </div>
                    <div class="instance-details">
                        <div class="detail-row">
                            <span class="detail-label">Port:</span>
                            <span class="detail-value">${instance.port}</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Database:</span>
                            <span class="detail-value">${instance.dbType} (${instance.dbName})</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">DB Port:</span>
                            <span class="detail-value">${instance.dbPort}</span>
                        </div>
                        <div class="detail-row">
                            <span class="detail-label">Direct URL:</span>
                            <span class="detail-value">${instance.directUrl}</span>
                        </div>
                    </div>
                    <div class="instance-links">
                        <a href="${instance.url}" class="instance-link">Open Instance</a>
                        <a href="${instance.directUrl}" class="instance-link secondary" target="_blank">Direct Access</a>
                    </div>
                `;
                grid.appendChild(card);
            });
        }
    </script>
</body>
</html>
EOF

    cat << EOF
    # Instance Dashboard
    Alias /znuny-dev /var/www/html/znuny-dev/index.html
    Alias /znuny-dev/ /var/www/html/znuny-dev/

    <Directory /var/www/html/znuny-dev>
        Options -Indexes
        AllowOverride None
        Require all granted
        <Files "*.js">
            Header set Content-Type "application/javascript"
        </Files>
    </Directory>
EOF
}

# Function to generate framework proxy configuration
generate_framework_proxy_config() {
    local framework="$1"
    local port="$2"

    cat << EOF
    # Proxy configuration for $framework
    <Location /$framework/>
        ProxyPreserveHost On
        ProxyPass http://znuny-${framework}-instance:80/
        ProxyPassReverse /

        # Rewrite Location header to include framework prefix (only for main app redirects)
        Header edit Location ^http://localhost/znuny/index\.pl http://localhost/$framework/index.pl
        Header edit Location ^/znuny/index\.pl /$framework/index.pl

        # Set headers for Znuny
        RequestHeader set X-Forwarded-Proto "http"
        RequestHeader set X-Forwarded-Port "80"
        RequestHeader set X-Forwarded-For "%{REMOTE_ADDR}s"
    </Location>

    # Redirect /$framework/ to /$framework/index.pl
    RewriteEngine On
    RewriteRule ^/$framework/$ /$framework/index.pl [R=302,L]

    # Proxy /$framework/index.pl to /znuny/index.pl
    <Location /$framework/index.pl>
        ProxyPreserveHost On
        ProxyPass http://znuny-${framework}-instance:80/znuny/index.pl
        ProxyPassReverse /

        # Rewrite HTML content to fix asset URLs
        AddOutputFilterByType SUBSTITUTE text/html
        Substitute "s|/znuny-web/|/$framework/znuny-web/|ni"
        Substitute "s|/static/|/$framework/static/|ni"
        Substitute "s|/var/|/$framework/var/|ni"

        # Set headers for Znuny
        RequestHeader set X-Forwarded-Proto "http"
        RequestHeader set X-Forwarded-Port "80"
        RequestHeader set X-Forwarded-For "%{REMOTE_ADDR}s"
    </Location>

    # Static assets for $framework
    <Location /$framework/static/>
        ProxyPreserveHost On
        ProxyPass http://znuny-${framework}-instance:80/static/
        ProxyPassReverse /
    </Location>

    <Location /$framework/var/>
        ProxyPreserveHost On
        ProxyPass http://znuny-${framework}-instance:80/var/
        ProxyPassReverse /
    </Location>

    <Location /$framework/znuny-web/>
        ProxyPreserveHost On
        ProxyPass http://znuny-${framework}-instance:80/znuny-web/
        ProxyPassReverse /
    </Location>

EOF
}

# Function to generate Apache configuration
generate_apache_config() {
    print_status "Generating Apache configuration for multi-instance setup..."

    local frameworks=()

    read_lines_to_array frameworks < <(get_available_frameworks)
    if [ ${#frameworks[@]} -eq 0 ]; then
        print_status "No frameworks found in mounted directory. Using default configuration."
        cp "$APACHE_CONFIG_TEMPLATE" "$APACHE_CONFIG_FILE"
        return 0
    fi

    print_status "Found frameworks: ${frameworks[*]}"

    # Create backup of existing config
    if [ -f "$APACHE_CONFIG_FILE" ]; then
        cp "$APACHE_CONFIG_FILE" "${APACHE_CONFIG_FILE}.backup"
        print_status "Backed up existing Apache configuration"
    fi

    # Generate new configuration (BASE_PORT default 10000)
    local base_port="${BASE_PORT:-10000}"
    cat > "$APACHE_CONFIG_FILE" << EOF
# Apache Virtual Host Configuration for Znuny Multi-Instance Setup
# This file is automatically generated by the Apache configuration generator

<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/html

    # Health check endpoint (first instance port)
    <Location /health>
        ProxyPass http://localhost:${base_port}/health
        ProxyPassReverse http://localhost:${base_port}/health
    </Location>

    # Instance Dashboard
    Alias /znuny-dev /var/www/html/znuny-dev/index.html
    Alias /znuny-dev/ /var/www/html/znuny-dev/

    <Directory /var/www/html/znuny-dev>
        Options -Indexes
        AllowOverride None
        Require all granted
        <Files "*.js">
            Header set Content-Type "application/javascript"
        </Files>
    </Directory>

EOF

    # Generate instance dashboard
    print_status "Generating instance dashboard"
    generate_instance_dashboard >> "$APACHE_CONFIG_FILE"

    # Add framework-specific proxy configurations (BASE_PORT default 10000, overridable via env)
    local base_port="${BASE_PORT:-10000}"
    local port_index=0
    for framework in "${frameworks[@]}"; do
        local port=$((base_port + port_index))
        print_status "Adding proxy configuration for $framework (port: $port)"

        generate_framework_proxy_config "$framework" "$port" >> "$APACHE_CONFIG_FILE"

        ((port_index++))
    done

    # Add remaining HTTP configuration
    cat >> "$APACHE_CONFIG_FILE" << 'EOF'

    # Error and access logs
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    # Security headers
    Header always set X-Content-Type-Options nosniff
    Header always set X-Frame-Options DENY
    Header always set X-XSS-Protection "1; mode=block"

    # Enable compression
    LoadModule deflate_module modules/mod_deflate.so
    <Location />
        SetOutputFilter DEFLATE
        SetEnvIfNoCase Request_URI \
            \.(?:gif|jpe?g|png)$ no-gzip dont-vary
        SetEnvIfNoCase Request_URI \
            \.(?:exe|t?gz|zip|bz2|sit|rar)$ no-gzip dont-vary
    </Location>
</VirtualHost>
EOF

    print_success "Apache configuration generated successfully!"
    print_status "Frameworks configured: ${frameworks[*]}"

    # Show URL mapping
    print_status "URL mapping:"
    for framework in "${frameworks[@]}"; do
        print_list "$framework: http://localhost/$framework/"
    done

    # Test Apache configuration
    if apache2ctl configtest; then
        print_success "Apache configuration is valid"
    else
        print_error "Apache configuration has errors"
        return 1
    fi
}

# Function to reload Apache configuration
reload_apache() {
    print_status "Reloading Apache configuration..."

    if apache2ctl graceful; then
        print_success "Apache configuration reloaded successfully"
    else
        print_error "Failed to reload Apache configuration"
        return 1
    fi
}

# Main function
main() {
    case "${1:-}" in
        --reload)
            generate_apache_config
            reload_apache
            ;;
        "")
            generate_apache_config
            ;;
        *)
            print_error "Unknown option: $1"
            print_status "Usage: $0 [--reload]"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
