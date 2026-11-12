import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/backend_api_client.dart';

/// SRS Section 9 (Module 7): Women's Menstrual Cycle Tracker Models,
/// Rolling-Average Prediction Engine, and Encrypted Local + Cloud Controller.

class MenstrualCycleEntry {
  final String id;
  final String startDate; // YYYY-MM-DD
  final String? endDate; // YYYY-MM-DD
  final int? cycleLengthDays;
  final int? periodDurationDays;
  final String flowIntensity; // Spotting, Light, Medium, Heavy
  final bool isIrregular;
  final String? notes;
  final String createdAt;

  const MenstrualCycleEntry({
    required this.id,
    required this.startDate,
    this.endDate,
    this.cycleLengthDays,
    this.periodDurationDays,
    this.flowIntensity = 'Medium',
    this.isIrregular = false,
    this.notes,
    required this.createdAt,
  });

  factory MenstrualCycleEntry.fromJson(Map<String, dynamic> json) {
    return MenstrualCycleEntry(
      id: (json['id'] ?? '').toString(),
      startDate: (json['startDate'] ?? '').toString(),
      endDate: json['endDate']?.toString(),
      cycleLengthDays: json['cycleLengthDays'] is num
          ? (json['cycleLengthDays'] as num).toInt()
          : null,
      periodDurationDays: json['periodDurationDays'] is num
          ? (json['periodDurationDays'] as num).toInt()
          : null,
      flowIntensity: (json['flowIntensity'] ?? 'Medium').toString(),
      isIrregular: json['isIrregular'] == true,
      notes: json['notes']?.toString(),
      createdAt: (json['createdAt'] ?? DateTime.now().toIso8601String())
          .toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startDate': startDate,
    'endDate': endDate,
    'cycleLengthDays': cycleLengthDays,
    'periodDurationDays': periodDurationDays,
    'flowIntensity': flowIntensity,
    'isIrregular': isIrregular,
    'notes': notes,
    'createdAt': createdAt,
  };
}

class MenstrualDailyLogEntry {
  final String id;
  final String logDate; // YYYY-MM-DD
  final String? flowIntensity; // None, Spotting, Light, Medium, Heavy
  final String? crampsSeverity; // None, Mild, Moderate, Severe
  final String? mood; // Calm, Happy, Sensitive, Anxious, Irritable, Energized, Tired
  final int? energyLevel; // 1..5
  final List<String> symptoms;
  final bool isPmsWindow;
  final int hydrationGlasses;
  final double? sleepHours;
  final String? personalNotes;

  const MenstrualDailyLogEntry({
    required this.id,
    required this.logDate,
    this.flowIntensity,
    this.crampsSeverity,
    this.mood,
    this.energyLevel,
    this.symptoms = const <String>[],
    this.isPmsWindow = false,
    this.hydrationGlasses = 0,
    this.sleepHours,
    this.personalNotes,
  });

