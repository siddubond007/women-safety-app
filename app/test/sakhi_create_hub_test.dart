import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/core/widgets/sakhi_create_hub_sheet.dart';
import 'package:women_safety_app/features/community/screens/community_screen.dart';
import 'package:women_safety_app/features/community/screens/sakhi_post_creation_flow.dart';

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
      expect(find.text('Post a Photo or Video'), findsOneWidget);
      expect(find.text('Write a Text Post'), findsOneWidget);
      expect(find.text('Create a Community Question'), findsOneWidget);
      expect(find.text('Share a Useful Resource'), findsOneWidget);

      await tester.tap(find.text('Create a Community Question'));
      await tester.pumpAndSettle();
      expect(selectedAction, SakhiCreateAction.communityQuestion);
    },
  );

  testWidgets(
    'Photo and video Create Hub action opens the dedicated media route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => openSakhiCreateAction(
                    context,
                    SakhiCreateAction.photoVideo,
                  ),
                  child: const Text('Open Media Composer'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Media Composer'));
      await tester.pumpAndSettle();

      expect(find.text('New Photo Post'), findsOneWidget);
      expect(find.text('Choose your moment'), findsOneWidget);
      expect(find.text('Create with Template'), findsOneWidget);
      expect(find.text('Post Settings'), findsNothing);
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
