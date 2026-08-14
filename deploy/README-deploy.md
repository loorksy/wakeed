# نشر Wakeed Platform على VPS

## المتطلبات

- Ubuntu 22.04+ (أو أي Linux)
- Node.js 18+
- nginx
- دومين يشير إلى IP السيرفر

## 1) رفع المشروع

```bash
sudo mkdir -p /opt/wakeed-platform
sudo chown $USER:$USER /opt/wakeed-platform
# انسخ الملفات (git clone أو scp)
cd /opt/wakeed-platform
npm install --production
```

## 2) إعداد `.env`

```bash
cp server/.env.example server/.env
nano server/.env
```

**غيّر قبل النشر:**

- `APP_URL=https://YOUR_DOMAIN`
- `SESSION_SECRET` — 64 hex عشوائي
- `CREDENTIALS_SECRET` — 64 hex عشوائي آخر
- `ADMIN_PASSWORD` — كلمة مرور قوية (لا تُرفع إلى git)

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

## 3) systemd

```bash
sudo cp deploy/systemd.service.example /etc/systemd/system/wakeed-platform.service
sudo systemctl daemon-reload
sudo systemctl enable wakeed-platform
sudo systemctl start wakeed-platform
sudo systemctl status wakeed-platform
```

## 4) nginx + SSL

```bash
sudo apt install nginx certbot python3-certbot-nginx
sudo cp deploy/nginx.conf.example /etc/nginx/sites-available/wakeed-platform
# عدّل YOUR_DOMAIN
sudo ln -s /etc/nginx/sites-available/wakeed-platform /etc/nginx/sites-enabled/
sudo nginx -t
sudo certbot --nginx -d YOUR_DOMAIN
sudo systemctl reload nginx
```

## 5) APK

1. ابنِ APK من مجلد `mobile/` (راجع `mobile/README.md`).
2. انسخ الملف إلى:

```bash
cp mobile/android/app/build/outputs/apk/release/app-release.apk /opt/wakeed-platform/releases/wakeed-app.apk
```

## 6) التحقق

| URL | الغرض |
|-----|--------|
| `https://YOUR_DOMAIN/` | التطبيق |
| `https://YOUR_DOMAIN/admin/` | لوحة الأدمن |
| `https://YOUR_DOMAIN/download/` | صفحة التحميل |
| `https://YOUR_DOMAIN/api/health` | فحص API |

## 7) Capacitor (APK)

في `mobile/capacitor.config.ts` عيّن:

```ts
server: { url: 'https://YOUR_DOMAIN', cleartext: false }
```

ثم `npx cap sync android` وابنِ من Android Studio.

## الأمان

- HTTPS إلزامي
- غيّر كلمة مرور الأدمن بعد أول دخول
- احتفظ بـ `.env` خارج git
- نسخ احتياطي لـ `server/data/` دورياً
