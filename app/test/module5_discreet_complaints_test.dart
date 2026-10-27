import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/navigation/app_routes.dart';
import 'package:women_safety_app/core/theme/app_theme.dart';
import 'package:women_safety_app/features/auth/backend_api_client.dart';
import 'package:women_safety_app/features/complaints/models/complaint_models.dart';
import 'package:women_safety_app/features/complaints/screens/complaint_admin_console_screen.dart';
import 'package:women_safety_app/features/complaints/screens/complaint_submission_wizard_screen.dart';
import 'package:women_safety_app/features/complaints/screens/complaint_tracking_screens.dart';
import 'package:women_safety_app/features/complaints/screens/discreet_complaint_hub_screen.dart';
import 'package:women_safety_app/features/complaints/services/complaint_controller.dart';

/// Isolated test-only API client that simulates the backend contract for widget/unit tests
/// without polluting production code with fake fallback records.
class _FakeComplaintBackendApiClient extends BackendApiClient {
  bool shouldFail = false;
  final Map<String, Map<String, dynamic>> storedComplaints =
      <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    if (shouldFail) {
      throw const BackendApiException(
        statusCode: 503,
        code: 'network_unavailable',
        message: 'Simulated backend offline error.',
      );
    }
    if (path.startsWith('complaints/categories')) {
      return <String, dynamic>{
        'categories': <Map<String, dynamic>>[],
        'retentionPolicy': <String, dynamic>{
          'closedEvidenceRetentionDays': 90,
          'rejectedReportRetentionDays': 30,
          'technicalRateLimitLogDays': 14,
        },
      };
    }
    if (path.startsWith('complaints/track/')) {
      final uri = Uri.parse('http://localhost/$path');
      final ref = Uri.decodeComponent(uri.pathSegments.last).toUpperCase();
      final pass = uri.queryParameters['passkey'] ?? '';
      final found = storedComplaints[ref];
      if (found == null) {
        throw const BackendApiException(
          statusCode: 404,
          code: 'not_found',
          message: 'Complaint not found.',
        );
      }
      if (pass.isEmpty || found['passkey'] != pass) {
        throw const BackendApiException(
          statusCode: 403,
          code: 'forbidden',
          message: 'Invalid check-in passkey.',
        );
      }
      return <String, dynamic>{'found': true, 'complaint': found};
    }
    if (path.startsWith('admin-review/complaints')) {
      return <String, dynamic>{
        'metrics': <String, dynamic>{
          'totalComplaints': storedComplaints.length,
          'openComplaintsCount': storedComplaints.length,
          'urgentP1Count': 0,
          'anonymousPercentage': 100,
          'confidentialPercentage': 0,
          'duplicateClustersCount': 0,
          'flaggedMaliciousAbuseCount': 0,
          'medianTriageHours': 0,
        },
        'complaints': storedComplaints.values.toList(),
        'categories': <Map<String, dynamic>>[],
        'retentionPolicy': <String, dynamic>{
          'closedEvidenceRetentionDays': 90,
          'rejectedReportRetentionDays': 30,
          'technicalRateLimitLogDays': 14,
        },
      };
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?> body = const <String, Object?>{},
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    if (shouldFail) {
      throw const BackendApiException(
        statusCode: 503,
        code: 'network_unavailable',
        message: 'Simulated backend offline error.',
      );
    }
    if (path == 'complaints/scrub-metadata') {
      return <String, dynamic>{
        'sanitizedFile': <String, dynamic>{
          'id': 'ev_test_01',
          'fileName': 'evidence_redacted_01.png',
          'originalFileNameRedacted': '[PURGED]',
          'contentType': body['contentType'] ?? 'image/png',
          'byteSize': body['byteSize'] ?? 1024,
          'sha256Digest':
              '8f4c2b910e4a71239c5812b74a0f12e9b814c6a2039481726354819203a4e92a',
          'exifGpsStripped': true,
          'deviceMetadataStripped': true,
          'visualBlurApplied': true,
          'scrubbedFields': <String>['EXIF.GPSLatitude', 'EXIF.DeviceModel'],
          'uploadedAt': '2026-10-26T10:00:00Z',
        },
      };
    }
    if (path == 'complaints') {
      const ref = '#SKH-ANON-2026-9001';
      const passkey = 'LOTUS-901-SAFE';
      final record = <String, dynamic>{
        'id': 'cmp-9001',
        'referenceNumber': ref,
        'passkey': passkey,
        'disguisedBackupSerial': 'SKH-WELLNESS-2026-9001::$passkey',
        'reportingMode': body['reportingMode'] ?? 'ANONYMOUS',
        'categorySlug': body['categorySlug'] ?? 'harassment',
        'categoryTitle': 'Harassment',
        'urgency': body['urgency'] ?? 'PAST_INCIDENT',
        'description': body['description'] ?? '',
        'approximateDateLabel': body['approximateDateLabel'] ?? 'Today',
        'approximateTimeWindow': body['approximateTimeWindow'] ?? 'Evening',
        'locationType': body['locationType'] ?? 'COARSE_AREA',
        'generalLocationLabel': body['generalLocationLabel'] ?? 'Online',
        'supportingLinks': body['supportingLinks'] ?? <String>[],
        'evidenceFiles': body['evidenceFiles'] ?? <Map<String, dynamic>>[],
        'status': 'SUBMITTED',
        'severity': 'S2_HIGH',
        'priority': 'P1_URGENT',
        'complainantMessages': <Map<String, dynamic>>[],
        'internalNotes': <Map<String, dynamic>>[],
        'auditHistory': <Map<String, dynamic>>[],
        'createdAt': '2026-10-26T10:00:00Z',
        'updatedAt': '2026-10-26T10:00:00Z',
      };
      storedComplaints[ref] = record;
      return <String, dynamic>{
        'submitted': true,
        'referenceNumber': ref,
        'passkey': passkey,
        'disguisedBackupSerial': record['disguisedBackupSerial'],
        'complaint': record,
      };
    }
    if (path.endsWith('/reply')) {
      final ref = '#SKH-ANON-2026-9001';
      final rec = Map<String, dynamic>.from(storedComplaints[ref]!);
      rec['status'] = 'UNDER_REVIEW';
      rec['complainantMessages'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'msg-1',
          'senderRole': 'COMPLAINANT_ANONYMOUS',
          'senderLabel': 'Anonymous Reporter',
          'message': body['message'],
          'createdAt': 'Just now',
        },
      ];
      storedComplaints[ref] = rec;
      return <String, dynamic>{'updated': true, 'complaint': rec};
    }
    if (path.endsWith('/appeal')) {
      final ref = '#SKH-ANON-2026-9001';
      final rec = Map<String, dynamic>.from(storedComplaints[ref]!);
      rec['status'] = 'ESCALATED';
      storedComplaints[ref] = rec;
      return <String, dynamic>{'appealed': true, 'complaint': rec};
    }
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = false,
    Map<String, String>? headers,
  }) async {
    final ref = '#SKH-ANON-2026-9001';
    final rec = Map<String, dynamic>.from(storedComplaints[ref]!);
    rec['mediaPurgedAt'] = '2026-10-26T10:05:00Z';
    rec['evidenceFiles'] = <Map<String, dynamic>>[];
    storedComplaints[ref] = rec;
    return <String, dynamic>{'purged': true, 'complaint': rec};
  }
}

