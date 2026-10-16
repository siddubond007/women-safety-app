import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackendApiException implements Exception {
  const BackendApiException({
    required this.statusCode,
    required this.code,
    required this.message,
  });

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'BackendApiException($statusCode, $code)';
}

/// Small native HTTP client used by the development backend adapter.
///
/// No request/response bodies, OTPs, bearer tokens or profile fields are
/// logged. The base URL is injected at build time; production auth remains
/// unconfigured until a production provider and API environment are approved.
class BackendApiClient {
  BackendApiClient({
    String? baseUrl,
    HttpClient? httpClient,
    FlutterSecureStorage? secureStorage,
  }) : baseUrl = baseUrl ?? _defaultBaseUrl(),
       _httpClient = httpClient ?? HttpClient(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _httpClient.connectionTimeout = const Duration(seconds: 8);
  }

  static String _defaultBaseUrl() {
    const configuredBaseUrl = String.fromEnvironment('SAKHI_API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) return configuredBaseUrl;

    // Android emulators reach the development host via 10.0.2.2, not their
    // own loopback address. Other native development targets use host loopback.
    return Platform.isAndroid
        ? 'http://10.0.2.2:3000/api/v1'
        : 'http://127.0.0.1:3000/api/v1';
  }

  static const _tokenStorageKey = 'sakhi.dev.auth.access_token';

  final String baseUrl;
  final HttpClient _httpClient;
  final FlutterSecureStorage _secureStorage;
  String? _accessToken;
  Future<void>? _tokenLoad;

  Future<void> _loadStoredToken() async {
    _accessToken = await _secureStorage.read(key: _tokenStorageKey);
  }

  Future<String?> readAccessToken() async {
    _tokenLoad ??= _loadStoredToken();
    await _tokenLoad;
    return _accessToken;
  }

  Future<void> storeAccessToken(String token) async {
    await _secureStorage.write(key: _tokenStorageKey, value: token);
    _accessToken = token;
    _tokenLoad = Future<void>.value();
  }

  Future<void> clearAccessToken() async {
    _accessToken = null;
    _tokenLoad = Future<void>.value();
    await _secureStorage.delete(key: _tokenStorageKey);
  }

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(normalizedBase)
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''));
  }

  Future<Map<String, dynamic>> get(String path, {bool authenticated = false}) =>
      _send('GET', path, authenticated: authenticated);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
  }) => _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
  }) async {
    try {
      final request = await _httpClient
          .openUrl(method, _uri(path))
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      // Resolve authentication before writing the body. Once request bytes are
      // written, some HttpClient implementations may begin sending the request
      // and no longer permit header mutation.
      if (authenticated) {
        final token = await readAccessToken();
        if (token == null || token.isEmpty) {
          throw const BackendApiException(
            statusCode: 401,
            code: 'session_missing',
            message: 'Sign in again to continue.',
          );
        }
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      final raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15));
      final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final rawMessage = payload['message'];
        final message = rawMessage is List
            ? rawMessage.map((value) => value.toString()).join(' ')
            : rawMessage is String
            ? rawMessage
            : 'The development backend could not complete the request.';
        throw BackendApiException(
          statusCode: response.statusCode,
          code: payload['code'] is String
              ? payload['code'] as String
              : 'http_${response.statusCode}',
          message: message,
        );
      }
      return payload;
    } on BackendApiException {
      rethrow;
    } on TimeoutException {
      throw const BackendApiException(
        statusCode: 0,
        code: 'timeout',
        message: 'Sakhi backend timed out. Check the local connection and try again.',
      );
    } on SocketException {
      throw const BackendApiException(
        statusCode: 0,
        code: 'network_unavailable',
        message: 'Sakhi backend is unreachable. Start the local backend and check the USB connection.',
      );
    } on HttpException {
      throw const BackendApiException(
        statusCode: 0,
        code: 'http_error',
        message: 'Sakhi backend returned an unreadable response.',
      );
    } on FormatException {
      throw const BackendApiException(
        statusCode: 0,
        code: 'invalid_response',
        message: 'Sakhi backend returned an invalid response.',
      );
    }
  }
}
