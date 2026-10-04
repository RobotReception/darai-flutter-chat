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

const config = DaraiChatConfig(
  baseUrl: 'https://chat.example.com',
  cId: 'c',
  appId: 'a',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(Uri.parse('https://chat.example.com')));
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('invalid config fails before any connection', () {
    expect(
      () => DaraiChatClient(
        onEvent: (_) {},
        config: const DaraiChatConfig(
          baseUrl: 'http://unsafe.example',
          cId: 'c',
          appId: 'a',
        ),
      ),
      throwsFormatException,
    );
  });
  test('identity failure does not issue guest token request', () async {
    final http = MockHttp();
    final events = <Map<String, dynamic>>[];
    final client = DaraiChatClient(
      config: config,
      httpClient: http,
      onEvent: events.add,
      getIdentityToken: () async => throw StateError('expired session'),
    );
    await client.connect();
    verifyNever(() => http.postUrl(any()));
    expect(events.single['event'], 'connection.error');
    await client.dispose();
  });
  test('closed client cannot send and never reconnects', () async {
    final http = MockHttp();
    final client = DaraiChatClient(
      config: config,
      httpClient: http,
      onEvent: (_) {},
    );
    await client.dispose();
    await client.connect();
    verifyNever(() => http.postUrl(any()));
    expect(() => client.sendText('hello'), throwsStateError);
  });
  test(
    'signed-in request excludes visitor key and rejects guest fallback',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'darai.visitor.chat.example.com.c': 'old-guest',
      });
      final http = MockHttp();
      final request = MockRequest();
      final headers = MockHeaders();
      final response = MockResponse();
      final events = <Map<String, dynamic>>[];
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
        (invocation) =>
            Stream<List<int>>.value(
              utf8.encode(
                jsonEncode({'app_id': 'a', 'visitorKey': 'guest-fallback'}),
              ),
            ).listen(
              invocation.positionalArguments[0] as void Function(List<int>)?,
              onError: invocation.namedArguments[#onError],
              onDone: invocation.namedArguments[#onDone] as void Function()?,
              cancelOnError: invocation.namedArguments[#cancelOnError] as bool?,
            ),
      );
      final client = DaraiChatClient(
        config: config,
        onEvent: events.add,
        httpClient: http,
        getIdentityToken: () async => 'signed-identity',
      );
      await client.connect();
      final body =
          jsonDecode(
                verify(() => request.write(captureAny())).captured.single
                    as String,
              )
              as Map;
      expect(body['identity_token'], 'signed-identity');
      expect(body.containsKey('visitor_key'), isFalse);
      expect(events.last['message'], contains('guest fallback is blocked'));
      expect(
        await const FlutterSecureStorage().read(
          key: 'darai.visitor.chat.example.com.c',
        ),
        isNull,
      );
      await client.dispose();
    },
  );
}
