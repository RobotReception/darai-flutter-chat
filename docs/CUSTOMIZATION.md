# تخصيص تجربة الدردشة

## ما تعدله من واجهة الاستخدام

`title` لعنوان الصفحة، و`welcomeTitle` و`welcomeMessage` لحالة البداية. `allowImageAttachments=false` يخفي اختيار الصور. `textDirection` يحدد اتجاه الشاشة؛ الافتراضي RTL.

`theme: DaraiChatTheme.light(primary: ..., fontFamily: ...)` يغير اللون الأساسي والخط. بقية ألوان الحالات والحدود في `darai_chat_theme.dart`. لتغيير شامل عدّل لوحة `AppColors` في نسخة الحزمة، أو استبدل الشاشة بواجهتك واستخدم `DaraiChatClient` فقط. لوحة فاتحة هي الافتراضية؛ لا تفترض أن تمرير ThemeData داكن وحده يغيّر كل الألوان الثابتة.

## خط داري

أضف ملفات TTF/OTF المصرح لك باستخدامها في تطبيق العميل؛ ملفات خط داري غير مضمنة في هذه الحزمة. مثال داخل `pubspec.yaml` الخاص بالتطبيق:

```yaml
flutter:
  uses-material-design: true
  fonts:
    - family: DaraiFont
      fonts:
        - asset: assets/fonts/darai-regular.ttf
          weight: 400
        - asset: assets/fonts/darai-bold.ttf
          weight: 700
```

ثم مرّر `fontFamily: 'DaraiFont'`. أسماء الملفات نموذجية؛ استخدم ملفاتك الفعلية. إذا لم توفر خطًا يستخدم Flutter خط النظام.

## بناء شاشة خاصة

العميل لا يعتمد على UI. استمع لأحداث `onEvent`، واربط معرّف الإرسال المحلي بفقاعة الرسالة، ثم حدّثها إلى «مقبولة» عند `message.ack`. عند `message.new` امنع التكرار باستخدام `payload.message_id` وأرسل القراءة عندما تظهر الرسالة فعليًا. لا تعرض الرموز في الواجهة أو السجلات.

## تغيير النصوص بالكامل

النصوص التشغيلية عربية داخل `darai_chat_screen.dart`. الإصدار الحالي لا يوفر ARB/localization لكل نص. أضف طبقة ترجمة في نسختك أو مرر نصوص البداية المتاحة. احتفظ بتمييز «مقبولة» عن «مقروءة».
