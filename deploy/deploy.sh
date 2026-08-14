#!/usr/bin/env bash
# Deploy Wakeed remittance import to VPS (wakeed.lork.cloud)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="/var/www/wakeed.lork.cloud"
DOMAIN="wakeed.lork.cloud"

echo "==> Building frontend"
cd "$ROOT_DIR/web"
npm ci
npm run build

echo "==> Ensuring server deps"
cd "$ROOT_DIR/server"
npm ci --omit=dev

echo "==> Syncing to ${APP_DIR}"
mkdir -p "$APP_DIR"
rsync -a --delete \
  --exclude node_modules \
  --exclude .git \
  --exclude web/node_modules \
  --exclude server/node_modules \
  "$ROOT_DIR/" "$APP_DIR/"

mkdir -p "$APP_DIR/web/dist"
rsync -a "$ROOT_DIR/web/dist/" "$APP_DIR/web/dist/"

cd "$APP_DIR/server"
npm ci --omit=dev

echo "==> Configuring nginx"
cp "$APP_DIR/deploy/nginx-wakeed.lork.cloud.conf" "/etc/nginx/sites-available/${DOMAIN}"
ln -sfn "/etc/nginx/sites-available/${DOMAIN}" "/etc/nginx/sites-enabled/${DOMAIN}"

# If certs do not exist yet, use temporary self-signed so nginx can start,
# then replace with Let's Encrypt.
if [ ! -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
  echo "==> Obtaining Let's Encrypt certificate"
  # Temporarily serve ACME over HTTP-only config
  cat > "/etc/nginx/sites-available/${DOMAIN}" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    location /.well-known/acme-challenge/ { root /var/www/html; }
    location / { return 200 'ok'; add_header Content-Type text/plain; }
}
EOF
  nginx -t
  systemctl reload nginx
  certbot certonly --webroot -w /var/www/html -d "${DOMAIN}" -d "www.${DOMAIN}" \
    --non-interactive --agree-tos --register-unsafely-without-email || \
  certbot certonly --webroot -w /var/www/html -d "${DOMAIN}" \
    --non-interactive --agree-tos --register-unsafely-without-email
  cp "$APP_DIR/deploy/nginx-wakeed.lork.cloud.conf" "/etc/nginx/sites-available/${DOMAIN}"
fi

nginx -t
systemctl reload nginx

echo "==> Starting PM2 app"
cd "$APP_DIR"
pm2 startOrReload ecosystem.config.cjs --env production
pm2 save

echo "==> Health check"
sleep 1
curl -fsS "http://127.0.0.1:3030/api/health"
echo
curl -fsSI "https://${DOMAIN}" | head -n 15 || true
echo "Deployed: https://${DOMAIN}"
