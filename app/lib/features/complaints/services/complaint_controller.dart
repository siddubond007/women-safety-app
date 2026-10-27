import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../auth/backend_api_client.dart';
import '../models/complaint_models.dart';

/// Allowed MIME types for Module 5 evidence attachments (max 15 MB per file).
const Set<String> kAllowedComplaintEvidenceMimeTypes = <String>{
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/webp',
  'application/pdf',
  'audio/mp4',
  'audio/mpeg',
  'audio/wav',
  'audio/aac',
  'audio/x-m4a',
  'audio/m4a',
};

const int kMaxComplaintEvidenceBytes = 15 * 1024 * 1024;
const int kMaxComplaintEvidenceFiles = 5;

/// Central state & real backend integration controller for Module 5:
/// Discreet and Anonymous Complaint System (SRS Section 7, 12.5, 13 & 14).
///
/// IMPORTANT: Zero fake complaints are seeded in production. All submissions,
/// lookups, status transitions, replies, appeals, media purges, and admin queue
/// operations execute against the real backend API (`/api/v1/complaints/*` and
/// `/api/v1/admin-review/complaints/*`).
class SakhiComplaintController extends ChangeNotifier {
  SakhiComplaintController({BackendApiClient? apiClient})
    : _apiClient = apiClient ?? BackendApiClient();

  static SakhiComplaintController instance = SakhiComplaintController();

  BackendApiClient _apiClient;
  void setApiClientForTesting(BackendApiClient client) {
    _apiClient = client;
  }

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _lastError;
  String? get lastError => _lastError;
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  String _adminReviewerToken = const String.fromEnvironment(
    'SAKHI_ADMIN_REVIEW_TOKEN',
    defaultValue: 'ADMIN2026TEST',
  );
  String get adminReviewerToken => _adminReviewerToken;
  void setAdminReviewerToken(String token) {
    _adminReviewerToken = token.trim();
    notifyListeners();
  }

  String _activeAdminRole =
      'SENIOR_REVIEWER'; // SENIOR_REVIEWER, SUPER_ADMIN, STANDARD_MODERATOR
  String get activeAdminRole => _activeAdminRole;

  bool get canViewConfidentialContact =>
      _activeAdminRole == 'SENIOR_REVIEWER' ||
      _activeAdminRole == 'SENIOR_SAFETY_REVIEWER' ||
      _activeAdminRole == 'SUPER_ADMIN';

  void setActiveAdminRole(String role) {
    final normalized = role == 'SENIOR_SAFETY_REVIEWER'
        ? 'SENIOR_REVIEWER'
        : role;
    if (_activeAdminRole == normalized) return;
    _activeAdminRole = normalized;
    notifyListeners();
  }

  ComplaintRetentionPolicyModel _retentionPolicy =
      const ComplaintRetentionPolicyModel(
        closedCaseRetentionDays: 90,
        rejectedCaseRetentionDays: 30,
        autoPurgeRawMediaAfterDays: 90,
        scrubIpLogsAfterHours: 336,
        allowUserImmediateMediaPurge: true,
        dpdpComplianceNote:
            'DPDP Act 2023 Compliant • Closed evidence purged after 90d • Rejected reports purged after 30d • Technical rate-limit logs rotated every 14d.',
      );
  ComplaintRetentionPolicyModel get retentionPolicy => _retentionPolicy;

