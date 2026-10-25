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

  group('Module 4 live-location & zero-fake-contacts safety gates', () {
    test('starts with zero fake hardcoded contacts and supports Show/Hide phone number toggle', () {
      final controller = SakhiSafetyController.instance;
      controller.trustedContacts.clear();

      expect(controller.trustedContacts, isEmpty);
      final err = controller.addTrustedContact(
        name: 'Meera Verma',
        mobileNumber: '9845099887',
        relationship: 'Sister',
        setAsPrimary: true,
      );
      expect(err, isNull);
      expect(controller.trustedContacts.length, 1);

      final contact = controller.trustedContacts.first;
      expect(contact.displayPhone(globalShowAll: false), contains('••••7'));
      controller.toggleSingleContactPhoneVisibility(contact.id);
      expect(contact.displayPhone(globalShowAll: false), '+91 98450 99887');
    });

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

  group(
    'Module 4 Emergency SOS & Personal Safety UI Screens (Distinct Navigation)',
    () {
      testWidgets(
        'Screen 1 Safety Hub renders live map, controls, and quote banner',
        (WidgetTester tester) async {
          SakhiSafetyController.instance.clearDeviceLocation();
          await tester.pumpWidget(const MaterialApp(home: SafetyScreen()));
          await tester.pump(const Duration(milliseconds: 600));

          expect(find.text('Safety'), findsOneWidget);
          expect(find.text('Tap SOS'), findsOneWidget);
          expect(find.text('Quick Safety Actions'), findsOneWidget);
          expect(find.text('Share my live location'), findsOneWidget);
          expect(find.text('SOS Activation History'), findsOneWidget);
          expect(
            find.text('Safety Checklist & Discreet Trigger'),
            findsOneWidget,
          );
          expect(find.text('Emergency Helplines & 112'), findsOneWidget);
          expect(find.byKey(const Key('sakhi-quote-banner')), findsOneWidget);
        },
      );

      testWidgets('Screen 2 SOS Confirmation & Active Workflow Screen', (
        WidgetTester tester,
      ) async {
        SakhiSafetyController.instance.clearDeviceLocation();
        await tester.pumpWidget(
          const MaterialApp(home: SosWorkflowScreen(isTestMode: false)),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Confirm Emergency SOS'), findsOneWidget);
        expect(find.text('Trigger SOS Now'), findsOneWidget);
        expect(find.text("Cancel (I'm Safe)"), findsOneWidget);
        expect(find.text('Current Location Unavailable'), findsOneWidget);
        expect(find.text('Official Police Integration Status'), findsOneWidget);
        expect(
          find.text('Call 112 National Emergency Helpline'),
          findsOneWidget,
        );
        expect(
          find.text('Call 100 Direct Police Control Room'),
          findsOneWidget,
        );
        expect(find.text('Stop Location Sharing & End SOS'), findsOneWidget);
      });

      testWidgets(
        'Screen 3 Nearest Police Stations renders compliance disclaimer and live map',
        (WidgetTester tester) async {
          SakhiSafetyController.instance.clearDeviceLocation();
          await tester.pumpWidget(
            const MaterialApp(home: NearestPoliceStationsScreen()),
          );
          await tester.pump(const Duration(milliseconds: 500));

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
        },
      );

      testWidgets(
        'Screen 4 Emergency Contacts (with Show/Hide Numbers) & Screen 5 Live Location',
        (WidgetTester tester) async {
          final controller = SakhiSafetyController.instance;
          controller.trustedContacts.clear();
          await tester.runAsync(() async {
            controller.addTrustedContact(
              name: 'Sita Devi',
              mobileNumber: '9845012345',
              relationship: 'Mom',
              setAsPrimary: true,
            );
          });

          await tester.pumpWidget(
            const MaterialApp(home: EmergencyContactsScreen()),
          );
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.text('Primary Contact'), findsOneWidget);
          expect(
            find.byKey(const Key('toggle-all-contact-numbers-button')),
            findsOneWidget,
          );
          expect(
            find.text('Send Emergency Alert to Selected Contacts'),
            findsOneWidget,
          );

          controller.clearDeviceLocation();
          await tester.pumpWidget(
            const MaterialApp(home: ShareLiveLocationScreen()),
          );
          await tester.pump(const Duration(milliseconds: 400));

          expect(find.text('GPS unavailable'), findsOneWidget);
          expect(
            find.text('Include my Name & Emergency Profile'),
            findsOneWidget,
          );
          expect(find.text('Add Trusted Emergency Contact'), findsOneWidget);
        },
      );

      testWidgets(
        'Dedicated Screens: DiscreetShortcutConfigScreen, PersonalSafetyTipsScreen, NationalEmergency112Screen, and VerifiedHelplinesDirectoryScreen',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            const MaterialApp(home: DiscreetShortcutConfigScreen()),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.text('Power / Volume Button Triple-Press Shortcut'),
            findsOneWidget,
          );
          expect(
            find.text('Run Safe Test Mode (Avoid False Triggers)'),
            findsOneWidget,
          );

          await tester.pumpWidget(
            const MaterialApp(home: PersonalSafetyTipsScreen()),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Personal Safety Tips & Guides'), findsOneWidget);
          expect(find.text('Commute & Cab Safety'), findsWidgets);

          await tester.pumpWidget(
            const MaterialApp(home: NationalEmergency112Screen()),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('112 Emergency Rapid Dispatch'), findsOneWidget);
          expect(find.text('Dial 112 in Phone Dialer Now'), findsOneWidget);

          await tester.pumpWidget(
            const MaterialApp(home: VerifiedHelplinesDirectoryScreen()),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.text('112 — India National Emergency Number'),
            findsOneWidget,
          );
          // Tap Commute & Cab Safety card to verify it opens the interactive detail sheet!
          await tester.ensureVisible(
            find.byKey(const Key('tip-card-commute-cab-safety')),
          );
          await tester.tap(
            find.byKey(const Key('tip-card-commute-cab-safety')),
          );
          await tester.pumpAndSettle();
          expect(
            find.text('Step-by-Step Safety Action Plan (Tap to Check Off):'),
            findsOneWidget,
          );
        },
      );
    },
  );
}
