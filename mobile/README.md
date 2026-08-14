# Wakeed Android (Capacitor)

## المتطلبات

- Node.js 18+
- Android Studio + Android SDK
- JDK 17

## الإعداد

```bash
cd mobile
npm install
```

## ربط السيرفر

عدّل `capacitor.config.ts`:

```ts
server: {
  url: "https://YOUR_DOMAIN",
  cleartext: false,
}
```

للتطوير المحلي مع السيرفر على الشبكة:

```ts
server: {
  url: "http://192.168.x.x:3780",
  cleartext: true,
}
```

## مزامنة وAndroid

```bash
npm run sync
npm run open
```

في Android Studio: **Build → Generate Signed Bundle / APK → APK → release**.

## نسخ APK للنشر

```bash
cp android/app/build/outputs/apk/release/app-release.apk ../releases/wakeed-app.apk
```

## deviceId

التطبيق يستخدم `@capacitor/device` عبر `client/capacitor-bridge.js` لربط جهاز واحد لكل ترخيص.
