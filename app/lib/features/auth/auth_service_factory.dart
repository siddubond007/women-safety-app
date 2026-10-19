import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'backend_auth_service.dart';

/// Backend integration is enabled by default in debug builds so mobile auth
/// always enforces real PostgreSQL registration and verification rules unless
/// explicitly disabled with `--dart-define=SAKHI_BACKEND_ENABLED=false`.
AuthService authServiceForCurrentBuild() {
  if (!kDebugMode) return const UnconfiguredAuthService();
  if (const bool.fromEnvironment('SAKHI_BACKEND_ENABLED', defaultValue: true)) {
    return BackendAuthService();
  }
  return const DemoAuthService();
}
