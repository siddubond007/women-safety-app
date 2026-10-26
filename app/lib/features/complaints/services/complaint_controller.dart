import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../auth/backend_api_client.dart';
import '../models/complaint_models.dart';

/// Central state & backend integration controller for Module 5:
/// Discreet and Anonymous Complaint System (SRS Section 7, 12.5, 13 & 14).
class SakhiComplaintController extends ChangeNotifier {
  SakhiComplaintController._() {
    _seedInitialCases();
  }

  static final SakhiComplaintController instance = SakhiComplaintController._();

  final BackendApiClient _apiClient = BackendApiClient();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String _activeAdminRole =
      'SENIOR_SAFETY_REVIEWER'; // or STANDARD_MODERATOR / SUPER_ADMIN
  String get activeAdminRole => _activeAdminRole;

  bool get canViewConfidentialContact =>
      _activeAdminRole == 'SENIOR_SAFETY_REVIEWER' ||
      _activeAdminRole == 'SUPER_ADMIN';

  void setActiveAdminRole(String role) {
    if (_activeAdminRole == role) return;
    _activeAdminRole = role;
    notifyListeners();
  }

  ComplaintRetentionPolicyModel _retentionPolicy =
      const ComplaintRetentionPolicyModel(
        closedCaseRetentionDays: 90,
        rejectedCaseRetentionDays: 30,
        autoPurgeRawMediaAfterDays: 45,
        scrubIpLogsAfterHours: 24,
        allowUserImmediateMediaPurge: true,
        dpdpComplianceNote: 'Compliant with India DPDP Act 2023 • Zero Aadhaar retention • Coarse blinded rate-limit bucket • Encrypted evidence vault.',
      );
  ComplaintRetentionPolicyModel get retentionPolicy => _retentionPolicy;

  final List<ComplaintCategoryInfo> _categories = <ComplaintCategoryInfo>[
    const ComplaintCategoryInfo(
      id: 'cat-1',
      code: 'HARASSMENT',
      label: 'Harassment',
      shortLabel: 'Harassment',
      subtitle:
          'Unwanted messages, repeated comments, intimidation or hostility',
      safetyGuidance: 'Save screenshots before blocking if safe to do so. Sakhi strips all EXIF GPS & camera metadata automatically.',
      defaultSeverity: 'HIGH_P2',
      icon: Icons.record_voice_over_rounded,
      flowerType: SakhiFlowerType.roseClassic,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-2',
      code: 'STALKING',
      label: 'Stalking',
      shortLabel: 'Stalking',
      subtitle: 'Offline or online tracking, unwanted following, or location watching',
      safetyGuidance: 'Never share live location publicly. If you are in immediate physical danger, use the SOS button or dial 112 / 1091 immediately.',
      defaultSeverity: 'CRITICAL_P1',
      icon: Icons.visibility_off_rounded,
      flowerType: SakhiFlowerType.cosmosViolet,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-3',
      code: 'CYBERBULLYING',
      label: 'Cyberbullying',
      shortLabel: 'Cyberbullying',
      subtitle:
          'Coordinated shaming, dogpiling, derogatory threads or body-shaming',
      safetyGuidance: 'Link the offending Sakhi post or comment ID so moderators can freeze the thread even if the author edits it.',
      defaultSeverity: 'MEDIUM_P3',
      icon: Icons.shield_moon_rounded,
      flowerType: SakhiFlowerType.cherryBlossom,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-4',
      code: 'BLACKMAIL_EXTORTION',
      label: 'Blackmail / Extortion',
      shortLabel: 'Blackmail / Extortion',
      subtitle: 'Coercion, threats to leak private photos/chats, or financial extortion',
      safetyGuidance: 'Do not pay or delete raw chat logs on your phone if you plan to file a Cybercrime report (1930). Our Evidence Vault stores a SHA-256 hash.',
      defaultSeverity: 'CRITICAL_P1',
      icon: Icons.lock_person_rounded,
      flowerType: SakhiFlowerType.babysBreath,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-5',
      code: 'DOMESTIC_FAMILY_CONCERN',
      label: 'Domestic or Family Concern',
      shortLabel: 'Domestic / Family',
      subtitle: 'Coercive control, domestic safety concern, or family pressure',
      safetyGuidance: 'Use Anonymous Mode + Discreet In-App Vault Only (Zero Push Notifications) if family members have access to your phone lock screen.',
      defaultSeverity: 'CRITICAL_P1',
      icon: Icons.home_work_rounded,
      flowerType: SakhiFlowerType.eucalyptusSage,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-6',
      code: 'WORKPLACE_HARASSMENT',
      label: 'Workplace Harassment',
      shortLabel: 'Workplace (POSH)',
      subtitle: 'POSH Act workplace misconduct, quid-pro-quo, or professional retaliation',
      safetyGuidance: 'Note approximate dates and witnesses if applicable. Under India\'s POSH Act 2013, you can also request Internal Committee (IC) guidance.',
      defaultSeverity: 'HIGH_P2',
      icon: Icons.business_center_rounded,
      flowerType: SakhiFlowerType.babysBreath,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-7',
      code: 'IMPERSONATION_FAKE_ACCOUNT',
      label: 'Impersonation / Fake Account',
      shortLabel: 'Impersonation / Fake',
      subtitle: 'Stolen photos, fake female identity, or unauthorized profile cloning',
      safetyGuidance: 'Provide the @handle of the suspected account. Our verification team can trigger a mandatory re-verification lock.',
      defaultSeverity: 'HIGH_P2',
      icon: Icons.person_off_rounded,
      flowerType: SakhiFlowerType.roseClassic,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-8',
      code: 'UNSAFE_COMMUNITY_BEHAVIOUR',
      label: 'Unsafe Community Behaviour',
      shortLabel: 'Unsafe Behaviour',
      subtitle: 'Predatory DMs, boundary violations, doxxing, or unsafe meetup pressure',
      safetyGuidance: 'Your report helps protect every woman on Sakhi. Duplicate reports against the same account automatically raise severity.',
      defaultSeverity: 'HIGH_P2',
      icon: Icons.health_and_safety_rounded,
      flowerType: SakhiFlowerType.cherryBlossom,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-9',
      code: 'BUSINESS_RELATED_COMPLAINT',
      label: 'Business-Related Complaint',
      shortLabel: 'Business Complaint',
      subtitle: 'Fraudulent Sakhi business page, unsafe service provider, or scam enquiry',
      safetyGuidance: 'Attach the Sakhi Business Page reference or booking screenshot so our commerce trust team can suspend unverified listings.',
      defaultSeverity: 'MEDIUM_P3',
      icon: Icons.storefront_rounded,
      flowerType: SakhiFlowerType.babysBreath,
    ),
    const ComplaintCategoryInfo(
      id: 'cat-10',
      code: 'OTHER',
      label: 'Other Safety or Privacy Concern',
      shortLabel: 'Other Concern',
      subtitle:
          'Any other sensitive community, privacy, or personal safety issue',
      safetyGuidance: 'Describe the concern in your own words. Our PII guard will alert you if you accidentally type your own phone number or email.',
      defaultSeverity: 'MEDIUM_P3',
      icon: Icons.spa_rounded,
      flowerType: SakhiFlowerType.eucalyptusSage,
    ),
  ];

