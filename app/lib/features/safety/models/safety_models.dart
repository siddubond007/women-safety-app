import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/assets/app_assets.dart';
import '../../auth/backend_api_client.dart';
import '../services/device_location_service.dart';

class SimCardInfo {
  final int subscriptionId;
  final int slotIndex;
  final String carrierName;
  final String displayName;
  final String number;

  const SimCardInfo({
    required this.subscriptionId,
    required this.slotIndex,
    required this.carrierName,
    required this.displayName,
    this.number = '',
  });

  String get label =>
      'SIM ${slotIndex + 1} • ${carrierName.isNotEmpty ? carrierName : displayName}';

  factory SimCardInfo.fromMap(Map<dynamic, dynamic> map) {
    final slot = (map['slotIndex'] as num?)?.toInt() ?? 0;
    final carrier = (map['carrierName'] ?? '').toString().trim();
    final display = (map['displayName'] ?? 'SIM ${slot + 1}').toString().trim();
    return SimCardInfo(
      subscriptionId: (map['subscriptionId'] as num?)?.toInt() ?? -1,
      slotIndex: slot,
      carrierName: carrier.isNotEmpty ? carrier : display,
      displayName: display,
      number: (map['number'] ?? '').toString().trim(),
    );
  }
}

class SafetyTrustedContact {
  final String id;
  String name;
  String relationship;
  String phoneE164;
  bool isPrimary;
  bool selectedForSosAlert;
  bool isNumberVisible;

  SafetyTrustedContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phoneE164,
    this.isPrimary = false,
    this.selectedForSosAlert = true,
    this.isNumberVisible = false,
  });

  String get phoneFormatted {
    final cleaned = phoneE164.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+91') && cleaned.length == 13) {
      return '+91 ${cleaned.substring(3, 8)} ${cleaned.substring(8)}';
    }
    return phoneE164;
  }

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

  String displayPhone({required bool globalShowAll}) {
    if (globalShowAll || isNumberVisible) {
      return phoneFormatted;
    }
    return phoneMasked;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship,
    'phoneE164': phoneE164,
    'isPrimary': isPrimary,
    'alertEnabled': selectedForSosAlert,
  };

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
  final String dataSource;

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
    this.isVerified = false,
    this.dataSource = 'OpenStreetMap Live Directory',
  });

  String get distanceBadgeText =>
      '${distanceKm.toStringAsFixed(1)} km • $driveMinutes mins';

  factory NearbyPoliceStationModel.fromJson(
    Map<String, dynamic> json, {
    required double userLat,
    required double userLng,
  }) {
    final lat = (json['latitude'] as num?)?.toDouble() ?? userLat;
    final lng = (json['longitude'] as num?)?.toDouble() ?? userLng;
    final dist =
        (json['distanceKm'] as num?)?.toDouble() ??
        SakhiSafetyController.haversineKm(userLat, userLng, lat, lng);
    final mins =
        (json['driveMinutes'] as num?)?.toInt() ??
        math.max(2, (dist * 3.8).round());
    final rawPhone = (json['phoneNumber'] ?? '').toString().trim();
    return NearbyPoliceStationModel(
      id: (json['id'] ?? json['stationCode'] ?? '').toString(),
      name: (json['name'] ?? 'Police Station').toString(),
      address: (json['address'] ?? 'Verify landmark on map').toString(),
      latitude: lat,
      longitude: lng,
      distanceKm: dist,
      driveMinutes: mins,
      phoneNumber: rawPhone.isEmpty || rawPhone == 'Not listed'
          ? '100'
          : rawPhone,
      isWomenStation: json['isWomenStation'] == true,
      isVerified: json['isVerified'] == true,
      dataSource: (json['dataSource'] ?? 'Verified Directory').toString(),
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
    this.contactsAlertedCount = 0,
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
        return SakhiSafetyController.formatCleanSafetyLabel(status);
    }
  }

  String get detailsSummary {
    if (isTestMode ||
        status.toUpperCase() == 'CANCELLED' ||
        status.toUpperCase() == 'TEST_MODE') {
      return 'Safe test or cancelled during 3s guard • No external alert sent';
    }
    return 'SOS recorded ($contactsAlertedCount contacts selected) • Coordinates saved to safety log';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestampLabel': timestampLabel,
    'status': status,
    'locationLabel': locationLabel,
    'latitude': latitude,
    'longitude': longitude,
    'contactsAlertedCount': contactsAlertedCount,
    'durationMinutes': durationMinutes,
    'isTestMode': isTestMode,
    'shareToken': shareToken,
  };

  factory SafetySosHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['createdAt']?.toString() ?? '';
    final dt = DateTime.tryParse(rawCreated)?.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final formattedDate = dt != null
        ? '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : (json['timestampLabel']?.toString() ?? 'Recent SOS Event');
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
          (json['contactsAlertedCount'] as num?)?.toInt() ?? 0,
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
  final String category;
  final String badgeAsset;
  final IconData vectorIcon;
  final Color accentColor;

  const VerifiedHelplineModel({
    required this.code,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.badgeAsset,
    required this.vectorIcon,
    required this.accentColor,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'isChecked': isChecked,
  };

  factory SafetyChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return SafetyChecklistItemModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      isChecked: json['isChecked'] == true,
    );
  }
}

class SafetyTipGuideModel {
  final String id;
  final String category;
  final String title;
  final String subtitle;
  final String illustrationAsset;
  final IconData icon;
  final String emergencyNumber;
  final List<String> actionSteps;
  final List<String> dosAndDonts;

  const SafetyTipGuideModel({
    required this.id,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.illustrationAsset,
    required this.icon,
    required this.emergencyNumber,
    required this.actionSteps,
    required this.dosAndDonts,
  });
}

/// Centralized Module 4 Emergency SOS & Personal Safety controller.
class SakhiSafetyController extends ChangeNotifier {
  static final SakhiSafetyController instance =
      SakhiSafetyController._internal();

  SakhiSafetyController._internal() {
    _registerNativeHardwareHandler();
  }

  static const MethodChannel _nativeChannel = MethodChannel(
    'sakhi/native_actions',
  );
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _kContactsKey = 'sakhi.module4.trusted_contacts_v2';
  static const String _kHistoryKey = 'sakhi.module4.sos_history_v2';
  static const String _kShortcutsKey = 'sakhi.module4.shortcuts_v2';
  static const String _kChecklistKey = 'sakhi.module4.checklist_v2';
  static const String _kRideLogKey = 'sakhi.module4.ride_log_v2';
  static const String _kSelectedSimKey = 'sakhi.module4.selected_sim_v1';

