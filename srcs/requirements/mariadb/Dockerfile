FROM alpine:3.21

RUN addgroup -S mysql && \
    adduser -S -G mysql mysql

RUN apk add --no-cache mariadb mariadb-client su-exec

COPY tools/docker-entrypoint.sh /usr/local/bin/

EXPOSE 3306
ENTRYPOINT ["sh", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["mariadbd"]
