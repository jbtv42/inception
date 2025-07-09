FROM alpine:3.18
RUN apk add --no-cache mariadb mariadb-client
COPY conf /etc/mysql
COPY tools /scripts
CMD ["mysqld"]
