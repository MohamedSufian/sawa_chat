# Sawa Chat — خطة المشروع

تطبيق محادثة فوري (Flutter) للـ Android وiOS، يدعم العربية والإنجليزية، مبني بتكلفة 0$.

## التقنيات

| الجزء | الأداة |
|---|---|
| الواجهة | Flutter + Material 3 |
| إدارة الحالة | Riverpod 3 |
| التنقل | go_router |
| الدخول | Supabase Auth (رقم الجوال + OTP) |
| قاعدة البيانات | Supabase Postgres + Row Level Security |
| الوقت الحقيقي | Supabase Realtime (Postgres Changes + Presence + Broadcast) |
| الملفات | Supabase Storage (`avatars` عام، `chat-media` خاص) |
| كود السيرفر | Supabase Edge Functions (Deno) |
| الإشعارات | Firebase Cloud Messaging (خطة Spark المجانية) |
| المكالمات | WebRTC (`flutter_webrtc`) + Signaling عبر Realtime Broadcast + CallKit/ConnectionService |
| الكاش المحلي | ملفات JSON على الجهاز (stale-while-revalidate) |
| اللغات | `flutter_localizations` + ARB (ar / en) |

## الهيكلة (Feature-first)

```
lib/
  main.dart                 تهيئة Supabase وSharedPreferences
  app.dart                  MaterialApp.router + اللغة + الثيم
  core/
    config/                 متغيرات البيئة (dart-define)
    theme/                  الثيم الفاتح/الداكن + controller
    localization/           controller اللغة
    router/                 go_router + التحويل حسب حالة الجلسة
    providers/              providers مشتركة (supabase, prefs)
    widgets/                عناصر واجهة مشتركة
    utils/
  features/
    auth/        data / presentation      رقم الجوال، OTP، حالة الجلسة
    profile/     data / domain / presentation   إكمال البيانات، تعديل البروفايل
    home/        presentation             التبويبات الرئيسية
    chats/       data / domain / presentation   قائمة المحادثات، شاشة المحادثة
    groups/      ...                      إنشاء وإدارة المجموعات
    calls/       ...                      WebRTC، شاشة المكالمة، السجل
    search/      ...                      البحث عن المستخدمين
    settings/    presentation             اللغة، الثيم، الحساب
  l10n/                     app_ar.arb / app_en.arb
supabase/
  migrations/               مخطط قاعدة البيانات + RLS + Storage
  functions/                Edge Functions (push, ...)
```

## قاعدة البيانات

ملف `supabase/migrations/0001_init.sql` كامل. الجداول:

- **profiles**: بيانات المستخدم (الرقم، الاسم، username، النبذة، الصورة، last_seen_at).
- **chats**: محادثة فردية (`direct`) أو مجموعة (`group`). المحادثة الفردية لها `direct_key` فريد يمنع التكرار. تحتفظ بآخر رسالة لقائمة المحادثات.
- **chat_members**: العضوية والدور (owner/admin/member) و**علامات القراءة والتسليم** `last_read_at` / `last_delivered_at`.
- **messages**: نص / صورة / صوت / نظام / مكالمة، مع رد على رسالة، وحذف للجميع، و`client_id` لمنع التكرار عند إعادة الإرسال.
- **hidden_messages**: "حذف عندي".
- **calls**: سجل المكالمات وحالتها.
- **device_tokens**: توكنات FCM لكل جهاز.
- **blocks**: الحظر.

### حالة القراءة والتسليم (Watermarks)
بدل ما نسجّل صف لكل رسالة ولكل عضو، كل عضو عنده طابعين زمنيين: `last_delivered_at` و`last_read_at`.
الرسالة **مقروءة** إذا كان `last_read_at` لكل الأعضاء الآخرين ≥ وقت الرسالة، و**مُسلَّمة** بنفس المنطق.
هذا يعمل للمحادثات الفردية والمجموعات بعدد كتابات ثابت، مهما كان عدد الرسائل.

### الأمان
- كل الجداول عليها RLS.
- العمليات الحساسة (إنشاء محادثة، إنشاء مجموعة، إضافة/إزالة أعضاء، تعليم كمقروء، حذف للجميع) تتم عبر دوال `security definer` تتحقق من الصلاحيات.
- ملفات المحادثات في bucket خاص؛ المسار يبدأ بـ `chat_id`، ولا يقرأها إلا أعضاء المحادثة.

### Online / Last seen / يكتب الآن
- **Online**: Realtime Presence على قناة عامة `online` (لا كتابة في القاعدة).
- **Last seen**: يُحدَّث `profiles.last_seen_at` عند خروج التطبيق للخلفية وبنبضة دورية.
- **يكتب الآن**: Realtime Broadcast على قناة المحادثة.

## تدفق الشاشات

```
Splash → (غير مسجّل) → رقم الجوال → رمز OTP → (مستخدم جديد) → إكمال البيانات (خطوتين) → الرئيسية
                                              → (مستخدم قديم) → الرئيسية
الرئيسية: [المحادثات] [المكالمات] [الإعدادات]
  المحادثات → شاشة المحادثة → معلومات المحادثة/المجموعة
            → بحث عن مستخدم → بدء محادثة
            → مجموعة جديدة (اختيار أعضاء → الاسم والصورة)
  المكالمات → السجل → اتصال صوت/فيديو
  الإعدادات → تعديل البروفايل، اللغة، الثيم، المحظورين، تسجيل الخروج
مكالمة واردة (فوق أي شاشة، أو شاشة النظام والتطبيق مسكّر)
```

## المراحل

| # | المرحلة | الحالة |
|---|---|---|
| 1 | الأساس: الهيكلة، الثيم، اللغتين، الدخول بالرقم + OTP، إكمال البيانات، الرئيسية والإعدادات | ✅ |
| 2 | المحادثات الفردية: قائمة المحادثات، البحث، إرسال نص، Realtime، Pagination، حالة الإرسال | ✅ |
| 3 | القراءة والتسليم، Online/Last seen، يكتب الآن، عدّاد غير المقروء | ✅ |
| 4 | الصور: ضغط، رفع مع تقدم، عرض بملء الشاشة | ✅ |
| 5 | الرسائل الصوتية: تسجيل بالضغط، موجة، تشغيل بسرعات | ✅ |
| 6 | المجموعات: إنشاء، أدمن، إضافة/إزالة، مغادرة | ✅ |
| 7 | الإشعارات: FCM + Edge Function + فتح المحادثة من الإشعار | ✅ |
| 8 | المكالمات: WebRTC صوت/فيديو، شاشة واردة، CallKit، السجل | ✅ |
| 9 | الكاش المحلي والعمل بدون نت (JSON على الجهاز) | ✅ |
| 10 | التلميع: الحظر، الاختبارات، GitHub Actions، README | ✅ |

## ملاحظات التكلفة (0$)
- Supabase Free: بدون بطاقة. يتوقف المشروع بعد أسبوع بلا نشاط ويُستعاد بزر (سنضيف ping عبر GitHub Actions).
- SMS: أرقام تجريبية برمز ثابت من لوحة Supabase للتطوير، وTwilio trial للإرسال لجوالك الموثّق.
- FCM: مجاني على Spark.
- TURN: خدمة مجانية بحدود (مثل Open Relay).
- iOS: الكود جاهز، والبناء يحتاج Mac؛ الإشعارات والمكالمات الواردة على iOS تحتاج حساب Apple Developer.