  factory MenstrualDailyLogEntry.fromJson(Map<String, dynamic> json) {
    final rawSymptoms = json['symptoms'];
    final parsedSymptoms = rawSymptoms is List
        ? rawSymptoms.map((e) => e.toString()).toList()
        : const <String>[];
    return MenstrualDailyLogEntry(
      id: (json['id'] ?? '').toString(),
      logDate: (json['logDate'] ?? '').toString(),
      flowIntensity: json['flowIntensity']?.toString(),
      crampsSeverity: json['crampsSeverity']?.toString(),
      mood: json['mood']?.toString(),
      energyLevel: json['energyLevel'] is num
          ? (json['energyLevel'] as num).toInt()
          : null,
      symptoms: parsedSymptoms,
      isPmsWindow: json['isPmsWindow'] == true,
      hydrationGlasses: json['hydrationGlasses'] is num
          ? (json['hydrationGlasses'] as num).toInt()
          : 0,
      sleepHours: json['sleepHours'] is num
          ? (json['sleepHours'] as num).toDouble()
          : null,
      personalNotes: json['personalNotes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'logDate': logDate,
    'flowIntensity': flowIntensity,
    'crampsSeverity': crampsSeverity,
    'mood': mood,
    'energyLevel': energyLevel,
    'symptoms': symptoms,
    'isPmsWindow': isPmsWindow,
    'hydrationGlasses': hydrationGlasses,
    'sleepHours': sleepHours,
    'personalNotes': personalNotes,
  };
}

class MenstrualTrackerPreferences {
  final int averageCycleLength;
  final int averagePeriodDuration;
  final bool notificationsEnabled;
  final bool discreetNotifications;
  final int periodReminderDaysBefore;
  final bool ovulationReminderEnabled;
  final bool hydrationReminderEnabled;
  final bool fertilityTrackingEnabled;
  final bool pmsTrackingEnabled;
  final bool shareWithCommunity; // Strictly false by default (SRS 9.4)
  final bool useCustomCycleLength;

  const MenstrualTrackerPreferences({
    this.averageCycleLength = 28,
    this.averagePeriodDuration = 5,
    this.notificationsEnabled = true,
    this.discreetNotifications = true,
    this.periodReminderDaysBefore = 2,
    this.ovulationReminderEnabled = false,
    this.hydrationReminderEnabled = true,
    this.fertilityTrackingEnabled = true,
    this.pmsTrackingEnabled = true,
    this.shareWithCommunity = false,
    this.useCustomCycleLength = false,
  });

  factory MenstrualTrackerPreferences.fromJson(Map<String, dynamic> json) {
    final rawCycleLen = json['averageCycleLength'] ?? json['defaultCycleLength'];
    final rawPeriodLen =
        json['averagePeriodDuration'] ?? json['defaultPeriodDuration'];
    final rawNotifEnabled =
        json['notificationsEnabled'] ?? json['periodReminderEnabled'];
    final rawFertility =
        json['fertilityTrackingEnabled'] ?? json['showFertilityEstimates'];
    return MenstrualTrackerPreferences(
      averageCycleLength: rawCycleLen is num
          ? rawCycleLen.toInt().clamp(21, 40)
          : 28,
      averagePeriodDuration: rawPeriodLen is num
          ? rawPeriodLen.toInt().clamp(2, 10)
          : 5,
      notificationsEnabled: rawNotifEnabled != false,
      discreetNotifications: json['discreetNotifications'] != false,
      periodReminderDaysBefore: json['periodReminderDaysBefore'] is num
          ? (json['periodReminderDaysBefore'] as num).toInt().clamp(1, 7)
          : 2,
      ovulationReminderEnabled: json['ovulationReminderEnabled'] == true,
      hydrationReminderEnabled: json['hydrationReminderEnabled'] != false,
      fertilityTrackingEnabled: rawFertility != false,
      pmsTrackingEnabled: json['pmsTrackingEnabled'] != false,
      shareWithCommunity: json['shareWithCommunity'] == true,
      useCustomCycleLength: json['useCustomCycleLength'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'averageCycleLength': averageCycleLength,
    'defaultCycleLength': averageCycleLength,
    'averagePeriodDuration': averagePeriodDuration,
    'defaultPeriodDuration': averagePeriodDuration,
    'notificationsEnabled': notificationsEnabled,
    'periodReminderEnabled': notificationsEnabled,
    'discreetNotifications': discreetNotifications,
    'periodReminderDaysBefore': periodReminderDaysBefore,
    'ovulationReminderEnabled': ovulationReminderEnabled,
    'hydrationReminderEnabled': hydrationReminderEnabled,
    'fertilityTrackingEnabled': fertilityTrackingEnabled,
    'showFertilityEstimates': fertilityTrackingEnabled,
    'pmsTrackingEnabled': pmsTrackingEnabled,
    'shareWithCommunity': shareWithCommunity,
    'useCustomCycleLength': useCustomCycleLength,
  };

  MenstrualTrackerPreferences copyWith({
    int? averageCycleLength,
    int? averagePeriodDuration,
    bool? notificationsEnabled,
    bool? discreetNotifications,
    int? periodReminderDaysBefore,
    bool? ovulationReminderEnabled,
    bool? hydrationReminderEnabled,
    bool? fertilityTrackingEnabled,
    bool? pmsTrackingEnabled,
    bool? shareWithCommunity,
    bool? useCustomCycleLength,
  }) {
    return MenstrualTrackerPreferences(
      averageCycleLength: averageCycleLength ?? this.averageCycleLength,
      averagePeriodDuration:
          averagePeriodDuration ?? this.averagePeriodDuration,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      discreetNotifications:
          discreetNotifications ?? this.discreetNotifications,
      periodReminderDaysBefore:
          periodReminderDaysBefore ?? this.periodReminderDaysBefore,
      ovulationReminderEnabled:
          ovulationReminderEnabled ?? this.ovulationReminderEnabled,
      hydrationReminderEnabled:
          hydrationReminderEnabled ?? this.hydrationReminderEnabled,
      fertilityTrackingEnabled:
          fertilityTrackingEnabled ?? this.fertilityTrackingEnabled,
      pmsTrackingEnabled: pmsTrackingEnabled ?? this.pmsTrackingEnabled,
      shareWithCommunity: shareWithCommunity ?? this.shareWithCommunity,
      useCustomCycleLength: useCustomCycleLength ?? this.useCustomCycleLength,
    );
  }
}

class CyclePredictionSummary {
  final int averageCycleLength;
  final int averagePeriodDuration;
  final String? lastPeriodStart;
  final String? lastPeriodEnd;
  final String? nextPeriodStart;
  final String? nextPeriodEnd;
  final String? nextPeriodWindowStart;
  final String? nextPeriodWindowEnd;
  final int uncertaintyRangeDays;
  final int? daysUntilNextPeriod;
  final int? currentCycleDay;
  final String currentPhase;
  final String? estimatedOvulationDate;
  final String? fertileWindowStart;
  final String? fertileWindowEnd;
  final String? pmsWindowStart;
  final String? pmsWindowEnd;
  final int cycleVariationDays;
  final bool hasIrregularity;
  final String? irregularityReason;
  final String regularityStatus; // Regular, Variable, Irregular, Building History
  final bool isCustomMode;
  final String predictionBasisLabel;
  final String discreetNotificationPreview;
  final List<String> personalizedSuggestions;

  const CyclePredictionSummary({
    required this.averageCycleLength,
    required this.averagePeriodDuration,
    this.lastPeriodStart,
    this.lastPeriodEnd,
    this.nextPeriodStart,
    this.nextPeriodEnd,
    this.nextPeriodWindowStart,
    this.nextPeriodWindowEnd,
    this.uncertaintyRangeDays = 2,
    this.daysUntilNextPeriod,
    this.currentCycleDay,
    required this.currentPhase,
    this.estimatedOvulationDate,
    this.fertileWindowStart,
    this.fertileWindowEnd,
    this.pmsWindowStart,
    this.pmsWindowEnd,
    this.cycleVariationDays = 0,
    this.hasIrregularity = false,
    this.irregularityReason,
    required this.regularityStatus,
    this.isCustomMode = false,
    this.predictionBasisLabel = 'Automatic (History-Based)',
    required this.discreetNotificationPreview,
    required this.personalizedSuggestions,
  });
}

class CyclePredictionEngine {
  static String formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static DateTime parseIsoDate(String value) {
    final parts = value.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]) ?? DateTime.now().year;
      final m = int.tryParse(parts[1]) ?? DateTime.now().month;
      final d = int.tryParse(parts[2]) ?? DateTime.now().day;
      return DateTime(y, m, d);
    }
    final parsed = DateTime.tryParse(value) ?? DateTime.now();
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String addDaysIso(String isoDate, int days) {
    final dt = parseIsoDate(isoDate).add(Duration(days: days));
    return formatIsoDate(dt);
  }

  static int diffDaysIso(String startIso, String endIso) {
    final s = parseIsoDate(startIso);
    final e = parseIsoDate(endIso);
    return e.difference(s).inDays;
  }

  static CyclePredictionSummary compute({
    required List<MenstrualCycleEntry> cycles,
    required MenstrualTrackerPreferences prefs,
    DateTime? referenceDate,
  }) {
    final sortedAsc = List<MenstrualCycleEntry>.from(cycles)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    final observedLengths = <int>[];
    final observedDurations = <int>[];

    for (var i = 0; i < sortedAsc.length; i++) {
      final current = sortedAsc[i];
      if (current.endDate != null && current.endDate!.isNotEmpty) {
        final dur = diffDaysIso(current.startDate, current.endDate!) + 1;
        if (dur >= 1 && dur <= 15) {
          observedDurations.add(dur);
        }
      } else if (current.periodDurationDays != null &&
          current.periodDurationDays! >= 1 &&
          current.periodDurationDays! <= 15) {
        observedDurations.add(current.periodDurationDays!);
      }

      if (i + 1 < sortedAsc.length) {
        final gap = diffDaysIso(current.startDate, sortedAsc[i + 1].startDate);
        if (gap >= 15 && gap <= 60) {
          observedLengths.add(gap);
        }
      }
    }

    final recentLengths = observedLengths.length > 6
        ? observedLengths.sublist(observedLengths.length - 6)
        : observedLengths;
    int medianInt(List<int> vals) {
      final sorted = List<int>.from(vals)..sort();
      final mid = sorted.length ~/ 2;
      if (sorted.length.isOdd) return sorted[mid];
      return ((sorted[mid - 1] + sorted[mid]) / 2).round();
    }

    final avgCycleLength =
        (prefs.useCustomCycleLength || recentLengths.isEmpty)
        ? prefs.averageCycleLength.clamp(21, 40)
        : medianInt(recentLengths).clamp(21, 40);
    final predictionBasisLabel = prefs.useCustomCycleLength
        ? 'Custom Mode • Manual $avgCycleLength-day cycle length'
        : recentLengths.isNotEmpty
        ? 'Automatic Mode • Robust median of ${recentLengths.length} recent cycle interval(s) ($avgCycleLength days)'
        : 'Automatic Mode • Baseline $avgCycleLength-day fallback (log 2+ period start dates for history estimation)';

    final avgPeriodDuration = observedDurations.isNotEmpty
        ? medianInt(observedDurations).clamp(2, 10)
        : prefs.averagePeriodDuration.clamp(2, 10);

    var cycleVariationDays = 0;
    if (recentLengths.length >= 2) {
      final minLen = recentLengths.reduce((a, b) => a < b ? a : b);
      final maxLen = recentLengths.reduce((a, b) => a > b ? a : b);
      cycleVariationDays = maxLen - minLen;
    }
    final uncertaintyRangeDays = cycleVariationDays <= 2
        ? 2
        : ((cycleVariationDays / 2).round().clamp(2, 6));

    final hasIrregularity =
        cycleVariationDays > 7 ||
        observedLengths.any((len) => len < 21 || len > 35) ||
        sortedAsc.any((c) => c.isIrregular);

    String? irregularityReason;
    if (hasIrregularity) {
      if (cycleVariationDays > 7) {
        irregularityReason =
            'Your recorded cycle lengths vary by $cycleVariationDays days (typical clinical regularity is ≤ 7 days variation).';
      } else {
        irregularityReason =
            'One or more recorded cycles fell outside the typical 21–35 day range.';
      }
    }

    final regularityStatus = sortedAsc.length < 2
        ? 'Building History'
        : hasIrregularity
        ? 'Irregular'
        : cycleVariationDays <= 3
        ? 'Regular'
        : 'Variable';

    final latest = sortedAsc.isNotEmpty ? sortedAsc.last : null;
    final todayIso = formatIsoDate(referenceDate ?? DateTime.now());

    String? nextPeriodStart;
    String? nextPeriodEnd;
    String? estimatedOvulationDate;
    String? fertileWindowStart;
    String? fertileWindowEnd;
    String? pmsWindowStart;
    String? pmsWindowEnd;
    int? daysUntilNextPeriod;
    int? currentCycleDay;
    var currentPhase = 'Log your first period to view cycle phase estimates';

    if (latest != null) {
      nextPeriodStart = addDaysIso(latest.startDate, avgCycleLength);
      nextPeriodEnd = addDaysIso(nextPeriodStart, avgPeriodDuration - 1);
      daysUntilNextPeriod = diffDaysIso(todayIso, nextPeriodStart);
      currentCycleDay = diffDaysIso(latest.startDate, todayIso) + 1;

      if (prefs.fertilityTrackingEnabled) {
        estimatedOvulationDate = addDaysIso(nextPeriodStart, -14);
        fertileWindowStart = addDaysIso(estimatedOvulationDate, -5);
        fertileWindowEnd = addDaysIso(estimatedOvulationDate, 1);
      }
      if (prefs.pmsTrackingEnabled) {
        pmsWindowStart = addDaysIso(nextPeriodStart, -5);
        pmsWindowEnd = addDaysIso(nextPeriodStart, -1);
      }

      if (currentCycleDay >= 1 && currentCycleDay <= avgPeriodDuration) {
        currentPhase = 'Menstrual Phase';
      } else if (estimatedOvulationDate != null &&
          fertileWindowStart != null &&
          fertileWindowEnd != null &&
          todayIso.compareTo(fertileWindowStart) >= 0 &&
          todayIso.compareTo(fertileWindowEnd) <= 0) {
        currentPhase = todayIso == estimatedOvulationDate
            ? 'Estimated Ovulation Day'
            : 'Fertile Window (Estimate)';
      } else if (pmsWindowStart != null &&
          pmsWindowEnd != null &&
          todayIso.compareTo(pmsWindowStart) >= 0 &&
          todayIso.compareTo(pmsWindowEnd) <= 0) {
        currentPhase = 'Luteal / PMS Window';
      } else if (currentCycleDay > 0 &&
          currentCycleDay < (avgCycleLength - 14)) {
        currentPhase = 'Follicular Phase';
      } else {
        currentPhase = 'Luteal Phase';
      }
    }

    final discreetPreview = prefs.discreetNotifications
        ? 'Wellness Check-In: You have a personal calendar update waiting in your wellness tracker.'
        : nextPeriodStart != null
        ? 'Period Reminder: Your next estimated cycle begins around $nextPeriodStart.'
        : 'Period Reminder: Log your cycle dates to receive upcoming reminders.';

    final suggestions = <String>[
      if (currentPhase == 'Menstrual Phase') ...[
        'Prioritize iron-rich foods (spinach, lentils, dates, jaggery) paired with Vitamin C to replenish stores.',
        'Gentle heat therapy, warm ginger-fennel tea, and restorative stretches can soothe uterine cramps.',
      ] else if (currentPhase.contains('Fertile') ||
          currentPhase.contains('Ovulation')) ...[
        'Energy and communication often peak mid-cycle — stay well hydrated (8–10 glasses of water) and add antioxidant-rich berries or greens.',
        'Important Reminder: Fertility and ovulation windows are mathematical estimates and must never be used as contraception.',
      ] else if (currentPhase.contains('PMS') ||
          currentPhase == 'Luteal Phase') ...[
        'Complex carbohydrates, magnesium-rich foods (pumpkin seeds, almonds, bananas), and reducing excess salt help ease bloating and mood shifts.',
        'Wind down 30 minutes earlier tonight to support progesterone-linked sleep changes.',
      ] else ...[
        'Follicular phase supports steady energy — a great window for strength training, brisk walks, and learning new skills.',
        'Keep logging daily mood, hydration, and cramps to sharpen your rolling cycle predictions.',
      ],
    ];

    return CyclePredictionSummary(
      averageCycleLength: avgCycleLength,
      averagePeriodDuration: avgPeriodDuration,
      lastPeriodStart: latest?.startDate,
      lastPeriodEnd:
          latest?.endDate ??
          (latest != null
              ? addDaysIso(latest.startDate, avgPeriodDuration - 1)
              : null),
      nextPeriodStart: nextPeriodStart,
      nextPeriodEnd: nextPeriodEnd,
      nextPeriodWindowStart: nextPeriodStart != null
          ? addDaysIso(nextPeriodStart, -uncertaintyRangeDays)
          : null,
      nextPeriodWindowEnd: nextPeriodStart != null
          ? addDaysIso(nextPeriodStart, uncertaintyRangeDays)
          : null,
      uncertaintyRangeDays: uncertaintyRangeDays,
      daysUntilNextPeriod: daysUntilNextPeriod,
      currentCycleDay: currentCycleDay,
      currentPhase: currentPhase,
      estimatedOvulationDate: estimatedOvulationDate,
      fertileWindowStart: fertileWindowStart,
      fertileWindowEnd: fertileWindowEnd,
      pmsWindowStart: pmsWindowStart,
      pmsWindowEnd: pmsWindowEnd,
      cycleVariationDays: cycleVariationDays,
      hasIrregularity: hasIrregularity,
      irregularityReason: irregularityReason,
      regularityStatus: regularityStatus,
      isCustomMode: prefs.useCustomCycleLength,
      predictionBasisLabel: predictionBasisLabel,
      discreetNotificationPreview: discreetPreview,
      personalizedSuggestions: suggestions,
    );
  }
}

class MenstrualHealthArticle {
  final String id;
  final String title;
  final String category;
  final String readTime;
  final String summary;
  final List<String> keyTakeaways;
  final String clinicalNote;
  final String sourceOrganization;
  final String sourceUrl;

  const MenstrualHealthArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.readTime,
    required this.summary,
    required this.keyTakeaways,
    required this.clinicalNote,
    this.sourceOrganization = 'ACOG / WHO Patient Education',
    this.sourceUrl = 'https://www.acog.org/womens-health/faqs/dysmenorrhea-painful-periods',
  });
}

class MenstrualHealthFaq {
  final String question;
  final String answer;

