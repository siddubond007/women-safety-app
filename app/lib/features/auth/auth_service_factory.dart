import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'backend_auth_service.dart';

/// The hosted backend can be selected in debug builds for local development,
/// or explicitly for the allowlisted staging-test APK. Release builds otherwise
/// fail closed to the unconfigured service.
AuthService authServiceForCurrentBuild() {
  const stagingTestBuild = bool.fromEnvironment(
    'SAKHI_STAGING_TEST_MODE',
    defaultValue: false,
  );
  if (!kDebugMode && !stagingTestBuild) {
    return const UnconfiguredAuthService();
  }
  if (stagingTestBuild) return BackendAuthService();
  if (const bool.fromEnvironment('SAKHI_BACKEND_ENABLED', defaultValue: true)) {
    return BackendAuthService();
  }
  return const DemoAuthService();
}
