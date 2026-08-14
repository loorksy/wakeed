# تطبيق وكيد — سند حوالة (Flutter)

تطبيق أندرويد لتسجيل سندات الحوالة في وكيد، مع تفعيل ترخيص ونبض حيّ عبر منصة الإنتاج.

**لا يعمل بدون سيرفر.** عند انقطاع الشبكة أو إيقاف الترخيص يُحظر التطبيق فوراً.

## المتطلبات

- Flutter 3.32+ (Dart 3.8+)
- Android SDK (API 24+)
- JDK 17+

المنصة: `https://wakeed.lork.cloud`

## التشغيل

```bash
cd flutter
flutter pub get
flutter test
flutter run
```

## الشاشات

1. **تفعيل الترخيص** — مفتاح `WKD-XXXX-XXXX-XXXX` (جهاز واحد لكل ترخيص)
2. **حظر** — عند قطع الشبكة أو إيقاف الترخيص (heartbeat كل 45 ثانية)
3. **دخول وكيد** — البريد وكلمة المرور
4. **التطبيق الرئيسي**
   - تبويب **جماعي**: سند واحد لكل العملاء
   - تبويب **لكل عميل**: سند منفصل لكل عميل (`parallel=2`)
   - تبويب **فردي**: سند لكل عميل مع ملاحظة مستقلة
   - تبويب **السجل**: عرض / بحث / تصدير + فحص «موجود في السجل»
5. **اختيار الحساب** — نافذة لدليل الحسابات (مدين / دائن)

## التخزين

محلياً عبر `SharedPreferences` فقط:

- `sessionToken`
- `deviceId`
- `licenseKey`

كل الإعدادات والسجل عبر API المنصة (`/api/user-data`, `/api/ledger`). لا يوجد وضع دون اتصال.

## بناء APK

```bash
cd flutter
flutter build apk --release --target-platform android-arm64
cp build/app/outputs/flutter-apk/app-release.apk ../releases/wakeed-app.apk
```

الملف الناتج: [`releases/wakeed-app.apk`](../releases/wakeed-app.apk)

## الاختبار اليدوي

1. افتح `/admin/` وأنشئ ترخيصاً.
2. فعّل المفتاح في التطبيق.
3. سجّل دخول وكيد.
4. الصق 3 عملاء (قالب: الاسم | المبلغ | الدائن) → معاينة → تسجيل جماعي.
5. جرّب تبويبي **لكل عميل** و**فردي** ثم **السجل** وفحص «موجود في السجل».

## الهيكل

```
flutter/lib/
  core/remittance_parser.dart   # نقل حرفي من parser.js
  services/platform_service.dart # تفعيل + heartbeat + headers
  services/api_service.dart      # login / proxy / user-data / ledger
  state/app_controller.dart      # منطق السندات والحسابات والسجل
  screens/                       # الترخيص، الحظر، الدخول، التبويبات
```

المرجع الوظيفي (للقراءة فقط): مستودع `wakeed2`. التكامل مع المنصة يطابق `client/platform.js` و `client/api-client.js`.
