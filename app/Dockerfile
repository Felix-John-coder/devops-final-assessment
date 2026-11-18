FROM nginx:1.30.6-alpine3.24-slim

# Copy source code
RUN rm -rf /usr/share/nginx/html/*
COPY index.html /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf 

ARG BUILD_SHA=unknown


# Create a non-root user and grant access to required files
RUN chown -R nginx:nginx /usr/share/nginx/html \
    /var/cache/nginx \
    /var/log/nginx \
    /etc/nginx \
    && touch /var/run/nginx.pid \
    && chown nginx:nginx /var/run/nginx.pid

# Run Nginx as a non-root user in nomand
USER nginx

# Add comment to container label
LABEL org.opencontainers.image.revision="${BUILD_SHA}"

EXPOSE 8080

# Container health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -q --spider http://127.0.0.1:8080/ || exit 1