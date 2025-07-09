FROM alpine:3.18
RUN apk add --no-cache nginx openssl
COPY conf /etc/nginx
COPY tools /scripts
CMD ["nginx", "-g", "daemon off;"]
