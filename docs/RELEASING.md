# تجهيز GitHub وإصدار الحزمة

1. المستودع الرسمي RobotReception/darai-flutter-chat، وترخيصه MIT. احتفظ بإشعار الترخيص عند التوزيع.
2. ارفع الملفات المفكوكة كمصدر، وليس ملف ZIP وحده. لا ترفع darai-config.json أو أسرار توقيع أو ملفات build/local.properties أو keystore.
3. شغّل التحليل والاختبارات وراجع VALIDATION.md. سير GitHub المرفق يتحقق على Flutter 3.41.0؛ لا ينشر تلقائيًا.
4. حدّث CHANGELOG.md والإصدار في pubspec.yaml. أنشئ Tag مثل v0.1.0.
5. أنشئ GitHub Release وأرفق ZIP نظيفًا مع SHA256 ونتائج التحقق. اجعل زر تنزيل داري يشير إلى إصدار محدد اختبرته، ورابط المصدر اختياريًا.
6. لا تضمّن قناة عميل حقيقية في الإعدادات العامة. يمكن للوحة داري تنزيل ملف إعداد منفصل لكل قناة مستقبلًا.

إذا اخترت اعتماد Git في تطبيق العميل، ثبّت ref على Tag/commit اختبرته، لا على فرع متغير. الحزمة حاليًا publish_to: none؛ نشر pub.dev يحتاج ترخيصًا عامًا وبيانات نشر ومراجعة توافق منفصلة.

توثيق GitHub: https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository

لإعادة بناء ملف التسليم من المصدر (Python 3):

```sh
python3 tool/package.py
```

ينتج ZIP وSHA256 في المجلد الأب، ويستبعد المخرجات والإعداد المحلي. راجع المحتويات قبل نشرها.
