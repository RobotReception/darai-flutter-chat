import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class DaraiChatConfig {
  const DaraiChatConfig({
    required this.baseUrl,
    required this.cId,
    required this.appId,
    this.platform = 'appchat',
    this.tokenPath = '/ws/token',
    this.uploadPath = '/ws/upload',
    this.webSocketPath = '/ws/ws',
  });

  /// Validate before opening a connection. No default customer channel is bundled.
  void validate() {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'baseUrl must be an HTTPS origin without a path',
      );
    }
    if (cId.trim().isEmpty || appId.trim().isEmpty || platform != 'appchat') {
      throw const FormatException('Provide cId, appId, and platform=appchat');
    }
    for (final path in [tokenPath, uploadPath, webSocketPath]) {
      if (!path.startsWith('/') ||
          path.startsWith('//') ||
          path.contains('?') ||
          path.contains('#')) {
        throw const FormatException(
          'Endpoint paths must be absolute local paths',
        );
      }
    }
  }

  final String baseUrl;
  final String cId;
  final String appId;
  final String platform;
  final String tokenPath;
  final String uploadPath;
  final String webSocketPath;
}

class DaraiChatClient {
  static const _supportedMediaTypes = {'audio', 'document', 'image', 'video'};
  static const _supportedImageMimeTypes = {
    'image/jpeg',
    'image/png',
    'image/webp',
  };

  DaraiChatClient({
    required this.onEvent,
    required this.config,
    this.getIdentityToken,
    FlutterSecureStorage? storage,
    HttpClient? httpClient,
    this.connectWebSocket,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _http =
           httpClient ??
           (HttpClient()..connectionTimeout = const Duration(seconds: 15)) {
    config.validate();
  }

  /// For signed-in users: fetch a fresh token from YOUR backend on every connection.
  /// A configured callback must return a token; failures do not fall back to a visitor.
  final Future<String> Function()? getIdentityToken;

  /// Optional transport factory for tests. Production uses dart:io WebSocket.
  final Future<WebSocket> Function(Uri)? connectWebSocket;

  final void Function(Map<String, dynamic>) onEvent;
  final DaraiChatConfig config;
  final FlutterSecureStorage _storage;
  final Map<String, Map<String, dynamic>> _pending = {};
  String get _visitorStorageKey =>
      'darai.visitor.${Uri.parse(config.baseUrl).authority}.${config.cId}';
  final HttpClient _http;
  DateTime? _lastFrameAt;

  WebSocket? _socket;
  Timer? _heartbeat;
  Timer? _reconnect;
  bool _closed = false;
  bool _connecting = false;
  int _attempt = 0;
  String? _accessToken;

  String? get accessToken => _accessToken;

  Future<void> connect() async {
    if (_closed || _connecting || _socket != null) return;
    _connecting = true;
    var stage = 'قراءة بيانات الزائر';

    try {
      final body = <String, dynamic>{
        'cId': config.cId,
        'platform': config.platform,
      };
      if (getIdentityToken != null) {
        stage = 'طلب هوية الحساب';
        // Remove the previous guest key before entering an authenticated session.
        await _storage.delete(key: _visitorStorageKey);
        final identity = await getIdentityToken!().timeout(
          const Duration(seconds: 15),
        );
        if (identity.trim().isEmpty) throw StateError('Missing identity token');
        body['identity_token'] = identity;
      } else {
        final visitorKey = await _storage.read(key: _visitorStorageKey);
        if (visitorKey != null) body['visitor_key'] = visitorKey;
      }

      if (_closed) return;
      stage = 'طلب تذكرة القناة';
      final baseUri = Uri.parse(config.baseUrl);
      if (baseUri.scheme != 'https' || !baseUri.hasAuthority) {
        throw const FormatException('Darai chat requires a valid HTTPS URL');
      }
      final request = await _http
          .postUrl(baseUri.replace(path: config.tokenPath))
          .timeout(const Duration(seconds: 15));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final rawResponse = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15));

      stage = 'التحقق من استجابة القناة';
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Token request failed (${response.statusCode})');
      }
      final data = jsonDecode(rawResponse);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid token response');
      }
      if (_closed) return;
      if (data['app_id'] != config.appId) {
        throw StateError('Channel app_id mismatch');
      }
      if (getIdentityToken != null && data['visitorKey'] is String) {
        throw StateError('Identity was rejected; guest fallback is blocked');
      }
      if (getIdentityToken == null && data['visitorKey'] is String) {
        stage = 'حفظ جلسة الزائر';
        await _storage.write(
          key: _visitorStorageKey,
          value: data['visitorKey'] as String,
        );
      }

      final token = data['token'];
      final senderId = data['senderId'];
      final ticket = data['wsTicket'];
      if (token is! String || senderId is! String || ticket is! String) {
        throw const FormatException('Token response is missing required data');
      }
      _accessToken = token;

      stage = 'فتح اتصال WebSocket الآمن';
      final uri = baseUri.replace(
        scheme: 'wss',
        path: config.webSocketPath,
        queryParameters: {
          'v': '1',
          'platform': config.platform,
          'app_id': config.appId,
          'sender_id': senderId,
          'ticket': ticket,
        },
      );
      final socket =
          await (connectWebSocket?.call(uri) ??
                  WebSocket.connect(uri.toString()))
              .timeout(const Duration(seconds: 15));
      if (_closed) {
        await socket.close();
        return;
      }

