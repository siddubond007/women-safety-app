import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/widgets/sakhi_create_hub_sheet.dart';
import 'package:women_safety_app/features/community/screens/community_screen.dart';

void main() {
  testWidgets(
    'Create Hub displays the four share actions and returns the selected intent',
    (tester) async {
      SakhiCreateAction? selectedAction;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    selectedAction = await showSakhiCreateHub(context);
                  },
                  child: const Text('Open Create Hub'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Create Hub'));
      await tester.pumpAndSettle();

      expect(find.text('Sakhi Create Hub'), findsOneWidget);
      expect(find.text('Post a Photo'), findsOneWidget);
      expect(find.text('Write a Text Post'), findsOneWidget);
      expect(find.text('Create a Community Question'), findsOneWidget);
      expect(find.text('Share a Useful Resource'), findsOneWidget);

      await tester.tap(find.text('Create a Community Question'));
      await tester.pumpAndSettle();
      expect(selectedAction, SakhiCreateAction.communityQuestion);
    },
  );

  testWidgets(
    'Text mode opens the Social Wall caption composer without the developer switcher',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommunityScreen(initialComposerMode: 'text', createIntent: 1),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Write a Text Post'), findsOneWidget);
      expect(find.text('Share Post'), findsOneWidget);
      expect(find.text('Quick Jump: All 12 Reference Screens'), findsNothing);
    },
  );
}