  const MenstrualHealthFaq({required this.question, required this.answer});
}

const List<MenstrualHealthArticle> sakhiMenstrualHealthArticles = [
  MenstrualHealthArticle(
    id: 'period-pain-heat-therapy',
    title: 'Warm Compress & Comfort Care for Period Cramps',
    category: 'Period Pain Help',
    readTime: '3 min read • Reviewed Nov 2026',
    summary:
        'General wellness suggestions for applying gentle external warmth to relax abdominal and lower-back muscle tension during menstruation (Reference: ACOG Patient Education on Dysmenorrhea).',
    keyTakeaways: [
      'Place a warm water bottle or heating pad wrapped in a soft cloth over the lower abdomen or lower back for 15–20 minute intervals.',
      'A warm shower or bath offers general relaxation and comfort before rest.',
      'Wellness Notice: External warmth is a supportive comfort measure, not a medical treatment. Consult a qualified clinician if cramps are severe or disrupt daily life.',
    ],
    clinicalNote:
        'Always place a protective cloth layer between a warm compress and your skin to avoid thermal irritation.',
  ),
  MenstrualHealthArticle(
    id: 'period-pain-gentle-exercise',
    title: 'Gentle Stretching & Restorative Movement on Period Days',
    category: 'Period Pain Help',
    readTime: '4 min read • Reviewed Nov 2026',
    summary:
        'Optional, low-impact stretches and light movement ideas for days when you feel comfortable moving (Reference: ACOG Exercise & Menstrual Comfort Overview).',
    keyTakeaways: [
      'Restorative postures such as Child’s Pose (Balasana) or reclining with a pillow under your knees may feel comforting for lower-back tension.',
      'If your energy allows, a short, unhurried walk outdoors can support general circulation and mood.',
      'Pace movement to how you feel: prioritize rest on heavy flow days and stop any activity that causes discomfort.',
    ],
    clinicalNote:
        'Stop any movement that increases sharp pain or dizziness, and consult a healthcare professional for persistent pelvic pain.',
  ),
  MenstrualHealthArticle(
    id: 'period-pain-hydration-rest',
    title: 'Hydration, Warm Fluids & Balanced Meals During Menstruation',
    category: 'Period Pain Help',
    readTime: '4 min read • Reviewed Nov 2026',
    summary:
        'Everyday hydration, nutrition, and restful sleep postures to support energy and iron intake during your menstrual cycle (Reference: WHO & ICMR-NIN Dietary Guidelines).',
    keyTakeaways: [
      'Sipping warm water or caffeine-free herbal infusions (such as ginger or chamomile) helps maintain daily hydration.',
      'Rest on your side with a pillow between your knees to reduce pressure on the lower back and abdomen.',
      'Include iron-containing foods (spinach, lentils, ragi, dates) alongside Vitamin C sources (lemon, amla, orange) as part of a balanced diet.',
    ],
    clinicalNote:
        'If period pain causes fainting, vomiting, fever, or soaking through a pad every hour for 2+ consecutive hours, seek medical care promptly.',
  ),
  MenstrualHealthArticle(
    id: 'four-phases',
    title: 'Understanding the 4 Phases of Your Menstrual Cycle',
    category: 'Cycle Science',
    readTime: '4 min read • Reviewed Nov 2026',
    summary:
        'An educational overview of how the Menstrual, Follicular, Ovulatory, and Luteal phases progress across 21–35 day cycles (Reference: ACOG Menstrual Cycle Overview).',
    keyTakeaways: [
      'Menstrual Phase (Days 1–5): Uterine lining sheds over 2–7 days. Focus on hydration, balanced iron-rich meals, and extra rest.',
      'Follicular Phase: Estrogen rises ahead of ovulation; energy often feels steadier.',
      'Ovulatory Phase: Luteinizing hormone surges to release an egg. Remember that calendar estimates cannot pinpoint exact ovulation.',
      'Luteal Phase: Progesterone rises after ovulation until your next period begins.',
    ],
    clinicalNote:
        'A typical adult menstrual cycle ranges from 21 to 35 days (including 24, 26, 28, or 32 days), with bleeding lasting 2 to 7 days.',
  ),
  MenstrualHealthArticle(
    id: 'irregular-cycles',
    title: 'Warning Signs: When to Consult a Gynecologist',
    category: 'Clinical Guidance',
    readTime: '5 min read • Reviewed Nov 2026',
    summary:
        'Occasional cycle shifts of a few days are common during travel, exams, illness, or stress. Persistent variation greater than 7–9 days or cycles shorter than 21 days or longer than 35 days merit clinical evaluation.',
    keyTakeaways: [
      'Potential causes of persistent cycle irregularity include PCOS, thyroid conditions, nutritional deficiencies, perimenopause, and high stress.',
      'Track period start/end dates, flow intensity, and symptoms for 3 cycles to share with your healthcare provider.',
      'Use the "Export Clinical Report" button in this tracker to generate a structured summary for your gynecologist.',
    ],
    clinicalNote:
        'Medical Disclaimer: Sakhi provides personal logging and educational information only and does not diagnose or treat medical conditions.',
  ),
  MenstrualHealthArticle(
    id: 'fertility-awareness-myths',
    title: 'Why Calendar Ovulation Estimates Are Not Contraception',
    category: 'Reproductive Literacy',
    readTime: '3 min read • Reviewed Nov 2026',
    summary:
        'Calendar-based apps estimate ovulation by counting back 14 days from your next expected period. Because ovulation timing can shift unexpectedly in any given month, calendar estimates alone cannot prevent pregnancy.',
    keyTakeaways: [
      'Sperm can survive in the reproductive tract for up to 5 days, and stress or illness can shift ovulation earlier or later without warning.',
      'Even women with regular cycles experience natural follicular and luteal phase variations.',
      'Always consult a qualified gynecologist for reliable contraceptive options tailored to your health profile.',
    ],
    clinicalNote:
        'Clinical Guidance: Fertility windows in Sakhi are informational estimates only and must never be treated as contraception.',
    sourceOrganization: 'ACOG Fertility Awareness Guidance',
    sourceUrl: 'https://www.acog.org/womens-health/faqs/fertility-awareness-based-methods-of-family-planning',
  ),
  MenstrualHealthArticle(
    id: 'pcos-and-thyroid-cycle-awareness',
    title: 'PCOS, Thyroid Health & Cycle Regularity Explained',
    category: 'Endocrine & Cycle Health',
    readTime: '5 min read • Reviewed Nov 2026',
    summary:
        'How common endocrine conditions such as Polycystic Ovary Syndrome (PCOS) and thyroid imbalances affect ovulation frequency, cycle intervals, and energy levels (Reference: WHO & NHS Women’s Health Guidance).',
    keyTakeaways: [
      'Cycles consistently longer than 35 days or fewer than 8–9 periods per year can be associated with ovulatory shifts such as PCOS.',
      'Both hypothyroidism and hyperthyroidism can contribute to lighter, heavier, or irregular menstrual bleeding and persistent fatigue.',
      'Logging cycle lengths, acne, sleep, and energy patterns over 3–6 months gives your clinician clear, structured history.',
    ],
    clinicalNote:
        'Only a qualified clinician can diagnose PCOS or thyroid conditions through clinical history, blood panels, or ultrasound.',
    sourceOrganization: 'World Health Organization (WHO) & NHS',
    sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/polycystic-ovary-syndrome',
  ),
  MenstrualHealthArticle(
    id: 'menstrual-hygiene-and-safe-product-use',
    title: 'Menstrual Hygiene, Safe Pad/Cup Change Intervals & Skin Comfort',
    category: 'Hygiene & Comfort',
    readTime: '4 min read • Reviewed Nov 2026',
    summary:
        'Practical, evidence-based menstrual hygiene habits to prevent skin irritation, rashes, and reproductive tract discomfort (Reference: UNICEF & WHO Menstrual Health Guidelines).',
    keyTakeaways: [
      'Change sanitary pads every 4–6 hours (and more frequently on heavy flow days) to keep skin dry and prevent chafing.',
      'If using a reusable menstrual cup, empty and rinse with clean water every 6–8 hours (up to 12 hours maximum) and sterilize between cycles.',
      'Wash the external vulvar area gently with plain warm water; avoid scented washes or internal douching which disrupt natural flora.',
    ],
    clinicalNote:
        'Seek medical evaluation if you notice persistent itching, unusual odor, pelvic pain, or fever during or after menstruation.',
    sourceOrganization: 'WHO / UNICEF Menstrual Health & Hygiene',
    sourceUrl: 'https://www.who.int/publications/i/item/9789240050181',
  ),
];

const List<MenstrualHealthFaq> sakhiMenstrualHealthFaqs = [
  MenstrualHealthFaq(
    question: 'Can anyone else on Sakhi or the Admin team see my period logs?',
    answer:
        'No. Under Sakhi’s strict health-data isolation architecture, your menstrual and reproductive health data is classified as strictly private. It is never shown on your public profile, never posted to the Social Wall, never shared with advertising/analytics, and blocked from administrator view.',
  ),
  MenstrualHealthFaq(
    question: 'How does Sakhi estimate my next period and fertile window?',
    answer:
        'Sakhi calculates a rolling average of your completed cycle lengths (up to your last 6 logged cycles) and period durations. It estimates ovulation roughly 14 days before your next expected period start, with a 6-day fertile window estimate.',
  ),
  MenstrualHealthFaq(
    question: 'What do Discreet Notifications look like on my lock screen?',
    answer:
        'When Discreet Notifications are enabled (the default), lock-screen alerts use neutral wording — "Wellness Check-In: You have a personal calendar update waiting in your wellness tracker" — without mentioning periods, ovulation, or symptoms.',
  ),
  MenstrualHealthFaq(
    question: 'Can I rely on the fertile window estimate to avoid pregnancy?',
    answer:
        'No. Calendar-based ovulation and fertility predictions are mathematical estimates and must NEVER be used as contraception. Ovulation can shift in any cycle.',
  ),
  MenstrualHealthFaq(
    question: 'How can I export or permanently delete my cycle tracking history?',
    answer:
        'Open the "Care, FAQs & Privacy" tab in the Menstrual Cycle Tracker. You can export a Doctor/Gynecologist clinical summary + JSON archive, or tap "Delete All Health Data" to permanently wipe both your cloud database records and local device cache.',
  ),
];

class MenstrualCycleController extends ChangeNotifier {
  MenstrualCycleController._();
  static final MenstrualCycleController instance = MenstrualCycleController._();

