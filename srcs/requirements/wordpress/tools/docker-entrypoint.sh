#!/bin/sh
set -eu

DOCROOT=/wp
PHP_RUN=/run/php
DB_HOST="${WORDPRESS_DB_HOST:-mariadb}"

echo "[wp] EntryPoint starting..."
echo "[wp] DOCROOT=$DOCROOT"
echo "[wp] DB_HOST=$DB_HOST"

mkdir -p "$DOCROOT" "$PHP_RUN"
chown -R jvittoz:jvittoz "$DOCROOT" "$PHP_RUN"

# ---------------------------------------------------------------------------
# 1. CHECK REQUIRED ENV VARS
# ---------------------------------------------------------------------------
missing=0
for var in WORDPRESS_DB_NAME WORDPRESS_DB_USER WORDPRESS_DB_PASSWORD; do
    val="$(eval "printf '%s' \"\${$var:-}\"")"
    [ -z "$val" ] && echo "[wp] ERROR: $var is not set" && missing=$((missing+1))
done

[ "$missing" -gt 0 ] && echo "[wp] Fatal: missing DB vars" && exit 1

# ---------------------------------------------------------------------------
# 2. WAIT FOR MARIADB
# ---------------------------------------------------------------------------
echo "[wp] Waiting for MariaDB at ${DB_HOST}..."
i=0
while ! mysql --connect-timeout=2 \
              -h "$DB_HOST" \
              -u "$WORDPRESS_DB_USER" \
              -p"$WORDPRESS_DB_PASSWORD" \
              -e "SELECT 1" >/dev/null 2>&1; do

    i=$((i+1))
    echo "[wp]  -> attempt $i failed"
    [ "$i" -ge 30 ] && echo "[wp] Warning: DB not ready, continuing..." && break
    sleep 1
done

# ---------------------------------------------------------------------------
# 3. DOWNLOAD WP IF NEEDED
# ---------------------------------------------------------------------------
if [ ! -f "$DOCROOT/wp-includes/version.php" ]; then
    echo "[wp] Downloading WordPress core into $DOCROOT..."
    su -s /bin/sh -c "wp core download --path='$DOCROOT' --allow-root --skip-content" jvittoz
fi

# ---------------------------------------------------------------------------
# 4. CREATE wp-config.php IF NEEDED
# ---------------------------------------------------------------------------
if [ ! -f "$DOCROOT/wp-config.php" ]; then
    echo "[wp] Creating wp-config.php..."
    su -s /bin/sh -c "
        cd '$DOCROOT' && \
        wp config create \
          --dbname='${WORDPRESS_DB_NAME}' \
          --dbuser='${WORDPRESS_DB_USER}' \
          --dbpass='${WORDPRESS_DB_PASSWORD}' \
          --dbhost='${DB_HOST}' \
          --skip-check \
          --allow-root
    " jvittoz
fi

if ! su -s /bin/sh -c "cd '$DOCROOT' && wp core is-installed --allow-root" jvittoz; then
    echo "[wp] Running initial WordPress install..."
    SITE_URL="https://${DOMAIN_NAME:-localhost}"

    su -s /bin/sh -c "
        cd '$DOCROOT' && \
        wp core install \
          --url='${SITE_URL}' \
          --title='${WORDPRESS_SITE_TITLE:-WordPress}' \
          --admin_user='${WORDPRESS_ADMIN_USER:-admin}' \
          --admin_password='${WORDPRESS_ADMIN_PASSWORD:-changeme}' \
          --admin_email='${WORDPRESS_ADMIN_EMAIL:-admin@example.com}' \
          --skip-email \
          --allow-root
    " jvittoz

    echo "[wp] Setting permalink structure..."
    su -s /bin/sh -c "
      cd '$DOCROOT' && \
      wp rewrite structure '/%postname%/' --allow-root && \
      wp rewrite flush --hard --allow-root
    " jvittoz
fi

if [ -n "${WORDPRESS_USER:-}" ] && [ -n "${WORDPRESS_PASSWORD:-}" ] && [ -n "${WORDPRESS_EMAIL:-}" ]; then
    echo "[wp] Managing user ${WORDPRESS_USER}..."

    cd "$DOCROOT" || exit 1

    if wp user get "$WORDPRESS_USER" --field=ID --allow-root >/dev/null 2>&1; then
        echo "[wp] User $WORDPRESS_USER exists, updating..."
        wp user update "$WORDPRESS_USER" \
            --user_pass="$WORDPRESS_PASSWORD" \
            --user_email="$WORDPRESS_EMAIL" \
            --role=author \
            --allow-root
    else
        echo "[wp] Creating additional user $WORDPRESS_USER..."
        wp user create "$WORDPRESS_USER" "$WORDPRESS_EMAIL" \
            --role=author \
            --user_pass="$WORDPRESS_PASSWORD" \
            --allow-root
    fi
fi


# ---------------------------------------------------------------------------
# 7. START PHP-FPM
# ---------------------------------------------------------------------------
echo "[wp] Starting PHP-FPM..."
exec "$@"
