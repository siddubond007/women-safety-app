import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
  }) : baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'SAKHI_API_BASE_URL',
             defaultValue: 'http://127.0.0.1:3000/api/v1',
           ),
       _httpClient = httpClient ?? HttpClient(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _httpClient.connectionTimeout = const Duration(seconds: 8);
    // The local Node backend closes idle keep-alive sockets quickly. Keep the
    // client's idle timeout shorter so later form submissions don't reuse a
    // socket the server has already closed.
    _httpClient.idleTimeout = const Duration(seconds: 4);
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

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
  }) => _send('PUT', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
  }) async {
    var requestStage = 'opening connection';
    int? responseStatusCode;
    try {
      final request = await _httpClient
          .openUrl(method, _uri(path))
          .timeout(const Duration(seconds: 12));
      requestStage = 'preparing request';
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      // Configure every header before writing any body bytes. Dart can make
      // request headers immutable as soon as request.write() begins.
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
      }
      if (body != null) {
        request.write(jsonEncode(body));
      }

      requestStage = 'waiting for response headers';
      final response = await request.close().timeout(
        const Duration(seconds: 15),
      );
      responseStatusCode = response.statusCode;
      requestStage = 'reading response body';
      final raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 15));
      requestStage = 'decoding response body';
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
    } on HttpException catch (error) {
      final detail = error.message.trim();
      final responseDescription = responseStatusCode == null
          ? 'no response headers received'
          : 'HTTP $responseStatusCode received';
      final detailDescription = detail.isEmpty
          ? 'unspecified HTTP transport error'
          : detail;
      // Log only the method, endpoint path and transport metadata. Never log
      // request/response bodies, OTPs, access tokens, or profile details.
      debugPrint(
        'Sakhi API transport failure: $method $path; '
        'stage=$requestStage; response=$responseDescription; '
        'detail=$detailDescription',
      );
      throw BackendApiException(
        statusCode: 0,
        code: 'http_error',
        message: 'Sakhi backend connection failed during $requestStage: '
            '$detailDescription.',
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