  static const String _storageKey = 'sakhi_module7_cycle_tracker_v1';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  BackendApiClient? _apiClient;
  BackendApiClient get _client => _apiClient ??= BackendApiClient();

  List<MenstrualCycleEntry> cycles = <MenstrualCycleEntry>[];
  List<MenstrualDailyLogEntry> dailyLogs = <MenstrualDailyLogEntry>[];
  MenstrualTrackerPreferences preferences = const MenstrualTrackerPreferences();
  bool isLoading = false;
  bool isSyncing = false;
  String? lastSyncMessage;

  static const List<String> supportedSymptoms = <String>[
    'Cramps',
    'Headache',
    'Fatigue',
    'Bloating',
    'Backache',
    'Tender Breasts',
    'Acne',
    'Cravings',
    'Insomnia',
    'Nausea',
  ];

  static const List<String> supportedMoods = <String>[
    'Calm',
    'Happy',
    'Energized',
    'Sensitive',
    'Tired',
    'Anxious',
    'Irritable',
  ];

  static const List<String> supportedFlows = <String>[
    'Spotting',
    'Light',
    'Medium',
    'Heavy',
  ];

  static const List<String> supportedCramps = <String>[
    'None',
    'Mild',
    'Moderate',
    'Severe',
  ];

  CyclePredictionSummary get predictions =>
      CyclePredictionEngine.compute(cycles: cycles, prefs: preferences);

