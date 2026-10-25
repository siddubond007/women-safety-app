import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// Accesses foreground device location with fast hardware fallback.
class SakhiDeviceLocationService {
  static const MethodChannel _nativeChannel = MethodChannel(
    'sakhi/native_actions',
  );

  Future<Position> requestCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const DeviceLocationException(
        'Turn on Location (GPS) in your device settings, then try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const DeviceLocationException(
        'Location permission was denied. Allow location access to view your live map and nearby police stations.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw const DeviceLocationException(
        'Location permission is disabled for Sakhi. Enable it in app settings to share your position.',
      );
    }

    try {
      return _validatedPosition(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        ),
      );
    } catch (_) {
      // Fallback 1: Last known Geolocator position
      final lastKnown = await Geolocator.getLastKnownPosition().catchError(
        (_) => null,
      );
      if (lastKnown != null) {
        return _validatedPosition(lastKnown);
      }
      // Fallback 2: Native Android LocationManager last known fix
      final nativeFix = await _readNativeAndroidLastKnownFix();
      if (nativeFix != null) {
        return nativeFix;
      }
      // Fallback 3: Medium/Network accuracy fix
      return _validatedPosition(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        ),
      );
    }
  }

  /// Reads location if permission and device services are already enabled.
  Future<Position?> currentLocationIfAlreadyAllowed() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return null;
      }

      try {
        return _validatedPosition(
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          ),
        );
      } catch (_) {
        final lastKnown = await Geolocator.getLastKnownPosition().catchError(
          (_) => null,
        );
        if (lastKnown != null) return _validatedPosition(lastKnown);
        return await _readNativeAndroidLastKnownFix();
      }
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _readNativeAndroidLastKnownFix() async {
    try {
      final res = await _nativeChannel.invokeMethod<Map<Object?, Object?>>(
        'getLastKnownNativeLocation',
      );
      if (res == null) return null;
      final lat = (res['latitude'] as num?)?.toDouble();
      final lng = (res['longitude'] as num?)?.toDouble();
      final acc = (res['accuracy'] as num?)?.toDouble() ?? 15.0;
      if (lat == null || lng == null) return null;
      return _validatedPosition(
        Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: acc,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Stream<Position> get positionStream => Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
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
        'The device returned an invalid location. Please check GPS settings.',
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
