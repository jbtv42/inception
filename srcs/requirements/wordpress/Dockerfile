FROM alpine:3.21

RUN apk add --no-cache \
    php83 \
    php83-fpm \
    php83-dom \
    php83-gd \
    php83-mbstring \
    php83-mysqli \
    php83-openssl \
    php83-phar \
    php83-zip \
    php83-xml \
    php83-curl \
    curl \
    mariadb-client

RUN addgroup -S jvittoz \
 && adduser -S -D -H -h /wp -s /sbin/nologin -G jvittoz jvittoz

RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
 && chmod +x /usr/local/bin/wp

COPY www.conf /etc/php83/php-fpm.d/www.conf

COPY tools/docker-entrypoint.sh /usr/local/bin/

EXPOSE 9000
ENTRYPOINT ["sh", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm83", "-F"]
