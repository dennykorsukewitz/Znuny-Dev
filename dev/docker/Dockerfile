# Znuny Multi-Instance Development Environment Dockerfile
# Apache + Perl stack for Znuny instance containers

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

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
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

# Apache: CGI by default (mod_perl off). Set ZNUNY_USE_MOD_PERL=true at runtime to enable mod_perl.
ENV ZNUNY_USE_MOD_PERL=false
RUN a2dismod mpm_prefork perl 2>/dev/null || true; \
    a2enmod mpm_event cgi headers deflate filter rewrite ssl

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
COPY dev/docker/configs/root.zshrc /root/.zshrc

# Copy startup scripts
COPY dev/docker/startup-instance.sh /usr/local/bin/startup-instance.sh
RUN chmod +x /usr/local/bin/startup-instance.sh

# Copy common functions script
COPY dev/scripts/common.sh /usr/local/bin/common.sh
RUN chmod +x /usr/local/bin/common.sh

# Configure Apache for Znuny (after Znuny is mounted)
# This will be done in the startup script

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Start Apache
CMD ["/usr/local/bin/startup-instance.sh"]