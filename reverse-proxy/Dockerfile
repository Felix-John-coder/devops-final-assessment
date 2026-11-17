# proxy/Dockerfile
# NGINX reverse proxy that terminates TLS with a self-signed certificate.
FROM nginx:1.30.6-alpine3.24-slim

RUN apk add --no-cache openssl \
 && mkdir -p /etc/nginx/certs \
 && openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout /etc/nginx/certs/server.key \
      -out /etc/nginx/certs/server.crt \
      -subj "/CN=localhost" \
      -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"


COPY nginx.conf /etc/nginx/conf.d/default.conf
