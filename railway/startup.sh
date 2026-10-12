#!/bin/sh

set -eu

APP_DIR="${ATROCORE_APP_DIR:-/var/www/atrocore}"
TEMPLATE_DIR="/opt/atrocore-template"
PORT="${PORT:-8080}"

echo "=== AtroCore Railway startup ==="
echo "App directory: ${APP_DIR}"
echo "HTTP port: ${PORT}"

# ---------------------------------------------------------
# Kötelező Railway PostgreSQL változók ellenőrzése
# ---------------------------------------------------------

: "${PGHOST:?PGHOST environment variable is required}"
: "${PGPORT:?PGPORT environment variable is required}"
: "${PGDATABASE:?PGDATABASE environment variable is required}"
: "${PGUSER:?PGUSER environment variable is required}"
: "${PGPASSWORD:?PGPASSWORD environment variable is required}"

# ---------------------------------------------------------
# AtroCore persistent volume inicializálása
# ---------------------------------------------------------

mkdir -p "${APP_DIR}"

if [ ! -f "${APP_DIR}/vendor/autoload.php" ]; then
    echo "AtroCore persistent directory is empty."
    echo "Copying application template to persistent volume..."

    cp -a "${TEMPLATE_DIR}/." "${APP_DIR}/"

    echo "AtroCore template copied."
else
    echo "Existing AtroCore installation detected."
    echo "Skipping template copy."
fi
# ---------------------------------------------------------
# Frontend assetek ellenőrzése / javítása
# ---------------------------------------------------------

echo "Checking AtroCore frontend assets..."

if [ ! -f "${APP_DIR}/public/client/app.min.js" ]; then
    echo "Frontend assets are missing."
    echo "Restoring public/client from Docker image..."

    mkdir -p "${APP_DIR}/public/client"

    # Ha van saját frontend customizáció, mentsük meg.
    if [ -d "${APP_DIR}/public/client/custom" ]; then
        rm -rf /tmp/atrocore-client-custom
        cp -a "${APP_DIR}/public/client/custom" /tmp/atrocore-client-custom
    fi

    rm -rf "${APP_DIR}/public/client"
    cp -a "${TEMPLATE_DIR}/public/client" "${APP_DIR}/public/client"

    # Saját custom fájlok visszaállítása.
    if [ -d /tmp/atrocore-client-custom ]; then
        mkdir -p "${APP_DIR}/public/client/custom"
        cp -a /tmp/atrocore-client-custom/. \
            "${APP_DIR}/public/client/custom/"
    fi

    echo "Frontend assets restored."
else
    echo "Frontend assets found."
fi

echo "Frontend check:"
ls -lh "${APP_DIR}/public/client/app.min.js" || true
ls -lh "${APP_DIR}/public/client/atro.min.js" || true
ls -lh "${APP_DIR}/public/client/css/style.css" || true
# ---------------------------------------------------------
# PostgreSQL konfiguráció
# ---------------------------------------------------------

echo "Configuring PostgreSQL connection..."

php /usr/local/bin/atrocore-configure-runtime.php

# ---------------------------------------------------------
# Jogosultságok
# ---------------------------------------------------------

echo "Setting file permissions..."

chown -R www-data:www-data "${APP_DIR}"

if [ -d "${APP_DIR}/client" ]; then
    chmod -R ug+rwX "${APP_DIR}/client"
fi

if [ -d "${APP_DIR}/data" ]; then
    chmod -R ug+rwX "${APP_DIR}/data"
fi

if [ -d "${APP_DIR}/upload" ]; then
    chmod -R ug+rwX "${APP_DIR}/upload"
fi
# ---------------------------------------------------------
# Magyar fordítások
# ---------------------------------------------------------

echo "Installing Hungarian translations..."

HU_SOURCE="/opt/atrocore-translations/hu_HU"
HU_TARGET="${APP_DIR}/app/Atro/Resources/i18n/hu_HU"

if [ -d "${HU_SOURCE}" ]; then
    mkdir -p "${HU_TARGET}"

    cp -a "${HU_SOURCE}/." "${HU_TARGET}/"

    chown -R www-data:www-data "${HU_TARGET}"

    echo "Hungarian translation files copied."

    echo "Refreshing AtroCore translations..."

    REFRESH_OK=0
    ATTEMPT=1

    while [ "${ATTEMPT}" -le 30 ]; do
        if su -s /bin/sh www-data -c \
            "cd '${APP_DIR}' && php console.php refresh translations"; then

            REFRESH_OK=1
            echo "Hungarian translations refreshed successfully."
            break
        fi

        echo "Translation refresh failed. Retry ${ATTEMPT}/30 in 2 seconds..."

        ATTEMPT=$((ATTEMPT + 1))
        sleep 2
    done

    if [ "${REFRESH_OK}" -eq 0 ]; then
        echo "WARNING: Translation refresh could not be completed."
    fi
else
    echo "WARNING: Hungarian translation source directory not found."
fi
# ---------------------------------------------------------
# Apache MPM fix
# ---------------------------------------------------------

echo "Forcing Apache MPM to prefork..."

rm -f /etc/apache2/mods-enabled/mpm_event.load
rm -f /etc/apache2/mods-enabled/mpm_event.conf
rm -f /etc/apache2/mods-enabled/mpm_worker.load
rm -f /etc/apache2/mods-enabled/mpm_worker.conf

ln -sf ../mods-available/mpm_prefork.load \
    /etc/apache2/mods-enabled/mpm_prefork.load

ln -sf ../mods-available/mpm_prefork.conf \
    /etc/apache2/mods-enabled/mpm_prefork.conf

echo "Enabled MPM modules:"
ls -la /etc/apache2/mods-enabled/mpm_* || true

# ---------------------------------------------------------
# Apache - Railway PORT
# ---------------------------------------------------------

echo "Configuring Apache..."

cat > /etc/apache2/ports.conf <<EOF
Listen ${PORT}
EOF

cat > /etc/apache2/sites-available/atrocore.conf <<EOF
<VirtualHost *:${PORT}>

    ServerName ${RAILWAY_PUBLIC_DOMAIN:-localhost}

    DocumentRoot ${APP_DIR}/public

    <Directory ${APP_DIR}/public>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Railway HTTPS proxy mögött fut.
    SetEnvIf X-Forwarded-Proto https HTTPS=on

    ErrorLog /proc/self/fd/2
    CustomLog /proc/self/fd/1 combined

</VirtualHost>
EOF

a2ensite atrocore >/dev/null

# ---------------------------------------------------------
# AtroCore cron
# ---------------------------------------------------------

echo "Configuring AtroCore cron..."

cat > /etc/cron.d/atrocore <<EOF
* * * * * www-data /usr/local/bin/php ${APP_DIR}/console.php cron >/dev/null 2>&1
EOF

chmod 0644 /etc/cron.d/atrocore

cron

# ---------------------------------------------------------
# Apache indítása
# ---------------------------------------------------------

echo "Starting Apache..."
echo "=== AtroCore startup complete ==="

exec apache2-foreground
