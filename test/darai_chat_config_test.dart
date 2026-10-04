import 'package:darai_chat/darai_chat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DaraiChatConfig config(String url, {String cId = 'channel'}) =>
      DaraiChatConfig(baseUrl: url, cId: cId, appId: 'application');
  test('HTTPS origin and endpoint defaults are accepted', () {
    final value = config('https://chat.example.com');
    expect(value.validate, returnsNormally);
    expect(value.tokenPath, '/ws/token');
    expect(value.uploadPath, '/ws/upload');
    expect(value.webSocketPath, '/ws/ws');
  });
  test('rejects insecure URLs and URLs carrying credentials or paths', () {
    for (final url in [
      'http://chat.example.com',
      '',
      'https://u:p@chat.example.com',
      'https://chat.example.com/ws',
      'https://chat.example.com?a=b',
      'https://chat.example.com#secret',
    ]) {
      expect(config(url).validate, throwsFormatException, reason: url);
    }
  });
  test('rejects blank identifiers and non-local endpoint paths', () {
    expect(
      config('https://chat.example.com', cId: '').validate,
      throwsFormatException,
    );
    const value = DaraiChatConfig(
      baseUrl: 'https://chat.example.com',
      cId: 'c',
      appId: 'a',
      tokenPath: '//other.example/token',
    );
    expect(value.validate, throwsFormatException);
  });
}
