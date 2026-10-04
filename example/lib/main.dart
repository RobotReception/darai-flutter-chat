import 'package:darai_chat/darai_chat.dart';
import 'package:flutter/material.dart';
import 'darai_config.dart';

void main() => runApp(const DaraiChatExampleApp());

class DaraiChatExampleApp extends StatelessWidget {
  const DaraiChatExampleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'داري — مثال الدردشة',
    theme: DaraiChatTheme.light(),
    home: const _ExampleHome(),
  );
}

class _ExampleHome extends StatelessWidget {
  const _ExampleHome();
  @override
  Widget build(BuildContext context) {
    String? configurationError;
    try {
      daraiConfig.validate();
    } on FormatException {
      configurationError =
          'أضف بيانات قناتك في darai-config.json ثم أعد تشغيل المثال.';
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مثال ربط داري')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 56),
                const SizedBox(height: 16),
                Text(
                  configurationError ?? 'الدردشة جاهزة للتجربة من هذا الزر.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  icon: const Icon(Icons.chat),
                  label: const Text('فتح الدردشة'),
                  onPressed: configurationError != null
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                const DaraiChatScreen(config: daraiConfig),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
