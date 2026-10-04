# عقد الاتصال والرسائل

المسارات الافتراضية نسبية لأصل Base URL: POST `/ws/token`، WSS `/ws/ws`، POST `/ws/upload`. يمكن تخصيصها في DaraiChatConfig إذا اختلفت البوابة.

## التذكرة

```json
{"cId":"YOUR_CHANNEL_ID","platform":"appchat","visitor_key":"OPTIONAL_SAVED_KEY"}
```

في وضع الحساب يحل `identity_token` محل visitor_key. الاستجابة المتوقعة تشمل `app_id` و`senderId` و`wsTicket` و`token`، وقد تشمل `visitorKey` للزائر. يتحقق العميل من app_id قبل فتح WebSocket.

اتصال WebSocket يستخدم Query: `v=1`، `platform=appchat`، `app_id`، `sender_id`، `ticket`. التذكرة قصيرة العمر ولمرة واحدة؛ لا تعِد استعمالها. يصدر العميل تذكرة جديدة عند كل اتصال.

## الإرسال

```json
{"event":"message.send","id":"UNIQUE_ID","payload":{"type":"text","text":"مرحبا"}}
```

| الحدث | المعنى |
|---|---|
| message.ack | قبول الرسالة وإزالة المعرف من قائمة الانتظار المحلية |
| message.new | رسالة واردة، يُستخدم payload.message_id لمنع التكرار |
| system.error | فشل؛ يعاد فقط إذا retryable=true وبنفس id |
| message.delivered | إقرار استلام لرسائل الخادم |
| message.read | إقرار قراءة عندما تعرض الواجهة الرسالة |
| connection.ready | حدث محلي: اتصال جاهز |
| connection.disconnected | حدث محلي: انقطع الاتصال وتبدأ إعادة المحاولة |
| connection.error | حدث محلي: فشل يتضمن message وقد يتضمن stage |

النصوص المعلقة تعاد بعد الاتصال. retry(id) يعيد الرسالة الموجودة في الذاكرة فقط. لا يوجد ضمان حفظ بعد إغلاق الشاشة ولا مهلة إقرار ثابتة. heartbeat كل 25 ثانية؛ إذا لم تصل أي إطار لأكثر من 60 ثانية يبدأ العميل إعادة اتصال، بتدرج 1 إلى 30 ثانية.

## الرفع

multipart مع Authorization: Bearer token، حقل type=image، وجزء file مع MIME الصحيح. JPEG=image/jpeg، PNG=image/png، WebP=image/webp. استجابة upload_token تستخدم في:

```json
{"event":"message.send","id":"UNIQUE_ID","payload":{"type":"image","upload_token":"TEMPORARY_UPLOAD_TOKEN"}}
```

نوع الملف الحقيقي والحجم المسموح يفحصهما الخادم. الواجهة تعرض placeholder للمرفقات الواردة؛ لا يوجد تنزيل أو عارض ملفات في هذا الإصدار. إضافة عارض تحتاج عقد رابط تحميل آمن من الخادم، فلا تخمن رابطًا من معرف الرسالة.
