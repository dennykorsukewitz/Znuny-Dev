# Znuny Multi-Instance Development Environment Dockerfile
# Includes Apache with reverse proxy configuration for multiple Znuny instances

FROM ubuntu:24.04
LABEL org.opencontainers.image.authors="Denny Korsukéwitz" \
      org.opencontainers.image.title="Znuny Development Environment" \
      org.opencontainers.image.description="https://github.com/dennykorsukewitz/Znuny-Dev"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_PID_FILE=/var/run/apache2/apache2.pid
ENV APACHE_RUN_DIR=/var/run/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2
ENV TZ="/usr/share/zoneinfo/Europe/Berlin"
RUN ln -snf $TZ /etc/localtime && echo $TZ > /etc/timezone

# Oracle environment
ENV ORACLE_HOME="/usr/lib/oracle/19.6/client64"
ENV NLS_DATE_FORMAT="YYYY-MM-DD HH24:MI:SS"
ENV NLS_LANG="GERMAN_GERMANY.AL32UTF8"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    apache2 \
    apache2-utils \
    libapache2-mod-perl2 \
    perl \
    cpanminus \
    build-essential \
    curl \
    wget \
    git \
    vim \
    nano \
    mysql-client \
    postgresql-client \
    libmysqlclient-dev \
    libpq-dev \
    libssl-dev \
    libxml2-dev \
    libexpat1-dev \
    zlib1g-dev \
    libdbi-perl \
    libdbd-mysql-perl \
    libdbd-pg-perl \
    libdbd-odbc-perl \
    libjson-perl \
    libyaml-perl \
    libxml-simple-perl \
    libnet-dns-perl \
    libnet-ldap-perl \
    libio-socket-ssl-perl \
    libwww-perl \
    libauthen-sasl-perl \
    libauthen-ntlm-perl \
    libmail-imapclient-perl \
    libplack-perl \
    libtimedate-perl \
    libpdf-api2-perl \
    libsoap-lite-perl \
    libtext-csv-xs-perl \
    libjson-xs-perl \
    libapache-dbi-perl \
    libxml-libxml-perl \
    libxml-libxslt-perl \
    libarchive-zip-perl \
    libcrypt-eksblowfish-perl \
    libencode-hanextra-perl \
    libtemplate-perl \
    libdatetime-perl \
    libmoo-perl \
    libhash-merge-perl \
    libical-parser-perl \
    libspreadsheet-xlsx-perl \
    libjavascript-minifier-xs-perl \
    libcss-minifier-xs-perl \
    liblocale-po-perl \
    libstring-similarity-perl \
    libcrypt-jwt-perl \
    libcrypt-openssl-x509-perl \
    bash-completion \
    libyaml-libyaml-perl \
    nullmailer \
    uuid-dev \
    cron \
    zsh \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install additional CPAN modules (incl. ZnunyCodePolicy deps; before purge of build-essential)
RUN cpanm --notest --force Jq Data::UUID Ref::Util && \
    cpanm --notest Algorithm::Diff Code::TidyAll Perl::Critic Perl::Tidy Pod::POM XML::Parser && \
    apt-get purge -y uuid-dev build-essential && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*


# Configure nullmailer
RUN echo "smtp.unibas.ch" > /etc/nullmailer/remotes

# Enable required Apache modules (use mpm_prefork for mod_perl)
RUN a2dismod mpm_event && \
    a2enmod mpm_prefork perl headers deflate filter cgi rewrite && \
    a2enmod proxy proxy_http proxy_balancer lbmethod_byrequests ssl

# Create directories
RUN mkdir -p /opt/znuny \
    && mkdir -p /var/lib/znuny \
    && mkdir -p /var/log/znuny \
    && mkdir -p /etc/znuny/configs

# Set permissions
RUN chown -R www-data:www-data /opt/znuny* \
    && chown -R www-data:www-data /var/lib/znuny \
    && chown -R www-data:www-data /var/log/znuny \
    && chown -R www-data:www-data /tmp

# Create Apache configuration directory
RUN mkdir -p /etc/apache2/sites-available \
    && mkdir -p /etc/apache2/sites-enabled

# Root zsh config (colored shell for zd shell --root)
RUN mkdir -p /root && cat > /root/.zshrc << 'ZROOT'
# Znuny Dev - root zsh (colored)
autoload -U colors && colors
autoload -U compinit && compinit
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
PROMPT='%F{red}root%f@%F{blue}%m%f:%F{yellow}%~%f# '
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
ZROOT

# Copy startup scripts
COPY dev/docker/startup-instance.sh /usr/local/bin/startup-instance.sh
COPY dev/docker/startup-reverse-proxy.sh /usr/local/bin/startup-reverse-proxy.sh
RUN chmod +x /usr/local/bin/startup-instance.sh /usr/local/bin/startup-reverse-proxy.sh

# Copy Apache configuration template
COPY dev/templates/apache/apache-config-template.conf /etc/apache2/sites-available/000-default.conf.template

# Copy common functions script
COPY dev/scripts/common.sh /usr/local/bin/common.sh
RUN chmod +x /usr/local/bin/common.sh

# Create Apache virtual host generator script
COPY dev/docker/generate-apache-config.sh /usr/local/bin/generate-apache-config.sh
RUN chmod +x /usr/local/bin/generate-apache-config.sh

# Configure Apache for Znuny (after Znuny is mounted)
# This will be done in the startup script

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start Apache
CMD ["/usr/local/bin/startup-instance.sh"]