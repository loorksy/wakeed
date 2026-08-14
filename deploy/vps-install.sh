#!/usr/bin/env bash
# Install/update Wakeed Platform on VPS — run as root on the server.
# Example: curl -fsSL https://raw.githubusercontent.com/loorksy/wakeed/main/deploy/vps-install.sh | bash

set -euo pipefail

APP_DIR="/opt/wakeed-platform"
REPO="https://github.com/loorksy/wakeed.git"
BRANCH="main"
DOMAIN="${WAKEED_DOMAIN:-wakeed.lork.cloud}"
PORT="${WAKEED_PORT:-3780}"

echo "==> Wakeed Platform deploy ($DOMAIN)"

if ! command -v node >/dev/null 2>&1; then
  echo "Installing Node.js 20..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs git
fi

if ! command -v nginx >/dev/null 2>&1; then
  apt-get update
  apt-get install -y nginx certbot python3-certbot-nginx
fi

# Stop/remove old wakeed services only (do not touch other projects)
for svc in wakeed wakeed-api wakeed-remittance wakeed-platform; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    systemctl stop "${svc}" 2>/dev/null || true
    systemctl disable "${svc}" 2>/dev/null || true
  fi
done

# Remove old wakeed app dirs if present (only wakeed-named paths)
for old in /opt/wakeed /opt/wakeed-api /var/www/wakeed /root/wakeed; do
  if [ -d "$old" ] && [ "$old" != "$APP_DIR" ]; then
    echo "Removing old path: $old"
    rm -rf "$old"
  fi
done

if [ -d "$APP_DIR/.git" ]; then
  echo "==> Updating repo"
  git -C "$APP_DIR" fetch origin
  git -C "$APP_DIR" reset --hard "origin/$BRANCH"
else
  echo "==> Cloning repo"
  rm -rf "$APP_DIR"
  git clone --branch "$BRANCH" --depth 1 "$REPO" "$APP_DIR"
fi

cd "$APP_DIR"
npm install --production

if [ ! -f server/.env ]; then
  echo "==> Creating server/.env — EDIT SECRETS AFTER INSTALL"
  SECRET1=$(openssl rand -hex 32)
  SECRET2=$(openssl rand -hex 32)
  cat > server/.env <<ENV
HOST=0.0.0.0
PORT=$PORT
APP_URL=https://$DOMAIN

SESSION_SECRET=$SECRET1
CREDENTIALS_SECRET=$SECRET2

ADMIN_EMAIL=loorksy@gmail.com
ADMIN_PASSWORD=CHANGE_ME_NOW

DB_PATH=./data/wakeed.db
HEARTBEAT_INTERVAL_SEC=45
SESSION_TTL_HOURS=24
ENV
fi

mkdir -p server/data releases

# systemd
cat > /etc/systemd/system/wakeed-platform.service <<UNIT
[Unit]
Description=Wakeed Platform API
After=network.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
Environment=NODE_ENV=production
EnvironmentFile=$APP_DIR/server/.env
ExecStart=/usr/bin/node server/index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable wakeed-platform
systemctl restart wakeed-platform

# nginx — only wakeed.lork.cloud vhost
cat > /etc/nginx/sites-available/wakeed-platform <<NGINX
server {
    listen 80;
    server_name $DOMAIN;

    location /releases/ {
        alias $APP_DIR/releases/;
        add_header Content-Disposition attachment;
    }

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/wakeed-platform /etc/nginx/sites-enabled/wakeed-platform
nginx -t
systemctl reload nginx

if ! certbot certificates 2>/dev/null | grep -q "$DOMAIN"; then
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m loorksy@gmail.com || true
fi

echo "==> Done. Check: https://$DOMAIN/api/health"
echo "==> Admin: https://$DOMAIN/admin/"
echo "==> Set ADMIN_PASSWORD in $APP_DIR/server/.env then: systemctl restart wakeed-platform"
