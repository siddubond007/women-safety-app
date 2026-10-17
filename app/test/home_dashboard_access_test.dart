import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/auth/auth_service.dart';
import 'package:women_safety_app/features/eligibility/eligibility_verification_models.dart';
import 'package:women_safety_app/features/home/sakhi_home_screen.dart';

void main() {
  testWidgets('dashboard itself fails closed for demo or non-verified status', (
    tester,
  ) async {
    const unconfiguredAuth = UnconfiguredAuthService();

    await tester.pumpWidget(
      const MaterialApp(
        home: SakhiHomeScreen(
          authService: unconfiguredAuth,
          verifiedStatus: EligibilityStatusResult(
            status: EligibilityStatus.verified,
            message: 'Synthetic demo status.',
            isDemo: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sakhi Home is not available'), findsOneWidget);
    expect(find.byKey(const Key('home-feature-grid')), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: SakhiHomeScreen(
          authService: unconfiguredAuth,
          verifiedStatus: EligibilityStatusResult(
            status: EligibilityStatus.pendingManualReview,
            message: 'Awaiting review.',
            isDemo: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sakhi Home is not available'), findsOneWidget);
    expect(find.byKey(const Key('home-feature-grid')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
