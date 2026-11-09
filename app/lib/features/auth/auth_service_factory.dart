import 'dart:io';

import '../../core/constants/mock_data.dart';
import 'auth_service.dart';
import 'backend_auth_service.dart';

/// Uses the live Sakhi backend (`BackendAuthService`) by default in both debug
/// and release builds unless explicitly disabled via `--dart-define=SAKHI_BACKEND_ENABLED=false`
/// or running inside an automated test harness without a live server.
AuthService authServiceForCurrentBuild() {
  const backendEnabled = bool.fromEnvironment(
    'SAKHI_BACKEND_ENABLED',
    defaultValue: true,
  );
  final isTestEnvironment =
      Platform.environment.containsKey('FLUTTER_TEST') ||
      const bool.fromEnvironment('FLUTTER_TEST_MODE');
  if (!backendEnabled || isTestEnvironment) {
    return const DemoAuthService();
  }
  return BackendAuthService(
    onSessionCleared: SakhiPrototypeState.instance.clearAccountScopedData,
  );
}
