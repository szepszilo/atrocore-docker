FROM php:8.4-apache-bookworm AS base
LABEL maintainer="AtroCore GmbH <support@atrocore.com>"

ARG SKELETON_VARIANT
ARG PRODUCTION_DOMAIN
ARG PRODUCTION_STABILITY
ARG PRODUCTION_DB
ARG TESTING_DOMAIN
ARG TESTING_STABILITY
ARG TESTING_DB
ARG DB_USER
ARG DB_PASSWORD

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"  \
    && printf "memory_limit = -1\nmax_execution_time = 0\nmax_input_time = -1\npost_max_size = 0\nupload_max_filesize = 0\n" >> "$PHP_INI_DIR/php.ini" \
    && apt-get update && apt-get install -y \
        git \
        cron \
        postgresql-client \
        zip unzip \
        build-essential \
        locales \
        libcurl4 \
        libcurl4-openssl-dev \
        libsodium-dev \
		libfreetype-dev \
		libjpeg62-turbo-dev \
		libpng-dev \
        libpq-dev \
        libavif-dev \
        libattr1-dev \
        libonig-dev \
        libzip-dev \
        zlib1g-dev \
        libmagickwand-dev \
        libldap2-dev \
        libldap-common \
    && docker-php-ext-configure gd --with-freetype --with-jpeg --with-avif \
    && docker-php-ext-install -j$(nproc) mbstring curl gd xml zip pdo_pgsql exif ftp ldap sockets \
    && pecl install xattr imagick \
    && docker-php-ext-enable xattr imagick \
    && a2enmod rewrite && a2dissite 000-default

WORKDIR /var/www

COPY php/scripts /var/www/scripts

RUN chmod +x scripts/*.sh && mkdir -p /var/spool/cron/crontabs/ \
    && /bin/bash ./scripts/prepare-pim.sh --optional "${SKELETON_VARIANT}" "${TESTING_STABILITY}" "${TESTING_DOMAIN}" "${DB_USER}" "${DB_PASSWORD}" "${TESTING_DB}" \
    && /bin/bash ./scripts/prepare-pim.sh "${SKELETON_VARIANT}" "${PRODUCTION_STABILITY}" "${PRODUCTION_DOMAIN}" "${DB_USER}" "${DB_PASSWORD}" "${PRODUCTION_DB}" \
    && chown www-data:crontab /var/spool/cron/crontabs/www-data \
    && chmod 600 /var/spool/cron/crontabs/www-data \
    && rm -rf scripts && mkdir -p /var/www/.cache && chown www-data:www-data /var/www/.cache
COPY translations/hu_HU /opt/atrocore-translations/hu_HU
COPY startup.sh /startup.sh
RUN chmod +x /startup.sh

CMD ["/startup.sh"]



FROM base AS pdf

RUN apt-get update && apt-get install -y --no-install-recommends \
        chromium \
        chromium-driver \
        libreoffice-core \
        libreoffice-writer \
        fonts-liberation \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/bin/chromium /usr/bin/google-chrome
