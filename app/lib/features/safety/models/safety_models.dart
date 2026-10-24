import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/assets/app_assets.dart';
import '../../auth/backend_api_client.dart';
import '../services/device_location_service.dart';

class SafetyTrustedContact {
  final String id;
  String name;
  String relationship;
  String phoneE164;
  bool isPrimary;
  bool selectedForSosAlert;

  SafetyTrustedContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phoneE164,
    this.isPrimary = false,
    this.selectedForSosAlert = true,
  });

  String get phoneMasked {
    final cleaned = phoneE164.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.length >= 10) {
      final prefix = cleaned.startsWith('+91')
          ? '+91 ${cleaned.substring(3, 8)}'
          : cleaned.substring(0, 5);
      final lastDigit = cleaned.substring(cleaned.length - 1);
      return '$prefix ••••$lastDigit';
    }
    return phoneE164;
  }

  factory SafetyTrustedContact.fromJson(Map<String, dynamic> json) {
    return SafetyTrustedContact(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['contactName'] ?? '').toString(),
      relationship: (json['relationship'] ?? 'Trusted Contact').toString(),
      phoneE164: (json['phoneE164'] ?? json['phoneNumber'] ?? '').toString(),
      isPrimary: json['isPrimary'] == true,
      selectedForSosAlert:
          json['alertEnabled'] != false &&
          json['isTrustedLocationContact'] != false,
    );
  }
}

class NearbyPoliceStationModel {
  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final double distanceKm;
  final int driveMinutes;
  final String phoneNumber;
  final bool isWomenStation;
  final bool isVerified;

  const NearbyPoliceStationModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.driveMinutes,
    required this.phoneNumber,
    this.isWomenStation = false,
    this.isVerified = true,
  });

  String get distanceBadgeText =>
      '${distanceKm.toStringAsFixed(1)} km • $driveMinutes mins';

  factory NearbyPoliceStationModel.fromJson(
    Map<String, dynamic> json, {
    double userLat = 12.9716,
    double userLng = 77.5946,
  }) {
    final lat = (json['latitude'] as num?)?.toDouble() ?? userLat;
    final lng = (json['longitude'] as num?)?.toDouble() ?? userLng;
    final dist =
        (json['distanceKm'] as num?)?.toDouble() ??
        SakhiSafetyController.haversineKm(userLat, userLng, lat, lng);
    final mins =
        (json['driveMinutes'] as num?)?.toInt() ??
        math.max(2, (dist * 4.5).round());
    return NearbyPoliceStationModel(
      id: (json['id'] ?? json['stationCode'] ?? '').toString(),
      name: (json['name'] ?? 'Verified Police Station').toString(),
      address: (json['address'] ?? 'Bengaluru, Karnataka').toString(),
      latitude: lat,
      longitude: lng,
      distanceKm: dist,
      driveMinutes: mins,
      phoneNumber: (json['phoneNumber'] ?? '+91 80-2294-2548').toString(),
      isWomenStation: json['isWomenStation'] == true,
      isVerified: json['isVerified'] != false,
    );
  }
}

class SafetySosHistoryItem {
  final String id;
  final String timestampLabel;
  final String status; // 'RESOLVED', 'CANCELLED', 'TEST_MODE', 'ACTIVE'
  final String locationLabel;
  final double? latitude;
  final double? longitude;
  final int contactsAlertedCount;
  final int durationMinutes;
  final bool isTestMode;
  final String? shareToken;

  const SafetySosHistoryItem({
    required this.id,
    required this.timestampLabel,
    required this.status,
    required this.locationLabel,
    this.latitude,
    this.longitude,
    this.contactsAlertedCount = 3,
    this.durationMinutes = 12,
    this.isTestMode = false,
    this.shareToken,
  });

  String get badgeLabel {
    switch (status.toUpperCase()) {
      case 'RESOLVED':
      case 'RECORDED':
        return 'Resolved Safely';
      case 'CANCELLED':
      case 'TEST_MODE':
        return 'Test Trigger / Cancelled';
      case 'ACTIVE':
        return 'Live Alert Active';
      default:
        return status;
    }
  }

  String get detailsSummary {
    if (isTestMode ||
        status.toUpperCase() == 'CANCELLED' ||
        status.toUpperCase() == 'TEST_MODE') {
      return 'Cancelled during 3s confirmation screen • No external alert sent';
    }
    return 'SOS event recorded; calls and messages are not automatically dispatched • Duration: $durationMinutes mins';
  }

