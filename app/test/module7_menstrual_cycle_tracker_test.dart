import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/wellness/models/menstrual_cycle_models.dart';
import 'package:women_safety_app/features/wellness/widgets/guided_meditation_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Module 7: Menstrual Cycle Models, Automatic vs Custom Modes & Reminder Scheduling Tests', () {
    test('Defaults to Automatic (history-based) mode and computes rolling average from logged cycles', () {
      const prefs = MenstrualTrackerPreferences();
      expect(prefs.useCustomCycleLength, isFalse);

      final cycles = [
        const MenstrualCycleEntry(
          id: 'cycle-1',
          startDate: '2026-09-01',
          endDate: '2026-09-05',
          periodDurationDays: 5,
          createdAt: '2026-09-01T08:00:00Z',
        ),
        const MenstrualCycleEntry(
          id: 'cycle-2',
          startDate: '2026-09-27', // 26 days
          endDate: '2026-10-01',
          periodDurationDays: 5,
          createdAt: '2026-09-27T08:00:00Z',
        ),
        const MenstrualCycleEntry(
          id: 'cycle-3',
          startDate: '2026-10-23', // 26 days
          endDate: '2026-10-27',
          periodDurationDays: 5,
          createdAt: '2026-10-23T08:00:00Z',
        ),
      ];

      final autoSummary = CyclePredictionEngine.compute(
        cycles: cycles,
        prefs: prefs, // default averageCycleLength is 28, but useCustomCycleLength is false
        referenceDate: DateTime(2026, 11, 5),
      );

      expect(autoSummary.isCustomMode, isFalse);
      expect(autoSummary.averageCycleLength, 26);
      expect(autoSummary.nextPeriodStart, '2026-11-18');
      expect(autoSummary.predictionBasisLabel, contains('Automatic Mode'));

      // Switching to Custom Mode (e.g. 24 days) overrides with the user-selected cycle length
      final customPrefs = prefs.copyWith(
        averageCycleLength: 24,
        useCustomCycleLength: true,
      );
      final customSummary = CyclePredictionEngine.compute(
        cycles: cycles,
        prefs: customPrefs,
        referenceDate: DateTime(2026, 11, 5),
      );
      expect(customSummary.isCustomMode, isTrue);
      expect(customSummary.averageCycleLength, 24);
      expect(customSummary.nextPeriodStart, '2026-11-16');
      expect(customSummary.predictionBasisLabel, contains('Custom Mode'));

      // Switching back to Automatic Mode restores history-based 26-day prediction
      final backToAuto = customPrefs.copyWith(useCustomCycleLength: false);
      final restoredSummary = CyclePredictionEngine.compute(
        cycles: cycles,
        prefs: backToAuto,
        referenceDate: DateTime(2026, 11, 5),
      );
      expect(restoredSummary.isCustomMode, isFalse);
      expect(restoredSummary.averageCycleLength, 26);
    });

    test('First-time user (0 cycles) and single-cycle user fallback behavior', () {
      const prefs = MenstrualTrackerPreferences(
        averageCycleLength: 28,
        useCustomCycleLength: false,
      );
      final emptySummary = CyclePredictionEngine.compute(
        cycles: const [],
        prefs: prefs,
      );
      expect(emptySummary.nextPeriodStart, isNull);
      expect(emptySummary.regularityStatus, 'Building History');

      final oneCycle = [
        const MenstrualCycleEntry(
          id: 'c1',
          startDate: '2026-10-10',
          endDate: '2026-10-14',
          periodDurationDays: 5,
          createdAt: '2026-10-10T08:00:00Z',
        ),
      ];
      final singleSummary = CyclePredictionEngine.compute(
        cycles: oneCycle,
        prefs: prefs,
        referenceDate: DateTime(2026, 10, 20),
      );
      expect(singleSummary.averageCycleLength, 28);
      expect(singleSummary.nextPeriodStart, '2026-11-07');
      expect(singleSummary.regularityStatus, 'Building History');
    });

    test('Detects cycle irregularity when variations exceed 7 days', () {
      final cycles = [
        const MenstrualCycleEntry(
          id: 'cycle-1',
          startDate: '2026-07-01',
          endDate: '2026-07-06',
          periodDurationDays: 5,
          createdAt: '2026-07-01T08:00:00Z',
        ),
        const MenstrualCycleEntry(
          id: 'cycle-2',
          startDate: '2026-07-22', // 21 days
          endDate: '2026-07-27',
          periodDurationDays: 5,
          createdAt: '2026-07-22T08:00:00Z',
        ),
        const MenstrualCycleEntry(
          id: 'cycle-3',
          startDate: '2026-08-25', // 34 days
          endDate: '2026-08-30',
          periodDurationDays: 5,
          createdAt: '2026-08-25T08:00:00Z',
        ),
      ];

      const prefs = MenstrualTrackerPreferences();
      final summary = CyclePredictionEngine.compute(cycles: cycles, prefs: prefs);

      expect(summary.cycleVariationDays, 13);
      expect(summary.hasIrregularity, isTrue);
      expect(summary.regularityStatus, 'Irregular');
      expect(summary.irregularityReason, contains('vary by 13 days'));
    });

    test('Schedules date-based discreet reminder via MethodChannel with nextPeriodStart and daysBefore', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('sakhi/safety_hardware'),
            (MethodCall call) async {
              calls.add(call);
              if (call.method == 'scheduleDiscreetWellnessReminder') {
                return <String, dynamic>{
                  'scheduled': true,
                  'triggerAtMillis': 1795000000000,
                };
              }
              return <String, dynamic>{'cancelled': true};
            },
          );

      final controller = MenstrualCycleController.instance;
      controller.cycles = [
        const MenstrualCycleEntry(
          id: 'c_future',
          startDate: '2026-11-01',
          endDate: '2026-11-05',
          periodDurationDays: 5,
          createdAt: '2026-11-01T08:00:00Z',
        ),
      ];
      await controller.updatePreferences(
        const MenstrualTrackerPreferences(
          averageCycleLength: 28,
          periodReminderDaysBefore: 3,
          notificationsEnabled: true,
          discreetNotifications: true,
        ),
      );

      final scheduleCalls = calls
          .where((c) => c.method == 'scheduleDiscreetWellnessReminder')
          .toList();
      expect(scheduleCalls, isNotEmpty);
      final args = Map<String, dynamic>.from(
        scheduleCalls.last.arguments as Map,
      );
      expect(args['nextPeriodStart'], '2026-11-29');
      expect(args['daysBefore'], 3);
      expect(args['title'], 'Wellness Check-In');
    });

    test('Soundscape titles describe synthesized harmonic drones honestly without instrument or EEG claims', () {
      for (final title in GuidedMeditationSessionController.soundscapeTitles) {
        final lower = title.toLowerCase();
        expect(lower.contains('rain'), isFalse);
        expect(lower.contains('ocean'), isFalse);
        expect(lower.contains('piano'), isFalse);
        expect(lower.contains('harp'), isFalse);
        expect(lower.contains('bansuri'), isFalse);
        expect(lower.contains('delta'), isFalse);
        expect(lower.contains('theta'), isFalse);
      }
    });
  }
    test('Exposes the 5 approved neural women voices (V22, V24, V26, V30, V01) and verifies SHA-256 digest', () {
      final voices = GuidedMeditationSessionController.approvedVoiceOptions;
      expect(voices.map((v) => v.voiceId).toList(), ['V22', 'V24', 'V26', 'V30', 'V01']);
      final digest = SakhiSha256.hexDigest(Uint8List.fromList('abc'.codeUnits));
      expect(
        digest,
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('Generates valid %PDF-1.4 bytes for Menstrual Cycle Clinical Summary export', () {
      final pdfBytes = MenstrualCycleController.instance.generateClinicalSummaryPdfBytes();
      final header = String.fromCharCodes(pdfBytes.take(8));
      expect(header, startsWith('%PDF-1.4'));
      expect(pdfBytes.length, greaterThan(400));
    });
  });
}
