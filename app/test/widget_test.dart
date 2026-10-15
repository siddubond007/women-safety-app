import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/branding/app_brand.dart';
import 'package:women_safety_app/main.dart';

void main() {
  test('brand profile centralizes app identity and replaceable assets', () {
    expect(AppBrand.appName, 'Sakhi');
    expect(AppBrand.shortName, 'Sakhi');
    expect(AppBrand.logoAsset, 'assets/brand/app_logo.png');
    expect(AppBrand.iconAsset, 'assets/brand/app_icon.png');
  });

  testWidgets('welcome screen uses supplied logo and full-screen artwork',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sakhi-logo-lockup')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-artwork-0')), findsOneWidget);
    expect(find.byKey(const Key('safety-visual-cue')), findsNothing);
    expect(find.text('A Safer, Brighter\nTomorrow for Every Woman'), findsOneWidget);
    expect(find.text('Safety • Community • Wellness • Opportunities'), findsOneWidget);
    expect(find.byKey(const Key('next-onboarding-button')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-dot-0')), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Next and horizontal swiping move through all three pages',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('next-onboarding-button')));
    await tester.pumpAndSettle();
    expect(find.text('Safety That Starts\nWith You'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-artwork-1')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-dot-1')), findsOneWidget);
    expect(find.byKey(const Key('safety-visual-cue')), findsOneWidget);

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

  testWidgets('Skip goes to the final page and Get started continues',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('skip-onboarding-button')));
    await tester.pumpAndSettle();
    expect(find.text('Stronger, Together'), findsOneWidget);
    expect(find.byKey(const Key('get-started-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('get-started-button')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Sakhi'), findsOneWidget);
    expect(find.text('Explore Sakhi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared home feature cards retain their existing navigation',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SakhiHomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Safety & support'));
    await tester.pumpAndSettle();

    expect(find.text('Safety & support preview'), findsOneWidget);
    expect(find.textContaining('service and backend integration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
