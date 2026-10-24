import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/widgets/sakhi_quote_loader.dart';
import 'package:women_safety_app/features/safety/models/safety_models.dart';
import 'package:women_safety_app/features/safety/screens/safety_screen.dart';

void main() {
  group(
    'Sakhi Discord-Style Animated Women Quotations Loader (168 Quotes)',
    () {
      test(
        'contains 168 curated women quotations with authors and categories',
        () {
          expect(SakhiWomenQuotes.all.length, greaterThanOrEqualTo(160));
          expect(SakhiWomenQuotes.all.length, 168);
          for (final item in SakhiWomenQuotes.all) {
            expect(item.quote.trim().isNotEmpty, isTrue);
            expect(item.author.trim().isNotEmpty, isTrue);
            expect(item.category.trim().isNotEmpty, isTrue);
          }
        },
      );

      testWidgets('SakhiQuoteLoader renders quote and cycles on tap', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SakhiQuoteLoader.fullScreen(initialQuoteIndex: 0),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.textContaining('Savitribai Phule'), findsOneWidget);
        await tester.tap(find.text('Inspire me with another quote'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('Sarojini Naidu'), findsOneWidget);
      });
    },
  );

  group('Module 4 live-location safety gates', () {
    test(
      'tracking URLs remain unavailable until a backend-confirmed share',
      () async {
        final controller = SakhiSafetyController.instance;
        controller.clearDeviceLocation();

        expect(controller.hasLiveLocation, isFalse);
        expect(controller.locationPermissionGranted, isFalse);
        expect(controller.liveLocationSharingActive, isFalse);
        expect(controller.activeShareToken, isEmpty);
        expect(controller.backendTrackingUrl, isEmpty);
        expect(controller.liveShareFullUrl, isEmpty);
        expect(controller.liveShareShortUrl, 'Live location unavailable');

        await controller.startLiveLocationSharing();

        expect(controller.liveLocationSharingActive, isFalse);
        expect(controller.activeShareToken, isEmpty);
        expect(controller.backendTrackingUrl, isEmpty);
        expect(controller.liveShareFullUrl, isEmpty);
      },
    );
  });
  group('Module 4 Emergency SOS & Personal Safety UI Screens (Screens 1-7)', () {
    testWidgets('Screen 1 Safety Hub renders all controls and quote banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SafetyScreen()));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Safety'), findsOneWidget);
      expect(find.text('Tap SOS'), findsOneWidget);
      expect(find.text('Quick Safety Actions'), findsOneWidget);
      expect(find.text('Tap to enable device GPS'), findsOneWidget);
      expect(find.text('Share my live location'), findsOneWidget);
      expect(find.text('SOS Activation History'), findsOneWidget);
      expect(find.text('Safety Checklist & Discreet Trigger'), findsOneWidget);
      expect(find.text('Emergency Helplines & 112'), findsOneWidget);
      expect(find.byKey(const Key('sakhi-quote-banner')), findsOneWidget);
    });

    testWidgets('Screen 2 SOS Confirmation & Active Workflow Screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: SosWorkflowScreen(isTestMode: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Confirm Emergency SOS'), findsOneWidget);
      expect(find.text('Trigger SOS Now'), findsOneWidget);
      expect(find.text("Cancel (I'm Safe)"), findsOneWidget);
      expect(find.text('Current Location Unavailable'), findsOneWidget);
      expect(find.text('Official Police Integration Status'), findsOneWidget);
      expect(find.text('Call 112 National Emergency Helpline'), findsOneWidget);
      expect(find.text('Call 100 Direct Police Control Room'), findsOneWidget);
      expect(find.text('Stop Location Sharing & End SOS'), findsOneWidget);
    });

    testWidgets(
      'Screen 3 Nearest Police Stations renders compliance disclaimer and station actions',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: NearestPoliceStationsScreen()),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('police-compliance-disclaimer-banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Enable device GPS to calculate nearby stations. Sakhi will not use a sample location.',
          ),
          findsOneWidget,
        );
        expect(find.text('Indiranagar Police Station'), findsNothing);
        expect(find.text('Ulsoor All-Women Police Station'), findsNothing);
        expect(find.text('Directions / Navigate'), findsNothing);
        expect(find.text('Call Station'), findsNothing);
      },
    );

    testWidgets(
      'Screen 4 Emergency Contacts & Screen 5 Live Location + Add Contact',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: EmergencyContactsScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Primary Contact'), findsOneWidget);
        expect(
          find.text('Send Emergency Alert to Selected Contacts'),
          findsOneWidget,
        );

        await tester.pumpWidget(
          const MaterialApp(home: ShareLiveLocationScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('GPS unavailable'), findsOneWidget);
        expect(
          find.text('Include my Name & Emergency Profile'),
          findsOneWidget,
        );
        expect(find.text('Add Trusted Emergency Contact'), findsOneWidget);
      },
    );

    testWidgets(
      'Screen 6 Safety History & Settings and Screen 7 Helplines & Safety Tips',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: SafetyHistoryAndSettingsScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Power Button Triple-Press Shortcut'), findsOneWidget);
        expect(
          find.text('Run Safe Test Mode (Avoid False Triggers)'),
          findsOneWidget,
        );
        expect(find.text('Pre-Travel Safety Checklist'), findsOneWidget);

        await tester.pumpWidget(
          const MaterialApp(home: HelplinesAndSafetyTipsScreen()),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('112 — India National Emergency Number'),
          findsOneWidget,
        );
        expect(find.text('Commute & Cab Safety'), findsOneWidget);
        expect(find.text('Using Discreet SOS Safely'), findsOneWidget);
      },
    );
  });
}
