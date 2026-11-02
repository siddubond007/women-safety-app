import '../../core/constants/mock_data.dart';
import 'auth_service.dart';
import 'backend_auth_service.dart';

/// Uses the live Sakhi backend (`BackendAuthService`) by default in both debug
/// and release builds unless explicitly disabled via `--dart-define=SAKHI_BACKEND_ENABLED=false`.
AuthService authServiceForCurrentBuild() {
  const backendEnabled = bool.fromEnvironment(
    'SAKHI_BACKEND_ENABLED',
    defaultValue: true,
  );
  if (!backendEnabled) {
    return const DemoAuthService();
  }
  return BackendAuthService(
    onSessionCleared: SakhiPrototypeState.instance.clearAccountScopedData,
  );
}
