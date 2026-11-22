# 🚀 دليل إطلاق «غزة الآن» على Google Play

التطبيق جاهز تقنياً للنشر. هذه الخطوات المتبقية تحتاج حساباتك الشخصية، ولا يمكن لأحد غيرك إتمامها.

## 1) الإعلانات: حساب Google AdMob (لتحصل على الأرباح)

التطبيق يعمل الآن بـ **إعلانات تجريبية من Google** (آمنة، لكنها لا تدرّ أرباحاً).

1. أنشئ حساباً على https://admob.google.com
2. **Apps ← Add app ← Android** ثم اكتب اسم «غزة الآن». ستحصل على **App ID** بالشكل `ca-app-pub-XXXX~YYYY`.
3. أنشئ 3 وحدات إعلانية (Ad units):
   | الوحدة | النوع | مكانها في التطبيق |
   |---|---|---|
   | `home_banner` | Banner | بعد الخبر الرابع في الرئيسية |
   | `article_mrec` | Banner (يظهر بحجم مستطيل متوسط) | أسفل نص الخبر |
   | `interstitial` | Interstitial | ملء الشاشة، مرة كل 5 أخبار وبحد أقصى مرة كل 3 دقائق |
4. ضع المعرّفات في GitHub: **Settings ← Secrets and variables ← Actions ← New repository secret**:
   - `ADMOB_APP_ID`
   - `ADMOB_BANNER_ANDROID`
   - `ADMOB_ARTICLE_ANDROID`
   - `ADMOB_INTERSTITIAL_ANDROID`

   (أو عدّلها مباشرة في `lib/config.dart` و `android/app/build.gradle.kts`)

> ⚠️ لا تضغط على إعلاناتك بنفسك أبداً، فهذا يؤدي لإيقاف حساب AdMob.

## 2) الأخبار عبر API (اختياري، يزيد عدد الأخبار والصور)

1. سجّل مجاناً على https://newsdata.io وانسخ **API Key**.
2. أضفه كـ Secret في GitHub باسم `NEWSDATA_API_KEY`.

ستظهر أخبار مئات المواقع العربية مع اسم الناشر الأصلي وصورته. بدون المفتاح يعمل التطبيق بالمصادر السبعة الموثوقة.

## 3) مفتاح التوقيع (مرة واحدة فقط، واحتفظ به للأبد)

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

ثم أضف إلى GitHub Secrets:
- `ANDROID_KEYSTORE_BASE64` ← ناتج `base64 -w0 upload-keystore.jks` (في ويندوز: `certutil -encode`)
- `ANDROID_KEYSTORE_PASSWORD`، `ANDROID_KEY_PASSWORD`، `ANDROID_KEY_ALIAS` (= `upload`)

> احفظ ملف `upload-keystore.jks` وكلمات السر في مكان آمن. إن ضاع لا يمكنك تحديث التطبيق لاحقاً.

للبناء المحلي بدل GitHub: أنشئ `android/key.properties`:
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/path/to/upload-keystore.jks
```

## 4) Google Play Console

1. حساب مطوّر: https://play.google.com/console (رسوم لمرة واحدة 25$).
2. **Create app** ← الاسم «غزة الآن»، اللغة العربية، تطبيق مجاني.
3. ارفع ملف **AAB** من GitHub: **Actions ← آخر بناء ← gaza-now-playstore-aab**.
4. املأ:
   - **سياسة الخصوصية**: `https://github.com/Emansalha/gaza_now/blob/main/PRIVACY.md`
   - **Ads**: نعم، التطبيق يحتوي إعلانات.
   - **Data safety**: لا جمع بيانات شخصية؛ معرّف الإعلانات تستخدمه Google AdMob.
   - **Content rating**: أخبار. **Target audience**: 18+ (أو 13+).
   - **News app declaration**: نعم، تطبيق أخبار، مع ذكر المصادر.
5. الصور المطلوبة: أيقونة 512×512 (`assets/images/app_icon.png` مصغّرة)، صورة غلاف 1024×500، ولقطتا شاشة على الأقل.
6. ابدأ بـ **Internal testing** ثم **Production**.

## 5) قبل الضغط على «نشر»

- [ ] غيّرت إعلانات AdMob التجريبية إلى معرّفاتك الحقيقية
- [ ] مفتاح التوقيع محفوظ في مكانين
- [ ] وسيلة التواصل في `lib/config.dart` (`CONTACT_EMAIL`) و `PRIVACY.md`: ضع بريدك بدل رابط GitHub إن أردت
- [ ] جرّبت التطبيق على جهاز حقيقي: الأخبار، الصور، فتح الخبر، الإعلانات
- [ ] `applicationId` في `android/app/build.gradle.kts` هو ما تريده (لا يمكن تغييره بعد النشر)
- [ ] رفعت رقم الإصدار في `pubspec.yaml` عند كل تحديث (`version: 1.3.0+4` ← `1.3.1+5`)
