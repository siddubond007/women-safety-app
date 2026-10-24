import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/auth/backend_api_client.dart';

const _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

// Flutter's test binding installs an HttpClient that returns synthetic 400s.
// Use Dart's real implementation for this test's explicitly loopback-only server.
class _RealHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final values = <String, String>{};

  setUp(() {
    values.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
          final arguments = call.arguments is Map
              ? Map<Object?, Object?>.from(call.arguments as Map)
              : <Object?, Object?>{};
          final key = arguments['key']?.toString() ?? '';
          switch (call.method) {
            case 'write':
              final value = arguments['value']?.toString();
              if (key.isNotEmpty && value != null) values[key] = value;
              return null;
            case 'read':
              return values[key];
            case 'delete':
              values.remove(key);
              return null;
            case 'deleteAll':
              values.clear();
              return null;
            case 'readAll':
              return Map<String, String>.from(values);
            case 'containsKey':
              return values.containsKey(key);
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  Future<({HttpServer server, HttpClient httpClient})> createServer(
    Future<void> Function(HttpRequest request) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      unawaited(handler(request));
    });
    final httpClient = HttpOverrides.runWithHttpOverrides(
      () => HttpClient(),
      _RealHttpOverrides(),
    );
    return (server: server, httpClient: httpClient);
  }

  test(
    'authenticated JSON POST sets Authorization before writing the body',
    () async {
      final received = Completer<Map<String, Object?>>();
      final fixture = await createServer((request) async {
        final body = await utf8.decoder.bind(request).join();
        received.complete({
          'authorization': request.headers.value(
            HttpHeaders.authorizationHeader,
          ),
          'contentType': request.headers.contentType?.mimeType,
          'body': body,
        });
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'ok': true}));
        await request.response.close();
      });
      addTearDown(() async {
        fixture.httpClient.close(force: true);
        await fixture.server.close(force: true);
      });

      final client = BackendApiClient(
        baseUrl: 'http://127.0.0.1:${fixture.server.port}/api/v1',
        httpClient: fixture.httpClient,
        secureStorage: const FlutterSecureStorage(),
      );
      await client.storeAccessToken(
        'test-access-token-that-is-long-enough-for-a-request',
      );
      final response = await client.post(
        'auth/profile',
        authenticated: true,
        body: {'displayName': 'Synthetic Test'},
      );
      final request = await received.future.timeout(const Duration(seconds: 3));

      expect(response['ok'], isTrue);
      expect(
        request['authorization'],
        'Bearer test-access-token-that-is-long-enough-for-a-request',
      );
      expect(request['contentType'], 'application/json');
      expect(jsonDecode(request['body']! as String), {
        'displayName': 'Synthetic Test',
      });
    },
  );

  test(
    'missing access token fails before sending an authenticated request',
    () async {
      var requestCount = 0;
      final fixture = await createServer((request) async {
        requestCount++;
        request.response.statusCode = HttpStatus.ok;
        request.response.write('{}');
        await request.response.close();
      });
      addTearDown(() async {
        fixture.httpClient.close(force: true);
        await fixture.server.close(force: true);
      });

      final client = BackendApiClient(
        baseUrl: 'http://127.0.0.1:${fixture.server.port}/api/v1',
        httpClient: fixture.httpClient,
        secureStorage: const FlutterSecureStorage(),
      );

      await expectLater(
        client.post(
          'auth/profile',
          authenticated: true,
          body: {'displayName': 'QA'},
        ),
        throwsA(
          isA<BackendApiException>().having(
            (error) => error.code,
            'code',
            'session_missing',
          ),
        ),
      );
      expect(requestCount, 0);
    },
  );

  test(
    'unauthenticated JSON POST still succeeds without an Authorization header',
    () async {
      final received = Completer<Map<String, Object?>>();
      final fixture = await createServer((request) async {
        final body = await utf8.decoder.bind(request).join();
        received.complete({
          'authorization': request.headers.value(
            HttpHeaders.authorizationHeader,
          ),
          'body': body,
        });
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'challengeId': 'synthetic-challenge'}),
        );
        await request.response.close();
      });
      addTearDown(() async {
        fixture.httpClient.close(force: true);
        await fixture.server.close(force: true);
      });

      final client = BackendApiClient(
        baseUrl: 'http://127.0.0.1:${fixture.server.port}/api/v1',
        httpClient: fixture.httpClient,
        secureStorage: const FlutterSecureStorage(),
      );
      final response = await client.post(
        'auth/otp/request',
        body: {'purpose': 'registration'},
      );
      final request = await received.future.timeout(const Duration(seconds: 3));

      expect(response['challengeId'], 'synthetic-challenge');
      expect(request['authorization'], isNull);
      expect(jsonDecode(request['body']! as String), {
        'purpose': 'registration',
      });
    },
  );

  test(
    'HTTP error responses preserve their status, code, and message',
    () async {
      final fixture = await createServer((request) async {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'code': 'invalid_profile',
            'message': 'A test validation message.',
          }),
        );
        await request.response.close();
      });
      addTearDown(() async {
        fixture.httpClient.close(force: true);
        await fixture.server.close(force: true);
      });

      final client = BackendApiClient(
        baseUrl: 'http://127.0.0.1:${fixture.server.port}/api/v1',
        httpClient: fixture.httpClient,
        secureStorage: const FlutterSecureStorage(),
      );

      await expectLater(
        client.post('auth/profile', body: {'displayName': 'QA'}),
        throwsA(
          isA<BackendApiException>()
              .having(
                (error) => error.statusCode,
                'statusCode',
                HttpStatus.badRequest,
              )
              .having((error) => error.code, 'code', 'invalid_profile')
              .having(
                (error) => error.message,
                'message',
                'A test validation message.',
              ),
        ),
      );
    },
  );

  test(
    'malformed success payload keeps the invalid-response mapping',
    () async {
      final fixture = await createServer((request) async {
        request.response.statusCode = HttpStatus.ok;
        request.response.write('not-json');
        await request.response.close();
      });
      addTearDown(() async {
        fixture.httpClient.close(force: true);
        await fixture.server.close(force: true);
      });

      final client = BackendApiClient(
        baseUrl: 'http://127.0.0.1:${fixture.server.port}/api/v1',
        httpClient: fixture.httpClient,
        secureStorage: const FlutterSecureStorage(),
      );

      await expectLater(
        client.post('auth/profile', body: {'displayName': 'QA'}),
        throwsA(
          isA<BackendApiException>().having(
            (error) => error.code,
            'code',
            'invalid_response',
          ),
        ),
      );
    },
  );
}
