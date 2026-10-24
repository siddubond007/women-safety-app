import 'package:geolocator/geolocator.dart';

/// Accesses foreground device location only. Background tracking is deliberately
/// not requested or enabled by this service.
class SakhiDeviceLocationService {
  Future<Position> requestCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const DeviceLocationException(
        'Turn on Location in your device settings, then try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
        'Location permission was denied. Allow location access to share your position.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        'Location permission is disabled for Sakhi. Enable it in app settings to share your position.',
      );
    }

    return _validatedPosition(
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ),
    );
  }

  /// Reads location only if permission and device services are already enabled.
  /// This path never opens a permission prompt, so it is safe for SOS handling.
  Future<Position?> currentLocationIfAlreadyAllowed() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }

      return _validatedPosition(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        ),
      );
    } catch (_) {
      // Plugin, permission, and sensor errors must not crash the SOS screen.
      return null;
    }
  }

  Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    ),
  );

  Position _validatedPosition(Position position) {
    if (!position.latitude.isFinite ||
        position.latitude < -90 ||
        position.latitude > 90 ||
        !position.longitude.isFinite ||
        position.longitude < -180 ||
        position.longitude > 180 ||
        !position.accuracy.isFinite ||
        position.accuracy < 0) {
      throw const DeviceLocationException(
        'The device returned an invalid location. No location was shared.',
      );
    }
    return position;
  }
}

class DeviceLocationException implements Exception {
  final String message;

  const DeviceLocationException(this.message);

  @override
  String toString() => message;
}
