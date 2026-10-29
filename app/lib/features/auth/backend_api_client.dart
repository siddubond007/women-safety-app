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

/// Native HTTP client for the Sakhi backend.
/// Debug builds default to the local development API; release builds default
/// to the hosted staging API so released apps never depend on developer localhost.
/// Override with SAKHI_API_BASE_URL for environment-specific builds.
class BackendApiClient {
  BackendApiClient({
    String? baseUrl,
    HttpClient? httpClient,
    FlutterSecureStorage? secureStorage,
  }) : baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'SAKHI_API_BASE_URL',
             // Release builds must use the hosted staging API by default.
             // Localhost is only the debug/development fallback.
             defaultValue: kReleaseMode
                 ? 'https://sakhi-staging-api.onrender.com/api/v1'
                 : 'http://127.0.0.1:3001/api/v1',
           ),
       _httpClient = httpClient ?? HttpClient(),
       _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    _httpClient.connectionTimeout = const Duration(seconds: 8);
    _httpClient.idleTimeout = const Duration(seconds: 4);
  }

  static const _tokenStorageKey = 'sakhi.dev.auth.access_token';
  static Future<Map<String, String>>? _imageRequestHeadersFuture;

  /// Cached auth headers for Image.network requests to protected media routes.
  /// Invalidated whenever this client stores or clears the session token.
  static Future<Map<String, String>> imageRequestHeaders() {
    _imageRequestHeadersFuture ??= _loadImageRequestHeaders();
    return _imageRequestHeadersFuture!;
  }

  static Future<Map<String, String>> _loadImageRequestHeaders() async {
    final token = await const FlutterSecureStorage().read(
      key: _tokenStorageKey,
    );
    if (token == null || token.isEmpty) return const <String, String>{};
    return <String, String>{HttpHeaders.authorizationHeader: 'Bearer $token'};
  }

  final String baseUrl;
  final HttpClient _httpClient;
  final FlutterSecureStorage _secureStorage;
  String? _accessToken;
  Future<void>? _tokenLoad;

  Future<void> _loadStoredToken() async {
    _accessToken = await _secureStorage
        .read(key: _tokenStorageKey)
        .timeout(const Duration(seconds: 3));
  }

  Future<String?> readAccessToken() async {
    final pendingLoad = _tokenLoad ??= _loadStoredToken();
    try {
      await pendingLoad;
    } catch (_) {
      if (identical(_tokenLoad, pendingLoad)) _tokenLoad = null;
      rethrow;
    }
    return _accessToken;
  }

  Future<void> storeAccessToken(String token) async {
    await _secureStorage.write(key: _tokenStorageKey, value: token);
    _accessToken = token;
    _tokenLoad = Future<void>.value();
    _imageRequestHeadersFuture = null;
  }

  Future<void> clearAccessToken() async {
    _accessToken = null;
    _tokenLoad = Future<void>.value();
    _imageRequestHeadersFuture = null;
    await _secureStorage.delete(key: _tokenStorageKey);
  }

  Uri _uri(String path) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse(normalizedBase)
        .resolve(path.replaceFirst(RegExp(r'^/+'), ''));
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) => _send('GET', path, authenticated: authenticated, headers: headers);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) => _send(
    'POST',
    path,
    body: body,
    authenticated: authenticated,
    headers: headers,
  );

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) => _send(
    'PUT',
    path,
    body: body,
    authenticated: authenticated,
    headers: headers,
  );

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) => _send(
    'PATCH',
    path,
    body: body,
    authenticated: authenticated,
    headers: headers,
  );

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
    Map<String, String>? headers,
  }) => _send(
    'DELETE',
    path,
    body: body,
    authenticated: authenticated,
    headers: headers,
  );

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required List<int> fileBytes,
    required String fileName,
    required String contentType,
    required Map<String, String> fields,
    bool authenticated = true,
  }) async {
    if (fileBytes.isEmpty) {
      throw const BackendApiException(
        statusCode: 400,
        code: 'file_empty',
        message: 'Choose an image file before uploading.',
      );
    }
    final boundary =
        '----SakhiBoundary${DateTime.now().microsecondsSinceEpoch}';
    var requestStage = 'opening upload connection';
    try {
      final request = await _httpClient
          .postUrl(_uri(path))
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );
      if (authenticated) {
        final token = await readAccessToken();
        if (token == null || token.isEmpty) {
          throw const BackendApiException(
            statusCode: 401,
            code: 'session_missing',
            message: 'Sign in again to upload a photo.',
          );
        }
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }

      requestStage = 'writing upload fields';
      for (final entry in fields.entries) {
        final fieldName = entry.key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
        final fieldValue = entry.value
            .replaceAll('\r', '')
            .replaceAll('\n', '');
        request.write('--$boundary\r\n');
        request.write(
          'Content-Disposition: form-data; name="$fieldName"\r\n\r\n',
        );
        request.write('$fieldValue\r\n');
      }
      final safeFileName = fileName
          .replaceAll(RegExp(r'["\r\n\\/]'), '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      request.write('--$boundary\r\n');
      request.write(
        'Content-Disposition: form-data; name="file"; filename="$safeFileName"\r\n',
      );
      request.write('Content-Type: $contentType\r\n\r\n');
      request.add(fileBytes);
      request.write('\r\n--$boundary--\r\n');

      requestStage = 'waiting for upload response';
      final response = await request.close().timeout(
        const Duration(seconds: 45),
      );
      requestStage = 'reading upload response';
      final raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 20));
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
            : 'The image upload failed.';
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
        message: 'The image upload timed out. Check the backend connection and try again.',
      );
    } on SocketException catch (error) {
      final parsedBase = Uri.tryParse(baseUrl);
      final targetHost = parsedBase?.host.isNotEmpty == true
          ? parsedBase!.host
          : 'configured server';
      final osError = error.osError;
      final osDetail = osError?.message.trim().isNotEmpty == true
          ? osError!.message.trim()
          : error.message.trim();
      debugPrint(
        'Sakhi upload socket failure: host=$targetHost path=$path '
        'stage=$requestStage osErrorCode=${osError?.errorCode} '
        'detail=$osDetail',
      );
      throw BackendApiException(
        statusCode: 0,
        code: 'network_unavailable',
        message:
            'Could not connect to Sakhi server ($targetHost) during '
            '$requestStage. Network detail: '
            '${osDetail.isEmpty ? 'no OS detail' : osDetail}. '
            'Check this app\'s network access and retry.',
      );
    } on HttpException catch (error) {
      debugPrint(
        'Sakhi multipart upload transport failure: $path; stage=$requestStage; type=${error.runtimeType}',
      );
      throw BackendApiException(
        statusCode: 0,
        code: 'http_error',
        message:
            'Image upload failed during $requestStage. Check the local backend.',
      );
    } on FormatException {
      throw const BackendApiException(
        statusCode: 0,
        code: 'invalid_response',
        message: 'Sakhi backend returned an invalid upload response.',
      );
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    var requestStage = 'opening connection';
    int? responseStatusCode;
    try {
      final request = await _httpClient
          .openUrl(method, _uri(path))
          .timeout(const Duration(seconds: 12));
      requestStage = 'preparing request';
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (headers != null) {
        headers.forEach((key, value) {
          request.headers.set(key, value);
        });
      }
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
    } on SocketException catch (error) {
      final parsedBase = Uri.tryParse(baseUrl);
      final targetHost = parsedBase?.host.isNotEmpty == true
          ? parsedBase!.host
          : 'configured server';
      final osError = error.osError;
      final osDetail = osError?.message.trim().isNotEmpty == true
          ? osError!.message.trim()
          : error.message.trim();
      debugPrint(
        'Sakhi API socket failure: method=$method path=$path '
        'host=$targetHost stage=$requestStage '
        'osErrorCode=${osError?.errorCode} detail=$osDetail',
      );
      throw BackendApiException(
        statusCode: 0,
        code: 'network_unavailable',
        message:
            'Could not connect to Sakhi server ($targetHost) during '
            '$requestStage. Network detail: '
            '${osDetail.isEmpty ? 'no OS detail' : osDetail}. '
            'Check this app\'s network access and retry.',
      );
    } on HttpException catch (error) {
      final detail = error.message.trim();
      final responseDescription = responseStatusCode == null
          ? 'no response headers received'
          : 'HTTP $responseStatusCode received';
      final detailDescription = detail.isEmpty
          ? 'unspecified HTTP transport error'
          : detail;
      debugPrint(
        'Sakhi API transport failure: $method $path; '
        'stage=$requestStage; response=$responseDescription; '
        'detail=$detailDescription',
      );
      throw BackendApiException(
        statusCode: 0,
        code: 'http_error',
        message:
            'Sakhi backend connection failed during $requestStage: '
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
