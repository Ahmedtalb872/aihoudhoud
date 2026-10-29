# نشر تطبيق «الهدهد كابتن» على App Store

هذا الدليل موجَّه للمطوّر الذي سيبني ويرفع النسخة إلى App Store Connect.

## المتطلبات

- macOS مع **Xcode 15** فأحدث.
- **Flutter SDK 3.24+** (`flutter --version`).
- **CocoaPods** (`sudo gem install cocoapods`).
- حساب **Apple Developer Program** مدفوع (99$/سنة) — بدونه لا يمكن الرفع.
- **App Store Connect** فيه سجل تطبيق منشأ مع Bundle ID: `com.alhudhud.alhudhud`.

## قبل البناء — ملفات لا يشملها المستودع

### 1. `env.json` (Supabase)
انسخ `env.json.example` إلى `env.json` في جذر المشروع، واملأ:
```json
{
  "SUPABASE_URL": "https://xxxxx.supabase.co",
  "SUPABASE_ANON_KEY": "eyJhbGciOi..."
}
```
اطلب هاتين القيمتين من صاحب المشروع (نفس القيمتين المستخدمتين في نسخة Android).

### 2. `ios/Runner/GoogleService-Info.plist` (Firebase)
مفقود من المستودع. لإنشائه:
1. افتح [Firebase Console](https://console.firebase.google.com) → مشروع الهدهد
2. Project Settings → «Your apps» → أضف iOS app بـ Bundle ID `com.alhudhud.alhudhud`
3. نزّل `GoogleService-Info.plist` وضعه في `ios/Runner/`
4. **افتحه في Xcode** واسحبه إلى مجموعة `Runner` (اختر "Copy items if needed") لتضمينه في البناء

بدونه سيفشل بناء iOS لأن `firebase_messaging` يبحث عنه وقت الإقلاع.

### 3. مفتاح Google Maps خاص بـ iOS
موجود مسبقًا في `ios/Runner/AppDelegate.swift`. تأكد في [Google Cloud Console](https://console.cloud.google.com/apis/credentials) أن هذا المفتاح:
- **Application restrictions** → iOS apps → Bundle ID = `com.alhudhud.alhudhud`
- **API restrictions** → مسموح باستخدام **Maps SDK for iOS**

## البناء

```bash
cd /path/to/aihoudhoud
flutter pub get
cd ios && pod install && cd ..

# تشغيل تجريبي على محاكي
flutter run --dart-define-from-file=env.json

# بناء نسخة الإصدار (Archive)
flutter build ipa --release --dart-define-from-file=env.json
```

الملف الناتج: `build/ios/archive/Runner.xcarchive` وهو ما يُرفع من Xcode.

## الرفع إلى App Store Connect

1. افتح Xcode → **Window → Organizer → Archives**
2. اختر آخر أرشيف → **Distribute App → App Store Connect → Upload**
3. Xcode يوقّع تلقائيًا إن كان الحساب مضبوطًا في Signing & Capabilities
4. بعد الرفع، انتظر ~15 دقيقة حتى يظهر البناء في App Store Connect → التطبيق → TestFlight

## ملفات إجبارية داخل مشروع Xcode

### ✅ `PrivacyInfo.xcprivacy` (موجود، يحتاج إضافة للـ target)
Apple تطلبه منذ مايو 2024. الملف موجود في `ios/Runner/PrivacyInfo.xcprivacy` لكن يحتاج تضمينه في target عبر Xcode:
1. افتح `ios/Runner.xcworkspace` في Xcode
2. من الشريط الجانبي، اسحب `PrivacyInfo.xcprivacy` إلى مجموعة `Runner`
3. تأكد أن **Target Membership** فيه `Runner` مؤشَّرًا في اللوحة اليمنى

بدون هذه الخطوة، الملف موجود على القرص لكن لن يُضمَّن في IPA وسيعترض Apple.

## في App Store Connect (قبل الإرسال للمراجعة)

### حقول التطبيق الأساسية
- **الاسم**: `الهدهد - كابتن`
- **الفئة الأساسية**: Travel
- **الفئة الفرعية**: Navigation
- **رابط سياسة الخصوصية**: `https://ahmedtalb872.github.io/aihoudhoud/privacy.html`
- **رابط الدعم**: `https://wa.me/22220522064` (أو صفحة دعم مخصصة)

### App Privacy (نموذج الخصوصية)
أعلن أن التطبيق يجمع:
- **Contact Info → Phone Number, Name** — App Functionality
- **Location → Precise Location** — App Functionality
- **User Content → Photos or Videos** (مستندات الهوية) — App Functionality
- **Financial Info → Other Financial Info** (رقم الدفع) — App Functionality

لكل نوع: مرتبط بالمستخدم، غير مُستخدم للتتبع.

### App Review Information
Apple ستختبر التطبيق فعليًا. **يجب** تزويدها بحساب تجريبي:
- **Sign-in required**: Yes
- **Username**: رقم هاتف اختباري مسجَّل مسبقًا (مثال: `+22200000000`)
- **Password**: كلمة المرور
- **Notes**: اشرح باختصار أن التطبيق للسائقين في موريتانيا، وأن الحساب التجريبي معتمَد مسبقًا حتى يتخطى المُراجِع خطوة رفع المستندات وانتظار الموافقة الإدارية.

بدون حساب تجريبي معتمَد، سيرفض Apple التطبيق تلقائيًا في أول مراجعة.

### لقطات الشاشة
مطلوبة **بمقاسَين على الأقل**:
- **iPhone 6.9" (6.7")** — 1290×2796 بكسل (iPhone 15/16 Pro Max)
- **iPhone 6.5"** — 1284×2778 بكسل (اختياري إن قدّمت 6.7")

التقطها من محاكي iPhone 15 Pro Max في Xcode (`Cmd+S`) أو من هاتف حقيقي.

### حذف الحساب
Apple تتحقق أن التطبيق يوفّر آلية داخلية لحذف الحساب — موجودة في **الإعدادات → حذف الحساب نهائياً** وتستدعي `delete_my_account` RPC. لا حاجة لخطوة إضافية هنا، فقط أشر إليها للمُراجِع في Notes.

## مدة المراجعة

عادة 24-48 ساعة لأول مراجعة. الرفض شائع في المحاولة الأولى — الأسباب المتوقعة:
1. حساب المراجعة لا يعمل → أعِد إرسال بيانات دخول صحيحة.
2. لقطات الشاشة لا تعكس التطبيق فعليًا → استخدم لقطات حقيقية.
3. أذونات الموقع تُطلب دون سبب واضح → نصوص `NSLocationWhenInUseUsageDescription` واضحة عندنا، فلا يُتوقع مشكلة هنا.

## بعد القبول

- التطبيق يصبح متاحًا خلال ساعات.
- حدّد **الدول**: موريتانيا فقط (على الأقل في البداية).
- استخدم **TestFlight** لتوزيع تحديثات على مختبرين قبل النشر للعامة.