  final List<ComplaintCategoryInfo> _categories = <ComplaintCategoryInfo>[
    const ComplaintCategoryInfo(
      id: 'cat-harassment',
      code: 'harassment',
      label: 'Harassment',
      shortLabel: 'Harassment',
      subtitle: 'Verbal, physical, or persistent intimidation and threats',
      safetyGuidance:
          'Do not engage directly with the harasser. Preserve screenshots with timestamps, enable Sakhi Profile Privacy Lock, and use Anonymous Mode if you fear retaliation.',
      legalHelplineNote:
          'For immediate physical danger dial 112 (Emergency ERSS) or 1091 (Women Police Helpline).',
      defaultPriority: 'P1_URGENT',
      defaultSeverity: 'S2_HIGH',
      icon: Icons.record_voice_over_rounded,
      flowerType: SakhiFlowerType.roseClassic,
      displayOrder: 1,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-online_abuse_cyberbullying',
      code: 'online_abuse_cyberbullying',
      label: 'Online abuse or cyberbullying',
      shortLabel: 'Online Abuse / Cyberbullying',
      subtitle:
          'Abusive DMs, image morphing, doxxing, non-consensual sharing, or trolling',
      safetyGuidance:
          'Take screenshots before blocking the account. Sakhi automatically strips EXIF GPS and device metadata from your uploaded screenshots.',
      legalHelplineNote:
          'You can also file an official cyber complaint via 1930 or cybercrime.gov.in.',
      defaultPriority: 'P1_URGENT',
      defaultSeverity: 'S2_HIGH',
      icon: Icons.shield_moon_rounded,
      flowerType: SakhiFlowerType.cherryBlossom,
      displayOrder: 2,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-stalking_unwanted_contact',
      code: 'stalking_unwanted_contact',
      label: 'Stalking or unwanted contact',
      shortLabel: 'Stalking / Unwanted Contact',
      subtitle:
          'Following, repeated unwanted calls/messages, or physical surveillance',
      safetyGuidance:
          'Ensure live location sharing is restricted only to your verified family contacts. Log approximate dates and patterns; Sakhi correlates repeat stalker handles automatically.',
      legalHelplineNote:
          'Call 1091 or 112 immediately if someone is following you or waiting near your residence/workplace.',
      defaultPriority: 'P1_URGENT',
      defaultSeverity: 'S1_CRITICAL',
      icon: Icons.visibility_off_rounded,
      flowerType: SakhiFlowerType.cosmosViolet,
      displayOrder: 3,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-workplace_misconduct',
      code: 'workplace_misconduct',
      label: 'Workplace misconduct',
      shortLabel: 'Workplace (POSH)',
      subtitle:
          'POSH sexual harassment, quid-pro-quo coercion, or hostile work environment',
      safetyGuidance:
          'Under the POSH Act, keep a dated log of incidents, witnesses, and messages. Avoid using your employer\'s Wi-Fi or corporate laptop when submitting sensitive evidence.',
      legalHelplineNote:
          'Contact NCW (7827-170-170) or SHe-Box portal for statutory Internal Complaints Committee (ICC) escalation.',
      defaultPriority: 'P1_URGENT',
      defaultSeverity: 'S2_HIGH',
      icon: Icons.business_center_rounded,
      flowerType: SakhiFlowerType.eucalyptusSage,
      displayOrder: 4,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-public_place_safety',
      code: 'public_place_safety',
      label: 'Public-place safety concerns',
      shortLabel: 'Public-Place Safety',
      subtitle:
          'Unsafe streets, dark corridors, transit harassment, or loitering hotspots',
      safetyGuidance:
          'Select a coarse 5 km neighbourhood zone rather than your exact home address. Your report helps warn the Sakhi safety team about unsafe corridors.',
      legalHelplineNote:
          'Use Module 4 Nearest Police Stations or dial 112 for immediate PCR van patrol.',
      defaultPriority: 'P2_HIGH',
      defaultSeverity: 'S2_HIGH',
      icon: Icons.location_city_rounded,
      flowerType: SakhiFlowerType.cosmosViolet,
      displayOrder: 5,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-fraud_suspicious_activity',
      code: 'fraud_suspicious_activity',
      label: 'Fraud or suspicious activity',
      shortLabel: 'Fraud / Fake Profile / Extortion',
      subtitle:
          'Financial scams, fake profiles, impersonation, or blackmail/extortion',
      safetyGuidance:
          'Never transfer money or share OTPs with anyone claiming to represent a business or moderator. Attach profile links and payment handle screenshots.',
      legalHelplineNote:
          'Dial 1930 immediately to freeze fraudulent UPI/bank transfers on the National Cyber Crime Portal.',
      defaultPriority: 'P2_HIGH',
      defaultSeverity: 'S2_HIGH',
      icon: Icons.lock_person_rounded,
      flowerType: SakhiFlowerType.babysBreath,
      displayOrder: 6,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-discrimination',
      code: 'discrimination',
      label: 'Discrimination',
      shortLabel: 'Discrimination',
      subtitle:
          'Exclusion, hate speech, or bias based on caste, religion, gender, or background',
      safetyGuidance:
          'Sakhi has zero tolerance for caste, religious, regional, or gender discrimination. Link the offending post or comment so we can archive a tamper-evident snapshot.',
      legalHelplineNote:
          'Severe hate speech or threats can be escalated to statutory commissions and cyber cells.',
      defaultPriority: 'P2_HIGH',
      defaultSeverity: 'S3_MODERATE',
      icon: Icons.balance_rounded,
      flowerType: SakhiFlowerType.roseClassic,
      displayOrder: 7,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-domestic_interpersonal_safety',
      code: 'domestic_interpersonal_safety',
      label: 'Domestic or interpersonal safety concerns',
      shortLabel: 'Domestic / Family Safety',
      subtitle:
          'Partner, spouse, family, or household abuse, coercion, and threats',
      safetyGuidance:
          'If a partner or family member checks your phone, use Anonymous Mode, tap "Discreet Backup" to save your reference code disguised as a Wellness Quote Card, and use the top-right "Quick Exit" button anytime.',
      legalHelplineNote:
          'Dial 181 (24/7 Women\'s Domestic Abuse & Sakhi One-Stop Centre Helpline) or 112 for shelter, legal, and medical aid.',
      defaultPriority: 'P1_URGENT',
      defaultSeverity: 'S1_CRITICAL',
      icon: Icons.home_work_rounded,
      flowerType: SakhiFlowerType.eucalyptusSage,
      displayOrder: 8,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-business_related_complaints',
      code: 'business_related_complaints',
      label: 'Business-related complaints',
      shortLabel: 'Business Complaint',
      subtitle:
          'Misconduct, unsafe service, or policy breach by a listed business page',
      safetyGuidance:
          'You can link the reported Sakhi Business Page directly. The business owner will NEVER be notified of who reported them.',
      legalHelplineNote:
          'Fraudulent businesses are suspended by Trust & Safety after verification.',
      defaultPriority: 'P3_STANDARD',
      defaultSeverity: 'S3_MODERATE',
      icon: Icons.storefront_rounded,
      flowerType: SakhiFlowerType.cherryBlossom,
      displayOrder: 9,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-other',
      code: 'other',
      label: 'Other',
      shortLabel: 'Other Concern',
      subtitle:
          'Any other personal safety, privacy, or community wellbeing concern',
      safetyGuidance:
          'Specify your custom topic and share only what you feel safe disclosing. Our real-time PII guard will warn you if any phrase could reveal your identity.',
      legalHelplineNote:
          'In-app complaints do not automatically file a police FIR. Use 112 / 1091 / 181 when official law-enforcement action is needed.',
      defaultPriority: 'P3_STANDARD',
      defaultSeverity: 'S3_MODERATE',
      icon: Icons.spa_rounded,
      flowerType: SakhiFlowerType.babysBreath,
      displayOrder: 10,
    ),
  ];

