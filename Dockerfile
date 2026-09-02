FROM php:8.4-apache-bookworm

LABEL maintainer="AtroCore Railway PoC"

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && printf "memory_limit = 512M\nmax_execution_time = 180\nmax_input_time = 180\npost_max_size = 64M\nupload_max_filesize = 64M\n" >> "$PHP_INI_DIR/php.ini" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        git cron postgresql-client zip unzip build-essential locales \
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
    && a2dissite 000-default \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 \
    https://github.com/atrocore/skeleton-pim-no-demo.git \
    /opt/atrocore-template \
    && cd /opt/atrocore-template \
    && php atrocore-installer.phar self-update \
    && php atrocore-installer.phar update \
    && find . -type d -exec chmod 755 {} + \
    && find . -type f -exec chmod 644 {} + \
    && find client data upload -type d -exec chmod 775 {} + \
    && find client data upload -type f -exec chmod 664 {} +

COPY railway/configure-runtime.php /usr/local/bin/atrocore-configure-runtime.php
COPY railway/startup.sh /usr/local/bin/atrocore-railway-startup

RUN chmod +x /usr/local/bin/atrocore-railway-startup

ENV ATROCORE_APP_DIR=/var/www/atrocore

CMD ["/usr/local/bin/atrocore-railway-startup"]
