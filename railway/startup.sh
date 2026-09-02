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
