import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/wellness/screens/wellness_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ttsChannel = MethodChannel('flutter_tts');
  const nativeAudioChannel = MethodChannel('sakhi/native_actions');
  final spokenPhrases = <String>[];

  setUp(() {
    spokenPhrases.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ttsChannel, (call) async {
      switch (call.method) {
        case 'getLanguages':
          return ['en-IN', 'en-US'];
        case 'speak':
          final arguments = call.arguments;
          spokenPhrases.add(
            arguments is Map
                ? arguments['text'].toString()
                : arguments.toString(),
          );
          return 1;
        default:
          return 1;
      }
    });
    messenger.setMockMethodCallHandler(
      nativeAudioChannel,
      (call) async => null,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(ttsChannel, null);
    messenger.setMockMethodCallHandler(nativeAudioChannel, null);
  });

  testWidgets(
    'voice guidance and singing-bowl audio have independent controls',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SakhiAiMentalWellnessStudioScreen()),
      );
      await tester.pump();

      expect(find.byTooltip('Turn voice guidance off'), findsOneWidget);
      expect(find.byTooltip('Mute singing bowl audio'), findsOneWidget);

      await tester.tap(find.byTooltip('Turn voice guidance off'));
      await tester.pump();

      expect(find.byTooltip('Turn voice guidance on'), findsOneWidget);
      expect(find.byTooltip('Mute singing bowl audio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('speaks the inhale cue when a guided session starts', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SakhiAiMentalWellnessStudioScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final startButton = find.text('Start AI Guided Session');
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      spokenPhrases,
      contains('Breathe in gently through your nose.'),
    );
    expect(tester.takeException(), isNull);
  });
}
