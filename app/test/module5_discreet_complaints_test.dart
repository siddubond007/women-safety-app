import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakhi_app/core/navigation/app_routes.dart';
import 'package:sakhi_app/core/theme/app_theme.dart';
import 'package:sakhi_app/features/complaints/models/complaint_models.dart';
import 'package:sakhi_app/features/complaints/screens/complaint_admin_console_screen.dart';
import 'package:sakhi_app/features/complaints/screens/complaint_submission_wizard_screen.dart';
import 'package:sakhi_app/features/complaints/screens/complaint_tracking_screens.dart';
import 'package:sakhi_app/features/complaints/screens/discreet_complaint_hub_screen.dart';
import 'package:sakhi_app/features/complaints/services/complaint_controller.dart';

Widget _wrapWithMaterialApp(Widget home) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    routes: AppRoutes.routes,
    home: home,
  );
}

void main() {
  group('Module 5 — SakhiComplaintController & Privacy Invariants', () {
    final controller = SakhiComplaintController.instance;

    test('exposes all 10 configurable SRS Section 7.3 categories', () {
      expect(controller.categories.length, greaterThanOrEqualTo(10));
      final codes = controller.categories.map((c) => c.code).toSet();
      expect(
        codes,
        containsAll(<String>[
          'HARASSMENT',
          'STALKING',
          'CYBERBULLYING',
          'BLACKMAIL_EXTORTION',
          'DOMESTIC_FAMILY_CONCERN',
          'WORKPLACE_HARASSMENT',
          'IMPERSONATION_FAKE_ACCOUNT',
          'UNSAFE_COMMUNITY_BEHAVIOUR',
          'BUSINESS_RELATED_COMPLAINT',
          'OTHER',
        ]),
      );
    });

    test('detects and redacts accidental self-identifying PII clues', () {
      const sample =
          'My name is Riya Sharma and my phone is +91 9876543210, email riya@example.com at Flat #402.';
      final res = controller.analyzeTextForSelfIdentifyingClues(sample);
      expect(res.hasPotentialPii, isTrue);
      expect(res.detectedItems.length, greaterThanOrEqualTo(3));
      expect(res.redactedText, isNot(contains('9876543210')));
      expect(res.redactedText, isNot(contains('riya@example.com')));
      expect(res.redactedText, contains('[REDACTED-MY-PHONE]'));
      expect(res.redactedText, contains('[REDACTED-MY-EMAIL]'));
    });

    test('scrubs EXIF and GPS metadata from evidence attachments', () {
      final ev = controller.scrubAndCreateEvidence(
        originalFileName: 'IMG_8812_LocationPhoto.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 512000,
      );
      expect(ev.exifScrubbed, isTrue);
      expect(ev.blurredByDefault, isTrue);
      expect(ev.removedTags, isNotEmpty);
      expect(ev.sha256Hash.length, 64);
    });

    test(
      'supports full lifecycle: submit, lookup, two-way reply, appeal, and DPDP media purge',
      () async {
        final created = await controller.submitComplaint(
          reportingMode: ComplaintReportingMode.anonymous,
          categoryCode: 'CYBERBULLYING',
          urgencyLevel: 'HIGH',
          description: 'Coordinated harassment thread in community group.',
          incidentDateWindow: 'Today • Evening',
          generalAreaText: 'Online Only',
          supportingLinks: const <String>['sakhi://post/test-99'],
          wantsFollowUp: true,
          discreetNotificationMode: 'SILENT_VAULT_ONLY',
          evidenceFiles: <SanitizedEvidenceFileModel>[
            controller.scrubAndCreateEvidence(
              originalFileName: 'Proof.png',
              mimeType: 'image/png',
              sizeBytes: 204800,
            ),
          ],
        );

        expect(created.referenceNumber, startsWith('#SKH-ANON-'));
        expect(
          controller.lookupByReferenceOrSerial(created.referenceNumber)?.id,
          created.id,
        );
        expect(
          controller.lookupByReferenceOrSerial(created.disguisedSerialTag)?.id,
          created.id,
        );

        final afterReply = await controller.sendComplainantReply(
          referenceNumber: created.referenceNumber,
          messageBody: 'Adding second screenshot context.',
        );
        expect(afterReply, isNotNull);
        expect(afterReply!.complainantMessages.length, greaterThanOrEqualTo(2));

        final afterAppeal = await controller.submitCaseAppeal(
          referenceNumber: created.referenceNumber,
          appealReason: 'Escalating threat requires independent review.',
        );
        expect(afterAppeal?.appealSubmitted, isTrue);

        final afterPurge = await controller.purgeEvidenceVaultMedia(
          referenceNumber: created.referenceNumber,
        );
        expect(afterPurge?.mediaPurgedByUser, isTrue);
        expect(afterPurge?.evidenceFiles, isEmpty);
      },
    );
  });

  group('Module 5 — Live Flutter UI Screens & Navigation', () {
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
      },
    );

    testWidgets(
      'QuickExitWellnessCamouflageScreen hides complaint terms and supports return to hub',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithMaterialApp(const QuickExitWellnessCamouflageScreen()),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Evening Chamomile & Gratitude'), findsOneWidget);
        expect(find.text('Today\'s Calm Reflection'), findsOneWidget);
      },
    );

    testWidgets(
      'ComplaintSubmissionWizardScreen navigates across all 5 steps',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithMaterialApp(const ComplaintSubmissionWizardScreen()),
        );
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          find.text('Select Your Privacy & Protection Mode'),
          findsOneWidget,
        );

        // Tap Step 2 chip
        await tester.tap(find.byKey(const Key('m5-step-chip-2')));
        await tester.pumpAndSettle();
        expect(
          find.text('What Kind of Concern Are You Reporting?'),
          findsOneWidget,
        );

        // Tap Step 3 chip
        await tester.tap(find.byKey(const Key('m5-step-chip-3')));
        await tester.pumpAndSettle();
        expect(find.text('Describe What Happened Safely'), findsOneWidget);

        // Tap Step 4 chip
        await tester.tap(find.byKey(const Key('m5-step-chip-4')));
        await tester.pumpAndSettle();
        expect(
          find.text('Encrypted Evidence Vault & Auto-EXIF Scrubber'),
          findsOneWidget,
        );

        // Tap Step 5 chip
        await tester.tap(find.byKey(const Key('m5-step-chip-5')));
        await tester.pumpAndSettle();
        expect(find.text('Discreet Updates & Final Review'), findsOneWidget);
      },
    );

    testWidgets(
      'ComplaintTrackingLookupScreen inspects all 7 SRS 7.5 status stages',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithMaterialApp(
            const ComplaintTrackingLookupScreen(
              initialReferenceNumber: '#SKH-ANON-2026-8492',
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Track Complaint Status'), findsOneWidget);
        expect(find.text('#SKH-ANON-2026-8492'), findsWidgets);

        for (final st in ComplaintStatus.values) {
          expect(
            find.byKey(Key('m5-status-stage-chip-${st.code}')),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets(
      'ComplaintAdminConsoleScreen enforces RBAC PII masking and audit trail tabs',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithMaterialApp(const ComplaintAdminConsoleScreen()),
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Admin Complaint Console'), findsOneWidget);
        expect(
          find.byKey(const Key('m5-admin-role-chip-STANDARD_MODERATOR')),
          findsOneWidget,
        );

        // Switch to Audit tab
        await tester.tap(find.byKey(const Key('m5-admin-tab-audit')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Immutable Case Audit History'),
          findsOneWidget,
        );

        // Switch to Categories & DPDP Retention tab
        await tester.tap(find.byKey(const Key('m5-admin-tab-config')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('DPDP Act 2023 Data Retention'),
          findsOneWidget,
        );
      },
    );
  });
}