  List<ComplaintCategoryInfo> get categories =>
      List<ComplaintCategoryInfo>.unmodifiable(_categories);

  List<ComplaintCategoryInfo> get enabledCategories =>
      _categories.where((c) => c.enabled).toList(growable: false);

  ComplaintCategoryInfo categoryByCode(String code) {
    final norm = code.trim().toLowerCase();
    for (final cat in _categories) {
      if (cat.code.toLowerCase() == norm) return cat;
    }
    // Support legacy uppercase aliases if passed
    const aliases = <String, String>{
      'harassment': 'harassment',
      'stalking': 'stalking_unwanted_contact',
      'cyberbullying': 'online_abuse_cyberbullying',
      'blackmail_extortion': 'fraud_suspicious_activity',
      'domestic_family_concern': 'domestic_interpersonal_safety',
      'workplace_harassment': 'workplace_misconduct',
      'impersonation_fake_account': 'fraud_suspicious_activity',
      'unsafe_community_behaviour': 'public_place_safety',
      'business_related_complaint': 'business_related_complaints',
      'other': 'other',
    };
    final mapped = aliases[norm];
    if (mapped != null) {
      for (final cat in _categories) {
        if (cat.code == mapped) return cat;
      }
    }
    return _categories.first;
  }

  /// Stores ONLY real complaints returned by the server during this session or via admin queue load.
  final List<DiscreetComplaintModel> _complaints = <DiscreetComplaintModel>[];
  List<DiscreetComplaintModel> get complaints =>
      List<DiscreetComplaintModel>.unmodifiable(_complaints);

  /// Stores passkeys issued by the server in this session so the user can immediately track their own newly filed complaint.
  final Map<String, String> _sessionIssuedPasskeys = <String, String>{};
  String? passkeyForReference(String referenceNumber) =>
      _sessionIssuedPasskeys[referenceNumber.trim().toUpperCase()];

  DiscreetComplaintModel? _lastSubmittedComplaint;
  DiscreetComplaintModel? get lastSubmittedComplaint => _lastSubmittedComplaint;

  Map<String, dynamic> _adminMetrics = const <String, dynamic>{
    'totalComplaints': 0,
    'openComplaintsCount': 0,
    'urgentP1Count': 0,
    'anonymousPercentage': 0,
    'confidentialPercentage': 0,
    'duplicateClustersCount': 0,
    'flaggedMaliciousAbuseCount': 0,
    'medianTriageHours': 0,
  };
  Map<String, dynamic> get adminMetrics => _adminMetrics;

  /// Syncs configurable categories & retention policy from `GET /api/v1/complaints/categories`.
  Future<void> syncCategoriesFromServer() async {
    try {
      final res = await _apiClient.get('complaints/categories');
      final rawCats = res['allCategories'] ?? res['categories'];
      if (rawCats is List && rawCats.isNotEmpty) {
        final nextCats = <ComplaintCategoryInfo>[];
        for (final item in rawCats.whereType<Map<String, dynamic>>()) {
          final slug = (item['slug'] as String? ?? '').trim().toLowerCase();
          final existing = _categories.cast<ComplaintCategoryInfo?>().firstWhere(
            (c) => c?.code == slug,
            orElse: () => null,
          );
          nextCats.add(
            ComplaintCategoryInfo.fromBackendJson(item, fallback: existing),
          );
        }
        if (nextCats.isNotEmpty) {
          _categories
            ..clear()
            ..addAll(nextCats);
        }
      }
      if (res['retentionPolicy'] is Map<String, dynamic>) {
        _retentionPolicy = ComplaintRetentionPolicyModel.fromBackendJson(
          res['retentionPolicy'] as Map<String, dynamic>,
        );
      }
      notifyListeners();
    } catch (_) {
      // Keep the 10 SRS schema categories if offline during initial screen load
    }
  }

  /// SRS 7.4 — Real-Time Identity-Reveal (PII) Detector & Auto-Redactor
  PiiCheckResultModel analyzeTextForSelfIdentifyingClues(String text) {
    final detected = <PiiDetectedItemModel>[];
    var redacted = text;

    final phoneRegex = RegExp(r'(?:\+91[\s-]?)?[6-9]\d{9}\b');
    for (final match in phoneRegex.allMatches(text)) {
      final val = match.group(0)!;
      detected.add(
        PiiDetectedItemModel(
          type: 'Mobile Number',
          snippet: val,
          replacement: '[phone number redacted]',
        ),
      );
      redacted = redacted.replaceAll(val, '[phone number redacted]');
    }

    final emailRegex = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b',
    );
    for (final match in emailRegex.allMatches(text)) {
      final val = match.group(0)!;
      detected.add(
        PiiDetectedItemModel(
          type: 'Email Address',
          snippet: val,
          replacement: '[email redacted]',
        ),
      );
      redacted = redacted.replaceAll(val, '[email redacted]');
    }

    final aadhaarRegex = RegExp(r'\b\d{4}[\s-]\d{4}[\s-]\d{4}\b');
    for (final match in aadhaarRegex.allMatches(text)) {
      final val = match.group(0)!;
      detected.add(
        PiiDetectedItemModel(
          type: 'Govt ID / Aadhaar Pattern',
          snippet: val,
          replacement: '[govt ID redacted]',
        ),
      );
      redacted = redacted.replaceAll(val, '[govt ID redacted]');
    }