  MenstrualDailyLogEntry? dailyLogForDate(String isoDate) {
    for (final entry in dailyLogs) {
      if (entry.logDate == isoDate) return entry;
    }
    return null;
  }

  bool isLoggedPeriodDay(String isoDate) {
    for (final c in cycles) {
      final end =
          c.endDate ??
          CyclePredictionEngine.addDaysIso(
            c.startDate,
            (c.periodDurationDays ?? preferences.averagePeriodDuration) - 1,
          );
      if (isoDate.compareTo(c.startDate) >= 0 && isoDate.compareTo(end) <= 0) {
        return true;
      }
    }
    final daily = dailyLogForDate(isoDate);
    if (daily != null &&
        daily.flowIntensity != null &&
        daily.flowIntensity != 'None') {
      return true;
    }
    return false;
  }

  bool isPredictedPeriodDay(String isoDate) {
    final p = predictions;
    if (p.nextPeriodStart == null || p.nextPeriodEnd == null) return false;
    return isoDate.compareTo(p.nextPeriodStart!) >= 0 &&
        isoDate.compareTo(p.nextPeriodEnd!) <= 0;
  }

  bool isFertileWindowDay(String isoDate) {
    if (!preferences.fertilityTrackingEnabled) return false;
    final p = predictions;
    if (p.fertileWindowStart == null || p.fertileWindowEnd == null) {
      return false;
    }
    return isoDate.compareTo(p.fertileWindowStart!) >= 0 &&
        isoDate.compareTo(p.fertileWindowEnd!) <= 0;
  }

