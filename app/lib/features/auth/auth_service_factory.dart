import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'backend_auth_service.dart';

/// Backend integration is opt-in and debug-only. Normal widget tests and
/// preview builds continue to use the existing non-persistent demo service.
AuthService authServiceForCurrentBuild() {
  if (!kDebugMode) return const UnconfiguredAuthService();
  if (const bool.fromEnvironment('SAKHI_BACKEND_ENABLED')) {
    return BackendAuthService();
  }
  return const DemoAuthService();
}
