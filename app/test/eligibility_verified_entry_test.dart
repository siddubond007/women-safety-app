import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/eligibility/eligibility_status_screen.dart';
import 'package:women_safety_app/features/eligibility/eligibility_verification_models.dart';

void main() {
  testWidgets(
    'dashboard entry is offered only for a non-demo verified backend result',
    (tester) async {
      var openedHome = false;
      const verifiedBackendResult = EligibilityStatusResult(
        status: EligibilityStatus.verified,
        message: 'The backend confirms verified status.',
        isDemo: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EligibilityStatusScreen(
            result: verifiedBackendResult,
            onOpenVerifiedHome: (_) => openedHome = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final continueButton = find.byKey(
        const Key('eligibility-open-verified-home-button'),
      );
      expect(continueButton, findsOneWidget);
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      expect(openedHome, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: EligibilityStatusScreen(
            result: const EligibilityStatusResult(
              status: EligibilityStatus.verified,
              message: 'This is a demo result.',
              isDemo: true,
            ),
            onOpenVerifiedHome: (_) => openedHome = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(continueButton, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