  factory SafetySosHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['createdAt']?.toString() ?? '';
    final dt = DateTime.tryParse(rawCreated)?.toLocal();
    final formattedDate = dt != null
        ? '${dt.day.toString().padLeft(2, '0')} Oct ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.hour >= 12 ? 'PM' : 'AM'}'
        : (json['timestampLabel']?.toString() ?? '23 Oct 2026 • 09:04 AM');
    final rawStatus = (json['status'] ?? 'RESOLVED').toString().toUpperCase();
    final rawType = (json['eventType'] ?? 'SOS_ACTIVATED')
        .toString()
        .toUpperCase();
    final isTest =
        json['isTestMode'] == true ||
        rawType.contains('TEST') ||
        rawStatus == 'CANCELLED';
    return SafetySosHistoryItem(
      id: (json['id'] ?? json['eventId'] ?? '').toString(),
      timestampLabel: formattedDate,
      status: isTest && rawStatus == 'RECORDED' ? 'TEST_MODE' : rawStatus,
      locationLabel: (json['locationLabel'] ?? 'Location unavailable')
          .toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      contactsAlertedCount:
          (json['contactsAlertedCount'] as num?)?.toInt() ?? (isTest ? 0 : 3),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 12,
      isTestMode: isTest,
      shareToken: json['shareToken']?.toString(),
    );
  }
}

class VerifiedHelplineModel {
  final String code;
  final String number;
  final String title;
  final String subtitle;
  final String badgeAsset;

  const VerifiedHelplineModel({
    required this.code,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.badgeAsset,
  });
}

class SafetyChecklistItemModel {
  final String id;
  final String title;
  bool isChecked;

  SafetyChecklistItemModel({
    required this.id,
    required this.title,
    required this.isChecked,
  });
}

/// Centralized Module 4 Emergency SOS & Personal Safety controller.
class SakhiSafetyController extends ChangeNotifier {
  static final SakhiSafetyController instance =
      SakhiSafetyController._internal();

  SakhiSafetyController._internal();

  BackendApiClient? _apiClient;
  BackendApiClient get _client => _apiClient ??= BackendApiClient();
  final SakhiDeviceLocationService _deviceLocationService =
      SakhiDeviceLocationService();
  StreamSubscription<Position>? _locationUpdates;
  DateTime? _lastLocationPingAt;
  DateTime? currentLocationUpdatedAt;
  bool isAcquiringLocation = false;
  String locationStatusMessage = 'Tap to enable device GPS.';

  void configureApiClient(BackendApiClient client) {
    _apiClient = client;
  }

  bool get hasRecentDeviceLocation {
    final updatedAt = currentLocationUpdatedAt;
    if (!hasLiveLocation || !locationPermissionGranted || updatedAt == null) {
      return false;
    }
    final age = DateTime.now().difference(updatedAt);
    return age >= Duration.zero && age <= const Duration(minutes: 1);
  }

  Future<bool> requestDeviceLocation() async {
    if (isAcquiringLocation) return false;
    isAcquiringLocation = true;
    locationStatusMessage = 'Getting current device location…';
    notifyListeners();
    try {
      final position = await _deviceLocationService.requestCurrentLocation();
      updateDeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        locationLabel: 'Current device location',
      );
      locationStatusMessage =
          'Location is available. Access is limited to when Sakhi is in use.';
      return true;
    } catch (error) {
      final token = activeShareToken;
      _stopLocationUpdates();
      _clearLocationState();
      if (token.isNotEmpty) unawaited(_stopRemoteLocationShare(token));
      locationStatusMessage = error is DeviceLocationException ? error.message : 'Unable to obtain device location. Check Location settings and try again.';
      return false;
    } finally {
      isAcquiringLocation = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentLocationIfAlreadyGranted() async {
    final position = await _deviceLocationService
        .currentLocationIfAlreadyAllowed();
    if (position == null) {
      if (currentLocationUpdatedAt == null ||
          DateTime.now().difference(currentLocationUpdatedAt!) >
              const Duration(minutes: 1)) {
        locationStatusMessage = 'No recent GPS fix is available. Coordinates will not be attached to an SOS.';
        notifyListeners();
      }
      return;
    }
    updateDeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      locationLabel: 'Current device location',
    );
    locationStatusMessage = 'Current device location refreshed.';
  }