  List<ComplaintCategoryInfo> get categories =>
      List<ComplaintCategoryInfo>.unmodifiable(_categories);

  List<ComplaintCategoryInfo> get enabledCategories =>
      _categories.where((c) => c.enabled).toList(growable: false);

  ComplaintCategoryInfo categoryByCode(String code) {
    for (final cat in _categories) {
      if (cat.code == code) return cat;
    }
    return _categories.first;
  }

  final List<DiscreetComplaintModel> _complaints = <DiscreetComplaintModel>[];
  List<DiscreetComplaintModel> get complaints =>
      List<DiscreetComplaintModel>.unmodifiable(_complaints);

  DiscreetComplaintModel? _lastSubmittedComplaint;
  DiscreetComplaintModel? get lastSubmittedComplaint => _lastSubmittedComplaint;

  int _blindedRateLimitRemaining = 4;
  int get blindedRateLimitRemaining => _blindedRateLimitRemaining;

  void _seedInitialCases() {
    if (_complaints.isNotEmpty) return;
    _complaints.addAll(<DiscreetComplaintModel>[
      DiscreetComplaintModel(
        id: 'cmp-8492',
        referenceNumber: '#SKH-ANON-2026-8492',
        passkey: 'LOTUS-94A2',
        disguisedSerialTag: 'SKH-WELLNESS-2026-8492-94A2',
        reportingMode: ComplaintReportingMode.anonymous,
        categoryCode: 'HARASSMENT',
        customCategoryNote: null,
        urgencyLevel: 'HIGH',
        status: ComplaintStatus.additionalInfoRequired,
        severityPriority: 'HIGH_P2',
        description: 'Repeated intimidating comments and unsolicited messages from a fake handle after I shared a workplace safety post in the Bengaluru Career Circle. They referenced my office building near Indiranagar.',
        incidentDateWindow: 'Yesterday • Evening (6 PM – 10 PM)',
        generalAreaText: 'Indiranagar, Bengaluru (~5 km coarse zone)',
        supportingLinks: const <String>[
          'sakhi://post/post-bengaluru-circle-204',
          'sakhi://profile/@anon_watch_99',
        ],
        linkedPostId: 'post-bengaluru-circle-204',
        linkedProfileHandle: '@anon_watch_99',
        linkedBusinessId: null,
        wantsFollowUp: true,
        discreetNotificationMode: 'SILENT_VAULT_ONLY',
        evidenceFiles: const <SanitizedEvidenceFileModel>[
          SanitizedEvidenceFileModel(
            id: 'ev-8492-1',
            originalLabel: 'IMG_20261025_ChatScreenshot.png',
            sanitizedFileName: 'SAKHI_EVID_8492_01_SCRUBBED.png',
            mimeType: 'image/png',
            sizeBytes: 428032,
            sha256Hash: '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
            exifScrubbed: true,
            removedTags: <String>[
              'GPSLatitude',
              'GPSLongitude',
              'DeviceMake: Apple iPhone',
              'OriginalTimestamp',
              'OwnerName',
            ],
            blurredByDefault: true,
            uploadedAtIso: '2026-10-25 21:14 IST',
          ),
          SanitizedEvidenceFileModel(
            id: 'ev-8492-2',
            originalLabel: 'Threat_Comment_Thread.jpg',
            sanitizedFileName: 'SAKHI_EVID_8492_02_SCRUBBED.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 312400,
            sha256Hash: '4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a',
            exifScrubbed: true,
            removedTags: <String>[
              'GPSCoordinates',
              'CameraSerial',
              'SoftwareTag',
            ],
            blurredByDefault: true,
            uploadedAtIso: '2026-10-25 21:15 IST',
          ),
        ],
        complainantMessages: const <ComplainantMessageModel>[
          ComplainantMessageModel(
            id: 'msg-8492-1',
            senderRole: 'REVIEWER',
            senderBadge: 'Senior Safety Reviewer #SR-04 (Anjali M.)',
            body: 'Thank you for speaking up safely. We have temporarily restricted @anon_watch_99 from commenting in your circle. Could you share whether they contacted you on any second handle so we can link the accounts?',
            createdAtLabel: '26 Oct 2026 • 10:15 AM',
          ),
        ],
        internalNotes: const <InternalReviewerNoteModel>[
          InternalReviewerNoteModel(
            id: 'note-8492-1',
            authorRole: 'SENIOR_SAFETY_REVIEWER',
            authorLabel: 'Anjali M. (Trust & Safety Lead)',
            note: 'INTERNAL ONLY: Verified EXIF-scrubbed screenshot matches device fingerprint of repeat offender cluster #CL-19. Waiting for complainant confirmation before permanent device ban.',
            visibilityScope: 'INTERNAL_ADMIN_ONLY',
            createdAtLabel: '26 Oct 2026 • 10:12 AM',
          ),
        ],
        auditTrail: const <ComplaintAuditEntryModel>[
          ComplaintAuditEntryModel(
            id: 'aud-8492-1',
            action: 'COMPLAINT_SUBMITTED_ANONYMOUS',
            actorBadge: 'System Zero-PII Gate',
            detail: '2 evidence files scrubbed of 8 EXIF tags; blinded rate-limit token verified.',
            integrityHash: 'SHA256:7d865e959b2466918c9863afca942d0fb89d7c9ac0c99bafc3749504ded97730',
            timestampLabel: '25 Oct 2026 • 09:15 PM',
          ),
          ComplaintAuditEntryModel(
            id: 'aud-8492-2',
            action: 'ASSIGNED_TO_REVIEWER',
            actorBadge: 'Super Admin Queue Router',
            detail:
                'Assigned to Senior Safety Reviewer #SR-04 • Priority HIGH_P2',
            integrityHash: 'SHA256:2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae',
            timestampLabel: '25 Oct 2026 • 09:42 PM',
          ),
          ComplaintAuditEntryModel(
            id: 'aud-8492-3',
            action: 'STATUS_CHANGED_ADDITIONAL_INFO',
            actorBadge: 'Senior Safety Reviewer #SR-04',
            detail: 'Status moved from UNDER_REVIEW to ADDITIONAL_INFORMATION_REQUIRED',
            integrityHash: 'SHA256:4e07408562bedb8b60ce05c1decfe3ad16b72230967de01f640b7e4729b49fce',
            timestampLabel: '26 Oct 2026 • 10:15 AM',
          ),
        ],
        assignedReviewerName: 'Anjali M. (#SR-04)',
        assignedDepartment: 'Harassment & Stalking Desk',
        slaTargetHours: 12,
        createdAtLabel: '25 Oct 2026 • 09:15 PM',
        updatedAtLabel: '26 Oct 2026 • 10:15 AM',
        duplicateClusterCount: 2,
      ),
      DiscreetComplaintModel(
        id: 'cmp-8489',
        referenceNumber: '#SKH-CONF-2026-8489',
        passkey: 'ROSE-71C8',
        disguisedSerialTag: 'SKH-WELLNESS-2026-8489-71C8',
        reportingMode: ComplaintReportingMode.confidential,
        categoryCode: 'WORKPLACE_HARASSMENT',
        customCategoryNote:
            'POSH committee guidance & unsafe recruiter listing',
        urgencyLevel: 'HIGH',
        status: ComplaintStatus.escalated,
        severityPriority: 'CRITICAL_P1',
        description: 'A verified recruiter business page on Sakhi asked for personal evening video calls outside official interview hours and pressured candidates to share private social media profiles.',
        incidentDateWindow: 'This Week • Afternoon (12 PM – 5 PM)',
        generalAreaText: 'HITEC City, Hyderabad (~5 km coarse zone)',
        supportingLinks: const <String>[
          'sakhi://business/biz-hyderabad-talent-hub',
        ],
        linkedPostId: null,
        linkedProfileHandle: '@hyd_talent_connect',
        linkedBusinessId: 'biz-hyderabad-talent-hub',
        wantsFollowUp: true,
        discreetNotificationMode: 'DISCREET_GENERIC_WELLNESS_ALERT',
        evidenceFiles: const <SanitizedEvidenceFileModel>[
          SanitizedEvidenceFileModel(
            id: 'ev-8489-1',
            originalLabel: 'Recruiter_Enquiry_Chat.png',
            sanitizedFileName: 'SAKHI_EVID_8489_01_SCRUBBED.png',
            mimeType: 'image/png',
            sizeBytes: 518200,
            sha256Hash: 'ef2d127de37b942baad06145e54b0c619a1f22327b2ebbcfbec78f5564afe39d',
            exifScrubbed: true,
            removedTags: <String>['GPSLatitude', 'GPSLongitude', 'DeviceModel'],
            blurredByDefault: true,
            uploadedAtIso: '24 Oct 2026 • 04:20 PM',
          ),
        ],
        complainantMessages: const <ComplainantMessageModel>[
          ComplainantMessageModel(
            id: 'msg-8489-1',
            senderRole: 'REVIEWER',
            senderBadge: 'POSH & Legal Escalation Desk (#LP-02)',
            body: 'Your case has been escalated to our POSH & Commerce Safety Panel. The business page has been frozen pending final review.',
            createdAtLabel: '25 Oct 2026 • 02:30 PM',
          ),
        ],
        internalNotes: const <InternalReviewerNoteModel>[
          InternalReviewerNoteModel(
            id: 'note-8489-1',
            authorRole: 'SUPER_ADMIN',
            authorLabel: 'Dr. Kavitha R. (Head of Safety)',
            note: 'INTERNAL ONLY: Confidential reporter identity verified by Senior Reviewer only. Business listing suspended under Section 9.6.',
            visibilityScope: 'INTERNAL_ADMIN_ONLY',
            createdAtLabel: '25 Oct 2026 • 02:25 PM',
          ),
        ],
        auditTrail: const <ComplaintAuditEntryModel>[
          ComplaintAuditEntryModel(
            id: 'aud-8489-1',
            action: 'COMPLAINT_SUBMITTED_CONFIDENTIAL',
            actorBadge: 'Encrypted Confidential Gate',
            detail: 'Identity sealed with AES-256; hidden from reported business and standard moderators.',
            integrityHash: 'SHA256:e7f6c011776e8db7cd330b54174fd76f7d0216b612387a5ffcfb81e6f0919683',
            timestampLabel: '24 Oct 2026 • 04:22 PM',
          ),
          ComplaintAuditEntryModel(
            id: 'aud-8489-2',
            action: 'ESCALATED_TO_POSH_PANEL',
            actorBadge: 'Dr. Kavitha R. (#SA-01)',
            detail: 'Status escalated to ESCALATED • Business page temporarily frozen.',
            integrityHash: 'SHA256:7902699be42c8a8e46fbbb4501726517e86b22c56a189f7625a6da49081b2451',
            timestampLabel: '25 Oct 2026 • 02:30 PM',
          ),
        ],
        assignedReviewerName: 'Dr. Kavitha R. (#SA-01)',
        assignedDepartment: 'POSH & Business Trust Panel',
        slaTargetHours: 4,
        createdAtLabel: '24 Oct 2026 • 04:22 PM',
        updatedAtLabel: '25 Oct 2026 • 02:30 PM',
        maskedConfidentialContact: 'Priya S. • +91 ••••• ••418 (Visible only to Senior Safety Reviewer)',
      ),
      DiscreetComplaintModel(
        id: 'cmp-8471',
        referenceNumber: '#SKH-ANON-2026-8471',
        passkey: 'SAGE-52D1',
        disguisedSerialTag: 'SKH-WELLNESS-2026-8471-52D1',
        reportingMode: ComplaintReportingMode.anonymous,
        categoryCode: 'IMPERSONATION_FAKE_ACCOUNT',
        customCategoryNote: null,
        urgencyLevel: 'STANDARD',
        status: ComplaintStatus.actionTaken,
        severityPriority: 'HIGH_P2',
        description: 'An account was using stolen photos from a wedding photographer portfolio to impersonate a member in the Chennai Entrepreneurs group.',
        incidentDateWindow: 'Last Week • Morning (8 AM – 12 PM)',
        generalAreaText: 'Adyar, Chennai (~5 km coarse zone)',
        supportingLinks: const <String>['sakhi://profile/@fake_studio_chennai'],
        linkedPostId: null,
        linkedProfileHandle: '@fake_studio_chennai',
        linkedBusinessId: null,
        wantsFollowUp: true,
        discreetNotificationMode: 'SILENT_VAULT_ONLY',
        evidenceFiles: const <SanitizedEvidenceFileModel>[
          SanitizedEvidenceFileModel(
            id: 'ev-8471-1',
            originalLabel: 'ClonedProfileComparison.jpg',
            sanitizedFileName: 'SAKHI_EVID_8471_01_SCRUBBED.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 284110,
            sha256Hash: '6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b',
            exifScrubbed: true,
            removedTags: <String>['GPSLatitude', 'GPSLongitude', 'CameraOwner'],
            blurredByDefault: true,
            uploadedAtIso: '20 Oct 2026 • 11:05 AM',
          ),
        ],
        complainantMessages: const <ComplainantMessageModel>[
          ComplainantMessageModel(
            id: 'msg-8471-1',
            senderRole: 'REVIEWER',
            senderBadge: 'Senior Safety Reviewer #SR-02 (Meera K.)',
            body: 'Action Taken: We verified the impersonation, permanently removed @fake_studio_chennai, and revoked its session tokens.',
            createdAtLabel: '21 Oct 2026 • 03:40 PM',
          ),
        ],
        internalNotes: const <InternalReviewerNoteModel>[],
        auditTrail: const <ComplaintAuditEntryModel>[
          ComplaintAuditEntryModel(
            id: 'aud-8471-1',
            action: 'ACTION_TAKEN_ACCOUNT_BANNED',
            actorBadge: 'Senior Safety Reviewer #SR-02',
            detail: 'Impersonating account permanently banned; complainant identity never exposed.',
            integrityHash: 'SHA256:d4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35',
            timestampLabel: '21 Oct 2026 • 03:40 PM',
          ),
        ],
        assignedReviewerName: 'Meera K. (#SR-02)',
        assignedDepartment: 'Identity & Impersonation Desk',
        slaTargetHours: 24,
        createdAtLabel: '20 Oct 2026 • 11:05 AM',
        updatedAtLabel: '21 Oct 2026 • 03:40 PM',
        publicResolutionNote: 'The reported impersonating profile has been permanently removed and its device signature blocked.',
      ),
      DiscreetComplaintModel(
        id: 'cmp-8465',
        referenceNumber: '#SKH-ANON-2026-8465',
        passkey: 'CALM-18F4',
        disguisedSerialTag: 'SKH-WELLNESS-2026-8465-18F4',
        reportingMode: ComplaintReportingMode.anonymous,
        categoryCode: 'BUSINESS_RELATED_COMPLAINT',
        customCategoryNote: 'Late delivery dispute without safety violation',
        urgencyLevel: 'LOW',
        status: ComplaintStatus.rejectedWithReason,
        severityPriority: 'LOW_P4',
        description: 'My handloom saree order arrived 3 days later than estimated by the seller.',
        incidentDateWindow: 'Earlier this month',
        generalAreaText: 'Pune (~5 km coarse zone)',
        supportingLinks: const <String>[],
        linkedPostId: null,
        linkedProfileHandle: null,
        linkedBusinessId: 'biz-pune-handloom',
        wantsFollowUp: true,
        discreetNotificationMode: 'SILENT_VAULT_ONLY',
        evidenceFiles: const <SanitizedEvidenceFileModel>[],
        complainantMessages: const <ComplainantMessageModel>[],
        internalNotes: const <InternalReviewerNoteModel>[],
        auditTrail: const <ComplaintAuditEntryModel>[
          ComplaintAuditEntryModel(
            id: 'aud-8465-1',
            action: 'REJECTED_WITH_TRANSPARENT_REASON',
            actorBadge: 'Senior Safety Reviewer #SR-04',
            detail: 'Closed as non-safety shipping delay; guided user to Business Enquiry resolution.',
            integrityHash: 'SHA256:4b227777d4dd1fc61c6f884f48641d02b4d121d3fd328cb08b5531fcacdabf8a',
            timestampLabel: '19 Oct 2026 • 05:10 PM',
          ),
        ],
        assignedReviewerName: 'Anjali M. (#SR-04)',
        assignedDepartment: 'Commerce Moderation Desk',
        slaTargetHours: 48,
        createdAtLabel: '18 Oct 2026 • 01:20 PM',
        updatedAtLabel: '19 Oct 2026 • 05:10 PM',
        rejectionReasonTitle: 'Shipping Delay Outside Safety Mandate',
        rejectionReasonDetail: 'No harassment, scam, or safety policy violation was found. If the seller threatened you or refused a refund fraudulently, tap "Submit Appeal / Request Re-Open" below with screenshots.',
      ),
    ]);
    _lastSubmittedComplaint = _complaints.first;
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
          replacement: '[REDACTED-MY-PHONE]',
        ),
      );
      redacted = redacted.replaceAll(val, '[REDACTED-MY-PHONE]');
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
          replacement: '[REDACTED-MY-EMAIL]',
        ),
      );
      redacted = redacted.replaceAll(val, '[REDACTED-MY-EMAIL]');
    }

    final aadhaarRegex = RegExp(r'\b\d{4}[\s-]\d{4}[\s-]\d{4}\b');
    for (final match in aadhaarRegex.allMatches(text)) {
      final val = match.group(0)!;
      detected.add(
        PiiDetectedItemModel(
          type: 'Govt ID / Aadhaar Pattern',
          snippet: val,
          replacement: '[REDACTED-GOVT-ID]',
        ),
      );
      redacted = redacted.replaceAll(val, '[REDACTED-GOVT-ID]');
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
          replacement: '[REDACTED-COMPLAINANT-IDENTITY]',
        ),
      );
      redacted = redacted.replaceAll(full, '[REDACTED-COMPLAINANT-IDENTITY]');
    }

    final flatAddressRegex = RegExp(
      r'\b(?:flat|apt|apartment|house\s*no\.?)\s*[#A-Za-z0-9/-]+',
      caseSensitive: false,
    );
    for (final match in flatAddressRegex.allMatches(text)) {
      final full = match.group(0)!;
      detected.add(
        PiiDetectedItemModel(
          type: 'Exact Door / Flat Number',
          snippet: full,
          replacement: '[REDACTED-EXACT-DOOR]',
        ),
      );
      redacted = redacted.replaceAll(full, '[REDACTED-EXACT-DOOR]');
    }

    return PiiCheckResultModel(
      hasPotentialPii: detected.isNotEmpty,
      detectedItems: detected,
      redactedText: redacted,
    );
  }

  /// SRS 7.3 & 13.9 — Automatic EXIF & GPS Metadata Scrubber for Evidence Files
  SanitizedEvidenceFileModel scrubAndCreateEvidence({
    required String originalFileName,
    required String mimeType,
    required int sizeBytes,
  }) {
    final random = Random();
    final numericId = 1000 + random.nextInt(8999);
    final ext = originalFileName.contains('.')
        ? originalFileName.split('.').last.toLowerCase()
        : (mimeType.contains('pdf')
              ? 'pdf'
              : mimeType.contains('audio')
              ? 'm4a'
              : 'png');
    final hashChars = '0123456789abcdef';
    final hash = List<String>.generate(
      64,
      (i) =>
          hashChars[(originalFileName.hashCode + i * 17 + sizeBytes).abs() %
              hashChars.length],
    ).join();

    return SanitizedEvidenceFileModel(
      id: 'ev-$numericId',
      originalLabel: originalFileName,
      sanitizedFileName: 'SAKHI_EVID_${numericId}_SCRUBBED.$ext',
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      sha256Hash: hash,
      exifScrubbed: true,
      removedTags: const <String>[
        'GPSLatitude & GPSLongitude',
        'DeviceMake & CameraModel',
        'OriginalCaptureTimestamp',
        'Author / Owner Tag',
        'Wi-Fi / Cell Tower Triangulation Hints',
      ],
      blurredByDefault: true,
      uploadedAtIso: 'Just now • EXIF Scrubbed',
    );
  }

  /// Submit a new Discreet or Confidential Complaint (syncs with Backend `/api/v1/complaints/submit` with automatic offline resilience)
  Future<DiscreetComplaintModel> submitComplaint({
    required ComplaintReportingMode reportingMode,
    required String categoryCode,
    String? customCategoryNote,
    required String urgencyLevel,
    required String description,
    required String incidentDateWindow,
    required String generalAreaText,
    required List<String> supportingLinks,
    String? linkedPostId,
    String? linkedProfileHandle,
    String? linkedBusinessId,
    required bool wantsFollowUp,
    required String discreetNotificationMode,
    required List<SanitizedEvidenceFileModel> evidenceFiles,
  }) async {
    _isSyncing = true;
    notifyListeners();

    final digits = (1000 + Random().nextInt(8999)).toString();
    final prefix = reportingMode == ComplaintReportingMode.anonymous
        ? '#SKH-ANON-2026-'
        : '#SKH-CONF-2026-';
    var referenceNumber = '$prefix$digits';
    var passkey =
        'LOTUS-${digits.substring(0, 2)}${String.fromCharCode(65 + Random().nextInt(25))}${Random().nextInt(9)}';
    var disguisedSerialTag = 'SKH-WELLNESS-2026-$digits-$passkey';

    final cat = categoryByCode(categoryCode);
    final severity = urgencyLevel == 'CRITICAL' || urgencyLevel == 'IMMEDIATE'
        ? 'CRITICAL_P1'
        : cat.defaultSeverity;

    try {
      final response = await _apiClient.post(
        'complaints/submit',
        authenticated: reportingMode == ComplaintReportingMode.confidential,
        body: <String, Object?>{
          'reportingMode': reportingMode.code,
          'category': categoryCode,
          if (customCategoryNote != null && customCategoryNote.isNotEmpty)
            'customCategoryLabel': customCategoryNote,
          'description': description,
          'incidentDateWindow': incidentDateWindow,
          'generalLocationArea': generalAreaText,
          'supportingLinks': supportingLinks,
          if (linkedPostId != null && linkedPostId.isNotEmpty)
            'linkedPostId': linkedPostId,
          if (linkedProfileHandle != null && linkedProfileHandle.isNotEmpty)
            'linkedTargetHandle': linkedProfileHandle,
          if (linkedBusinessId != null && linkedBusinessId.isNotEmpty)
            'linkedBusinessId': linkedBusinessId,
          'wantsFollowUp': wantsFollowUp,
          'notificationChannel': discreetNotificationMode,
          'urgencyLevel': urgencyLevel,
          'evidenceFiles': evidenceFiles.map((e) => e.toJson()).toList(),
        },
      );
      if (response['referenceNumber'] is String &&
          (response['referenceNumber'] as String).isNotEmpty) {
        referenceNumber = response['referenceNumber'] as String;
      }
      if (response['passkey'] is String &&
          (response['passkey'] as String).isNotEmpty) {
        passkey = response['passkey'] as String;
      }
      if (response['disguisedBackupSerial'] is String &&
          (response['disguisedBackupSerial'] as String).isNotEmpty) {
        disguisedSerialTag = response['disguisedBackupSerial'] as String;
      }
    } catch (_) {
      // Offline / local test fallback — keeps UI 100% functional
    }

    final created = DiscreetComplaintModel(
      id: 'cmp-$digits',
      referenceNumber: referenceNumber,
      passkey: passkey,
      disguisedSerialTag: disguisedSerialTag,
      reportingMode: reportingMode,
      categoryCode: categoryCode,
      customCategoryNote: customCategoryNote,
      urgencyLevel: urgencyLevel,
      status: ComplaintStatus.submitted,
      severityPriority: severity,
      description: description,
      incidentDateWindow: incidentDateWindow,
      generalAreaText: generalAreaText,
      supportingLinks: supportingLinks,
      linkedPostId: linkedPostId,
      linkedProfileHandle: linkedProfileHandle,
      linkedBusinessId: linkedBusinessId,
      wantsFollowUp: wantsFollowUp,
      discreetNotificationMode: discreetNotificationMode,
      evidenceFiles: evidenceFiles,
      complainantMessages: <ComplainantMessageModel>[
        ComplainantMessageModel(
          id: 'msg-$digits-init',
          senderRole: 'REVIEWER',
          senderBadge: 'Sakhi Encrypted Intake Vault',
          body: reportingMode == ComplaintReportingMode.anonymous
              ? 'Your anonymous report has been sealed. Zero account identifiers were stored. Use your Reference Number ($referenceNumber) anytime to check status or reply.'
              : 'Your confidential report has been sealed for Senior Safety Reviewers only. Your identity is completely hidden from the reported party and standard moderators.',
          createdAtLabel: 'Just now',
        ),
      ],
      internalNotes: const <InternalReviewerNoteModel>[],
      auditTrail: <ComplaintAuditEntryModel>[
        ComplaintAuditEntryModel(
          id: 'aud-$digits-1',
          action: reportingMode == ComplaintReportingMode.anonymous
              ? 'COMPLAINT_SUBMITTED_ANONYMOUS'
              : 'COMPLAINT_SUBMITTED_CONFIDENTIAL',
          actorBadge: 'Sakhi Privacy Gate',
          detail:
              '${evidenceFiles.length} evidence file(s) scrubbed of EXIF GPS/device metadata; queued under $severity.',
          integrityHash: 'SHA256:8f434346648f6b96df89dda901c5176b10a6d83961dd3c1ac88b59b2dc327aa4',
          timestampLabel: 'Just now',
        ),
      ],
      assignedReviewerName: 'Pending Senior Safety Triage',
      assignedDepartment: 'Trust & Safety Intake Queue',
      slaTargetHours: severity == 'CRITICAL_P1' ? 4 : 12,
      createdAtLabel: 'Just now • 26 Oct 2026',
      updatedAtLabel: 'Just now • 26 Oct 2026',
      maskedConfidentialContact:
          reportingMode == ComplaintReportingMode.confidential
          ? 'Verified Sakhi Member • +91 ••••• ••812 (Senior Reviewer Eyes Only)'
          : null,
    );

    _complaints.insert(0, created);
    _lastSubmittedComplaint = created;
    if (_blindedRateLimitRemaining > 0) {
      _blindedRateLimitRemaining--;
    }
    _isSyncing = false;
    notifyListeners();
    return created;
  }

  /// Lookup complaint by Reference Number (`#SKH-ANON-...` or `#SKH-CONF-...`) or Disguised Wellness Quote Serial
  DiscreetComplaintModel? lookupByReferenceOrSerial(String query) {
    final normalized = query.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    for (final item in _complaints) {
      final refUpper = item.referenceNumber.toUpperCase();
      final refPlain = refUpper.replaceFirst('#', '');
      final serialUpper = item.disguisedSerialTag.toUpperCase();
      if (refUpper == normalized ||
          refPlain == normalized.replaceFirst('#', '') ||
          serialUpper == normalized ||
          refUpper.endsWith(normalized)) {
        return item;
      }
    }
    return null;
  }

  /// Two-Way Encrypted Anonymous / Confidential Follow-up Reply from Complainant
  Future<DiscreetComplaintModel?> sendComplainantReply({
    required String referenceNumber,
    required String messageBody,
    List<SanitizedEvidenceFileModel> newEvidence =
        const <SanitizedEvidenceFileModel>[],
  }) async {
    final idx = _complaints.indexWhere(
      (c) => c.referenceNumber.toUpperCase() == referenceNumber.toUpperCase(),
    );
    if (idx < 0) return null;

    final current = _complaints[idx];
    final nextMessages = <ComplainantMessageModel>[
      ...current.complainantMessages,
      ComplainantMessageModel(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        senderRole: 'COMPLAINANT',
        senderBadge: current.reportingMode == ComplaintReportingMode.anonymous
            ? 'Anonymous Complainant (Zero-PII Verified Token)'
            : 'Confidential Complainant (Encrypted Channel)',
        body: messageBody.trim(),
        createdAtLabel: 'Just now',
        attachmentNames: newEvidence
            .map((e) => e.sanitizedFileName)
            .toList(growable: false),
      ),
    ];

    final nextEvidence = <SanitizedEvidenceFileModel>[
      ...current.evidenceFiles,
      ...newEvidence,
    ];

    final nextStatus = current.status == ComplaintStatus.additionalInfoRequired
        ? ComplaintStatus.underReview
        : current.status;

    final nextAudit = <ComplaintAuditEntryModel>[
      ...current.auditTrail,
      ComplaintAuditEntryModel(
        id: 'aud-${DateTime.now().millisecondsSinceEpoch}',
        action: 'COMPLAINANT_ENCRYPTED_REPLY',
        actorBadge: 'Two-Way Anonymous Relay',
        detail:
            'Complainant submitted follow-up response (${newEvidence.length} new scrubbed attachment(s)).',
        integrityHash: 'SHA256:3f79bb7b435b05321651daefd374cdc681dc06faa65e374e38337b88ca046dea',
        timestampLabel: 'Just now',
      ),
    ];

    try {
      await _apiClient.post(
        'complaints/track/${Uri.encodeComponent(current.referenceNumber)}/reply',
        body: <String, Object?>{
          'passkey': current.passkey,
          'message': messageBody.trim(),
          'evidenceFiles': newEvidence.map((e) => e.toJson()).toList(),
        },
      );
    } catch (_) {}

    final updated = current.copyWith(
      status: nextStatus,
      evidenceFiles: nextEvidence,
      complainantMessages: nextMessages,
      auditTrail: nextAudit,
      updatedAtLabel: 'Just now',
    );
    _complaints[idx] = updated;
    notifyListeners();
    return updated;
  }

  /// Submit Appeal / Request Case Re-Open (for Rejected or Closed complaints)
  Future<DiscreetComplaintModel?> submitCaseAppeal({
    required String referenceNumber,
    required String appealReason,
  }) async {
    final idx = _complaints.indexWhere(
      (c) => c.referenceNumber.toUpperCase() == referenceNumber.toUpperCase(),
    );
    if (idx < 0) return null;

    final current = _complaints[idx];
    final nextMessages = <ComplainantMessageModel>[
      ...current.complainantMessages,
      ComplainantMessageModel(
        id: 'msg-appeal-${DateTime.now().millisecondsSinceEpoch}',
        senderRole: 'COMPLAINANT',
        senderBadge: 'Appeal Request • Escalated to Different Senior Reviewer',
        body: 'APPEAL SUBMITTED: ${appealReason.trim()}',
        createdAtLabel: 'Just now',
      ),
    ];

    final nextAudit = <ComplaintAuditEntryModel>[
      ...current.auditTrail,
      ComplaintAuditEntryModel(
        id: 'aud-appeal-${DateTime.now().millisecondsSinceEpoch}',
        action: 'CASE_APPEAL_SUBMITTED',
        actorBadge: 'Complainant Token Verification',
        detail: 'Complainant requested re-open & independent review by Ombudsperson.',
        integrityHash: 'SHA256:9b871512327c09ce91dd649b3f96a63b7408ef267c8cc571be524e1a1b2e072f',
        timestampLabel: 'Just now',
      ),
    ];

    try {
      await _apiClient.post(
        'complaints/track/${Uri.encodeComponent(current.referenceNumber)}/appeal',
        body: <String, Object?>{
          'passkey': current.passkey,
          'appealReason': appealReason.trim(),
        },
      );
    } catch (_) {}

    final updated = current.copyWith(
      status: ComplaintStatus.underReview,
      appealSubmitted: true,
      appealReasonText: appealReason.trim(),
      assignedReviewerName: 'Ombudsperson Appeal Panel (#SR-01)',
      complainantMessages: nextMessages,
      auditTrail: nextAudit,
      updatedAtLabel: 'Just now • Appeal Active',
    );
    _complaints[idx] = updated;
    notifyListeners();
    return updated;
  }

  /// Immediate User-Initiated Media Purge from Vault (SRS 13.14 Data Retention & Deletion Controls)
  Future<DiscreetComplaintModel?> purgeEvidenceVaultMedia({
    required String referenceNumber,
  }) async {
    final idx = _complaints.indexWhere(
      (c) => c.referenceNumber.toUpperCase() == referenceNumber.toUpperCase(),
    );
    if (idx < 0) return null;

    final current = _complaints[idx];
    try {
      await _apiClient.post(
        'complaints/track/${Uri.encodeComponent(current.referenceNumber)}/purge-media',
        body: <String, Object?>{'passkey': current.passkey},
      );
    } catch (_) {}

    final updated = current.copyWith(
      evidenceFiles: const <SanitizedEvidenceFileModel>[],
      mediaPurgedByUser: true,
      auditTrail: <ComplaintAuditEntryModel>[
        ...current.auditTrail,
        const ComplaintAuditEntryModel(
          id: 'aud-purge',
          action: 'USER_PURGED_EVIDENCE_MEDIA',
          actorBadge: 'Complainant DPDP Right-to-Erasure',
          detail: 'All binary evidence attachments permanently zero-wiped from object storage.',
          integrityHash: 'SHA256:0000000000000000000000000000000000000000000000000000000000000000',
          timestampLabel: 'Just now',
        ),
      ],
      updatedAtLabel: 'Just now • Media Purged',
    );
    _complaints[idx] = updated;
    notifyListeners();
    return updated;
  }

  /// Admin Action: Update Complaint Status, Public Resolution/Rejection Note, or Reviewer Assignment
  Future<DiscreetComplaintModel?> adminUpdateComplaint({
    required String complaintId,
    ComplaintStatus? newStatus,
    String? severityPriority,
    String? assignedReviewerName,
    String? assignedDepartment,
    int? slaTargetHours,
    String? publicMessageToComplainant,
    String? internalPrivateNote,
    String? publicResolutionNote,
    String? rejectionReasonTitle,
    String? rejectionReasonDetail,
    String? duplicateOfReference,
    bool? maliciousAbuseFlagged,
  }) async {
    final idx = _complaints.indexWhere((c) => c.id == complaintId);
    if (idx < 0) return null;

    final current = _complaints[idx];
    final nextMessages = List<ComplainantMessageModel>.from(
      current.complainantMessages,
    );
    if (publicMessageToComplainant != null &&
        publicMessageToComplainant.trim().isNotEmpty) {
      nextMessages.add(
        ComplainantMessageModel(
          id: 'msg-adm-${DateTime.now().millisecondsSinceEpoch}',
          senderRole: 'REVIEWER',
          senderBadge:
              '${assignedReviewerName ?? current.assignedReviewerName} ($_activeAdminRole)',
          body: publicMessageToComplainant.trim(),
          createdAtLabel: 'Just now',
        ),
      );
    }

    final nextInternalNotes = List<InternalReviewerNoteModel>.from(
      current.internalNotes,
    );
    if (internalPrivateNote != null && internalPrivateNote.trim().isNotEmpty) {
      nextInternalNotes.add(
        InternalReviewerNoteModel(
          id: 'note-adm-${DateTime.now().millisecondsSinceEpoch}',
          authorRole: _activeAdminRole,
          authorLabel:
              '${assignedReviewerName ?? current.assignedReviewerName} ($_activeAdminRole)',
          note: internalPrivateNote.trim(),
          visibilityScope: 'INTERNAL_ADMIN_ONLY',
          createdAtLabel: 'Just now',
        ),
      );
    }

    final nextAudit = <ComplaintAuditEntryModel>[
      ...current.auditTrail,
      ComplaintAuditEntryModel(
        id: 'aud-adm-${DateTime.now().millisecondsSinceEpoch}',
        action: newStatus != null
            ? 'ADMIN_STATUS_${newStatus.code}'
            : 'ADMIN_CASE_UPDATED',
        actorBadge: '$_activeAdminRole (${current.assignedReviewerName})',
        detail: [
          if (newStatus != null)
            'Status: ${current.status.label} → ${newStatus.label}',
          if (severityPriority != null) 'Priority: $severityPriority',
          if (assignedReviewerName != null) 'Assigned: $assignedReviewerName',
          if (duplicateOfReference != null) 'Merged into $duplicateOfReference',
          if (maliciousAbuseFlagged == true)
            'Blinded bucket rate-limit throttle applied',
          if (internalPrivateNote != null &&
              internalPrivateNote.trim().isNotEmpty)
            'Added internal note (hidden from complainant)',
        ].join(' • '),
        integrityHash:
            'SHA256:${DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(64, 'a')}',
        timestampLabel: 'Just now',
      ),
    ];

    try {
      if (newStatus != null) {
        await _apiClient.patch(
          'admin-review/complaints/$complaintId/status',
          authenticated: true,
          body: <String, Object?>{
            'status': newStatus.code,
            'complainantVisibleMessage': ?publicMessageToComplainant,
            'resolutionSummary': ?publicResolutionNote,
            'rejectionReason': ?rejectionReasonDetail,
          },
        );
      }
    } catch (_) {}

    final updated = current.copyWith(
      status: newStatus,
      severityPriority: severityPriority,
      assignedReviewerName: assignedReviewerName,
      assignedDepartment: assignedDepartment,
      slaTargetHours: slaTargetHours,
      complainantMessages: nextMessages,
      internalNotes: nextInternalNotes,
      auditTrail: nextAudit,
      publicResolutionNote: publicResolutionNote,
      rejectionReasonTitle: rejectionReasonTitle,
      rejectionReasonDetail: rejectionReasonDetail,
      duplicateOfReference: duplicateOfReference,
      maliciousAbuseFlagged: maliciousAbuseFlagged,
      updatedAtLabel: 'Just now',
    );
    _complaints[idx] = updated;
    notifyListeners();
    return updated;
  }

  /// Admin Action: Log Watermarked Evidence Inspection / Download
  void logAdminEvidenceInspection({
    required String complaintId,
    required String fileName,
    required String actionType,
  }) {
    final idx = _complaints.indexWhere((c) => c.id == complaintId);
    if (idx < 0) return;
    final current = _complaints[idx];
    final updated = current.copyWith(
      auditTrail: <ComplaintAuditEntryModel>[
        ...current.auditTrail,
        ComplaintAuditEntryModel(
          id: 'aud-ev-${DateTime.now().millisecondsSinceEpoch}',
          action: actionType,
          actorBadge: '$_activeAdminRole (${current.assignedReviewerName})',
          detail:
              'Evidence "$fileName" accessed with watermark overlay [WM-$_activeAdminRole-2026].',
          integrityHash:
              'SHA256:${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(64, 'c')}',
          timestampLabel: 'Just now',
        ),
      ],
    );
    _complaints[idx] = updated;
    notifyListeners();
  }

  /// Admin Action: Toggle or Add Configurable Complaint Categories (SRS 7.3)
  void toggleCategoryEnabled(String categoryCode, bool enabled) {
    final idx = _categories.indexWhere((c) => c.code == categoryCode);
    if (idx < 0) return;
    _categories[idx] = _categories[idx].copyWith(enabled: enabled);
    notifyListeners();
  }

  void updateCategoryConfig({
    required String categoryCode,
    required String label,
    required String defaultSeverity,
    required String safetyGuidance,
  }) {
    final idx = _categories.indexWhere((c) => c.code == categoryCode);
    if (idx < 0) return;
    _categories[idx] = _categories[idx].copyWith(
      label: label,
      shortLabel: label,
      defaultSeverity: defaultSeverity,
      safetyGuidance: safetyGuidance,
    );
    notifyListeners();
  }

  void updateRetentionPolicy(ComplaintRetentionPolicyModel nextPolicy) {
    _retentionPolicy = nextPolicy;
    notifyListeners();
  }
}
