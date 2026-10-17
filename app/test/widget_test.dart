import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/branding/app_brand.dart';
import 'package:women_safety_app/core/theme/sakhi_design_system.dart';
import 'package:women_safety_app/features/auth/auth_service.dart';
import 'package:women_safety_app/features/eligibility/eligibility_verification_models.dart';
import 'package:women_safety_app/features/home/sakhi_home_screen.dart';
import 'package:women_safety_app/main.dart';

void main() {
  test('brand profile centralizes app identity and replaceable assets', () {
    expect(AppBrand.appName, 'Sakhi');
    expect(AppBrand.shortName, 'Sakhi');
    expect(AppBrand.logoAsset, 'assets/brand/app_logo.png');
    expect(AppBrand.iconAsset, 'assets/brand/app_icon.png');
  });

  testWidgets('welcome screen uses supplied logo and full-screen artwork', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sakhi-logo-lockup')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-artwork-0')), findsOneWidget);
    expect(find.byKey(const Key('safety-visual-cue')), findsNothing);
    expect(
      find.text('A Safer, Brighter\nTomorrow for Every Woman'),
      findsOneWidget,
    );
    expect(
      find.text('Safety • Community • Wellness • Opportunities'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('next-onboarding-button')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-dot-0')), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Next and horizontal swiping move through all three pages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('next-onboarding-button')));
    await tester.pumpAndSettle();
    expect(find.text('Safety That Starts\nWith You'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-artwork-1')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-dot-1')), findsOneWidget);
    expect(find.byKey(const Key('safety-visual-cue')), findsOneWidget);
    expect(
      find.byKey(const Key('safety-callout-emergency-sos')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('safety-callout-find-nearby-help')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('safety-callout-report-concern')),
      findsOneWidget,
    );
    expect(find.text('Emergency SOS'), findsOneWidget);
    expect(find.text('Trusted Contacts'), findsOneWidget);
    expect(find.text('Find Nearby Help'), findsOneWidget);
    expect(find.text('Report a Concern'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.phone_in_talk_rounded)).color,
      SakhiColors.pinkAccent,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.chat_bubble_outline_rounded)).color,
      SakhiColors.pinkAccent,
    );

    await tester.drag(
      find.byKey(const Key('sakhi-onboarding-page-view')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Stronger, Together'), findsOneWidget);
    expect(find.byKey(const Key('safety-visual-cue')), findsNothing);
    expect(find.byKey(const Key('onboarding-artwork-2')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-dot-2')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('sakhi-onboarding-page-view')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Safety That Starts\nWith You'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stage 2 safety callouts fit a narrow phone viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('next-onboarding-button')));
    await tester.pumpAndSettle();

    final calloutKeys = [
      const Key('safety-callout-emergency-sos'),
      const Key('safety-visual-cue'),
      const Key('safety-callout-find-nearby-help'),
      const Key('safety-callout-report-concern'),
    ];

    final logoRect = tester.getRect(find.byKey(const Key('sakhi-logo-lockup')));
    final calloutRects = <Rect>[];
    for (final key in calloutKeys) {
      final rect = tester.getRect(find.byKey(key));
      calloutRects.add(rect);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(640));
      expect(rect.width, lessThanOrEqualTo(320 * 0.40));
      expect(rect.overlaps(logoRect), isFalse);
    }

    for (var i = 0; i < calloutRects.length; i++) {
      for (var j = i + 1; j < calloutRects.length; j++) {
        expect(calloutRects[i].overlaps(calloutRects[j]), isFalse);
      }
    }

    final headingTop = tester
        .getRect(find.text('Safety That Starts\nWith You'))
        .top;
    expect(calloutRects.every((rect) => rect.bottom < headingTop), isTrue);

    final descriptionRect = tester.getRect(
      find.textContaining('Explore practical guidance'),
    );
    final indicatorRect = tester.getRect(
      find.byKey(const Key('onboarding-dot-1')),
    );
    final nextButtonRect = tester.getRect(
      find.byKey(const Key('next-onboarding-button')),
    );
    expect(descriptionRect.bottom, lessThanOrEqualTo(indicatorRect.top));
    expect(indicatorRect.bottom, lessThanOrEqualTo(nextButtonRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip goes to the final page and Get started continues', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('skip-onboarding-button')));
    await tester.pumpAndSettle();
    expect(find.text('Stronger, Together'), findsOneWidget);
    expect(find.byKey(const Key('get-started-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('get-started-button')));
    await tester.pumpAndSettle();
    expect(find.text('Create your Sakhi account'), findsOneWidget);
    expect(find.byKey(const Key('auth-mobile-number-field')), findsOneWidget);
    expect(find.byKey(const Key('auth-send-otp-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared home feature cards retain their existing navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SakhiHomeScreen(
          authService: UnconfiguredAuthService(),
          verifiedStatus: const EligibilityStatusResult(
            status: EligibilityStatus.verified,
            message: 'Synthetic test status.',
            isDemo: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Safety & support'));
    await tester.pumpAndSettle();

    expect(find.text('Safety & support preview'), findsOneWidget);
    expect(
      find.textContaining('service and backend integration'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
