FROM php:8.4-apache-bookworm

LABEL maintainer="AtroCore Railway PoC"

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && printf "memory_limit = 512M\nmax_execution_time = 180\nmax_input_time = 180\npost_max_size = 64M\nupload_max_filesize = 64M\n" >> "$PHP_INI_DIR/php.ini" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        git curl ca-certificates cron postgresql-client zip unzip \
        build-essential locales \
        libcurl4 libcurl4-openssl-dev libsodium-dev \
        libfreetype-dev libjpeg62-turbo-dev libpng-dev libpq-dev \
        libavif-dev libattr1-dev libonig-dev libzip-dev zlib1g-dev \
        libmagickwand-dev libldap2-dev libldap-common \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-avif \
    && docker-php-ext-install -j"$(nproc)" \
        mbstring curl gd xml zip pdo_pgsql exif ftp ldap sockets \
    && pecl install xattr imagick \
    && docker-php-ext-enable xattr imagick \
    && a2enmod rewrite \
    && (a2dismod mpm_event || true) \
    && (a2dismod mpm_worker || true) \
    && a2enmod mpm_prefork \
    && a2dissite 000-default \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/atrocore-template \
    && curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --retry 5 \
        --retry-delay 2 \
        "https://codeload.github.com/atrocore/skeleton-pim-no-demo/tar.gz/refs/heads/master" \
        | tar -xz \
            --strip-components=1 \
            -C /opt/atrocore-template \
    && cd /opt/atrocore-template \
    && php atrocore-installer.phar self-update \
    && php atrocore-installer.phar update \
    && find . -type d -exec chmod 755 {} + \
    && find . -type f -exec chmod 644 {} + \
    && for dir in client data upload; do \
         if [ -d "$dir" ]; then \
           find "$dir" -type d -exec chmod 775 {} +; \
           find "$dir" -type f -exec chmod 664 {} +; \
         fi; \
       done

COPY railway/configure-runtime.php /usr/local/bin/atrocore-configure-runtime.php
COPY railway/startup.sh /usr/local/bin/atrocore-railway-startup

RUN chmod +x /usr/local/bin/atrocore-railway-startup

ENV ATROCORE_APP_DIR=/var/www/atrocore

CMD ["/usr/local/bin/atrocore-railway-startup"]
