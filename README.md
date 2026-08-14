# وكيد — إدخال دفعي لسندات الحوالات

تطبيق ويب للصق بيانات سندات الحوالات من Excel وإرسالها إلى [Wakeed API](https://docs.wakeed.app/) عبر `POST /api/JournalVoucher`.

## المميزات

- تسجيل الدخول إلى وكيد (Bearer token)
- اختيار الاشتراك (`owner-key`)
- لصق صفوف من Excel دفعة واحدة
- ربط الأعمدة تلقائياً/يدوياً
- إعدادات افتراضية لنوع السند، الحساب، العملة، ومركز التكلفة
- إرسال كل صف كسند حوالة إلى وكيد

## التشغيل

```bash
npm install
npm install --prefix server
npm install --prefix web
npm run dev
```

- الواجهة: `http://localhost:5173`
- الـ API الوسيط: `http://localhost:8787`

## أعمدة اللصق المقترحة

| العمود | المعنى |
|---|---|
| التاريخ | تاريخ السند |
| رقم الحوالة | رقم مرجعي / OffLineNumber |
| الحساب الرئيسي | UUID حساب الصندوق/البنك |
| حساب الطرف | UUID الحساب المقابل |
| المبلغ | قيمة الحوالة |
| العملة | UUID العملة |
| سعر الصرف | نسبة التحويل |
| البيان | ملاحظات السند |

يمكن وضع الحساب/العملة/مركز التكلفة كقيم افتراضية من الواجهة بدل تكرارها في كل صف.

## ملاحظات API

حسب [وثائق وكيد](https://docs.wakeed.app/):

- المصادقة: `authentication: Bearer {token}`
- المستأجر: `owner-key`
- إصدار العميل: `build-number`
- إنشاء السند: `POST https://server1.wakeed.app/api/JournalVoucher`
- فهرس الحوالات: `GET /api/JournalEntry/RemittanceIndex`