Widget _wrapWithMaterialApp(Widget home) {
  final routes = Map<String, WidgetBuilder>.from(AppRoutes.routes)
    ..remove(AppRoutes.root);
  return MaterialApp(
    theme: AppTheme.lightTheme,
    routes: routes,
    home: home,
  );
}

void main() {
  group('Module 5 — Real Data, Validation & Privacy Invariants', () {
    test('starts with an empty complaint list (zero fabricated records)', () {
      final freshController = SakhiComplaintController(
        apiClient: _FakeComplaintBackendApiClient(),
      );
      expect(freshController.complaints, isEmpty);
      expect(freshController.categories.length, 10);
    });

    test('exposes all 10 configurable SRS Section 7.2 categories', () {
      final controller = SakhiComplaintController.instance;
      final codes = controller.categories.map((c) => c.code).toSet();
      expect(
        codes,
        containsAll(<String>[
          'harassment',
          'online_abuse_cyberbullying',
          'stalking_unwanted_contact',
          'workplace_misconduct',
          'public_place_safety',
          'fraud_suspicious_activity',
          'discrimination',
          'domestic_interpersonal_safety',
          'business_related_complaints',
          'other',
        ]),
      );
    });

    test('detects and redacts accidental self-identifying PII clues', () {
      final controller = SakhiComplaintController.instance;
      const sample =
          'My name is Riya Sharma and my phone is +91 9876543210, email riya@example.com at Flat #402.';
      final res = controller.analyzeTextForSelfIdentifyingClues(sample);
      expect(res.hasPotentialPii, isTrue);
      expect(res.detectedItems.length, greaterThanOrEqualTo(3));
      expect(res.redactedText, isNot(contains('9876543210')));
      expect(res.redactedText, isNot(contains('riya@example.com')));
    });

    test('strips binary JPEG EXIF/APP1 markers on client before upload', () {
      final controller = SakhiComplaintController.instance;
      final jpegWithExif = Uint8List.fromList(<int>[
        0xff, 0xd8, // SOI
        0xff, 0xe1, 0x00, 0x08, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // APP1 EXIF
        0xff, 0xd9, // EOI
      ]);
      final stripped = controller.stripClientBinaryMetadata(jpegWithExif);
      expect(stripped, equals(Uint8List.fromList(<int>[0xff, 0xd8, 0xff, 0xd9])));
    });

    test('never invents a fake reference number when the backend fails', () async {
      final fakeClient = _FakeComplaintBackendApiClient()..shouldFail = true;
      final controller = SakhiComplaintController(apiClient: fakeClient);

      await expectLater(
        () => controller.submitComplaint(
          reportingMode: ComplaintReportingMode.anonymous,
          categoryCode: 'harassment',
          urgencyLevel: 'PAST_INCIDENT',
          description:
              'Repeated harassing messages sent in the community group.',
          approximateDateLabel: 'Today',
          approximateTimeWindow: 'Evening',
          locationType: 'COARSE_AREA',
          supportingLinks: const <String>[],
          wantsFollowUp: true,
          discreetNotificationMode: 'SILENT_VAULT_ONLY',
          acknowledgedNonPoliceLegalNotice: true,
          evidenceFiles: const <SanitizedEvidenceFileModel>[],
        ),
        throwsA(isA<BackendApiException>()),
      );
      expect(controller.complaints, isEmpty);
    });

    test(
      'executes full server-backed lifecycle: scrub, submit, passkey lookup, reply, appeal, and purge',
      () async {
        final fakeClient = _FakeComplaintBackendApiClient();
        final controller = SakhiComplaintController(apiClient: fakeClient);

        final scrubbed = await controller.uploadAndScrubEvidenceOnServer(
          originalFileName: 'Proof.png',
          mimeType: 'image/png',
          fileBytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]),
        );
        expect(scrubbed.exifScrubbed, isTrue);

        final created = await controller.submitComplaint(
          reportingMode: ComplaintReportingMode.anonymous,
          categoryCode: 'online_abuse_cyberbullying',
          urgencyLevel: 'HAPPENING_NOW',
          description:
              'Coordinated harassment thread in community group targeting members.',
          approximateDateLabel: 'Today',
          approximateTimeWindow: 'Evening',
          locationType: 'ONLINE_IN_APP',
          supportingLinks: const <String>['sakhi://post/test-99'],
          wantsFollowUp: true,
          discreetNotificationMode: 'SILENT_VAULT_ONLY',
          acknowledgedNonPoliceLegalNotice: true,
          evidenceFiles: <SanitizedEvidenceFileModel>[scrubbed],
        );

        expect(created.referenceNumber, '#SKH-ANON-2026-9001');
        expect(created.passkey, 'LOTUS-901-SAFE');

        final lookedUp = await controller.lookupComplaintOnServer(
          referenceOrSerial: created.referenceNumber,
          passkey: created.passkey,
        );
        expect(lookedUp.referenceNumber, created.referenceNumber);

        final afterReply = await controller.sendComplainantReply(
          referenceNumber: created.referenceNumber,
          passkey: created.passkey,
          messageBody: 'Adding second screenshot context.',
        );
        expect(afterReply.status, ComplaintStatus.underReview);

        final afterAppeal = await controller.submitCaseAppeal(
          referenceNumber: created.referenceNumber,
          passkey: created.passkey,
          appealReason: 'Escalating threat requires independent review.',
        );
        expect(afterAppeal.status, ComplaintStatus.escalated);

        final afterPurge = await controller.purgeEvidenceVaultMedia(
          referenceNumber: created.referenceNumber,
          passkey: created.passkey,
        );
        expect(afterPurge.mediaPurgedByUser, isTrue);
      },
    );
  });

  group('Module 5 — Live Flutter UI Screens & Step Validation', () {
    setUp(() {
      SakhiComplaintController.instance.setApiClientForTesting(
        _FakeComplaintBackendApiClient(),
      );
    });

    testWidgets(
      'DiscreetComplaintHubScreen renders hero, legal notice, modes, and quick exit',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithMaterialApp(const DiscreetComplaintHubScreen()),
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Discreet Complaint Hub'), findsOneWidget);
        expect(
          find.text('Speak Up Safely, On Your Own Terms'),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('m5-start-discreet-report-button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('m5-legal-disclaimer-banner')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('m5-quick-exit-button')), findsOneWidget);
        // End-user hub must never expose Admin Complaint Console card
        expect(
          find.byKey(const Key('m5-open-admin-console-card')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'ComplaintSubmissionWizardScreen blocks advancing past Step 3 when description is empty and advances once valid',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithMaterialApp(const ComplaintSubmissionWizardScreen()),
        );
        await tester.pump(const Duration(milliseconds: 200));

        // Step 1 -> Step 2
        await tester.tap(find.byKey(const Key('m5-wizard-primary-next-button')));
        await tester.pumpAndSettle();
        expect(
          find.text('What Kind of Concern Are You Reporting?'),
          findsOneWidget,
        );

        // Step 2 -> Step 3
        await tester.tap(find.byKey(const Key('m5-wizard-primary-next-button')));
        await tester.pumpAndSettle();
        expect(find.text('Describe What Happened Safely'), findsOneWidget);

        // Try to advance Step 3 with empty description -> blocked with validation error banner!
        await tester.tap(find.byKey(const Key('m5-wizard-primary-next-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('m5-wizard-validation-error-banner')),
          findsOneWidget,
        );

        // Verify general location input starts empty (no pre-filled text requiring backspace)
        final locField = tester.widget<TextField>(
          find.byKey(const Key('m5-general-location-input')),
        );
        expect(locField.controller?.text ?? '', isEmpty);

        // Numbers-only description (>= 20 chars) is blocked with validation error
        await tester.enterText(
          find.byKey(const Key('m5-incident-description-input')),
          '1234567890123456789012345',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('m5-wizard-primary-next-button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('m5-wizard-validation-error-banner')),
          findsOneWidget,
        );

        // Enter a valid >= 20 char description and advance to Step 4
        await tester.enterText(
          find.byKey(const Key('m5-incident-description-input')),
          'Repeated intimidating messages sent after a community safety discussion.',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('m5-wizard-primary-next-button')));
        await tester.pumpAndSettle();
        expect(
          find.text('Encrypted Evidence Vault & Server EXIF Scrubber'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ComplaintTrackingLookupScreen renders read-only 7-stage timeline for preloaded complaint',
      (tester) async {
        const sample = DiscreetComplaintModel(
          id: 'cmp-9001',
          referenceNumber: '#SKH-ANON-2026-9001',
          passkey: 'LOTUS-901-SAFE',
          disguisedSerialTag: 'SKH-WELLNESS-2026-9001::LOTUS-901-SAFE',
          reportingMode: ComplaintReportingMode.anonymous,
          categoryCode: 'harassment',
          categoryTitle: 'Harassment',
          customCategoryNote: null,
          urgencyLevel: 'PAST_INCIDENT',
          status: ComplaintStatus.submitted,
          severity: 'S2_HIGH',
          priority: 'P1_URGENT',
          description: 'Verified test complaint record.',
          approximateDateLabel: 'Today',
          approximateTimeWindow: 'Evening',
          locationType: 'COARSE_AREA',
          generalAreaText: 'Online',
          supportingLinks: <String>[],
          linkedPostId: null,
          linkedProfileHandle: null,
          linkedBusinessId: null,
          wantsFollowUp: true,
          discreetNotificationMode: 'SILENT_VAULT_ONLY',
          evidenceFiles: <SanitizedEvidenceFileModel>[],
          complainantMessages: <ComplainantMessageModel>[],
          internalNotes: <InternalReviewerNoteModel>[],
          auditTrail: <ComplaintAuditEntryModel>[],
          assignedReviewerName: 'Pending Senior Safety Triage',
          assignedDepartment: 'Trust & Safety Desk',
          slaTargetHours: 4,
          createdAtLabel: 'Just now',
          updatedAtLabel: 'Just now',
        );

        await tester.pumpWidget(
          _wrapWithMaterialApp(
            const ComplaintTrackingLookupScreen(
              initialPreloadedComplaint: sample,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Track Complaint Status'), findsOneWidget);
        for (final st in ComplaintStatus.values) {
          expect(
            find.byKey(Key('m5-status-stage-chip-${st.code}')),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      'ComplaintAdminConsoleScreen renders empty queue honesty state and RBAC role selector',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithMaterialApp(const ComplaintAdminConsoleScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Admin Complaint Console'), findsOneWidget);
        expect(
          find.byKey(const Key('m5-admin-role-chip-STANDARD_MODERATOR')),
          findsOneWidget,
        );
        expect(
          find.text('No Complaints in Queue (0 Database Records)'),
          findsOneWidget,
        );
      },
    );
  });
}