      _socket = socket;
      _lastFrameAt = DateTime.now();
      _attempt = 0;
      socket.listen(
        _handleFrame,
        onError: (Object error) {
          _emit({'event': 'connection.error', 'message': error.toString()});
          _disconnected(socket);
        },
        onDone: () => _disconnected(socket),
      );
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
        if (_lastFrameAt != null &&
            DateTime.now().difference(_lastFrameAt!) >
                const Duration(seconds: 60)) {
          _disconnected(socket);
        } else {
          _send({'event': 'ping'});
        }
      });
      for (final message in _pending.values) {
        _send(message);
      }
      _emit({'event': 'connection.ready'});
    } catch (error) {
      if (!_closed) {
        _emit({
          'event': 'connection.error',
          'stage': stage,
          'message': error.toString(),
        });
        _scheduleReconnect();
      }
    } finally {
      _connecting = false;
    }
  }

  String sendText(String text) {
    if (_closed) throw StateError('Client is closed');
    if (text.trim().isEmpty) throw ArgumentError('Empty message');

    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final message = <String, dynamic>{
      'event': 'message.send',
      'id': id,
      'payload': {'type': 'text', 'text': text.trim()},
    };
    _pending[id] = message;
    _send(message);
    return id;
  }

  Future<String> uploadFile({
    required File file,
    required String type,
    required String mimeType,
    required String filename,
  }) async {
    if (_closed) throw StateError('Client is closed');
    final token = _accessToken;
    if (token == null) throw StateError('Connect before uploading a file');
    if (!_supportedMediaTypes.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported media type');
    }
    if (type == 'image' && !_supportedImageMimeTypes.contains(mimeType)) {
      throw ArgumentError.value(
        mimeType,
        'mimeType',
        'Supported image formats are JPEG, PNG, and WebP',
      );
    }

    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse(config.baseUrl).replace(path: config.uploadPath),
          )
          ..headers['Authorization'] = 'Bearer $token'
          ..fields['type'] = type
          ..files.add(
            await http.MultipartFile.fromPath(
              'file',
              file.path,
              filename: filename,
              contentType: MediaType.parse(mimeType),
            ),
          );
    final response = await request.send().timeout(const Duration(seconds: 30));
    final rawResponse = await response.stream.bytesToString().timeout(
      const Duration(seconds: 30),
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Upload failed (${response.statusCode})');
    }

    final data = jsonDecode(rawResponse);
    if (data is! Map<String, dynamic> || data['upload_token'] is! String) {
      throw const FormatException('Upload response is missing upload_token');
    }
    return data['upload_token'] as String;
  }

  String sendUpload({required String type, required String uploadToken}) {
    if (_closed) throw StateError('Client is closed');
    if (!_supportedMediaTypes.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Unsupported upload type');
    }
    final random = Random.secure();
    final id = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final message = <String, dynamic>{
      'event': 'message.send',
      'id': id,
      'payload': {'type': type, 'upload_token': uploadToken},
    };
    _pending[id] = message;
    _send(message);
    return id;
  }

  void retry(String id) {
    final message = _pending[id];
    if (message != null) _send(message);
  }

  void markRead(String id) => _send({
    'event': 'message.read',
    'message_ids': [id],
  });

  Future<void> reconnect() async {
    if (_closed) return;
    _reconnect?.cancel();
    _heartbeat?.cancel();
    final socket = _socket;
    _socket = null;
    await socket?.close();
    await connect();
  }

  void _handleFrame(dynamic raw) {
    _lastFrameAt = DateTime.now();
    try {
      final decoded = jsonDecode(
        raw is String ? raw : utf8.decode(raw as List<int>),
      );
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid WebSocket event');
      }

      final id = decoded['id'];
      if (decoded['event'] == 'message.ack' && id is String) {
        _pending.remove(id);
      }
      if (decoded['event'] == 'system.error' &&
          decoded['retryable'] != true &&
          id is String) {
        _pending.remove(id);
      }
      if (decoded['event'] == 'message.new') {
        final payload = decoded['payload'];
        final messageId = payload is Map<String, dynamic>
            ? payload['message_id']
            : null;
        if (messageId is String) {
          _send({
            'event': 'message.delivered',
            'message_ids': [messageId],
          });
        }
      }
      _emit(decoded);
    } catch (error) {
      _emit({'event': 'connection.error', 'message': error.toString()});
    }
  }

  void _send(Map<String, dynamic> event) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.add(jsonEncode(event));
    } catch (error) {
      _emit({'event': 'connection.error', 'message': error.toString()});
      _disconnected(socket);
    }
  }

  void _emit(Map<String, dynamic> event) {
    if (!_closed) onEvent(event);
  }

  void _disconnected(WebSocket socket) {
    if (!identical(socket, _socket)) return;
    _socket = null;
    _heartbeat?.cancel();
    _accessToken = null;
    unawaited(socket.close());
    _emit({'event': 'connection.disconnected'});
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || (_reconnect?.isActive ?? false)) return;
    final seconds = min(30, 1 << min(_attempt++, 5));
    _reconnect = Timer(Duration(seconds: seconds), connect);
  }

  Future<void> dispose() async {
    _closed = true;
    _reconnect?.cancel();
    _heartbeat?.cancel();
    _pending.clear();
    _accessToken = null;
    _http.close(force: true);
    await _socket?.close();
    _socket = null;
  }
}
