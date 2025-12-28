#!/bin/sh
set -eu

DATADIR='/var/lib/mysql'
SOCKET="$DATADIR/mysql.sock"
INITDIR='/docker-entrypoint-initdb.d'
INITFILE="$INITDIR/_init.sql"

check_env() {
    missing=0
    for var in MARIADB_ROOT_PASSWORD MARIADB_USER MARIADB_PASSWORD MARIADB_DATABASE; do
        eval "val=\${$var:-}"
        if [ -z "$val" ]; then
            echo "You need to specify $var"
            missing=$((missing+1))
        fi
    done

    case "$MARIADB_ROOT_PASSWORD" in
        *\'*|*\\*)
            echo "MARIADB_ROOT_PASSWORD must not contain ' or \\"
            missing=$((missing+1))
        ;;
    esac
    case "$MARIADB_PASSWORD" in
        *\'*|*\\*)
            echo "MARIADB_PASSWORD must not contain ' or \\"
            missing=$((missing+1))
        ;;
    esac

    if [ "$missing" -gt 0 ]; then
        exit 1
    fi
}

prepare_files() {
    if [ "$(id -u)" = "0" ]; then
        cat > /etc/my.cnf <<EOF
[client-server]
socket=$SOCKET
port=3306

[mysqld]
datadir=$DATADIR
socket=$SOCKET
skip-bind-address
skip-networking=false
EOF
        mkdir -p "$DATADIR" "$INITDIR"
        chown -R mysql:mysql "$DATADIR" "$INITDIR"
    fi
}

init_datadir() {
    echo "Initializing MariaDB data directory in $DATADIR..."
    mysql_install_db \
        --user=mysql \
        --datadir="$DATADIR" \
        --rpm \
        --auth-root-authentication-method=normal \
        --skip-test-mariadb \
        --default-time-zone=SYSTEM \
        --skip-log-bin \
        --expire-logs-days=0 \
        --loose-innodb_buffer_pool_load_at_startup=0 \
        --loose-innodb_buffer_pool_dump_at_shutdown=0
}

write_init_sql() {
    echo "Writing init SQL to $INITFILE"

    cat > "$INITFILE" <<EOSQL
-- Init DB and users
SET @orig_sql_log_bin = @@SESSION.SQL_LOG_BIN;
SET @@SESSION.SQL_LOG_BIN = 0;
SET @@SESSION.SQL_MODE = REPLACE(@@SESSION.SQL_MODE, 'NO_BACKSLASH_ESCAPES', '');

-- reset default root users and create root@localhost with password
DROP USER IF EXISTS root@'127.0.0.1', root@'::1', root@'localhost';
CREATE USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION;

-- drop test DB if present
DROP DATABASE IF EXISTS test;

SET @@SESSION.SQL_LOG_BIN = @orig_sql_log_bin;

-- create app database and user
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';
GRANT ALL ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
EOSQL

    chown mysql:mysql "$INITFILE"
}

run_as_mysql() {
    if [ "$(id -u)" = "0" ]; then
        exec su-exec mysql "$@"
    else
        exec "$@"
    fi
}

main() {
    prepare_files

    first_run=0
    if [ ! -d "$DATADIR/mysql" ]; then
        first_run=1
    fi

    if [ "$first_run" -eq 1 ]; then
        check_env
        init_datadir
        write_init_sql
        run_as_mysql "$@" --defaults-file=/etc/my.cnf --init-file="$INITFILE"
        rm -f "$INITFILE"
    else
        run_as_mysql "$@" --defaults-file=/etc/my.cnf
    fi
}

main "$@"

