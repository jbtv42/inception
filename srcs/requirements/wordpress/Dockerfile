FROM alpine:3.18
RUN apk add --no-cache php81 php81-fpm php81-mysqli php81-curl php81-json php81-mbstring php81-session
COPY tools /scripts
CMD ["php-fpm81", "-F"]