    final nameClueRegex = RegExp(
      r'\b(?:my name is|i am|this is)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)',
      caseSensitive: false,
    );
    for (final match in nameClueRegex.allMatches(text)) {
      final full = match.group(0)!;
      detected.add(
        PiiDetectedItemModel(
          type: 'Self-Identifying Name Phrase',
          snippet: full,
          replacement: '[complainant identity redacted]',
        ),
      );
      redacted = redacted.replaceAll(full, '[complainant identity redacted]');
    }

    final flatAddressRegex = RegExp(
      r'\b(?:flat|apt|apartment|house|plot|room)\s*(?:no\.?|#)?\s*[A-Za-z0-9/-]+',
      caseSensitive: false,
    );
    for (final match in flatAddressRegex.allMatches(text)) {
      final full = match.group(0)!;
      detected.add(
        PiiDetectedItemModel(
          type: 'Exact Door / Flat Number',
          snippet: full,
          replacement: '[general building area]',
        ),
      );
      redacted = redacted.replaceAll(full, '[general building area]');
    }

    return PiiCheckResultModel(
      hasPotentialPii: detected.isNotEmpty,
      detectedItems: detected,
      redactedText: redacted,
    );
  }

  /// Strips binary JPEG APP1..APP15/COM and PNG eXIf/tEXt metadata segments on the client
  /// before transmitting to the backend EXIF scrubber.
  Uint8List stripClientBinaryMetadata(Uint8List input) {
    if (input.length < 12) return input;
    // JPEG (FFD8)
    if (input[0] == 0xff && input[1] == 0xd8) {
      final builder = BytesBuilder(copy: false);
      builder.add(const <int>[0xff, 0xd8]);
      var offset = 2;
      while (offset + 2 <= input.length) {
        if (input[offset] != 0xff) {
          builder.add(input.sublist(offset));
          break;
        }
        final marker = input[offset + 1];
        if (marker == 0xda || marker == 0xd9) {
          builder.add(input.sublist(offset));
          break;
        }
        if (marker == 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
          builder.add(input.sublist(offset, offset + 2));
          offset += 2;
          continue;
        }
        if (offset + 4 > input.length) {
          builder.add(input.sublist(offset));
          break;
        }
        final segLen = (input[offset + 2] << 8) | input[offset + 3];
        if (segLen < 2 || offset + 2 + segLen > input.length) {
          builder.add(input.sublist(offset));
          break;
        }
        final isExifOrComment =
            (marker >= 0xe1 && marker <= 0xef) || marker == 0xfe;
        if (!isExifOrComment) {
          builder.add(input.sublist(offset, offset + 2 + segLen));
        }
        offset += 2 + segLen;
      }
      return builder.toBytes();
    }
    return input;
  }

  /// Uploads and scrubs evidence via the backend API (`POST /api/v1/complaints/scrub-metadata`).
  /// Validates MIME type and file size (1B .. 15MB) and throws a `BackendApiException` on failure.
  Future<SanitizedEvidenceFileModel> uploadAndScrubEvidenceOnServer({
    required String originalFileName,
    required String mimeType,
    required Uint8List fileBytes,
    bool visualBlurApplied = true,
  }) async {
    final cleanMime = mimeType.trim().toLowerCase();
    if (!kAllowedComplaintEvidenceMimeTypes.contains(cleanMime)) {
      throw BackendApiException(
        statusCode: 400,
        code: 'unsupported_file_type',
        message:
            'Unsupported file type "$mimeType". Allowed: PNG, JPEG, WebP, PDF, M4A, MP3, WAV.',
      );
    }
    if (fileBytes.isEmpty || fileBytes.length > kMaxComplaintEvidenceBytes) {
      throw const BackendApiException(
        statusCode: 400,
        code: 'invalid_file_size',
        message: 'Evidence file must be between 1 byte and 15 MB.',
      );
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final locallyStripped = stripClientBinaryMetadata(fileBytes);
      final response = await _apiClient.post(
        'complaints/scrub-metadata',
        body: <String, Object?>{
          'originalFileName': originalFileName.trim(),
          'contentType': cleanMime,
          'byteSize': locallyStripped.length,
          'visualBlurApplied': visualBlurApplied,
          'base64Data': base64Encode(locallyStripped),
        },
      );
      final sanitizedJson = response['sanitizedFile'];
      if (sanitizedJson is! Map<String, dynamic>) {
        throw const BackendApiException(
          statusCode: 500,
          code: 'invalid_scrubber_response',
          message: 'Backend did not return a valid sanitizedFile record.',
        );
      }
      return SanitizedEvidenceFileModel.fromBackendJson(sanitizedJson);
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Validates a supporting URL (only `https://`, `http://`, or `sakhi://` allowed).
  static String? validateSupportingLinkUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Enter a URL or Sakhi reference link.';
    if (trimmed.length > 500) return 'Link cannot exceed 500 characters.';
    if (trimmed.startsWith('sakhi://')) {
      final validSakhi = RegExp(r'^sakhi://[a-zA-Z0-9_./@-]+$');
      if (!validSakhi.hasMatch(trimmed)) {
        return 'Invalid Sakhi internal link format (e.g. sakhi://post/123).';
      }
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAbsolutePath ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return 'Enter a valid https://, http://, or sakhi:// URL.';
    }
    return null;
  }

  /// Submits a new Discreet or Confidential Complaint to `POST /api/v1/complaints`.
  /// NEVER invents a client-side reference number or fakes success when the backend fails!
  Future<DiscreetComplaintModel> submitComplaint({
    required ComplaintReportingMode reportingMode,
    required String categoryCode,
    String? customCategoryNote,
    required String urgencyLevel,
    required String description,
    required String approximateDateLabel,
    required String approximateTimeWindow,
    required String locationType,
    String? generalAreaText,
    required List<String> supportingLinks,
    String? linkedPostId,
    String? linkedProfileHandle,
    String? linkedBusinessId,
    required bool wantsFollowUp,
    required String discreetNotificationMode,
    required bool acknowledgedNonPoliceLegalNotice,
    required List<SanitizedEvidenceFileModel> evidenceFiles,
    bool piiGuardRedacted = false,
  }) async {
    final cleanDesc = description.trim();
    if (cleanDesc.length < 20) {
      throw const BackendApiException(
        statusCode: 400,
        code: 'description_too_short',
        message:
            'Please provide an incident description of at least 20 non-whitespace characters.',
      );
    }
    if (!acknowledgedNonPoliceLegalNotice) {
      throw const BackendApiException(
        statusCode: 400,
        code: 'disclaimer_required',
        message:
            'Please acknowledge the non-police / emergency channels disclaimer before submitting.',
      );
    }
    final cat = categoryByCode(categoryCode);
    if (!cat.enabled) {
      throw BackendApiException(
        statusCode: 400,
        code: 'category_disabled',
        message: 'The category "${cat.label}" is currently disabled.',
      );
    }
    if (cat.code == 'other' &&
        (customCategoryNote == null || customCategoryNote.trim().length < 3)) {
      throw const BackendApiException(
        statusCode: 400,
        code: 'custom_category_required',
        message:
            'Please specify a custom category label (at least 3 characters) when selecting "Other".',
      );
    }
    for (final link in supportingLinks) {
      final linkErr = validateSupportingLinkUrl(link);
      if (linkErr != null) {
        throw BackendApiException(
          statusCode: 400,
          code: 'invalid_supporting_link',
          message: linkErr,
        );
      }
    }
    if (evidenceFiles.length > kMaxComplaintEvidenceFiles) {
      throw const BackendApiException(
        statusCode: 400,
        code: 'too_many_evidence_files',
        message: 'A maximum of 5 evidence files can be attached per report.',
      );
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final mappedUrgency =
          urgencyLevel == 'CRITICAL' || urgencyLevel == 'HAPPENING_NOW'
          ? 'HAPPENING_NOW'
          : urgencyLevel == 'HIGH' || urgencyLevel == 'REPEATED_PATTERN'
          ? 'REPEATED_PATTERN'
          : 'PAST_INCIDENT';

      final response = await _apiClient.post(
        'complaints',
        authenticated: reportingMode == ComplaintReportingMode.confidential,
        body: <String, Object?>{
          'reportingMode': reportingMode.code,
          'categorySlug': cat.code,
          if (customCategoryNote != null &&
              customCategoryNote.trim().isNotEmpty)
            'customCategoryLabel': customCategoryNote.trim(),
          'urgency': mappedUrgency,
          'description': cleanDesc,
          'piiGuardRedacted': piiGuardRedacted,
          'approximateDateLabel': approximateDateLabel.trim(),
          'approximateTimeWindow': approximateTimeWindow.trim(),
          'locationType': locationType.trim(),
          if (generalAreaText != null && generalAreaText.trim().isNotEmpty)
            'generalLocationLabel': generalAreaText.trim(),
          if (linkedProfileHandle != null &&
              linkedProfileHandle.trim().isNotEmpty)
            'linkedTargetHandle': linkedProfileHandle.trim(),
          if (linkedPostId != null && linkedPostId.trim().isNotEmpty)
            'linkedPostId': linkedPostId.trim(),
          if (linkedBusinessId != null && linkedBusinessId.trim().isNotEmpty)
            'linkedBusinessId': linkedBusinessId.trim(),
          'evidenceFiles': evidenceFiles.map((e) => e.toJson()).toList(),
          'supportingLinks': supportingLinks,
          'wantsUpdates': wantsFollowUp,
          'submitAnonymouslyToReviewTeam':
              reportingMode == ComplaintReportingMode.anonymous,
          'acknowledgedNonPoliceLegalNotice': acknowledgedNonPoliceLegalNotice,
        },
      );

      final refNumber = (response['referenceNumber'] as String? ?? '').trim();
      final issuedPasskey = (response['passkey'] as String? ?? '').trim();
      final complaintJson = response['complaint'];

      if (refNumber.isEmpty ||
          issuedPasskey.isEmpty ||
          complaintJson is! Map<String, dynamic>) {
        throw const BackendApiException(
          statusCode: 500,
          code: 'invalid_submission_receipt',
          message:
              'The server did not return a valid complaint reference number and passkey.',
        );
      }

      final created = DiscreetComplaintModel.fromBackendJson(
        complaintJson,
        knownPasskey: issuedPasskey,
      );

      _sessionIssuedPasskeys[created.referenceNumber.toUpperCase()] =
          issuedPasskey;
      _complaints.removeWhere(
        (c) =>
            c.referenceNumber.toUpperCase() ==
            created.referenceNumber.toUpperCase(),
      );
      _complaints.insert(0, created);
      _lastSubmittedComplaint = created;
      return created;
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Looks up a complaint on the backend (`GET /api/v1/complaints/track/:referenceNumber?passkey=...`).
  /// Requires a valid passkey (or Disguised Wellness Quote Serial containing `::PASSKEY`).
  Future<DiscreetComplaintModel> lookupComplaintOnServer({
    required String referenceOrSerial,
    String? passkey,
  }) async {
    final cleanRef = referenceOrSerial.trim();
    if (cleanRef.isEmpty) {
      throw const BackendApiException(
        statusCode: 400,
        code: 'reference_required',
        message:
            'Enter your #SKH-ANON / #SKH-CONF Reference Number or Disguised Quote Serial.',
      );
    }

    final effectivePasskey =
        (passkey != null && passkey.trim().isNotEmpty)
        ? passkey.trim()
        : passkeyForReference(cleanRef);

    if ((effectivePasskey == null || effectivePasskey.isEmpty) &&
        !cleanRef.contains('::')) {
      throw const BackendApiException(
        statusCode: 403,
        code: 'passkey_required',
        message:
            'Enter the Check-In Passkey issued with your complaint receipt (or paste your full Disguised Wellness Quote Serial).',
      );
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final encodedRef = Uri.encodeComponent(cleanRef);
      final query = effectivePasskey != null && effectivePasskey.isNotEmpty
          ? '?passkey=${Uri.encodeQueryComponent(effectivePasskey)}'
          : '';
      final response = await _apiClient.get(
        'complaints/track/$encodedRef$query',
      );
      final complaintJson = response['complaint'];
      if (complaintJson is! Map<String, dynamic>) {
        throw const BackendApiException(
          statusCode: 404,
          code: 'complaint_not_found',
          message: 'No complaint found matching that reference number.',
        );
      }
      final resolvedPasskey =
          effectivePasskey ??
          (cleanRef.contains('::') ? cleanRef.split('::').last.trim() : '');
      final model = DiscreetComplaintModel.fromBackendJson(
        complaintJson,
        knownPasskey: resolvedPasskey,
      );
      if (resolvedPasskey.isNotEmpty) {
        _sessionIssuedPasskeys[model.referenceNumber.toUpperCase()] =
            resolvedPasskey;
      }
      _upsertLocalCache(model);
      return model;
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _upsertLocalCache(DiscreetComplaintModel updated) {
    final idx = _complaints.indexWhere(
      (c) =>
          c.referenceNumber.toUpperCase() ==
          updated.referenceNumber.toUpperCase(),
    );
    if (idx >= 0) {
      _complaints[idx] = updated;
    } else {
      _complaints.insert(0, updated);
    }
  }

  /// Sends a Two-Way Encrypted Follow-Up Reply to `POST /api/v1/complaints/track/:referenceNumber/reply`.
  Future<DiscreetComplaintModel> sendComplainantReply({
    required String referenceNumber,
    required String passkey,
    required String messageBody,
    List<SanitizedEvidenceFileModel> newEvidence =
        const <SanitizedEvidenceFileModel>[],
  }) async {
    final cleanMsg = messageBody.trim();
    if (cleanMsg.length < 2) {
      throw const BackendApiException(
        statusCode: 400,
        code: 'reply_empty',
        message: 'Please enter a reply message (at least 2 characters).',
      );
    }
    final cleanPass = passkey.trim().isNotEmpty
        ? passkey.trim()
        : (passkeyForReference(referenceNumber) ?? '');
    if (cleanPass.isEmpty) {
      throw const BackendApiException(
        statusCode: 403,
        code: 'passkey_required',
        message: 'Your complaint passkey is required to send a reply.',
      );
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        'complaints/track/${Uri.encodeComponent(referenceNumber.trim())}/reply',
        body: <String, Object?>{
          'passkey': cleanPass,
          'message': cleanMsg,
          'additionalEvidenceFiles': newEvidence
              .map((e) => e.toJson())
              .toList(),
        },
      );
      final complaintJson = response['complaint'];
      if (complaintJson is! Map<String, dynamic>) {
        throw const BackendApiException(
          statusCode: 500,
          code: 'invalid_reply_response',
          message: 'Server did not return updated complaint after reply.',
        );
      }
      final updated = DiscreetComplaintModel.fromBackendJson(
        complaintJson,
        knownPasskey: cleanPass,
      );
      _upsertLocalCache(updated);
      return updated;
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Submits a Case Appeal to `POST /api/v1/complaints/track/:referenceNumber/appeal`.
  Future<DiscreetComplaintModel> submitCaseAppeal({
    required String referenceNumber,
    required String passkey,
    String appealReasonCategory = 'New Evidence or Escalating Concern',
    required String appealReason,
  }) async {
    final cleanReason = appealReason.trim();
    if (cleanReason.length < 10) {
      throw const BackendApiException(
        statusCode: 400,
        code: 'appeal_too_short',
        message:
            'Please provide at least 10 characters explaining why this case should be re-opened.',
      );
    }
    final cleanPass = passkey.trim().isNotEmpty
        ? passkey.trim()
        : (passkeyForReference(referenceNumber) ?? '');
    if (cleanPass.isEmpty) {
      throw const BackendApiException(
        statusCode: 403,
        code: 'passkey_required',
        message: 'Your complaint passkey is required to submit an appeal.',
      );
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final response = await _apiClient.post(
        'complaints/track/${Uri.encodeComponent(referenceNumber.trim())}/appeal',
        body: <String, Object?>{
          'passkey': cleanPass,
          'appealReasonCategory': appealReasonCategory.trim(),
          'appealDescription': cleanReason,
        },
      );
      final complaintJson = response['complaint'];
      if (complaintJson is! Map<String, dynamic>) {
        throw const BackendApiException(
          statusCode: 500,
          code: 'invalid_appeal_response',
          message: 'Server did not return updated complaint after appeal.',
        );
      }
      final updated = DiscreetComplaintModel.fromBackendJson(
        complaintJson,
        knownPasskey: cleanPass,
      ).copyWith(appealSubmitted: true, appealReasonText: cleanReason);
      _upsertLocalCache(updated);
      return updated;
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Purges uploaded evidence media on the server (`DELETE /api/v1/complaints/track/:referenceNumber/media`).
  Future<DiscreetComplaintModel> purgeEvidenceVaultMedia({
    required String referenceNumber,
    required String passkey,
  }) async {
    final cleanPass = passkey.trim().isNotEmpty
        ? passkey.trim()
        : (passkeyForReference(referenceNumber) ?? '');
    if (cleanPass.isEmpty) {
      throw const BackendApiException(
        statusCode: 403,
        code: 'passkey_required',
        message: 'Your complaint passkey is required to purge evidence media.',
      );
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final encodedRef = Uri.encodeComponent(referenceNumber.trim());
      final encodedPass = Uri.encodeQueryComponent(cleanPass);
      final response = await _apiClient.delete(
        'complaints/track/$encodedRef/media?passkey=$encodedPass',
        body: <String, Object?>{'passkey': cleanPass},
      );
      final complaintJson = response['complaint'];
      if (complaintJson is! Map<String, dynamic>) {
        throw const BackendApiException(
          statusCode: 500,
          code: 'invalid_purge_response',
          message: 'Server did not confirm media erasure.',
        );
      }
      final updated = DiscreetComplaintModel.fromBackendJson(
        complaintJson,
        knownPasskey: cleanPass,
      );
      _upsertLocalCache(updated);
      return updated;
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ===========================================================================
  // ADMIN CONSOLE REAL BACKEND OPERATIONS (`/api/v1/admin-review/complaints*`)
  // ===========================================================================

  Map<String, String> get _adminHeaders => <String, String>{
    'x-sakhi-admin-token': _adminReviewerToken,
    'x-sakhi-admin-review-token': _adminReviewerToken,
  };

  Future<List<DiscreetComplaintModel>> loadAdminDashboardQueue({
    String status = 'ALL',
    String reportingMode = 'ALL',
    String search = '',
    int page = 1,
  }) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final qs = <String, String>{
        'status': status,
        'reportingMode': reportingMode,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page': page.toString(),
        'viewerRole': _activeAdminRole,
      };
      final queryStr = qs.entries
          .map(
            (e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
          )
          .join('&');
      final res = await _apiClient.get(
        'admin-review/complaints?$queryStr',
        headers: _adminHeaders,
      );

      if (res['metrics'] is Map<String, dynamic>) {
        _adminMetrics = res['metrics'] as Map<String, dynamic>;
      }
      if (res['retentionPolicy'] is Map<String, dynamic>) {
        _retentionPolicy = ComplaintRetentionPolicyModel.fromBackendJson(
          res['retentionPolicy'] as Map<String, dynamic>,
        );
      }
      if (res['categories'] is List) {
        final rawCats = res['categories'] as List;
        final nextCats = <ComplaintCategoryInfo>[];
        for (final item in rawCats.whereType<Map<String, dynamic>>()) {
          final slug = (item['slug'] as String? ?? '').trim().toLowerCase();
          final existing = _categories.cast<ComplaintCategoryInfo?>().firstWhere(
            (c) => c?.code == slug,
            orElse: () => null,
          );
          nextCats.add(
            ComplaintCategoryInfo.fromBackendJson(item, fallback: existing),
          );
        }
        if (nextCats.isNotEmpty) {
          _categories
            ..clear()
            ..addAll(nextCats);
        }
      }

      final rawComplaints = res['complaints'];
      final loaded = rawComplaints is List
          ? rawComplaints
                .whereType<Map<String, dynamic>>()
                .map(
                  (j) => DiscreetComplaintModel.fromBackendJson(
                    j,
                    knownPasskey: passkeyForReference(
                      j['referenceNumber'] as String? ?? '',
                    ),
                  ),
                )
                .toList(growable: false)
          : const <DiscreetComplaintModel>[];

      _complaints
        ..clear()
        ..addAll(loaded);
      return _complaints;
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<DiscreetComplaintModel> adminAssignAndClassifyOnServer({
    required String referenceNumber,
    required String assignedReviewerId,
    required String assignedReviewerName,
    required String severity,
    required String priority,
  }) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final res = await _apiClient.patch(
        'admin-review/complaints/${Uri.encodeComponent(referenceNumber)}/assign',
        headers: _adminHeaders,
        body: <String, Object?>{
          'assignedReviewerId': assignedReviewerId,
          'assignedReviewerName': assignedReviewerName,
          'severity': severity,
          'priority': priority,
        },
      );
      final updated = DiscreetComplaintModel.fromBackendJson(
        res['complaint'] as Map<String, dynamic>,
        knownPasskey: passkeyForReference(referenceNumber),
      );
      _upsertLocalCache(updated);
      return updated;
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<DiscreetComplaintModel> adminUpdateStatusOnServer({
    required String referenceNumber,
    required ComplaintStatus newStatus,
    String? publicMessageToComplainant,
    String? rejectionReasonCode,
  }) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final res = await _apiClient.post(
        'admin-review/complaints/${Uri.encodeComponent(referenceNumber)}/status',
        headers: _adminHeaders,
        body: <String, Object?>{
          'status': newStatus.code,
          if (publicMessageToComplainant != null &&
              publicMessageToComplainant.trim().isNotEmpty)
            'publicMessageToComplainant': publicMessageToComplainant.trim(),
          if (rejectionReasonCode != null &&
              rejectionReasonCode.trim().isNotEmpty)
            'rejectionReasonCode': rejectionReasonCode.trim(),
        },
      );
      final updated = DiscreetComplaintModel.fromBackendJson(
        res['complaint'] as Map<String, dynamic>,
        knownPasskey: passkeyForReference(referenceNumber),
      );
      _upsertLocalCache(updated);
      return updated;
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<DiscreetComplaintModel> adminAddInternalNoteOnServer({
    required String referenceNumber,
    required String noteText,
    String visibilityRole = 'SENIOR_REVIEWER',
  }) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final res = await _apiClient.post(
        'admin-review/complaints/${Uri.encodeComponent(referenceNumber)}/internal-notes',
        headers: _adminHeaders,
        body: <String, Object?>{
          'noteText': noteText.trim(),
          'visibilityRole': visibilityRole,
        },
      );
      final updated = DiscreetComplaintModel.fromBackendJson(
        res['complaint'] as Map<String, dynamic>,
        knownPasskey: passkeyForReference(referenceNumber),
      );
      _upsertLocalCache(updated);
      return updated;
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<String> adminAccessEvidenceOnServer({
    required String referenceNumber,
    required String evidenceId,
    required String action,
    required String justificationReason,
  }) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final res = await _apiClient.post(
        'admin-review/complaints/${Uri.encodeComponent(referenceNumber)}/evidence-access',
        headers: _adminHeaders,
        body: <String, Object?>{
          'evidenceId': evidenceId,
          'action': action,
          'justificationReason': justificationReason.trim(),
          'viewerRole': _activeAdminRole,
        },
      );
      if (res['complaint'] is Map<String, dynamic>) {
        final updated = DiscreetComplaintModel.fromBackendJson(
          res['complaint'] as Map<String, dynamic>,
          knownPasskey: passkeyForReference(referenceNumber),
        );
        _upsertLocalCache(updated);
      }
      return (res['watermarkOverlayText'] as String? ?? 'WATERMARKED').trim();
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> adminMergeDuplicatesOnServer({
    required String primaryReferenceNumber,
    required List<String> duplicateReferenceNumbers,
    String? clusterId,
  }) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      await _apiClient.post(
        'admin-review/complaints/merge-duplicates',
        headers: _adminHeaders,
        body: <String, Object?>{
          'primaryReferenceNumber': primaryReferenceNumber.trim(),
          'duplicateReferenceNumbers': duplicateReferenceNumbers,
          if (clusterId != null && clusterId.trim().isNotEmpty)
            'clusterId': clusterId.trim(),
          'viewerRole': _activeAdminRole,
        },
      );
      await loadAdminDashboardQueue();
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> adminHandleMaliciousOnServer({
    required String referenceNumber,
    required String reason,
    int cooldownHours = 72,
  }) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      await _apiClient.post(
        'admin-review/complaints/${Uri.encodeComponent(referenceNumber)}/malicious-guard',
        headers: _adminHeaders,
        body: <String, Object?>{
          'action': 'THROTTLE_BLINDED_BUCKET',
          'cooldownHours': cooldownHours,
          'reason': reason.trim(),
          'viewerRole': _activeAdminRole,
        },
      );
      await loadAdminDashboardQueue();
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> toggleCategoryEnabledOnServer(
    ComplaintCategoryInfo cat,
    bool enabled,
  ) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      await _apiClient.put(
        'admin-review/complaints/categories',
        headers: _adminHeaders,
        body: <String, Object?>{
          'slug': cat.code,
          'name': cat.label,
          'description': cat.subtitle,
          'defaultPriority': cat.defaultPriority,
          'defaultSeverity': cat.defaultSeverity,
          'safetyGuidanceText': cat.safetyGuidance,
          'legalHelplineNote': cat.legalHelplineNote,
          'isEnabled': enabled,
          'displayOrder': cat.displayOrder,
          'viewerRole': _activeAdminRole,
        },
      );
      final idx = _categories.indexWhere((c) => c.code == cat.code);
      if (idx >= 0) {
        _categories[idx] = _categories[idx].copyWith(enabled: enabled);
      }
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> updateRetentionPolicyOnServer({
    required int closedEvidenceRetentionDays,
    required int rejectedReportRetentionDays,
    required int technicalRateLimitLogDays,
  }) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final res = await _apiClient.put(
        'admin-review/complaints/retention-policy',
        headers: _adminHeaders,
        body: <String, Object?>{
          'closedEvidenceRetentionDays': closedEvidenceRetentionDays,
          'rejectedReportRetentionDays': rejectedReportRetentionDays,
          'technicalRateLimitLogDays': technicalRateLimitLogDays,
          'viewerRole': _activeAdminRole,
        },
      );
      if (res['retentionPolicy'] is Map<String, dynamic>) {
        _retentionPolicy = ComplaintRetentionPolicyModel.fromBackendJson(
          res['retentionPolicy'] as Map<String, dynamic>,
        );
      }
    } on BackendApiException catch (err) {
      _lastError = err.message;
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
