# Wakeed Platform

تطبيق وكيد (سند حوالة) مع تراخيص، VPS، لوحة أدمن، وAPK أندرويد.

المشروع المرجعي `wakeed-api-app` **لم يُعدَّل** — هذا مشروع منفصل.

## التشغيل المحلي

```bash
cd wakeed-platform
npm install
cp server/.env.example server/.env   # عدّل الأسرار
npm start
```

| المسار | الوصف |
|--------|--------|
| http://localhost:3780/ | التطبيق |
| http://localhost:3780/admin/ | لوحة الأدمن |
| http://localhost:3780/download/ | صفحة التحميل |
| http://localhost:3780/api/health | فحص API |

## الهيكل

- `server/` — API + proxy وكيد + تخزين JSON
- `client/` — واجهة المستخدم + platform.js + api-client.js
- `admin/` — لوحة إدارة التراخيص
- `download/` — صفحة تنزيل APK
- `mobile/` — Capacitor Android
- `deploy/` — nginx + systemd + دليل النشر

## الترخيص

1. ادخل `/admin/` وأنشئ ترخيصاً (`WKD-XXXX-XXXX-XXXX`)
2. في التطبيق فعّل المفتاح (جهاز واحد لكل ترخيص)
3. سجّل الدخول بحساب وكيد

## النشر

راجع [`deploy/README-deploy.md`](deploy/README-deploy.md).

## APK

راجع [`mobile/README.md`](mobile/README.md).
