import 'package:flutter_test/flutter_test.dart';
import 'package:women_safety_app/features/wellness/models/menstrual_cycle_models.dart';

void main() {
  group('Module 7: Menstrual Cycle Models & Prediction Engine Tests', () {
    test('Calculates rolling averages, ovulation, fertile and PMS windows accurately', () {
      final cycles = [
        const MenstrualCycleEntry(
          id: 'cycle-1',
          startDate: '2026-09-01',
          endDate: '2026-09-06',
          periodDurationDays: 5,
          createdAt: '2026-09-01T08:00:00Z',
        ),
        const MenstrualCycleEntry(
          id: 'cycle-2',
          startDate: '2026-09-29',
          endDate: '2026-10-04',
          periodDurationDays: 5,
          createdAt: '2026-09-29T08:00:00Z',
        ),
        const MenstrualCycleEntry(
          id: 'cycle-3',
          startDate: '2026-10-27',
          endDate: '2026-11-01',
          periodDurationDays: 5,
          createdAt: '2026-10-27T08:00:00Z',
        ),
      ];

      const prefs = MenstrualTrackerPreferences(
        averageCycleLength: 28,
        averagePeriodDuration: 5,
        fertilityTrackingEnabled: true,
        pmsTrackingEnabled: true,
        discreetNotifications: true,
      );

      final summary = CyclePredictionEngine.compute(cycles: cycles, prefs: prefs);

      expect(summary.averageCycleLength, 28);
      expect(summary.averagePeriodDuration, 5);
      expect(summary.lastPeriodStart, '2026-10-27');
      expect(summary.nextPeriodStart, '2026-11-24');
      expect(summary.nextPeriodEnd, '2026-11-28');
      expect(summary.estimatedOvulationDate, '2026-11-10');
      expect(summary.fertileWindowStart, '2026-11-05');
      expect(summary.fertileWindowEnd, '2026-11-11');
      expect(summary.pmsWindowStart, '2026-11-19');
      expect(summary.pmsWindowEnd, '2026-11-23');
      expect(summary.hasIrregularity, false);
      expect(summary.regularityStatus, 'Regular');
      expect(summary.discreetNotificationPreview, contains('Wellness Check-In'));
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
          startDate: '2026-07-22',
          endDate: '2026-07-27',
          periodDurationDays: 5,
          createdAt: '2026-07-22T08:00:00Z',
        ),
        const MenstrualCycleEntry(
          id: 'cycle-3',
          startDate: '2026-08-25',
          endDate: '2026-08-30',
          periodDurationDays: 5,
          createdAt: '2026-08-25T08:00:00Z',
        ),
      ];

      const prefs = MenstrualTrackerPreferences();
      final summary = CyclePredictionEngine.compute(cycles: cycles, prefs: prefs);

      expect(summary.cycleVariationDays, 13);
      expect(summary.hasIrregularity, true);
      expect(summary.regularityStatus, 'Irregular');
      expect(summary.irregularityReason, contains('vary by 13 days'));
    });

    test('Daily log entry serializes and deserializes properly with symptoms and hydration', () {
      const log = MenstrualDailyLogEntry(
        id: 'log-101',
        logDate: '2026-11-03',
        flowIntensity: 'Medium',
        crampsSeverity: 'Mild',
        mood: 'Calm',
        energyLevel: 4,
        symptoms: ['Cramps', 'Headache'],
        isPmsWindow: false,
        hydrationGlasses: 8,
        sleepHours: 8.0,
        personalNotes: 'Felt good after warm chamomile tea',
      );

      final json = log.toJson();
      final parsed = MenstrualDailyLogEntry.fromJson(json);

      expect(parsed.id, 'log-101');
      expect(parsed.logDate, '2026-11-03');
      expect(parsed.flowIntensity, 'Medium');
      expect(parsed.crampsSeverity, 'Mild');
      expect(parsed.mood, 'Calm');
      expect(parsed.energyLevel, 4);
      expect(parsed.symptoms, ['Cramps', 'Headache']);
      expect(parsed.hydrationGlasses, 8);
      expect(parsed.sleepHours, 8.0);
      expect(parsed.personalNotes, 'Felt good after warm chamomile tea');
    });

    test('Discreet notification preview adjusts to preferences', () {
      const discretePrefs = MenstrualTrackerPreferences(discreetNotifications: true);
      const detailedPrefs = MenstrualTrackerPreferences(discreetNotifications: false);

      final cycles = [
        const MenstrualCycleEntry(
          id: 'c1',
          startDate: '2026-10-10',
          periodDurationDays: 5,
          createdAt: '2026-10-10T08:00:00Z',
        ),
      ];

      final discreteSummary = CyclePredictionEngine.compute(cycles: cycles, prefs: discretePrefs);
      final detailedSummary = CyclePredictionEngine.compute(cycles: cycles, prefs: detailedPrefs);

      expect(discreteSummary.discreetNotificationPreview, contains('Wellness Check-In'));
      expect(detailedSummary.discreetNotificationPreview, contains('Period Reminder: Your next estimated cycle'));
    });
  });
}
