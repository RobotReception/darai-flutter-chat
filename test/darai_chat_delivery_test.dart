import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:darai_chat/darai_chat.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttp extends Mock implements HttpClient {}

class MockRequest extends Mock implements HttpClientRequest {}

class MockHeaders extends Mock implements HttpHeaders {}

class MockResponse extends Mock implements HttpClientResponse {}

class MockSocket extends Mock implements WebSocket {}

const config = DaraiChatConfig(
  baseUrl: 'https://chat.example.com',
  cId: 'c',
  appId: 'a',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(Uri.parse('https://chat.example.com')));
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<(DaraiChatClient, MockSocket, StreamController<dynamic>, MockRequest)>
  connected({
    Future<String> Function()? identity,
    List<Map<String, dynamic>>? events,
  }) async {
    final http = MockHttp();
    final request = MockRequest();
    final headers = MockHeaders();
    final response = MockResponse();
    final socket = MockSocket();
    final frames = StreamController<dynamic>.broadcast();
    when(() => http.postUrl(any())).thenAnswer((_) async => request);
    when(() => request.headers).thenReturn(headers);
    when(() => request.close()).thenAnswer((_) async => response);
    when(() => response.statusCode).thenReturn(200);
    when(
      () => response.listen(
        any(),
        onError: any(named: 'onError'),
        onDone: any(named: 'onDone'),
        cancelOnError: any(named: 'cancelOnError'),
      ),
    ).thenAnswer(
      (i) =>
          Stream<List<int>>.value(
            utf8.encode(
              jsonEncode({
                'app_id': 'a',
                'token': 'access',
                'senderId': 'sender',
                'wsTicket': 'ticket',
                if (identity == null) 'visitorKey': 'signed-visitor',
              }),
            ),
          ).listen(
            i.positionalArguments[0] as void Function(List<int>)?,
            onError: i.namedArguments[#onError],
            onDone: i.namedArguments[#onDone] as void Function()?,
            cancelOnError: i.namedArguments[#cancelOnError] as bool?,
          ),
    );
    when(
      () => socket.listen(
        any(),
        onError: any(named: 'onError'),
        onDone: any(named: 'onDone'),
        cancelOnError: any(named: 'cancelOnError'),
      ),
    ).thenAnswer(
      (i) => frames.stream.listen(
        i.positionalArguments[0] as void Function(dynamic)?,
        onError: i.namedArguments[#onError],
        onDone: i.namedArguments[#onDone] as void Function()?,
      ),
    );
    when(() => socket.close()).thenAnswer((_) async {});
    final client = DaraiChatClient(
      config: config,
      onEvent: (e) => events?.add(e),
      httpClient: http,
      getIdentityToken: identity,
      connectWebSocket: (uri) async {
        expect(uri.scheme, 'wss');
        expect(uri.queryParameters['ticket'], 'ticket');
        expect(uri.queryParameters.containsKey('token'), isFalse);
        return socket;
      },
    );
    await client.connect();
    return (client, socket, frames, request);
  }

  test('pending resend preserves id; ack removes pending message', () async {
    final (client, socket, frames, _) = await connected();
    final id = client.sendText('hello');
    client.retry(id);
    final sent = verify(() => socket.add(captureAny())).captured;
    expect(sent.length, 2);
    expect(
      sent.map((e) => (jsonDecode(e as String) as Map)['id']),
      everyElement(id),
    );
    frames.add(jsonEncode({'event': 'message.ack', 'id': id}));
    await Future<void>.delayed(Duration.zero);
    client.retry(id);
    verifyNever(() => socket.add(any()));
    await client.dispose();
    await frames.close();
  });
  test(
    'guest key persists and delivery receipt uses server message id',
    () async {
      final (client, socket, frames, _) = await connected();
      expect(
        await const FlutterSecureStorage().read(
          key: 'darai.visitor.chat.example.com.c',
        ),
        'signed-visitor',
      );
      frames.add(
        jsonEncode({
          'event': 'message.new',
          'payload': {'message_id': 'server-1', 'text': 'reply'},
        }),
      );
      await Future<void>.delayed(Duration.zero);
      final sent =
          jsonDecode(
                verify(() => socket.add(captureAny())).captured.single
                    as String,
              )
              as Map;
      expect(sent['event'], 'message.delivered');
      expect(sent['message_ids'], ['server-1']);
      await client.dispose();
      await frames.close();
    },
  );
  test('each authenticated reconnect fetches a fresh identity token', () async {
    var calls = 0;
    final (client, _, frames, request) = await connected(
      identity: () async => 'identity-${++calls}',
    );
    await client.reconnect();
    expect(calls, 2);
    final bodies = verify(
      () => request.write(captureAny()),
    ).captured.map((e) => jsonDecode(e as String) as Map).toList();
    expect(bodies.map((e) => e['identity_token']), [
      'identity-1',
      'identity-2',
    ]);
    expect(bodies.every((e) => !e.containsKey('visitor_key')), isTrue);
    await client.dispose();
    await frames.close();
  });
}
