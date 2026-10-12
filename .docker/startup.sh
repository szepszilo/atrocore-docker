#!/bin/sh

set -e

echo "Hungarian translations: installing..."

for APP_DIR in /var/www/*; do
    if [ -f "$APP_DIR/console.php" ]; then
        echo "AtroCore found: $APP_DIR"

        mkdir -p "$APP_DIR/app/Atro/Resources/i18n/hu_HU"

        cp -a /opt/atrocore-translations/hu_HU/. \
            "$APP_DIR/app/Atro/Resources/i18n/hu_HU/"

        chown -R www-data:www-data \
            "$APP_DIR/app/Atro/Resources/i18n/hu_HU"

        echo "Refreshing translations..."

        REFRESH_OK=0

        for i in $(seq 1 30); do
            if (
                cd "$APP_DIR"
                php console.php refresh translations
            ); then
                REFRESH_OK=1
                echo "Hungarian translations refreshed successfully."
                break
            fi

            echo "AtroCore/database not ready yet. Retry $i/30..."
            sleep 2
        done

        if [ "$REFRESH_OK" -eq 0 ]; then
            echo "WARNING: Translation refresh failed."
            echo "The application will still be started."
        fi
    fi
done

cron

apache2-foreground
