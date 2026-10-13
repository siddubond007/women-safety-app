import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/main.dart';

void main() {
  testWidgets('welcome screen displays the Sakhi brand and first page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    expect(find.text('Sakhi'), findsOneWidget);
    expect(find.text('Safer Women. Stronger Together.'), findsOneWidget);
    expect(
      find.text('A Safer, Brighter\nTomorrow for Every Woman'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('next-onboarding-button')), findsOneWidget);
    expect(find.byKey(const Key('onboarding-dot-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Next advances to the following onboarding page',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('next-onboarding-button')));
    // The PageController animation lasts 320 ms. Advance beyond it directly;
    // pumpAndSettle can time out if an unrelated ticker is active in the tree.
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Safety That Starts\nWith You'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('swiping horizontally changes onboarding pages',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('sakhi-onboarding-page-view')),
      const Offset(-600, 0),
    );
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Safety That Starts\nWith You'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip moves to final page and Get started opens the app',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SakhiApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('skip-onboarding-button')));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Stronger, Together'), findsOneWidget);
    expect(find.byKey(const Key('get-started-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('get-started-button')));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Welcome to Sakhi'), findsOneWidget);
    expect(find.text('Explore Sakhi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home feature cards open their preview screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SakhiHomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Safety & support'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Safety & support preview'), findsOneWidget);
    expect(
      find.textContaining('service and backend integration'),
      findsOneWidget,
    );
  });
}