  bool isOvulationDay(String isoDate) {
    if (!preferences.fertilityTrackingEnabled) return false;
    return predictions.estimatedOvulationDate == isoDate;
  }

  bool isPmsWindowDay(String isoDate) {
    if (!preferences.pmsTrackingEnabled) return false;
    final p = predictions;
    if (p.pmsWindowStart == null || p.pmsWindowEnd == null) return false;
    return isoDate.compareTo(p.pmsWindowStart!) >= 0 &&
        isoDate.compareTo(p.pmsWindowEnd!) <= 0;
  }

  String? lastReminderScheduleStatus;

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    await _loadFromEncryptedLocalStorage();
    isLoading = false;
    notifyListeners();
    await _scheduleNativeDiscreetReminderIfNeeded();
    await syncWithBackend();
  }

  Future<void> _loadFromEncryptedLocalStorage() async {
    try {
      final raw = await _secureStorage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['cycles'] is List) {
        cycles = (decoded['cycles'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MenstrualCycleEntry.fromJson)
            .toList();
      }
      if (decoded['dailyLogs'] is List) {
        dailyLogs = (decoded['dailyLogs'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MenstrualDailyLogEntry.fromJson)
            .toList();
      }
      if (decoded['preferences'] is Map<String, dynamic>) {
        preferences = MenstrualTrackerPreferences.fromJson(
          decoded['preferences'] as Map<String, dynamic>,
        );
      }
    } catch (_) {}
  }

  Future<void> _saveToEncryptedLocalStorage() async {
    try {
      final payload = jsonEncode({
        'cycles': cycles.map((c) => c.toJson()).toList(),
        'dailyLogs': dailyLogs.map((d) => d.toJson()).toList(),
        'preferences': preferences.toJson(),
      });
      await _secureStorage.write(key: _storageKey, value: payload);
    } catch (_) {}
  }

  Future<void> syncWithBackend() async {
    isSyncing = true;
    notifyListeners();
    try {
      final res = await _client.get(
        'module2/cycle-tracker/overview',
        authenticated: true,
      );
      final rawCycles = res['cycles'] ?? res['cycleLogs'];
      if (rawCycles is List) {
        cycles = rawCycles
            .whereType<Map<String, dynamic>>()
            .map(MenstrualCycleEntry.fromJson)
            .toList();
      }
      if (res['dailyLogs'] is List) {
        dailyLogs = (res['dailyLogs'] as List)
            .whereType<Map<String, dynamic>>()
            .map(MenstrualDailyLogEntry.fromJson)
            .toList();
      }
      if (res['preferences'] is Map<String, dynamic>) {
        preferences = MenstrualTrackerPreferences.fromJson(
          res['preferences'] as Map<String, dynamic>,
        );
      }
      await _saveToEncryptedLocalStorage();
      await _scheduleNativeDiscreetReminderIfNeeded();
      lastSyncMessage = 'Private health vault synced';
    } catch (_) {
      lastSyncMessage = 'Protected in local encrypted vault';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  /// Convenience alias for upsertCycle
  Future<bool> saveCycle({
    String? cycleId,
    required String startDate,
    String? endDate,
    required String flowIntensity,
    String? notes,
  }) => upsertCycle(
    cycleId: cycleId,
    startDate: startDate,
    endDate: endDate,
    flowIntensity: flowIntensity,
    notes: notes,
  );

  Future<bool> upsertCycle({
    String? cycleId,
    required String startDate,
    String? endDate,
    required String flowIntensity,
    String? notes,
  }) async {
    final periodDurationDays = (endDate != null && endDate.isNotEmpty)
        ? (CyclePredictionEngine.diffDaysIso(startDate, endDate) + 1).clamp(
            1,
            15,
          )
        : preferences.averagePeriodDuration;

    final localEntry = MenstrualCycleEntry(
      id: cycleId ?? 'local_cycle_${DateTime.now().millisecondsSinceEpoch}',
      startDate: startDate,
      endDate: endDate,
      periodDurationDays: periodDurationDays,
      flowIntensity: flowIntensity,
      notes: notes,
      createdAt: DateTime.now().toIso8601String(),
    );

    final existingIdx = cycles.indexWhere(
      (c) => (cycleId != null && c.id == cycleId) || c.startDate == startDate,
    );
    if (existingIdx >= 0) {
      cycles[existingIdx] = localEntry;
    } else {
      cycles.insert(0, localEntry);
    }
    cycles.sort((a, b) => b.startDate.compareTo(a.startDate));
    await _saveToEncryptedLocalStorage();
    notifyListeners();
    await _scheduleNativeDiscreetReminderIfNeeded();

    try {
      await _client.post(
        'module2/cycle-tracker/cycles',
        authenticated: true,
        body: {
          if (cycleId != null && !cycleId.startsWith('local_'))
            'cycleId': cycleId,
          'startDate': startDate,
          if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
          'flowIntensity': flowIntensity,
          'notes': notes ?? '',
        },
      );
      await syncWithBackend();
    } catch (_) {}
    return true;
  }

  Future<bool> deleteCycle(String cycleId) async {
    cycles.removeWhere((c) => c.id == cycleId);
    await _saveToEncryptedLocalStorage();
    notifyListeners();
    await _scheduleNativeDiscreetReminderIfNeeded();
    if (!cycleId.startsWith('local_')) {
      try {
        await _client.delete(
          'module2/cycle-tracker/cycles/${Uri.encodeComponent(cycleId)}',
          authenticated: true,
        );
        await syncWithBackend();
      } catch (_) {}
    }
    return true;
  }

  Future<bool> upsertDailyLog({
    required String logDate,
    String? flowIntensity,
    String? crampsSeverity,
    String? mood,
    int? energyLevel,
    required List<String> symptoms,
    bool isPmsWindow = false,
    required int hydrationGlasses,
    double? sleepHours,
    String? personalNotes,
  }) async {
    final existing = dailyLogForDate(logDate);
    final entry = MenstrualDailyLogEntry(
      id: existing?.id ?? 'local_log_${DateTime.now().millisecondsSinceEpoch}',
      logDate: logDate,
      flowIntensity: flowIntensity,
      crampsSeverity: crampsSeverity,
      mood: mood,
      energyLevel: energyLevel,
      symptoms: symptoms,
      isPmsWindow: isPmsWindow,
      hydrationGlasses: hydrationGlasses.clamp(0, 20),
      sleepHours: sleepHours,
      personalNotes: personalNotes,
    );

    final idx = dailyLogs.indexWhere((d) => d.logDate == logDate);
    if (idx >= 0) {
      dailyLogs[idx] = entry;
    } else {
      dailyLogs.insert(0, entry);
    }
    dailyLogs.sort((a, b) => b.logDate.compareTo(a.logDate));
    await _saveToEncryptedLocalStorage();
    notifyListeners();

    try {
      await _client.post(
        'module2/cycle-tracker/daily-logs',
        authenticated: true,
        body: {
          'logDate': logDate,
          'flowIntensity': flowIntensity,
          'crampsSeverity': crampsSeverity,
          'mood': mood,
          'energyLevel': energyLevel,
          'symptoms': symptoms,
          'isPmsWindow': isPmsWindow,
          'hydrationGlasses': hydrationGlasses.clamp(0, 20),
          'sleepHours': sleepHours,
          'personalNotes': personalNotes,
        },
      );
      await syncWithBackend();
    } catch (_) {}
    return true;
  }

  Future<bool> deleteDailyLog(String logId, String logDate) async {
    dailyLogs.removeWhere((d) => d.id == logId || d.logDate == logDate);
    await _saveToEncryptedLocalStorage();
    notifyListeners();
    if (!logId.startsWith('local_')) {
      try {
        await _client.delete(
          'module2/cycle-tracker/daily-logs/${Uri.encodeComponent(logId)}',
          authenticated: true,
        );
        await syncWithBackend();
      } catch (_) {}
    }
    return true;
  }

  static const MethodChannel _wellnessChannel =
      MethodChannel('sakhi/safety_hardware');

  Future<bool> _scheduleNativeDiscreetReminderIfNeeded() async {
    try {
      final p = predictions;
      if (!preferences.notificationsEnabled ||
          p.nextPeriodStart == null ||
          p.nextPeriodStart!.isEmpty) {
        await _wellnessChannel.invokeMethod('cancelDiscreetWellnessReminder');
        lastReminderScheduleStatus = 'Reminders disabled or no cycle logged';
        return true;
      }
      final title = preferences.discreetNotifications
          ? 'Wellness Check-In'
          : 'Upcoming Period Reminder';
      final body = p.discreetNotificationPreview;
      final dynamic rawRes = await _wellnessChannel.invokeMethod(
        'scheduleDiscreetWellnessReminder',
        {
          'title': title,
          'body': body,
          'daysBefore': preferences.periodReminderDaysBefore,
          'nextPeriodStart': p.nextPeriodStart!,
          'discreet': preferences.discreetNotifications,
        },
      );
      if (rawRes is Map) {
        final scheduled = rawRes['scheduled'] == true;
        lastReminderScheduleStatus = scheduled
            ? 'Scheduled for ${preferences.periodReminderDaysBefore}d before ${p.nextPeriodStart}'
            : (rawRes['reason']?.toString() ?? 'Not scheduled');
        return scheduled;
      }
      lastReminderScheduleStatus = 'Scheduled';
      return true;
    } on PlatformException catch (e) {
      lastReminderScheduleStatus =
          'Reminder scheduling failed: ${e.message ?? e.code}';
      return false;
    } catch (_) {
      lastReminderScheduleStatus = 'Reminder scheduling unavailable on platform';
      return false;
    }
  }

  int _preferenceMutationSeq = 0;

  Future<void> updatePreferences(MenstrualTrackerPreferences updated) async {
    final mutationSeq = ++_preferenceMutationSeq;
    preferences = updated;
    await _saveToEncryptedLocalStorage();
    notifyListeners();
    await _scheduleNativeDiscreetReminderIfNeeded();
    try {
      await _client.patch(
        'module2/cycle-tracker/preferences',
        authenticated: true,
        body: updated.toJson(),
      );
      if (mutationSeq == _preferenceMutationSeq) {
        lastSyncMessage = 'Private health vault synced';
        notifyListeners();
      }
    } catch (_) {
      if (mutationSeq == _preferenceMutationSeq) {
        lastSyncMessage = 'Protected in local encrypted vault';
        notifyListeners();
      }
    }
  }

  /// Generates a valid, self-contained %PDF-1.4 document for clinical/personal
  /// sharing so the user exports a clean formatted PDF rather than raw HTML/text.
  Uint8List generateClinicalSummaryPdfBytes({
    int maxCycles = 12,
    int maxDailyLogs = 30,
    bool includeCycleSummary = true,
    bool includeCycleHistory = true,
    bool includeDailySymptoms = true,
  }) {
    final p = predictions;
    final lines = <String>[
      'SAKHI WOMEN'S MENSTRUAL HEALTH & CYCLE SUMMARY (PDF)',
      'Generated: ${DateTime.now().toIso8601String().substring(0, 19).replaceFirst('T', ' ')}',
      'Privacy Classification: Strictly Owner-Isolated & Encrypted Health Vault',
      '------------------------------------------------------------------------',
    ];

    if (includeCycleSummary) {
      lines.addAll([
        '',
        '1. CYCLE SUMMARY & PREDICTION ESTIMATES',
        '   Prediction Mode: ${p.predictionBasisLabel}',
        '   Median/Custom Cycle Length: ${p.averageCycleLength} days (+/- ${p.uncertaintyRangeDays}d window)',
        '   Average Period Duration: ${p.averagePeriodDuration} days',
        '   Regularity Status: ${p.regularityStatus} (Variation: ${p.cycleVariationDays} days)',
        '   Last Recorded Period Start: ${p.lastPeriodStart ?? "None recorded"}',
        '   Estimated Next Period: ${p.nextPeriodStart ?? "Pending"} '
            '${p.nextPeriodWindowStart != null ? "(Window: ${p.nextPeriodWindowStart} to ${p.nextPeriodWindowEnd})" : ""}',
        '   Current Phase Estimate: ${p.currentPhase}',
        '   Irregularity Flag: ${p.hasIrregularity ? "Yes - ${p.irregularityReason}" : "None detected"}',
      ]);
    }

    if (includeCycleHistory) {
      final slice = cycles.take(maxCycles).toList();
      lines.addAll([
        '',
        '2. RECORDED MENSTRUAL CYCLES (${slice.length} of ${cycles.length})',
      ]);
      if (slice.isEmpty) {
        lines.add('   No menstrual cycle entries recorded in selected range.');
      } else {
        for (final c in slice) {
          lines.add(
            '   - Start: ${c.startDate} | End: ${c.endDate ?? "Estimated"} | '
            'Flow: ${c.flowIntensity} | Duration: ${c.periodDurationDays ?? p.averagePeriodDuration}d'
            '${c.notes != null && c.notes!.isNotEmpty ? " | Note: ${c.notes}" : ""}',
          );
        }
      }
    }

    if (includeDailySymptoms) {
      final logSlice = dailyLogs.take(maxDailyLogs).toList();
      lines.addAll([
        '',
        '3. DAILY SYMPTOM & WELLNESS LOGS (${logSlice.length} of ${dailyLogs.length})',
      ]);
      if (logSlice.isEmpty) {
        lines.add('   No daily symptom logs recorded in selected range.');
      } else {
        for (final d in logSlice) {
          lines.add(
            '   - ${d.logDate}: Flow=${d.flowIntensity ?? "None"}, '
            'Cramps=${d.crampsSeverity ?? "None"}, Mood=${d.mood ?? "-"}, '
            'Energy=${d.energyLevel ?? "-"}/5, Water=${d.hydrationGlasses}gl, '
            'Symptoms=[${d.symptoms.join(", ")}]',
          );
        }
      }
    }

    lines.addAll([
      '',
      '4. MEDICAL & CONTRACEPTIVE DISCLAIMER',
      '   This report is a personal wellness summary and mathematical estimate.',
      '   It is not a medical diagnosis and must never be used as contraception.',
    ]);

    String escapePdfText(String s) {
      return s
          .replaceAll(r'\', r'\\')
          .replaceAll('(', r'\(')
          .replaceAll(')', r'\)')
          .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ');
    }

    final streamBuf = StringBuffer()
      ..writeln('BT')
      ..writeln('/F1 10 Tf')
      ..writeln('14 TL')
      ..writeln('42 790 Td');
    for (var i = 0; i < lines.length && i < 52; i++) {
      final escaped = escapePdfText(lines[i]);
      if (i == 0) {
        streamBuf.writeln('($escaped) Tj');
      } else {
        streamBuf.writeln('T* ($escaped) Tj');
      }
    }
    streamBuf.writeln('ET');
    final contentStream = streamBuf.toString();

    final objects = <String>[
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] '
          '/Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
      '5 0 obj\n<< /Length ${contentStream.length} >>\nstream\n$contentStream\nendstream\nendobj\n',
    ];

    final pdf = StringBuffer('%PDF-1.4
');
    final offsets = <int>[0];
    for (final obj in objects) {
      final normalizedObj = obj.replaceAll(r'
', '
');
      offsets.add(pdf.length);
      pdf.write(normalizedObj);
    }
    final xrefOffset = pdf.length;
    pdf.writeln('xref');
    pdf.writeln('0 ${objects.length + 1}');
    pdf.writeln('0000000000 65535 f ');
    for (var i = 1; i < offsets.length; i++) {
      pdf.writeln('${offsets[i].toString().padLeft(10, '0')} 00000 n ');
    }
    pdf.writeln('trailer');
    pdf.writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>');
    pdf.writeln('startxref');
    pdf.writeln('$xrefOffset');
    pdf.write('%%EOF');
    return Uint8List.fromList(utf8.encode(pdf.toString()));
  }

  String generateClinicalExportReport() {
    final p = predictions;
    final buf = StringBuffer()
      ..writeln('====================================================')
      ..writeln('SAKHI WOMEN’S MENSTRUAL HEALTH CLINICAL SUMMARY')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Privacy Classification: STRICTLY OWNER-ISOLATED & ENCRYPTED')
      ..writeln('====================================================')
      ..writeln('')
      ..writeln('1. CYCLE SUMMARY & ROLLING AVERAGES')
      ..writeln('• Prediction Mode: ${p.predictionBasisLabel}')
      ..writeln('• Average Cycle Length: ${p.averageCycleLength} days')
      ..writeln('• Average Period Duration: ${p.averagePeriodDuration} days')
      ..writeln('• Regularity Status: ${p.regularityStatus}')
      ..writeln('• Cycle Variation: ${p.cycleVariationDays} days')
      ..writeln('• Last Recorded Period Start: ${p.lastPeriodStart ?? "None"}')
      ..writeln('• Estimated Next Period: ${p.nextPeriodStart ?? "Pending"}')
      ..writeln('• Current Phase Estimate: ${p.currentPhase}')
      ..writeln(
        '• Irregularity Flag: ${p.hasIrregularity ? "YES (${p.irregularityReason})" : "None detected"}',
      )
      ..writeln('')
      ..writeln('2. HISTORICAL MENSTRUAL CYCLES (${cycles.length})');

    if (cycles.isEmpty) {
      buf.writeln('  No cycle entries recorded.');
    } else {
      for (final c in cycles) {
        buf.writeln(
          '  - Start: ${c.startDate} | End: ${c.endDate ?? "Ongoing/Est"} | Flow: ${c.flowIntensity} | Duration: ${c.periodDurationDays ?? p.averagePeriodDuration}d${c.notes != null && c.notes!.isNotEmpty ? " | Notes: ${c.notes}" : ""}',
        );
      }
    }

    buf
      ..writeln('')
      ..writeln('3. RECENT DAILY SYMPTOM & WELLNESS LOGS (${dailyLogs.length})');
    if (dailyLogs.isEmpty) {
      buf.writeln('  No daily symptom logs recorded.');
    } else {
      for (final d in dailyLogs.take(30)) {
        buf.writeln(
          '  - ${d.logDate}: Flow=${d.flowIntensity ?? "None"}, Cramps=${d.crampsSeverity ?? "None"}, Mood=${d.mood ?? "-"}, Energy=${d.energyLevel ?? "-"}/5, Hydration=${d.hydrationGlasses} glasses, Symptoms=[${d.symptoms.join(", ")}]${d.personalNotes != null && d.personalNotes!.isNotEmpty ? " | Note: ${d.personalNotes}" : ""}',
        );
      }
    }

    buf
      ..writeln('')
      ..writeln('4. MEDICAL & WELLNESS DISCLAIMER')
      ..writeln(
        'This export is a personal wellness record and mathematical estimate. It is not a medical diagnosis or contraceptive guide.',
      );
    return buf.toString();
  }

  Future<bool> deleteAllPersonalTrackingData() async {
    final token = await _client.readAccessToken().catchError((Object _) => null);
    if (token != null && token.isNotEmpty) {
      try {
        final res = await _client.delete(
          'module2/cycle-tracker/data',
          authenticated: true,
        );
        if (res['deleted'] != true) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }

    cycles.clear();
    dailyLogs.clear();
    preferences = const MenstrualTrackerPreferences();
    try {
      await _secureStorage.delete(key: _storageKey);
    } catch (_) {}
    try {
      await _wellnessChannel.invokeMethod('cancelDiscreetWellnessReminder');
    } catch (_) {}
    notifyListeners();
    return true;
  }
}