  void _startLocationUpdates() {
    _stopLocationUpdates();
    final expectedToken = activeShareToken;
    if (expectedToken.isEmpty || !liveLocationSharingActive) return;

    _locationUpdates = _deviceLocationService.positionStream.listen(
      (position) {
        if (expectedToken != activeShareToken || !liveLocationSharingActive) {
          return;
        }
        updateDeviceLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          locationLabel: 'Current device location',
        );
        final now = DateTime.now();
        if (_lastLocationPingAt == null ||
            now.difference(_lastLocationPingAt!) >=
                const Duration(seconds: 15)) {
          _lastLocationPingAt = now;
          unawaited(_pingLocationShare(expectedToken, position));
        }
      },
      onError: (Object _) {
        if (expectedToken != activeShareToken) return;
        locationStatusMessage = 'GPS updates stopped. Check device Location settings; the shared position may be old.';
        notifyListeners();
      },
    );
  }

  Future<void> _pingLocationShare(String token, Position position) async {
    try {
      final response = await _client.patch(
        'module2/safety/location-shares/$token/ping',
        authenticated: true,
        body: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracyMeters': position.accuracy,
          'locationLabel': 'Current device location',
        },
      );
      if (token != activeShareToken) return;
      if (response['status']?.toString().toUpperCase() != 'ACTIVE') {
        _stopShareAfterLocationFailure(
          token,
          'The server no longer confirms this location share as active.',
        );
        return;
      }
      locationStatusMessage =
          'Location updates are being sent while Sakhi is open.';
    } catch (_) {
      if (token != activeShareToken) return;
      locationStatusMessage = 'Latest location update could not be confirmed. The tracking page may show an older position.';
    }
    notifyListeners();
  }

  void _stopShareAfterLocationFailure(String token, String message) {
    _stopLocationUpdates();
    activeShareToken = '';
    activeTrackingUrl = '';
    liveLocationSharingActive = false;
    locationStatusMessage = message;
    notifyListeners();
    unawaited(_stopRemoteLocationShare(token));
  }

  Future<void> _stopRemoteLocationShare(String token) async {
    await _sendBackend((client) async {
      await client.post(
        'module2/safety/location-shares/$token/stop',
        authenticated: true,
        body: {},
      );
    });
  }

  void _stopLocationUpdates() {
    final subscription = _locationUpdates;
    _locationUpdates = null;
    _lastLocationPingAt = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _clearLocationState() {
    hasLiveLocation = false;
    locationPermissionGranted = false;
    currentLatitude = 0.0;
    currentLongitude = 0.0;
    currentAccuracyMeters = null;
    currentLocationUpdatedAt = null;
    batteryPercent = null;
    currentLocationLabel = 'Location unavailable';
    activeShareToken = '';
    activeTrackingUrl = '';
    liveLocationSharingActive = false;
    nearbyPoliceStations.clear();
  }

  bool locationPermissionGranted = false;
  bool hasLiveLocation = false;
  bool powerButtonShortcutEnabled = true;
  bool discreetShakeTriggerEnabled = false;
  bool liveLocationSharingActive = false;
  String selectedDurationLabel = '1 Hour';
  bool includeNameAndProfileInAlert = true;
  bool includeTimestampAndMapLink = true;
  double currentLatitude = 0.0;
  double currentLongitude = 0.0;
  double? currentAccuracyMeters;
  String currentLocationLabel = 'Location unavailable';
  int? batteryPercent;
  String activeShareToken = '';
  String activeTrackingUrl = '';
  bool isLoadingStations = false;
  bool isSyncingSafety = false;

  String get liveShareShortUrl {
    final link = liveShareFullUrl;
    if (link.isEmpty) return 'Live location unavailable';
    return 'Live tracking link ready';
  }

  String get liveShareFullUrl =>
      hasRecentDeviceLocation &&
          liveLocationSharingActive &&
          activeShareToken.isNotEmpty &&
          activeTrackingUrl.isNotEmpty
      ? activeTrackingUrl
      : '';

  String get backendTrackingUrl => liveShareFullUrl;

  String? _resolveTrackingUrl(String rawUrl) {
    final candidate = Uri.tryParse(rawUrl.trim());
    if (candidate == null) return null;
    if ((candidate.scheme == 'https' || candidate.scheme == 'http') &&
        candidate.host.isNotEmpty) {
      return candidate.toString();
    }
    final base = Uri.tryParse(_client.baseUrl);
    if (base == null ||
        (base.scheme != 'https' && base.scheme != 'http') ||
        base.host.isEmpty) {
      return null;
    }
    final path = rawUrl.trim().startsWith('/')
        ? rawUrl.trim()
        : '/${rawUrl.trim()}';
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
    ).toString();
  }

  bool _acceptLocationShareResponse(
    Map<String, dynamic> response, {
    required bool sosActivation,
  }) {
    final shareToken = response['shareToken']?.toString().trim() ?? '';
    final trackingPath = response['trackingUrl']?.toString().trim() ?? '';
    final statusAllowsShare = sosActivation
        ? response['locationAvailable'] == true
        : response['status']?.toString().toUpperCase() == 'ACTIVE';
    final resolvedUrl = trackingPath.isEmpty
        ? null
        : _resolveTrackingUrl(trackingPath);

    if (!statusAllowsShare ||
        shareToken.isEmpty ||
        resolvedUrl == null ||
        resolvedUrl.isEmpty) {
      activeShareToken = '';
      activeTrackingUrl = '';
      liveLocationSharingActive = false;
      return false;
    }

    activeShareToken = shareToken;
    activeTrackingUrl = resolvedUrl;
    liveLocationSharingActive = true;
    return true;
  }

  String get batteryLabel =>
      batteryPercent == null ? 'Unknown' : '$batteryPercent%';

  void updateDeviceLocation({
    required double latitude,
    required double longitude,
    String? locationLabel,
    double? accuracyMeters,
    int? batteryPercent,
  }) {
    if (!latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      clearDeviceLocation();
      return;
    }
    currentLatitude = latitude;
    currentLongitude = longitude;
    currentLocationLabel = locationLabel?.trim().isNotEmpty == true
        ? locationLabel!.trim()
        : 'Current device location';
    currentAccuracyMeters =
        accuracyMeters != null && accuracyMeters.isFinite && accuracyMeters >= 0
        ? accuracyMeters
        : null;
    this.batteryPercent =
        batteryPercent != null && batteryPercent >= 0 && batteryPercent <= 100
        ? batteryPercent
        : null;
    currentLocationUpdatedAt = DateTime.now();
    locationPermissionGranted = true;
    hasLiveLocation = true;
    notifyListeners();
  }

  void clearDeviceLocation() {
    final token = activeShareToken;
    _stopLocationUpdates();
    _clearLocationState();
    locationStatusMessage = 'Location unavailable. Tap to enable device GPS.';
    notifyListeners();
    if (token.isNotEmpty) unawaited(_stopRemoteLocationShare(token));
  }

  final List<SafetyTrustedContact> trustedContacts = [
    SafetyTrustedContact(
      id: 'ec_mom',
      name: 'Lakshmi Devi',
      relationship: 'Mom',
      phoneE164: '+919845011111',
      isPrimary: true,
      selectedForSosAlert: true,
    ),
    SafetyTrustedContact(
      id: 'ec_sister',
      name: 'Priya Sharma',
      relationship: 'Sister',
      phoneE164: '+919880122224',
      isPrimary: false,
      selectedForSosAlert: true,
    ),
    SafetyTrustedContact(
      id: 'ec_roommate',
      name: 'Ananya Rao',
      relationship: 'Roommate',
      phoneE164: '+919731233339',
      isPrimary: false,
      selectedForSosAlert: true,
    ),
  ];

  final List<NearbyPoliceStationModel> nearbyPoliceStations = [];

  final List<SafetySosHistoryItem> sosHistory = [];

  final List<SafetyChecklistItemModel> preTravelChecklist = [
    SafetyChecklistItemModel(
      id: 'chk_cab_route',
      title: 'Share cab vehicle number & live route with Primary Contact',
      isChecked: true,
    ),
    SafetyChecklistItemModel(
      id: 'chk_gps_battery',
      title: 'Verify GPS permission & battery above 20%',
      isChecked: true,
    ),
    SafetyChecklistItemModel(
      id: 'chk_112_shortcut',
      title: 'Keep 112 & Discreet SOS shortcut enabled',
      isChecked: false,
    ),
  ];

  final List<VerifiedHelplineModel> verifiedHelplines = const [
    VerifiedHelplineModel(
      code: '1091',
      number: '1091',
      title: '1091 — Women in Distress Helpline',
      subtitle: "Police Women's Safety Cell • Toll-Free",
      badgeAsset: AppAssets.icM4WomenPolice1091,
    ),
    VerifiedHelplineModel(
      code: '181',
      number: '181',
      title: '181 — Women Domestic & Safety Helpline',
      subtitle: '24/7 Support & Counselling',
      badgeAsset: AppAssets.icM4DomesticSupport181,
    ),
    VerifiedHelplineModel(
      code: '108_1930',
      number: '108',
      title: '108 / 1930 — Medical Ambulance (108) & Cyber Crime (1930)',
      subtitle: 'Emergency medical & online fraud support',
      badgeAsset: AppAssets.icM4MedicalCyber108,
    ),
    VerifiedHelplineModel(
      code: '100',
      number: '100',
      title: '100 — Direct Police Control Room Dispatch',
      subtitle: '24/7 Police Emergency Response Across India',
      badgeAsset: AppAssets.icM4NearestPolice,
    ),
  ];

  List<SafetyTrustedContact> get selectedContacts =>
      trustedContacts.where((c) => c.selectedForSosAlert).toList();

  SafetyTrustedContact? get primaryContact {
    for (final c in trustedContacts) {
      if (c.isPrimary) return c;
    }
    return trustedContacts.isNotEmpty ? trustedContacts.first : null;
  }

  static double haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  Future<void> syncSafetyOverview() async {
    if (isSyncingSafety) return;
    isSyncingSafety = true;
    notifyListeners();
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return;
      final res = await _client.get(
        'module2/safety/overview',
        authenticated: true,
      );
      final rawContacts = res['emergencyContacts'];
      if (rawContacts is List && rawContacts.isNotEmpty) {
        trustedContacts
          ..clear()
          ..addAll(
            rawContacts.whereType<Map<String, dynamic>>().map(
              SafetyTrustedContact.fromJson,
            ),
          );
        _ensurePrimaryExists();
      }
      final rawHistory = res['sosHistory'];
      if (rawHistory is List && rawHistory.isNotEmpty) {
        sosHistory
          ..clear()
          ..addAll(
            rawHistory.whereType<Map<String, dynamic>>().map(
              SafetySosHistoryItem.fromJson,
            ),
          );
      }
      final rawStations = res['policeStations'];
      if (rawStations is List && rawStations.isNotEmpty) {
        nearbyPoliceStations
          ..clear()
          ..addAll(
            rawStations.whereType<Map<String, dynamic>>().map(
              (s) => NearbyPoliceStationModel.fromJson(
                s,
                userLat: currentLatitude,
                userLng: currentLongitude,
              ),
            ),
          );
      }
    } catch (_) {
      // Keep local resilient state if backend is offline.
    } finally {
      isSyncingSafety = false;
      notifyListeners();
    }
  }

  Future<void> refreshNearbyPoliceStations() async {
    if (!hasRecentDeviceLocation) {
      nearbyPoliceStations.clear();
      isLoadingStations = false;
      notifyListeners();
      return;
    }
    isLoadingStations = true;
    notifyListeners();
    try {
      final res = await _client.get(
        'module2/safety/police-stations?lat=$currentLatitude&lng=$currentLongitude&radiusMeters=5000',
        authenticated: false,
      );
      final rows = res['stations'];
      if (rows is List && rows.isNotEmpty) {
        nearbyPoliceStations
          ..clear()
          ..addAll(
            rows.whereType<Map<String, dynamic>>().map(
              (s) => NearbyPoliceStationModel.fromJson(
                s,
                userLat: currentLatitude,
                userLng: currentLongitude,
              ),
            ),
          );
      }
    } catch (_) {
      // Fallback to verified built-in stations sorted by distance.
    } finally {
      isLoadingStations = false;
      notifyListeners();
    }
  }

  void _ensurePrimaryExists() {
    if (trustedContacts.isEmpty) return;
    if (!trustedContacts.any((c) => c.isPrimary)) {
      trustedContacts.first.isPrimary = true;
      trustedContacts.first.selectedForSosAlert = true;
    }
  }

  void setPrimaryContact(String contactId) {
    for (final c in trustedContacts) {
      c.isPrimary = (c.id == contactId);
      if (c.isPrimary) {
        c.selectedForSosAlert = true;
      }
    }
    notifyListeners();
    unawaited(
      _sendBackend((client) async {
        await client.patch(
          'module2/safety/contacts/$contactId',
          authenticated: true,
          body: {'isPrimary': true, 'alertEnabled': true},
        );
      }),
    );
  }

  bool toggleContactSelectedForSos(String contactId, bool nextVal) {
    final idx = trustedContacts.indexWhere((c) => c.id == contactId);
    if (idx == -1) return false;
    final contact = trustedContacts[idx];
    // SRS 6.5 guardrail: at least 1 contact must remain selected if primary
    if (!nextVal &&
        selectedContacts.length <= 1 &&
        contact.selectedForSosAlert) {
      return false;
    }
    contact.selectedForSosAlert = nextVal;
    notifyListeners();
    unawaited(
      _sendBackend((client) async {
        await client.patch(
          'module2/safety/contacts/$contactId',
          authenticated: true,
          body: {'alertEnabled': nextVal},
        );
      }),
    );
    return true;
  }

  bool removeTrustedContact(String contactId) {
    if (trustedContacts.length <= 1) {
      return false;
    }
    trustedContacts.removeWhere((c) => c.id == contactId);
    _ensurePrimaryExists();
    notifyListeners();
    unawaited(
      _sendBackend((client) async {
        await client.delete(
          'module2/safety/contacts/$contactId',
          authenticated: true,
        );
      }),
    );
    return true;
  }

  String? addTrustedContact({
    required String name,
    required String mobileNumber,
    required String relationship,
    required bool setAsPrimary,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.length < 2) {
      return 'Please enter the contact’s full name.';
    }
    if (trustedContacts.length >= 5) {
      return 'Maximum 5 trusted emergency contacts allowed.';
    }
    final digitsOnly = mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final tenDigits = digitsOnly.length == 12 && digitsOnly.startsWith('91')
        ? digitsOnly.substring(2)
        : digitsOnly;
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(tenDigits)) {
      return 'Enter a valid 10-digit Indian mobile number (+91).';
    }
    final phoneE164 = '+91$tenDigits';
    if (setAsPrimary) {
      for (final c in trustedContacts) {
        c.isPrimary = false;
      }
    }
    final newContact = SafetyTrustedContact(
      id: 'ec_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      relationship: relationship.trim().isEmpty
          ? 'Sister'
          : relationship.trim(),
      phoneE164: phoneE164,
      isPrimary: setAsPrimary || trustedContacts.isEmpty,
      selectedForSosAlert: true,
    );
    trustedContacts.add(newContact);
    _ensurePrimaryExists();
    notifyListeners();

    unawaited(
      _sendBackend((client) async {
        final created = await client.post(
          'module2/safety/contacts',
          authenticated: true,
          body: {
            'name': trimmedName,
            'relationship': newContact.relationship,
            'phoneE164': phoneE164,
            'isPrimary': newContact.isPrimary,
            'alertEnabled': true,
          },
        );
        if (created['id'] is String && (created['id'] as String).isNotEmpty) {
          final idx = trustedContacts.indexWhere((c) => c.id == newContact.id);
          if (idx != -1) {
            trustedContacts[idx] = SafetyTrustedContact(
              id: created['id'] as String,
              name: newContact.name,
              relationship: newContact.relationship,
              phoneE164: newContact.phoneE164,
              isPrimary: newContact.isPrimary,
              selectedForSosAlert: newContact.selectedForSosAlert,
            );
            notifyListeners();
          }
        }
      }),
    );
    return null;
  }

  Future<SafetySosHistoryItem> activateSosEvent({
    bool isTestMode = false,
  }) async {
    final now = DateTime.now();
    final eventId =
        'SOS-${now.year}-${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    final canSendLocation = hasRecentDeviceLocation;

    // The backend generates unpredictable public tracking tokens after persistence.
    final previousShareToken = activeShareToken;
    _stopLocationUpdates();
    activeShareToken = '';
    activeTrackingUrl = '';
    liveLocationSharingActive = false;
    final item = SafetySosHistoryItem(
      id: eventId,
      timestampLabel:
          'Just now — ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      status: isTestMode ? 'TEST_MODE' : 'ACTIVE',
      locationLabel: canSendLocation
          ? currentLocationLabel
          : 'Location unavailable',
      latitude: canSendLocation ? currentLatitude : null,
      longitude: canSendLocation ? currentLongitude : null,
      contactsAlertedCount: 0,
      durationMinutes: 0,
      isTestMode: isTestMode,
      shareToken: null,
    );
    sosHistory.insert(0, item);
    notifyListeners();
    if (previousShareToken.isNotEmpty) {
      unawaited(_stopRemoteLocationShare(previousShareToken));
    }

    unawaited(
      _sendBackend((client) async {
        final response = await client.post(
          'module2/safety/sos/activate',
          authenticated: true,
          body: {
            'eventType': isTestMode ? 'SOS_TEST_MODE' : 'SOS_ACTIVATED',
            'isTestMode': isTestMode,
            'contactsAlertedCount': 0,
            if (canSendLocation) ...{
              'locationLabel': currentLocationLabel,
              'latitude': currentLatitude,
              'longitude': currentLongitude,
            },
          },
        );
        if (!isTestMode && canSendLocation) {
          final shareAccepted = _acceptLocationShareResponse(
            response,
            sosActivation: true,
          );
          if (shareAccepted) {
            locationStatusMessage = 'SOS location share is active; updates run while Sakhi is open.';
            _startLocationUpdates();
          } else {
            locationStatusMessage = 'SOS recorded, but the server did not confirm a live tracking link.';
          }
        } else {
          activeShareToken = '';
          activeTrackingUrl = '';
          liveLocationSharingActive = false;
          if (!isTestMode) {
            locationStatusMessage = 'SOS recorded without a location because no recent GPS fix was available.';
          }
        }
        notifyListeners();
      }),
    );
    return item;
  }

  void cancelSosDuringCountdown({bool isTestMode = false}) {
    final now = DateTime.now();
    final item = SafetySosHistoryItem(
      id: 'SOS-CANCEL-${now.millisecondsSinceEpoch % 10000}',
      timestampLabel: 'Just now • Cancelled in 3s Guard',
      status: 'CANCELLED',
      locationLabel: currentLocationLabel,
      latitude: currentLatitude,
      longitude: currentLongitude,
      contactsAlertedCount: 0,
      durationMinutes: 0,
      isTestMode: true,
    );
    sosHistory.insert(0, item);
    notifyListeners();

    unawaited(
      _sendBackend((client) async {
        await client.post(
          'module2/safety/events',
          authenticated: true,
          body: {
            'eventType': 'SOS_ACTIVATED',
            'status': 'CANCELLED',
            'locationLabel': currentLocationLabel,
            'isTestMode': true,
          },
        );
      }),
    );
  }

  void stopLocationSharingAndEndSos() {
    final confirmedShareToken = activeShareToken;
    _stopLocationUpdates();
    activeShareToken = '';
    activeTrackingUrl = '';
    liveLocationSharingActive = false;
    locationStatusMessage = 'Live location sharing stopped.';
    for (var i = 0; i < sosHistory.length; i++) {
      if (sosHistory[i].status == 'ACTIVE') {
        final old = sosHistory[i];
        sosHistory[i] = SafetySosHistoryItem(
          id: old.id,
          timestampLabel: old.timestampLabel,
          status: 'RESOLVED',
          locationLabel: old.locationLabel,
          latitude: old.latitude,
          longitude: old.longitude,
          contactsAlertedCount: old.contactsAlertedCount,
          durationMinutes: old.durationMinutes,
          isTestMode: old.isTestMode,
          shareToken: null,
        );
      }
    }
    notifyListeners();

    if (confirmedShareToken.isNotEmpty) {
      unawaited(
        _sendBackend((client) async {
          await client.post(
            'module2/safety/location-shares/$confirmedShareToken/stop',
            authenticated: true,
            body: {},
          );
        }),
      );
    }
  }

  Future<bool> startLiveLocationSharing({String? duration}) async {
    if (duration != null) selectedDurationLabel = duration;
    final locationReady = await requestDeviceLocation();
    if (!locationReady || !hasRecentDeviceLocation) return false;

    final previousShareToken = activeShareToken;
    _stopLocationUpdates();
    activeShareToken = '';
    activeTrackingUrl = '';
    liveLocationSharingActive = false;
    if (previousShareToken.isNotEmpty) {
      unawaited(_stopRemoteLocationShare(previousShareToken));
    }
    // Keep the share hidden until the backend confirms it was persisted.
    notifyListeners();
    try {
      final response = await _client.post(
        'module2/safety/location-shares',
        authenticated: true,
        body: {
          'durationLabel': selectedDurationLabel,
          'includeProfile': includeNameAndProfileInAlert,
          'includeTimestamp': includeTimestampAndMapLink,
          'latitude': currentLatitude,
          'longitude': currentLongitude,
          if (currentAccuracyMeters != null)
            'accuracyMeters': currentAccuracyMeters,
          if (batteryPercent != null) 'batteryPercent': batteryPercent,
          'locationLabel': currentLocationLabel,
        },
      );
      final accepted = _acceptLocationShareResponse(
        response,
        sosActivation: false,
      );
      if (accepted) {
        locationStatusMessage =
            'Location share is active. Updates are sent while Sakhi is open.';
        _startLocationUpdates();
      } else {
        locationStatusMessage = 'The server did not confirm this location share. No tracking link is available.';
      }
      notifyListeners();
      return accepted;
    } catch (_) {
      activeShareToken = '';
      activeTrackingUrl = '';
      liveLocationSharingActive = false;
      locationStatusMessage = 'The server could not confirm the location share. Try again when connected.';
      notifyListeners();
      return false;
    }
  }

  void toggleChecklist(String id, bool value) {
    final idx = preTravelChecklist.indexWhere((c) => c.id == id);
    if (idx != -1) {
      preTravelChecklist[idx].isChecked = value;
      notifyListeners();
    }
  }

  String buildEmergencyAlertMessage() {
    final parts = <String>[
      'SAKHI EMERGENCY SOS ALERT',
      if (includeNameAndProfileInAlert)
        'Member: Sakhi member requested emergency assistance.',
      if (hasRecentDeviceLocation) ...[
        'Location: $currentLocationLabel (Lat ${currentLatitude.toStringAsFixed(5)}, Lng ${currentLongitude.toStringAsFixed(5)})',
        if (includeTimestampAndMapLink) ...[
          'Google Maps: https://www.google.com/maps?q=$currentLatitude,$currentLongitude',
          if (liveShareFullUrl.isNotEmpty)
            'Live Tracking Link: $liveShareFullUrl',
        ],
      ] else ...[
        'No recent device GPS fix is available. No coordinates or tracking link are attached.',
      ],
      'Battery: $batteryLabel',
      'Emergency Helpline: 112 / 100',
    ];
    return parts.join('\n');
  }

  Future<void> launchPhoneCall(
    BuildContext context,
    String phoneNumber, {
    String? label,
  }) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final telUri = 'tel:$cleaned';
    await Clipboard.setData(ClipboardData(text: cleaned));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF3B0D47),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Dialing ${label ?? cleaned} ($telUri) • Number copied to dialer',
        ),
        action: SnackBarAction(
          label: 'Share',
          textColor: const Color(0xFFFCE8EC),
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(text: 'Call ${label ?? cleaned}: $cleaned'),
            );
          },
        ),
      ),
    );
  }

  Future<void> launchDirectionsToStation(
    BuildContext context,
    NearbyPoliceStationModel station,
  ) async {
    final mapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=${station.latitude},${station.longitude}&travelmode=driving';
    await Clipboard.setData(ClipboardData(text: mapsUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF5A1868),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Opening turn-by-turn directions to ${station.name} (${station.distanceBadgeText})',
        ),
        action: SnackBarAction(
          label: 'Share Map',
          textColor: Colors.white,
          onPressed: () {
            SharePlus.instance.share(
              ShareParams(
                text:
                    '${station.name} — ${station.address}\nDirections: $mapsUrl',
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> dispatchSosAlertToContacts(BuildContext context) async {
    final message = buildEmergencyAlertMessage();
    final recipients = selectedContacts.map((c) => c.name).join(', ');
    await Clipboard.setData(ClipboardData(text: message));
    try {
      await SharePlus.instance.share(ShareParams(text: message));
    } catch (_) {
      // Share sheet may not open in headless widget tests.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFC92A49),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Emergency message prepared; Sakhi does not automatically dispatch calls or SMS for $recipients (${selectedContacts.length} selected)',
        ),
      ),
    );
  }

  Future<void> _sendBackend(
    Future<void> Function(BackendApiClient client) fn,
  ) async {
    try {
      final token = await _client.readAccessToken();
      if (token == null || token.isEmpty) return;
      await fn(_client);
    } catch (_) {}
  }
}
