import 'package:darai_chat/darai_chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const config = DaraiChatConfig(
  baseUrl: 'https://chat.example.com',
  cId: 'c',
  appId: 'a',
);

class FakeClient extends DaraiChatClient {
  FakeClient(void Function(Map<String, dynamic>) event, DaraiChatConfig config)
    : super(onEvent: event, config: config);
  bool closed = false;
  @override
  Future<void> connect() async {}
  @override
  Future<void> dispose() async {
    closed = true;
    await super.dispose();
  }

  @override
  String sendText(String text) => 'test-id';
}

void main() {
  testWidgets('custom title, RTL, hidden attachments and safe disposal', (
    tester,
  ) async {
    late FakeClient client;
    await tester.pumpWidget(
      MaterialApp(
        home: DaraiChatScreen(
          config: config,
          title: 'خدمة العملاء',
          allowImageAttachments: false,
          clientBuilder: (event, config) => client = FakeClient(event, config),
        ),
      ),
    );
    expect(find.text('خدمة العملاء'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file_rounded), findsNothing);
    final scaffold = tester.element(find.byType(Scaffold));
    expect(Directionality.of(scaffold), TextDirection.rtl);
    expect(Theme.of(scaffold).colorScheme.primary, const Color(0xFF1B5091));
    await tester.pumpWidget(const SizedBox());
    expect(client.closed, isTrue);
  });
  testWidgets('long title fits a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: DaraiChatScreen(
          config: config,
          title: 'فريق خدمة العملاء والدعم الفني لتطبيق العميل',
          clientBuilder: (event, config) => FakeClient(event, config),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('ack displays acceptance, not read status', (tester) async {
    late FakeClient client;
    await tester.pumpWidget(
      MaterialApp(
        home: DaraiChatScreen(
          config: config,
          clientBuilder: (event, config) => client = FakeClient(event, config),
        ),
      ),
    );
    client.onEvent({'event': 'connection.ready'});
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'مرحبا');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();
    client.onEvent({'event': 'message.ack', 'id': 'test-id'});
    await tester.pumpAndSettle();
    expect(find.text('مقبولة'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