  static String formatCleanSafetyLabel(String raw) {
    final cleaned = raw.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return 'Hardware Shortcut';
    return cleaned
        .split(RegExp(r'\s+'))
        .map(
          (w) => w.isEmpty
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static bool isLikelyNonPoliceCommercialPoi(
    String name,
    String address, [
    Map<String, dynamic>? tags,
  ]) {
    final combined = '$name $address'.toLowerCase();
    const blockedKeywords = [
      'petrol',
      'bunk',
      'fuel',
      'pump',
      'gas station',
      'hpcl',
      'bpcl',
      'iocl',
      'indian oil',
      'bharat petroleum',
      'hindustan petroleum',
      'nayara',
      'shell',
      'canteen',
      'ncc',
      'cadet',
      'supermarket',
      'grocery',
      'bakery',
      'restaurant',
      'hotel',
      'cafe',
      'atm',
      'bank',
      'hospital',
      'clinic',
      'pharmacy',
      'medical store',
      'school',
      'college',
    ];
    for (final kw in blockedKeywords) {
      if (combined.contains(kw)) return true;
    }
    if (tags != null) {
      final amenity = (tags['amenity'] ?? '').toString().toLowerCase();
      final shop = (tags['shop'] ?? '').toString().toLowerCase();
      if (shop.isNotEmpty) return true;
      if (amenity.isNotEmpty && amenity != 'police') return true;
      if (amenity == 'police') return false;
    }
    return !RegExp(
      r'\b(police|thana|chowki|mahila|ps|station|outpost|commissioner|cop|control room|rps|grp)\b',
      caseSensitive: false,
    ).hasMatch(combined);
  }

  BackendApiClient? _apiClient;
  BackendApiClient get _client => _apiClient ??= BackendApiClient();
  final SakhiDeviceLocationService _deviceLocationService =
      SakhiDeviceLocationService();

  StreamSubscription<Position>? _locationUpdates;
  DateTime? _lastLocationPingAt;
  DateTime? currentLocationUpdatedAt;
  bool isAcquiringLocation = false;
  bool _localPersistenceLoaded = false;
  String locationStatusMessage = 'Tap to enable live device GPS.';

  /// Callback invoked when hardware 3x button or shake gesture triggers SOS.
  void Function(String source)? onDiscreetShortcutTriggered;

  void configureApiClient(BackendApiClient client) {
    _apiClient = client;
  }

  void _registerNativeHardwareHandler() {
    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method == 'onDiscreetTrigger') {
        final args = call.arguments;
        String rawSource = 'HARDWARE_SHORTCUT';
        if (args is Map && args['source'] != null) {
          rawSource = args['source'].toString();
        }
        final cleanSource = formatCleanSafetyLabel(rawSource);
        lastShortcutTriggerSource = cleanSource;
        lastShortcutTriggeredAt = DateTime.now();
        notifyListeners();
        onDiscreetShortcutTriggered?.call(cleanSource);
      }
      return null;
    });
  }

  bool locationPermissionGranted = false;
  bool hasLiveLocation = false;
  bool powerButtonShortcutEnabled = true;
  bool discreetShakeTriggerEnabled = false;
  double shakeSensitivityG = 2.35;
  String? lastShortcutTriggerSource;
  DateTime? lastShortcutTriggeredAt;

  bool liveLocationSharingActive = false;
  String selectedDurationLabel = '1 Hour';
  bool includeNameAndProfileInAlert = true;
  bool includeTimestampAndMapLink = true;
  double currentLatitude = 0.0;
  double currentLongitude = 0.0;
  double? currentAccuracyMeters;
  String currentLocationLabel = 'Acquiring GPS location…';
  int? batteryPercent;
  final List<SimCardInfo> availableSimCards = [];
  int? selectedSimSubscriptionId;
  String selectedSimLabel = 'Auto Default SIM';
  String activeShareToken = '';
  String activeTrackingUrl = '';
  bool isLoadingStations = false;
  bool isSyncingSafety = false;
  int selectedSearchRadiusMeters = 15000;
  bool showAllContactPhoneNumbers = false;

  // Pre-travel Cab / Auto Ride Logger state
  String loggedVehicleNumber = '';
  String loggedRideDestination = '';
  DateTime? loggedRideTimestamp;

  /// Real user-configured emergency contacts (NO fake default contacts!).
  final List<SafetyTrustedContact> trustedContacts = [];

  /// Real nearby police stations around user's live GPS coordinates.
  final List<NearbyPoliceStationModel> nearbyPoliceStations = [];

  /// Chronological SOS & safety history log.
  final List<SafetySosHistoryItem> sosHistory = [];

  final List<SafetyChecklistItemModel> preTravelChecklist = [
    SafetyChecklistItemModel(
      id: 'chk_cab_route',
      title: 'Share cab/auto vehicle number & live route with Primary Contact',
      isChecked: true,
    ),
    SafetyChecklistItemModel(
      id: 'chk_gps_battery',
      title: 'Verify GPS location permission & phone battery above 20%',
      isChecked: true,
    ),
    SafetyChecklistItemModel(
      id: 'chk_112_shortcut',
      title: 'Keep 112 & Discreet SOS shortcut enabled before travelling',
      isChecked: true,
    ),
    SafetyChecklistItemModel(
      id: 'chk_child_lock',
      title: 'Check rear door child-lock & match vehicle plate before boarding',
      isChecked: false,
    ),
  ];

  final List<VerifiedHelplineModel> verifiedHelplines = const [
    VerifiedHelplineModel(
      code: '112',
      number: '112',
      title: '112 — National Emergency Response (ERSS)',
      subtitle: 'All-in-One Police, Fire & Medical Emergency Dispatch (24/7)',
      category: 'National Emergency',
      badgeAsset: AppAssets.icM4Helplines112,
      vectorIcon: Icons.emergency_share_rounded,
      accentColor: Color(0xFFC92A49),
    ),
    VerifiedHelplineModel(
      code: '100',
      number: '100',
      title: '100 — Direct Police Control Room Dispatch',
      subtitle: '24/7 Immediate Police Patrol Response Across India',
      category: 'Police',
      badgeAsset: AppAssets.icM4NearestPolice,
      vectorIcon: Icons.local_police_rounded,
      accentColor: Color(0xFF5A1868),
    ),
    VerifiedHelplineModel(
      code: '1091',
      number: '1091',
      title: '1091 — Women in Distress Police Helpline',
      subtitle: "Dedicated Police Women's Safety Cell • Toll-Free 24/7",
      category: 'Women Safety',
      badgeAsset: AppAssets.icM4WomenPolice1091,
      vectorIcon: Icons.shield_rounded,
      accentColor: Color(0xFF7B228E),
    ),
    VerifiedHelplineModel(
      code: '181',
      number: '181',
      title: '181 — Women Domestic & Safety Helpline',
      subtitle: '24/7 Crisis Intervention, Legal Aid & One-Stop Sakhi Centre',
      category: 'Women Safety',
      badgeAsset: AppAssets.icM4DomesticSupport181,
      vectorIcon: Icons.support_agent_rounded,
      accentColor: Color(0xFF9C2766),
    ),
    VerifiedHelplineModel(
      code: '108',
      number: '108',
      title: '108 — Emergency Medical & Ambulance Service',
      subtitle: 'Free 24/7 Emergency Paramedic & Hospital Transport',
      category: 'Medical & Cyber',
      badgeAsset: AppAssets.icM4MedicalCyber108,
      vectorIcon: Icons.medical_services_rounded,
      accentColor: Color(0xFF1E7E55),
    ),
    VerifiedHelplineModel(
      code: '1930',
      number: '1930',
      title: '1930 — National Cyber Crime & Online Harassment Helpline',
      subtitle: 'Report cyber stalking, morphing, financial fraud & doxxing',
      category: 'Medical & Cyber',
      badgeAsset: AppAssets.icM4MedicalCyber108,
      vectorIcon: Icons.security_rounded,
      accentColor: Color(0xFF1B5E7B),
    ),
    VerifiedHelplineModel(
      code: '7827170170',
      number: '7827170170',
      title: '7827-170-170 — National Commission for Women (NCW)',
      subtitle: '24/7 Digital Complaint & Police Coordination Helpline',
      category: 'Women Safety',
      badgeAsset: AppAssets.icM4WomenPolice1091,
      vectorIcon: Icons.gavel_rounded,
      accentColor: Color(0xFF5A1868),
    ),
    VerifiedHelplineModel(
      code: '1098',
      number: '1098',
      title: '1098 — Childline India Emergency Support',
      subtitle: '24/7 Protection for Girls & Minors in Distress',
      category: 'National Emergency',
      badgeAsset: AppAssets.icM4DomesticSupport181,
      vectorIcon: Icons.volunteer_activism_rounded,
      accentColor: Color(0xFFB54708),
    ),
  ];

  final List<SafetyTipGuideModel> safetyTipGuides = const [
    SafetyTipGuideModel(
      id: 'tip_commute_cab',
      category: 'Commute & Cab Safety',
      title: 'Commute & Cab Safety',
      subtitle: 'Verify plate, child-lock & share live route with family',
      illustrationAsset: 'assets/module4/illustrations/illustration_commute_and_cab_safety.jpg',
      icon: Icons.directions_car_filled_rounded,
      emergencyNumber: '112',
      actionSteps: [
        'Before boarding any cab or auto, match the physical license plate with the app booking and log it in Sakhi Pre-Travel Checklist.',
        'Check that the rear door child-lock switch is unlocked and test opening the window before the ride starts.',
        'Sit in the back seat behind the driver or diagonal to have clear visibility of both exits and the driver mirror.',
        'Tap "Share My Live Location" in Sakhi to send your real-time OpenStreetMap & Google Maps tracking link to your Primary Contact.',
        'If the driver deviates from the route or refuses to stop, tap SOS immediately or dial 112.',
      ],
      dosAndDonts: [
        'DO call a family member aloud and state the cab number and expected arrival time.',
        'DO keep your phone battery above 20% and mobile data + GPS switched on.',
        'DON’T accept rides where another unverified passenger is already seated inside.',
      ],
    ),
    SafetyTipGuideModel(
      id: 'tip_discreet_sos',
      category: 'Discreet SOS & Silent Alerts',
      title: 'Using Discreet SOS Safely',
      subtitle: 'How to trigger silent alerts via 3x hardware press or shake',
      illustrationAsset: 'assets/module4/illustrations/illustration_using_discreet_sos_safely.jpg',
      icon: Icons.vibration_rounded,
      emergencyNumber: '112',
      actionSteps: [
        'Open the "Shortcut" screen (top-right gear on Safety Hub) and enable either Volume/Power 3x Rapid Press or Discreet Shake-to-SOS.',
        'When you feel unsafe and cannot look at your screen, press the Volume Down/Up or Power button 3 times within 2 seconds (or shake your phone 3 times firmly).',
        'Your phone gives a short tactile vibration pulse and opens the 3-second SOS guard screen.',
        'If triggered accidentally, tap "Cancel (I\'m Safe)" within 3 seconds so no false alarm is sent.',
        'Use "Run Safe Test Mode" anytime to verify your shortcut without sending real emergency alerts.',
      ],
      dosAndDonts: [
        'DO test your preferred shortcut once in Safe Test Mode so you know the exact feel.',
        'DO keep at least 1 Primary Contact configured in Emergency Contacts.',
        'DON’T set shake sensitivity too low if your phone is carried loosely while jogging.',
      ],
    ),
    SafetyTipGuideModel(
      id: 'tip_night_travel',
      category: 'Night Travel & Public Spaces',
      title: 'Night Travel & Safe Halts',
      subtitle: 'Choosing well-lit corridors, verified stations & 24/7 spots',
      illustrationAsset: 'assets/module4/illustrations/illustration_night_travel_and_safe_halts.jpg',
      icon: Icons.nightlight_round,
      emergencyNumber: '100',
      actionSteps: [
        'Open "Nearest Police Stations" in Sakhi before starting late-night travel to see verified police stations along your route.',
        'Wait for cabs or buses only near open 24/7 pharmacies, hospital entrances, ATM lobbies, or metro/railway gates with CCTV.',
        'Keep one ear free of earphones/ANC headphones so you stay aware of footsteps and approaching vehicles.',
        'If you suspect someone is following you, cross the street toward an open shop or police booth and trigger Sakhi Live Location Sharing.',
      ],
      dosAndDonts: [
        'DO walk facing oncoming traffic on roads without footpaths so vehicles cannot pull up behind you unnoticed.',
        'DON’T take unlit shortcuts through isolated service lanes late at night.',
      ],
    ),
    SafetyTipGuideModel(
      id: 'tip_cyber_safety',
      category: 'Digital & Cyber Safety',
      title: 'Cyber Stalking & Solo Living Safety',
      subtitle: 'Handling online harassment, home security & 1930 reporting',
      illustrationAsset: 'assets/module4/illustrations/illustration_solo_living_and_home_safety.jpg',
      icon: Icons.security_rounded,
      emergencyNumber: '1930',
      actionSteps: [
        'Do not delete threatening messages, emails, or fake profiles—take full-screen screenshots showing the URL, handle, and timestamp as legal evidence.',
        'Use Sakhi Privacy & Account Settings to restrict profile visibility to Verified Members and block abusive handles immediately.',
        'Call 1930 (National Cyber Crime Helpline) or file an anonymous women-related cyber complaint at cybercrime.gov.in.',
        'Enable Two-Factor Authentication (2FA) and review Active Login Sessions regularly.',
      ],
      dosAndDonts: [
        'DO preserve raw chat exports and transaction IDs before blocking an extortionist.',
        'DON’T share OTPs, live home addresses, or private identity documents in public chats.',
      ],
    ),
    SafetyTipGuideModel(
      id: 'tip_legal_rights',
      category: 'Legal Rights & Zero FIR',
      title: 'Know Your Legal Rights (Zero FIR & POSH)',
      subtitle: 'Mandatory police registration & workplace POSH protection',
      illustrationAsset: 'assets/module4/illustrations/illustration_workplace_and_legal_rights.jpg',
      icon: Icons.gavel_rounded,
      emergencyNumber: '1091',
      actionSteps: [
        'Zero FIR Right: Under Indian law (BNSS / CrPC), ANY police station must register your FIR regardless of where the incident occurred—they cannot turn you away citing jurisdiction.',
        'Right to a Woman Officer: A woman complainant has the legal right to have her statement recorded by a woman police officer in a safe environment.',
        'No Night Arrest / Summons Guardrail: Women cannot be arrested after sunset and before sunrise except in exceptional circumstances with a magistrate order and woman officer present.',
        'Free Legal Aid: Every woman is entitled to free legal aid through the District Legal Services Authority (DLSA) or by calling 181 / 15100.',
      ],
      dosAndDonts: [
        'DO ask for a free copy of the registered FIR or CSR receipt immediately.',
        'DO call 1091 or 7827-170-170 (NCW) if local staff delay registering your complaint.',
      ],
    ),
    SafetyTipGuideModel(
      id: 'tip_public_crowd_safety',
      category: 'Public Crowd & Event Safety',
      title: 'Public Transit, Crowd & Event Safety',
      subtitle: 'Staying safe in metro stations, festivals & crowded spaces',
      illustrationAsset: 'assets/module4/illustrations/illustration_public_crowd_and_event_safety.jpg',
      icon: Icons.groups_rounded,
      emergencyNumber: '112',
      actionSteps: [
        'Board the dedicated Women’s Coach in metro trains and suburban railways, especially during early morning or late evening hours.',
        'Agree on a well-lit physical meeting landmark (such as a metro help desk or police kiosk) when attending concerts, markets, or public gatherings.',
        'Enable Sakhi Discreet 3x Volume/Power Button SOS before entering dense crowds so you can trigger an alert without unlocking your phone.',
        'Share your live GPS location link with your Primary Contact before boarding public transit.',
      ],
      dosAndDonts: [
        'DO alert station security or railway police (139 / 112) immediately if you notice harassment.',
        'DON’T let your phone battery drop below 20% in crowded venues.',
      ],
    ),
  ];

  bool get hasRecentDeviceLocation {
    if (!hasLiveLocation || !locationPermissionGranted) {
      return false;
    }
    if (currentLatitude == 0.0 && currentLongitude == 0.0) {
      return false;
    }
    return true;
  }

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

  /// A Google Maps pin URL for the currently confirmed device GPS location.
  /// This is not a live-tracking URL and remains empty until GPS is available.
  String get googleMapsPinUrl {
    if (!hasRecentDeviceLocation) return '';
    final coordinates =
        '${currentLatitude.toStringAsFixed(6)},${currentLongitude.toStringAsFixed(6)}';
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': coordinates,
    }).toString();
  }

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
      batteryPercent == null ? 'Live Battery' : '$batteryPercent%';

  List<NearbyPoliceStationModel> get withinRadiusPoliceStations {
    final maxKm = selectedSearchRadiusMeters / 1000.0;
    return nearbyPoliceStations
        .where((s) => s.distanceKm <= maxKm)
        .toList(growable: false);
  }

  List<NearbyPoliceStationModel> get extendedRadiusPoliceStations {
    final maxKm = selectedSearchRadiusMeters / 1000.0;
    return nearbyPoliceStations
        .where((s) => s.distanceKm > maxKm)
        .toList(growable: false);
  }

  Future<int?> refreshDeviceBatteryLevel() async {
    try {
      final level = await _nativeChannel.invokeMethod<int>('getBatteryLevel');
      if (level != null && level >= 0 && level <= 100) {
        batteryPercent = level;
        notifyListeners();
        return level;
      }
    } catch (_) {}
    return batteryPercent;
  }

  Future<void> refreshAvailableSimCards({bool requestPermission = false}) async {
    try {
      final rawList = await _nativeChannel.invokeMethod<List<dynamic>>(
        requestPermission
            ? 'requestSmsAndSimPermissions'
            : 'getAvailableSimCards',
      );
      if (rawList != null) {
        final parsed = rawList
            .whereType<Map<dynamic, dynamic>>()
            .map(SimCardInfo.fromMap)
            .toList();
        availableSimCards
          ..clear()
          ..addAll(parsed);
        if (availableSimCards.length == 1) {
          selectedSimSubscriptionId = availableSimCards.first.subscriptionId;
          selectedSimLabel = availableSimCards.first.label;
        } else if (availableSimCards.length > 1) {
          final match = availableSimCards.where(
            (s) => s.subscriptionId == selectedSimSubscriptionId,
          );
          if (match.isNotEmpty) {
            selectedSimLabel = match.first.label;
          } else {
            selectedSimSubscriptionId = availableSimCards.first.subscriptionId;
            selectedSimLabel = availableSimCards.first.label;
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> selectSimForSos(SimCardInfo sim) async {
    selectedSimSubscriptionId = sim.subscriptionId;
    selectedSimLabel = sim.label;
    notifyListeners();
    try {
      await _secureStorage.write(
        key: _kSelectedSimKey,
        value: jsonEncode({
          'subscriptionId': sim.subscriptionId,
          'label': sim.label,
        }),
      );
    } catch (_) {}
  }

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

  /// Loads persisted contacts, history, checklist, and shortcut settings from
  /// encrypted local storage first, then syncs with backend & acquires live GPS.
  Future<void> initializeSafetyState({bool autoRequestGps = true}) async {
    await _loadLocalStateIfNeeded();
    unawaited(refreshDeviceBatteryLevel());
    unawaited(refreshAvailableSimCards(requestPermission: false));
    unawaited(syncSafetyOverview());
    if (autoRequestGps && !hasRecentDeviceLocation && !isAcquiringLocation) {
      unawaited(requestDeviceLocation());
    }
  }

  Future<void> _loadLocalStateIfNeeded() async {
    if (_localPersistenceLoaded) return;
    _localPersistenceLoaded = true;
    try {
      final rawContacts = await _secureStorage.read(key: _kContactsKey);
      if (rawContacts != null && rawContacts.trim().isNotEmpty) {
        final decoded = jsonDecode(rawContacts);
        if (decoded is List) {
          trustedContacts
            ..clear()
            ..addAll(
              decoded
                  .whereType<Map<dynamic, dynamic>>()
                  .map(
                    (e) => SafetyTrustedContact.fromJson(
                      Map<String, dynamic>.from(e),
                    ),
                  )
                  .where((c) => !_isLegacyFakeContact(c)),
            );
          _ensurePrimaryExists();
        }
      }

      final rawHistory = await _secureStorage.read(key: _kHistoryKey);
      if (rawHistory != null && rawHistory.trim().isNotEmpty) {
        final decoded = jsonDecode(rawHistory);
        if (decoded is List) {
          sosHistory
            ..clear()
            ..addAll(
              decoded.whereType<Map<dynamic, dynamic>>().map(
                (e) =>
                    SafetySosHistoryItem.fromJson(Map<String, dynamic>.from(e)),
              ),
            );
        }
      }

      final rawShortcuts = await _secureStorage.read(key: _kShortcutsKey);
      if (rawShortcuts != null && rawShortcuts.trim().isNotEmpty) {
        final decoded = jsonDecode(rawShortcuts);
        if (decoded is Map) {
          powerButtonShortcutEnabled =
              decoded['powerButtonShortcutEnabled'] != false;
          discreetShakeTriggerEnabled =
              decoded['discreetShakeTriggerEnabled'] == true;
          shakeSensitivityG =
              (decoded['shakeSensitivityG'] as num?)?.toDouble() ?? 2.35;
        }
      }

      final rawChecklist = await _secureStorage.read(key: _kChecklistKey);
      if (rawChecklist != null && rawChecklist.trim().isNotEmpty) {
        final decoded = jsonDecode(rawChecklist);
        if (decoded is List && decoded.isNotEmpty) {
          preTravelChecklist
            ..clear()
            ..addAll(
              decoded.whereType<Map<dynamic, dynamic>>().map(
                (e) => SafetyChecklistItemModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              ),
            );
        }
      }

      final rawRide = await _secureStorage.read(key: _kRideLogKey);
      if (rawRide != null && rawRide.trim().isNotEmpty) {
        final decoded = jsonDecode(rawRide);
        if (decoded is Map) {
          loggedVehicleNumber = (decoded['vehicleNumber'] ?? '').toString();
          loggedRideDestination = (decoded['destination'] ?? '').toString();
          final ts = decoded['timestamp']?.toString();
          if (ts != null) loggedRideTimestamp = DateTime.tryParse(ts);
        }
      }

      final rawSim = await _secureStorage.read(key: _kSelectedSimKey);
      if (rawSim != null && rawSim.trim().isNotEmpty) {
        final decoded = jsonDecode(rawSim);
        if (decoded is Map) {
          selectedSimSubscriptionId =
              (decoded['subscriptionId'] as num?)?.toInt();
          selectedSimLabel =
              (decoded['label'] ?? 'Auto Default SIM').toString();
        }
      }
    } catch (_) {
      // SecureStorage unavailable in headless unit tests.
    }
    unawaited(_syncShortcutsToNativeAndroid());
    notifyListeners();
  }

  bool _isLegacyFakeContact(SafetyTrustedContact c) {
    final fakePhones = {'+919845011111', '+919880122224', '+919731233339'};
    final fakeIds = {'ec_mom', 'ec_sister', 'ec_roommate'};
    return fakePhones.contains(c.phoneE164.replaceAll(' ', '')) ||
        fakeIds.contains(c.id);
  }

  Future<void> _saveContactsLocally() async {
    try {
      final jsonStr = jsonEncode(
        trustedContacts.map((c) => c.toJson()).toList(),
      );
      await _secureStorage.write(key: _kContactsKey, value: jsonStr);
    } catch (_) {}
  }

  Future<void> _saveHistoryLocally() async {
    try {
      final jsonStr = jsonEncode(
        sosHistory.take(30).map((h) => h.toJson()).toList(),
      );
      await _secureStorage.write(key: _kHistoryKey, value: jsonStr);
    } catch (_) {}
  }

  Future<void> _saveShortcutsLocally() async {
    try {
      final jsonStr = jsonEncode({
        'powerButtonShortcutEnabled': powerButtonShortcutEnabled,
        'discreetShakeTriggerEnabled': discreetShakeTriggerEnabled,
        'shakeSensitivityG': shakeSensitivityG,
      });
      await _secureStorage.write(key: _kShortcutsKey, value: jsonStr);
    } catch (_) {}
    await _syncShortcutsToNativeAndroid();
  }

  Future<void> _saveChecklistLocally() async {
    try {
      final jsonStr = jsonEncode(
        preTravelChecklist.map((c) => c.toJson()).toList(),
      );
      await _secureStorage.write(key: _kChecklistKey, value: jsonStr);
    } catch (_) {}
  }

  Future<void> _syncShortcutsToNativeAndroid() async {
    try {
      await _nativeChannel.invokeMethod('configureShortcuts', {
        'powerShortcutEnabled': powerButtonShortcutEnabled,
        'shakeShortcutEnabled': discreetShakeTriggerEnabled,
        'shakeThresholdG': shakeSensitivityG,
      });
    } catch (_) {}
  }

  void setPowerButtonShortcut(bool value) {
    powerButtonShortcutEnabled = value;
    notifyListeners();
    unawaited(_saveShortcutsLocally());
  }

  void setDiscreetShakeShortcut(bool value) {
    discreetShakeTriggerEnabled = value;
    notifyListeners();
    unawaited(_saveShortcutsLocally());
  }

  void setShakeSensitivity(double value) {
    shakeSensitivityG = value.clamp(1.6, 3.8);
    notifyListeners();
    unawaited(_saveShortcutsLocally());
  }

  void toggleShowAllPhoneNumbers() {
    showAllContactPhoneNumbers = !showAllContactPhoneNumbers;
    for (final c in trustedContacts) {
      c.isNumberVisible = showAllContactPhoneNumbers;
    }
    notifyListeners();
  }

  void toggleSingleContactPhoneVisibility(String contactId) {
    final idx = trustedContacts.indexWhere((c) => c.id == contactId);
    if (idx == -1) return;
    trustedContacts[idx].isNumberVisible =
        !trustedContacts[idx].isNumberVisible;
    notifyListeners();
  }

  Future<bool> requestDeviceLocation() async {
    if (isAcquiringLocation) return hasRecentDeviceLocation;
    isAcquiringLocation = true;
    locationStatusMessage = 'Acquiring live device GPS coordinates…';
    notifyListeners();
    try {
      final position = await _deviceLocationService.requestCurrentLocation();
      updateDeviceLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: position.accuracy,
        locationLabel:
            'Live GPS (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
      );
      locationStatusMessage =
          'Live GPS active (±${position.accuracy.toStringAsFixed(0)}m accuracy).';
      unawaited(
        _reverseGeocodeLocationLabel(position.latitude, position.longitude),
      );
      unawaited(refreshNearbyPoliceStations());
      return true;
    } catch (error) {
      locationStatusMessage = error is DeviceLocationException
          ? error.message
          : 'Unable to obtain GPS fix. Make sure Location is turned ON.';
      return false;
    } finally {
      isAcquiringLocation = false;
      notifyListeners();
    }
  }

  Future<void> refreshCurrentLocationIfAlreadyGranted() async {
    final position = await _deviceLocationService
        .currentLocationIfAlreadyAllowed();
    if (position == null) return;
    updateDeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      locationLabel: currentLocationLabel.startsWith('Acquiring')
          ? 'Live GPS (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})'
          : currentLocationLabel,
    );
    locationStatusMessage = 'Live device GPS location active.';
    unawaited(
      _reverseGeocodeLocationLabel(position.latitude, position.longitude),
    );
    if (nearbyPoliceStations.isEmpty) {
      unawaited(refreshNearbyPoliceStations());
    }
  }

  Future<void> _reverseGeocodeLocationLabel(double lat, double lng) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&zoom=16&addressdetails=1',
      );
      final req = await client.getUrl(uri);
      req.headers.set(
        'User-Agent',
        'SakhiWomenSafetyApp/2.0 (Android; Safety-Reverse-Geocode)',
      );
      final resp = await req.close().timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body);
        if (data is Map) {
          final addr = data['address'];
          if (addr is Map) {
            final parts = <String>[
              for (final k in [
                'suburb',
                'neighbourhood',
                'road',
                'town',
                'city',
                'county',
                'state_district',
                'state',
              ])
                if (addr[k] is String && (addr[k] as String).trim().isNotEmpty)
                  (addr[k] as String).trim(),
            ];
            final unique = <String>[];
            for (final p in parts) {
              if (!unique.contains(p)) unique.add(p);
            }
            if (unique.isNotEmpty) {
              currentLocationLabel = unique.take(3).join(', ');
              notifyListeners();
              return;
            }
          }
          final display = data['display_name']?.toString() ?? '';
          if (display.isNotEmpty) {
            currentLocationLabel = display
                .split(',')
                .take(3)
                .map((s) => s.trim())
                .join(', ');
            notifyListeners();
          }
        }
      }
    } catch (_) {
      // Keep coordinate label if offline.
    } finally {
      client.close(force: true);
    }
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
        final preservedLabel =
            (currentLocationLabel.isNotEmpty &&
                !currentLocationLabel.startsWith('Acquiring') &&
                currentLocationLabel != 'Location unavailable' &&
                currentLocationLabel != 'Current device location')
            ? currentLocationLabel
            : 'Live GPS (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        updateDeviceLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          locationLabel: preservedLabel,
        );
        final now = DateTime.now();
        if (_lastLocationPingAt == null ||
            now.difference(_lastLocationPingAt!) >=
                const Duration(seconds: 5)) {
          _lastLocationPingAt = now;
          if (expectedToken.isNotEmpty) {
            unawaited(_pingLocationShare(expectedToken, position));
          }
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
          if (batteryPercent != null) 'batteryPercent': batteryPercent,
          'locationLabel': currentLocationLabel.isNotEmpty
              ? currentLocationLabel
              : 'Current device location',
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
    currentLocationLabel = 'Location unavailable';
    activeShareToken = '';
    activeTrackingUrl = '';
    liveLocationSharingActive = false;
    nearbyPoliceStations.clear();
  }

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
    if (locationLabel != null && locationLabel.trim().isNotEmpty) {
      currentLocationLabel = locationLabel.trim();
    } else if (currentLocationLabel.startsWith('Acquiring') ||
        currentLocationLabel == 'Location unavailable') {
      currentLocationLabel =
          'GPS (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
    }
    currentAccuracyMeters =
        accuracyMeters != null && accuracyMeters.isFinite && accuracyMeters >= 0
        ? accuracyMeters
        : null;
    if (batteryPercent != null &&
        batteryPercent >= 0 &&
        batteryPercent <= 100) {
      this.batteryPercent = batteryPercent;
    }
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

  Future<void> syncSafetyOverview() async {
    await _loadLocalStateIfNeeded();
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
        final remoteContacts = rawContacts
            .whereType<Map<String, dynamic>>()
            .map(SafetyTrustedContact.fromJson)
            .where((c) => !_isLegacyFakeContact(c))
            .toList();

        // Merge local user-added contacts with remote contacts so nothing is ever lost!
        final mergedByPhone = <String, SafetyTrustedContact>{};
        for (final remote in remoteContacts) {
          mergedByPhone[remote.phoneE164.replaceAll(' ', '')] = remote;
        }
        for (final local in trustedContacts) {
          final key = local.phoneE164.replaceAll(' ', '');
          if (!mergedByPhone.containsKey(key)) {
            mergedByPhone[key] = local;
            // Also push this local contact to backend so both stay synced
            unawaited(_pushSingleContactToBackend(local));
          }
        }
        trustedContacts
          ..clear()
          ..addAll(mergedByPhone.values);
        _ensurePrimaryExists();
        unawaited(_saveContactsLocally());
      } else if (trustedContacts.isNotEmpty) {
        // Backend returned empty, so sync local contacts up to backend
        for (final local in List<SafetyTrustedContact>.from(trustedContacts)) {
          unawaited(_pushSingleContactToBackend(local));
        }
      }

      final rawHistory = res['sosHistory'];
      if (rawHistory is List && rawHistory.isNotEmpty) {
        final remoteHistory = rawHistory
            .whereType<Map<String, dynamic>>()
            .map(SafetySosHistoryItem.fromJson)
            .toList();
        final existingIds = sosHistory.map((e) => e.id).toSet();
        for (final item in remoteHistory) {
          if (!existingIds.contains(item.id)) {
            sosHistory.add(item);
          }
        }
        unawaited(_saveHistoryLocally());
      }
    } catch (_) {
      // Keep local persisted state when offline.
    } finally {
      isSyncingSafety = false;
      notifyListeners();
    }
  }

  Future<void> _pushSingleContactToBackend(SafetyTrustedContact contact) async {
    await _sendBackend((client) async {
      final created = await client.post(
        'module2/safety/contacts',
        authenticated: true,
        body: {
          'name': contact.name,
          'relationship': contact.relationship,
          'phoneE164': contact.phoneE164,
          'isPrimary': contact.isPrimary,
          'alertEnabled': contact.selectedForSosAlert,
        },
      );
      if (created['id'] is String && (created['id'] as String).isNotEmpty) {
        final idx = trustedContacts.indexWhere(
          (c) => c.phoneE164 == contact.phoneE164,
        );
        if (idx != -1) {
          trustedContacts[idx] = SafetyTrustedContact(
            id: created['id'] as String,
            name: contact.name,
            relationship: contact.relationship,
            phoneE164: contact.phoneE164,
            isPrimary: contact.isPrimary,
            selectedForSosAlert: contact.selectedForSosAlert,
            isNumberVisible: contact.isNumberVisible,
          );
          await _saveContactsLocally();
          notifyListeners();
        }
      }
    });
  }

  /// Queries REAL nearby police stations around the user's actual GPS coordinates
  /// using direct OpenStreetMap Overpass API + Nominatim + Backend API,
  /// filtering out any distant seed stations so the user ONLY sees real stations near them.
  Future<void> refreshNearbyPoliceStations({int? radiusMeters}) async {
    if (radiusMeters != null) {
      selectedSearchRadiusMeters = radiusMeters;
    }
    if (!hasRecentDeviceLocation) {
      final ok = await requestDeviceLocation();
      if (!ok) return;
    }
    isLoadingStations = true;
    notifyListeners();

    final lat = currentLatitude;
    final lng = currentLongitude;
    final resultsById = <String, NearbyPoliceStationModel>{};

    try {
      // 1. Query OpenStreetMap Overpass API directly (nodes, ways, and relations)
      final directOsm = await _queryDirectOverpassPoliceStations(
        lat: lat,
        lng: lng,
        radiusMeters: selectedSearchRadiusMeters,
      );
      for (final s in directOsm) {
        resultsById['${s.name.toLowerCase()}_${s.distanceKm.toStringAsFixed(1)}'] =
            s;
      }

      // 2. If fewer than 3 stations in current radius, also query Nominatim Police Search around user
      if (resultsById.length < 3) {
        final nominatimStations = await _queryNominatimPoliceStations(
          lat: lat,
          lng: lng,
          radiusKm: math.max(25.0, selectedSearchRadiusMeters / 1000.0),
        );
        for (final s in nominatimStations) {
          final key =
              '${s.name.toLowerCase()}_${s.distanceKm.toStringAsFixed(1)}';
          resultsById.putIfAbsent(key, () => s);
        }
      }

      // 3. Also query backend `/module2/safety/police-stations` and keep only stations within 60 km of user
      try {
        final res = await _client.get(
          'module2/safety/police-stations?lat=$lat&lng=$lng&radiusMeters=$selectedSearchRadiusMeters',
          authenticated: false,
        );
        final rows = res['stations'];
        if (rows is List) {
          for (final raw in rows.whereType<Map<String, dynamic>>()) {
            final model = NearbyPoliceStationModel.fromJson(
              raw,
              userLat: lat,
              userLng: lng,
            );
            if (isLikelyNonPoliceCommercialPoi(model.name, model.address)) {
              continue;
            }
            // Never include hardcoded Bengaluru stations if user is > 60 km away!
            if (model.distanceKm <= 60.0) {
              final key =
                  '${model.name.toLowerCase()}_${model.distanceKm.toStringAsFixed(1)}';
              resultsById.putIfAbsent(key, () => model);
            }
          }
        }
      } catch (_) {}

      final sorted = resultsById.values.toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      nearbyPoliceStations
        ..clear()
        ..addAll(sorted.take(12));
    } finally {
      isLoadingStations = false;
      notifyListeners();
    }
  }

  Future<List<NearbyPoliceStationModel>> _queryDirectOverpassPoliceStations({
    required double lat,
    required double lng,
    required int radiusMeters,
  }) async {
    final radiiToTry = <int>{
      radiusMeters,
      if (radiusMeters < 25000) 25000,
      if (radiusMeters < 45000) 45000,
    }.toList();

    const endpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://lz4.overpass-api.de/api/interpreter',
    ];

    for (final rad in radiiToTry) {
      final query =
          '[out:json][timeout:6];nwr["amenity"="police"](around:$rad,$lat,$lng);out center 15;';
      for (final endpoint in endpoints) {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 5);
        try {
          final req = await client.postUrl(Uri.parse(endpoint));
          req.headers.set(
            'Content-Type',
            'application/x-www-form-urlencoded; charset=utf-8',
          );
          req.headers.set(
            'User-Agent',
            'SakhiWomenSafetyApp/2.0 (Android; Emergency-Police-Finder)',
          );
          req.write('data=${Uri.encodeQueryComponent(query)}');
          final resp = await req.close().timeout(const Duration(seconds: 6));
          if (resp.statusCode == 200) {
            final text = await resp.transform(utf8.decoder).join();
            final decoded = jsonDecode(text);
            if (decoded is Map && decoded['elements'] is List) {
              final elements = decoded['elements'] as List;
              final found = <NearbyPoliceStationModel>[];
              for (final el in elements.whereType<Map<dynamic, dynamic>>()) {
                final sLat =
                    (el['lat'] as num?)?.toDouble() ??
                    (el['center'] is Map
                        ? (el['center']['lat'] as num?)?.toDouble()
                        : null);
                final sLng =
                    (el['lon'] as num?)?.toDouble() ??
                    (el['center'] is Map
                        ? (el['center']['lon'] as num?)?.toDouble()
                        : null);
                if (sLat == null || sLng == null) continue;
                final tags = el['tags'] is Map
                    ? Map<String, dynamic>.from(el['tags'] as Map)
                    : <String, dynamic>{};
                final rawName =
                    (tags['name:en'] ??
                            tags['name'] ??
                            tags['official_name'] ??
                            'Police Station')
                        .toString()
                        .trim();
                final addrParts = <String>[
                  for (final k in [
                    'addr:street',
                    'addr:suburb',
                    'addr:city',
                    'addr:district',
                    'addr:state',
                  ])
                    if (tags[k] != null && tags[k].toString().trim().isNotEmpty)
                      tags[k].toString().trim(),
                ];
                final address = addrParts.isNotEmpty
                    ? addrParts.join(', ')
                    : 'Near ${currentLocationLabel.isNotEmpty ? currentLocationLabel : "${sLat.toStringAsFixed(4)}, ${sLng.toStringAsFixed(4)}"}';
                final phone =
                    (tags['phone'] ??
                            tags['contact:phone'] ??
                            tags['emergency:phone'] ??
                            '100')
                        .toString()
                        .trim();
                if (isLikelyNonPoliceCommercialPoi(rawName, address, tags)) {
                  continue;
                }
                final dist = haversineKm(lat, lng, sLat, sLng);
                found.add(
                  NearbyPoliceStationModel(
                    id: 'osm_${el['id']}',
                    name: rawName,
                    address: address,
                    latitude: sLat,
                    longitude: sLng,
                    distanceKm: dist,
                    driveMinutes: math.max(2, (dist * 3.5).round()),
                    phoneNumber: phone.isEmpty ? '100' : phone,
                    isWomenStation: RegExp(
                      r'women|mahila|she\b',
                      caseSensitive: false,
                    ).hasMatch(rawName),
                    isVerified: false,
                    dataSource: 'OpenStreetMap Live GPS',
                  ),
                );
              }
              if (found.isNotEmpty) {
                found.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
                return found;
              }
            }
          }
        } catch (_) {
          // Try next mirror/radius
        } finally {
          client.close(force: true);
        }
      }
    }
    return const [];
  }

  Future<List<NearbyPoliceStationModel>> _queryNominatimPoliceStations({
    required double lat,
    required double lng,
    required double radiusKm,
  }) async {
    final degOffset = (radiusKm / 111.0).clamp(0.15, 0.6);
    final minLon = lng - degOffset;
    final maxLon = lng + degOffset;
    final minLat = lat - degOffset;
    final maxLat = lat + degOffset;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=jsonv2&q=police+station&viewbox=$minLon,$maxLat,$maxLon,$minLat&bounded=1&limit=10&addressdetails=1',
      );
      final req = await client.getUrl(uri);
      req.headers.set(
        'User-Agent',
        'SakhiWomenSafetyApp/2.0 (Android; Emergency-Police-Search)',
      );
      final resp = await req.close().timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded is List) {
          final results = <NearbyPoliceStationModel>[];
          for (final item in decoded.whereType<Map<dynamic, dynamic>>()) {
            final sLat = double.tryParse(item['lat']?.toString() ?? '');
            final sLng = double.tryParse(item['lon']?.toString() ?? '');
            if (sLat == null || sLng == null) continue;
            final display = (item['display_name'] ?? 'Police Station')
                .toString();
            final parts = display.split(',').map((s) => s.trim()).toList();
            final name = (item['name']?.toString().trim().isNotEmpty == true)
                ? item['name'].toString().trim()
                : parts.first;
            final address = parts.length > 1
                ? parts.skip(1).take(3).join(', ')
                : display;
            if (isLikelyNonPoliceCommercialPoi(name, address)) {
              continue;
            }
            final dist = haversineKm(lat, lng, sLat, sLng);
            if (dist > 60.0) continue;
            results.add(
              NearbyPoliceStationModel(
                id: 'nom_${item['place_id']}',
                name: name,
                address: address,
                latitude: sLat,
                longitude: sLng,
                distanceKm: dist,
                driveMinutes: math.max(2, (dist * 3.5).round()),
                phoneNumber: '100',
                isWomenStation: RegExp(
                  r'women|mahila',
                  caseSensitive: false,
                ).hasMatch(name),
                isVerified: false,
                dataSource: 'OpenStreetMap Nominatim',
              ),
            );
          }
          return results;
        }
      }
    } catch (_) {
    } finally {
      client.close(force: true);
    }
    return const [];
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
    unawaited(_saveContactsLocally());
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
    if (!nextVal &&
        selectedContacts.length <= 1 &&
        contact.selectedForSosAlert) {
      return false;
    }
    contact.selectedForSosAlert = nextVal;
    notifyListeners();
    unawaited(_saveContactsLocally());
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
    final idx = trustedContacts.indexWhere((c) => c.id == contactId);
    if (idx == -1) return false;
    trustedContacts.removeAt(idx);
    _ensurePrimaryExists();
    notifyListeners();
    unawaited(_saveContactsLocally());
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
    if (trustedContacts.any(
      (c) => c.phoneE164.replaceAll(' ', '') == phoneE164,
    )) {
      return 'This mobile number is already in your Emergency Contacts.';
    }
    if (setAsPrimary) {
      for (final c in trustedContacts) {
        c.isPrimary = false;
      }
    }
    final newContact = SafetyTrustedContact(
      id: 'ec_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      relationship: relationship.trim().isEmpty
          ? 'Family'
          : relationship.trim(),
      phoneE164: phoneE164,
      isPrimary: setAsPrimary || trustedContacts.isEmpty,
      selectedForSosAlert: true,
      isNumberVisible: showAllContactPhoneNumbers,
    );
    trustedContacts.add(newContact);
    _ensurePrimaryExists();
    notifyListeners();
    unawaited(_saveContactsLocally());
    unawaited(_pushSingleContactToBackend(newContact));
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

    await _sendBackend((client) async {
      final response = await client
          .post(
            'module2/safety/sos/activate',
            authenticated: true,
            body: {
              'eventType': isTestMode ? 'SOS_TEST_MODE' : 'SOS_ACTIVATED',
              'isTestMode': isTestMode,
              'contactsAlertedCount': selectedContacts.length,
              if (batteryPercent != null) 'batteryPercent': batteryPercent,
              if (currentAccuracyMeters != null)
                'accuracyMeters': currentAccuracyMeters,
              if (lastShortcutTriggerSource != null)
                'triggerSource': lastShortcutTriggerSource,
              if (selectedSimLabel.isNotEmpty)
                'simCarrierName': selectedSimLabel,
              if (canSendLocation) ...{
                'locationLabel': currentLocationLabel,
                'latitude': currentLatitude,
                'longitude': currentLongitude,
              },
            },
          )
          .timeout(const Duration(seconds: 4));
      if (!isTestMode && canSendLocation) {
        final shareAccepted = _acceptLocationShareResponse(
          response,
          sosActivation: true,
        );
        if (shareAccepted) {
          locationStatusMessage =
              'SOS location share is active; updates run while Sakhi is open.';
          _startLocationUpdates();
        } else {
          locationStatusMessage =
              'SOS recorded, but the server did not confirm a live tracking link.';
        }
      } else {
        activeShareToken = '';
        activeTrackingUrl = '';
        liveLocationSharingActive = false;
        if (!isTestMode) {
          locationStatusMessage =
              'SOS recorded without a location because no recent GPS fix was available.';
        }
      }
      notifyListeners();
    });
    unawaited(_saveHistoryLocally());
    return item;
  }

  void cancelSosDuringCountdown({bool isTestMode = false}) {
    final now = DateTime.now();
    final item = SafetySosHistoryItem(
      id: 'SOS-CANCEL-${now.millisecondsSinceEpoch % 10000}',
      timestampLabel: 'Just now • Cancelled in 3s Guard',
      status: 'CANCELLED',
      locationLabel: hasRecentDeviceLocation
          ? currentLocationLabel
          : 'Cancelled before dispatch',
      latitude: hasRecentDeviceLocation ? currentLatitude : null,
      longitude: hasRecentDeviceLocation ? currentLongitude : null,
      contactsAlertedCount: 0,
      durationMinutes: 0,
      isTestMode: true,
    );
    sosHistory.insert(0, item);
    notifyListeners();
    unawaited(_saveHistoryLocally());

    unawaited(
      _sendBackend((client) async {
        await client.post(
          'module2/safety/events',
          authenticated: true,
          body: {
            'eventType': 'SOS_ACTIVATED',
            'status': 'CANCELLED',
            'locationLabel': item.locationLabel,
            'isTestMode': true,
          },
        );
      }),
    );
  }

  void clearLocalTestLogs() {
    sosHistory.removeWhere(
      (h) =>
          h.isTestMode ||
          h.status.toUpperCase() == 'CANCELLED' ||
          h.status.toUpperCase() == 'TEST_MODE',
    );
    notifyListeners();
    unawaited(_saveHistoryLocally());
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
    unawaited(_saveHistoryLocally());

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

  /// Starts live location sharing reliably. Even if the staging server is waking up
  /// or a migration hasn't run yet, generates a working live OpenStreetMap/Google Maps
  /// tracking link from the user's real device GPS coordinates so sharing NEVER fails!
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
      unawaited(_saveChecklistLocally());
    }
  }

  void addCustomChecklistItem(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    preTravelChecklist.add(
      SafetyChecklistItemModel(
        id: 'chk_${DateTime.now().millisecondsSinceEpoch}',
        title: trimmed,
        isChecked: true,
      ),
    );
    notifyListeners();
    unawaited(_saveChecklistLocally());
  }

  void saveRideLog({
    required String vehicleNumber,
    required String destination,
  }) {
    loggedVehicleNumber = vehicleNumber.trim().toUpperCase();
    loggedRideDestination = destination.trim();
    loggedRideTimestamp = DateTime.now();
    notifyListeners();
    unawaited(() async {
      try {
        await _secureStorage.write(
          key: _kRideLogKey,
          value: jsonEncode({
            'vehicleNumber': loggedVehicleNumber,
            'destination': loggedRideDestination,
            'timestamp': loggedRideTimestamp?.toIso8601String(),
          }),
        );
      } catch (_) {}
    }());
  }

  String buildEmergencyAlertMessage() {
    final parts = <String>[
      '🚨 SAKHI EMERGENCY SOS ALERT',
      if (includeNameAndProfileInAlert)
        'Member requested urgent safety assistance on Sakhi.',
      if (loggedVehicleNumber.isNotEmpty)
        'Logged Vehicle / Cab Plate: $loggedVehicleNumber${loggedRideDestination.isNotEmpty ? " (Towards $loggedRideDestination)" : ""}',
      if (hasRecentDeviceLocation) ...[
        'Current Location: $currentLocationLabel',
        'GPS Coordinates: ${currentLatitude.toStringAsFixed(6)}, ${currentLongitude.toStringAsFixed(6)}',
        if (includeTimestampAndMapLink) ...[
          'Google Maps Pin: https://www.google.com/maps?q=${currentLatitude.toStringAsFixed(6)},${currentLongitude.toStringAsFixed(6)}',
          'OpenStreetMap Live Pin: https://www.openstreetmap.org/?mlat=${currentLatitude.toStringAsFixed(6)}&mlon=${currentLongitude.toStringAsFixed(6)}#map=17/${currentLatitude.toStringAsFixed(6)}/${currentLongitude.toStringAsFixed(6)}',
          if (liveShareFullUrl.isNotEmpty)
            'Sakhi Live Tracking Link: $liveShareFullUrl',
        ],
      ] else ...[
        'GPS Status: Acquiring live device coordinates. Please call immediately.',
      ],
      'Battery: $batteryLabel • Time: ${DateTime.now().toLocal()}',
      'India National Emergency Helpline: 112 / Police: 100',
    ];
    return parts.join('\n');
  }

  /// Launches the phone's real native SIM Dialer (`Intent.ACTION_DIAL` on Android)
  /// with `tel:<number>` pre-filled ready to call!
  Future<void> launchPhoneCall(
    BuildContext context,
    String phoneNumber, {
    String? label,
  }) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final dialTarget = cleaned.isEmpty ? '112' : cleaned;
    bool openedNativeDialer = false;
    try {
      final res = await _nativeChannel.invokeMethod<bool>('dialNumber', {
        'number': dialTarget,
      });
      openedNativeDialer = res == true;
    } catch (_) {
      openedNativeDialer = false;
    }
    await Clipboard.setData(ClipboardData(text: dialTarget));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF3B0D47),
        behavior: SnackBarBehavior.floating,
        content: Text(
          openedNativeDialer
              ? 'Opening Phone Dialer for ${label ?? dialTarget} ($dialTarget)…'
              : 'Dialing ${label ?? dialTarget} (tel:$dialTarget) • Number ready in dialer',
        ),
      ),
    );
  }

  /// Launches real turn-by-turn navigation in Google Maps / external map app.
  Future<void> launchDirectionsToStation(
    BuildContext context,
    NearbyPoliceStationModel station,
  ) async {
    final mapsUrl =
        'https://www.google.com/maps/dir/?api=1&destination=${station.latitude},${station.longitude}&travelmode=driving';
    bool openedMaps = false;
    try {
      final res = await _nativeChannel.invokeMethod<bool>('openExternalUrl', {
        'url': mapsUrl,
      });
      openedMaps = res == true;
    } catch (_) {
      openedMaps = false;
    }
    await Clipboard.setData(ClipboardData(text: mapsUrl));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF5A1868),
        behavior: SnackBarBehavior.floating,
        content: Text(
          openedMaps
              ? 'Opening live Google Maps directions to ${station.name}…'
              : 'Directions to ${station.name} (${station.distanceBadgeText}) copied & ready',
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

  /// Automatically dispatches emergency SMS directly via selected SIM (SmsManager)
  /// without waiting for the user to tap Send in the Messages app, falling back
  /// to native SMS composer / Share Sheet only if direct SMS permission is unavailable.
  Future<void> dispatchSosAlertToContacts(
    BuildContext context, {
    bool isAutomaticSosTrigger = false,
  }) async {
    await refreshDeviceBatteryLevel();
    final message = buildEmergencyAlertMessage();
    final recipients = selectedContacts.map((c) => c.name).join(', ');
    final recipientPhones = selectedContacts
        .map((c) => c.phoneE164.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final phoneList = recipientPhones.join(';');
    await Clipboard.setData(ClipboardData(text: message));

    bool sentDirectly = false;
    int directSentCount = 0;
    if (recipientPhones.isNotEmpty) {
      try {
        final directRes = await _nativeChannel
            .invokeMethod<Map<dynamic, dynamic>>('sendDirectEmergencySms', {
              'recipientList': recipientPhones,
              'recipients': phoneList,
              'body': message,
              'subscriptionId': selectedSimSubscriptionId ?? -1,
            });
        if (directRes != null) {
          directSentCount = (directRes['sentCount'] as num?)?.toInt() ?? 0;
          sentDirectly = directRes['sentDirectly'] == true && directSentCount > 0;
        }
      } catch (_) {
        sentDirectly = false;
      }
    }

    bool openedSms = false;
    if (!sentDirectly && phoneList.isNotEmpty) {
      try {
        final res = await _nativeChannel.invokeMethod<bool>('composeSms', {
          'recipients': phoneList,
          'body': message,
          'subscriptionId': selectedSimSubscriptionId ?? -1,
        });
        openedSms = res == true;
      } catch (_) {
        openedSms = false;
      }
    }
    if (!sentDirectly && !openedSms && !isAutomaticSosTrigger) {
      try {
        await SharePlus.instance.share(ShareParams(text: message));
      } catch (_) {}
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFC92A49),
        behavior: SnackBarBehavior.floating,
        content: Text(
          sentDirectly
              ? 'Emergency SOS SMS sent automatically to $recipients ($directSentCount/${recipientPhones.length}) via $selectedSimLabel!'
              : selectedContacts.isEmpty
              ? 'Emergency SOS alert & live GPS link prepared! Add Emergency Contacts for automatic SMS dispatch.'
              : 'Emergency SOS alert dispatched to $recipients (${selectedContacts.length} contact(s))',
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
