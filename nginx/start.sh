#!/bin/sh
set -e

# This script generates /etc/nginx/conf.d/default.conf from ACTIVE_POOL env var and starts nginx.
ACTIVE_POOL=${ACTIVE_POOL:-blue}

echo "Generating nginx config for ACTIVE_POOL=${ACTIVE_POOL}"

cat > /etc/nginx/conf.d/default.conf <<'NGCONF'
user  nginx;
worker_processes  auto;
pid /var/run/nginx.pid;

events { worker_connections 1024; }

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    sendfile        on;
    keepalive_timeout  65;

    proxy_pass_header Server;

    # Proxy settings tuned for quick detection & transparent retry to backup
    proxy_connect_timeout 1s;
    proxy_send_timeout 3s;
    proxy_read_timeout 5s;
    proxy_next_upstream error timeout http_502 http_503 http_504 http_500;
    proxy_next_upstream_tries 2;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
NGCONF

if [ "$ACTIVE_POOL" = "green" ]; then
  cat >> /etc/nginx/conf.d/default.conf <<'UPSTREAM'
    upstream backend_pool {
        server app_green:3000 max_fails=1 fail_timeout=2s;
        server app_blue:3000 backup;
    }
UPSTREAM
else
  cat >> /etc/nginx/conf.d/default.conf <<'UPSTREAM'
    upstream backend_pool {
        server app_blue:3000 max_fails=1 fail_timeout=2s;
        server app_green:3000 backup;
    }
UPSTREAM
fi

cat >> /etc/nginx/conf.d/default.conf <<'SERVER'
    server {
        listen 80;
        server_name localhost;

        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;

        location / {
            proxy_pass http://backend_pool;
            proxy_read_timeout 5s;
        }

        location /version {
            proxy_pass http://backend_pool/version;
        }

        location /healthz {
            proxy_pass http://backend_pool/healthz;
        }
    }
}
SERVER

echo "Starting nginx..."
exec nginx -g 'daemon off;'
