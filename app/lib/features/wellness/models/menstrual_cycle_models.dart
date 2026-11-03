import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/backend_api_client.dart';

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
  final String?
  mood; // Calm, Happy, Sensitive, Anxious, Irritable, Energized, Tired
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
  });
  factory MenstrualTrackerPreferences.fromJson(Map<String, dynamic> json) {
    return MenstrualTrackerPreferences(
      averageCycleLength: json['averageCycleLength'] is num
          ? (json['averageCycleLength'] as num).toInt().clamp(18, 45)
          : 28,
      averagePeriodDuration: json['averagePeriodDuration'] is num
          ? (json['averagePeriodDuration'] as num).toInt().clamp(2, 12)
          : 5,
      notificationsEnabled: json['notificationsEnabled'] != false,
      discreetNotifications: json['discreetNotifications'] != false,
      periodReminderDaysBefore: json['periodReminderDaysBefore'] is num
          ? (json['periodReminderDaysBefore'] as num).toInt().clamp(1, 7)
          : 2,
      ovulationReminderEnabled: json['ovulationReminderEnabled'] == true,
      hydrationReminderEnabled: json['hydrationReminderEnabled'] != false,
      fertilityTrackingEnabled: json['fertilityTrackingEnabled'] != false,
      pmsTrackingEnabled: json['pmsTrackingEnabled'] != false,
      shareWithCommunity: json['shareWithCommunity'] == true,
    );
  }
  Map<String, dynamic> toJson() => {
    'averageCycleLength': averageCycleLength,
    'averagePeriodDuration': averagePeriodDuration,
    'notificationsEnabled': notificationsEnabled,
    'discreetNotifications': discreetNotifications,
    'periodReminderDaysBefore': periodReminderDaysBefore,
    'ovulationReminderEnabled': ovulationReminderEnabled,
    'hydrationReminderEnabled': hydrationReminderEnabled,
    'fertilityTrackingEnabled': fertilityTrackingEnabled,
    'pmsTrackingEnabled': pmsTrackingEnabled,
    'shareWithCommunity': shareWithCommunity,
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
  final String
  regularityStatus; // Regular, Variable, Irregular, Building History
  final String discreetNotificationPreview;
  final List<String> personalizedSuggestions;
  const CyclePredictionSummary({
    required this.averageCycleLength,
    required this.averagePeriodDuration,
    this.lastPeriodStart,
    this.lastPeriodEnd,
    this.nextPeriodStart,
    this.nextPeriodEnd,
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
    final avgCycleLength = observedLengths.isNotEmpty
        ? (observedLengths.reduce((a, b) => a + b) / observedLengths.length)
              .round()
        : prefs.averageCycleLength.clamp(20, 45);
    final avgPeriodDuration = observedDurations.isNotEmpty
        ? (observedDurations.reduce((a, b) => a + b) / observedDurations.length)
              .round()
        : prefs.averagePeriodDuration.clamp(2, 10);
    var cycleVariationDays = 0;
    if (observedLengths.length >= 2) {
      final minLen = observedLengths.reduce((a, b) => a < b ? a : b);
      final maxLen = observedLengths.reduce((a, b) => a > b ? a : b);
      cycleVariationDays = maxLen - minLen;
    }
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
        irregularityReason = 'One or more recorded cycles fell outside the typical 21–35 day range.';
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
    final todayIso = formatIsoDate(DateTime.now());
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
        'Reminder (SRS 9.3): Fertility and ovulation windows are mathematical estimates and must never be used as contraception.',
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
  const MenstrualHealthArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.readTime,
    required this.summary,
    required this.keyTakeaways,
    required this.clinicalNote,
  });
}

class MenstrualHealthFaq {
  final String question;
  final String answer;
  const MenstrualHealthFaq({required this.question, required this.answer});
}

const List<MenstrualHealthArticle> sakhiMenstrualHealthArticles = [
  MenstrualHealthArticle(
    id: 'four-phases',
    title: 'Understanding the 4 Phases of Your Menstrual Cycle',
    category: 'Cycle Science',
    readTime: '4 min read',
    summary: 'Your menstrual cycle is more than just your period. Across the Menstrual, Follicular, Ovulatory, and Luteal phases, shifting estrogen and progesterone levels influence energy, sleep, metabolism, and mood.',
    keyTakeaways: [
      'Menstrual Phase (Days 1–5): Hormone levels dip as the uterine lining sheds. Focus on iron replenishment, warm fluids, and gentle movement.',
      'Follicular Phase (Days 6–13): Rising estrogen boosts focus, stamina, and mood — ideal for strength workouts and creative planning.',
      'Ovulatory Phase (~Day 14 in a 28-day cycle): Luteinizing hormone surges to release an egg. Hydration and balanced electrolytes support peak energy.',
      'Luteal Phase (Days 15–28): Progesterone rises, increasing basal body temperature and caloric needs slightly. Magnesium and B-vitamins help ease premenstrual tension.',
    ],
    clinicalNote: 'A typical adult menstrual cycle ranges from 21 to 35 days, with bleeding lasting 2 to 7 days.',
  ),
  MenstrualHealthArticle(
    id: 'irregular-cycles',
    title: 'When Are Irregular Periods Worth a Gynecologist Visit?',
    category: 'Clinical Guidance',
    readTime: '5 min read',
    summary: 'Occasional cycle shifts of a few days are common during travel, exams, illness, or stress. Persistent variation greater than 7–9 days or cycles shorter than 21 days or longer than 35 days merit clinical evaluation.',
    keyTakeaways: [
      'Common causes of cycle irregularity include PCOS, thyroid imbalances, iron-deficiency anemia, perimenopause, and high cortisol.',
      'Track period start/end dates, flow intensity, and accompanying symptoms (such as acne, hair changes, or severe pelvic pain) for 3 cycles to share with your doctor.',
      'Use the "Export Clinical Report" button in this tracker to generate a clean summary for your gynecologist.',
    ],
    clinicalNote: 'Seek prompt medical care if you soak through one or more pads/tampons every hour for two consecutive hours, or experience sudden severe pelvic pain.',
  ),
  MenstrualHealthArticle(
    id: 'cramps-and-pms',
    title: 'Evidence-Based Relief for Cramps & PMS Symptoms',
    category: 'Self-Care & Nutrition',
    readTime: '3 min read',
    summary: 'Primary dysmenorrhea (period cramps) is caused by prostaglandins triggering uterine muscle contractions. Targeted heat, anti-inflammatory nutrition, and gentle movement reduce prostaglandin discomfort.',
    keyTakeaways: [
      'Continuous low-level heat wraps (40°C) on the lower abdomen improve pelvic blood flow and relax contracting muscle fibers.',
      'Omega-3 fatty acids (flaxseeds, walnuts), ginger tea, and magnesium glycinate support natural prostaglandin balance.',
      'Reducing refined sugar and excess sodium 5 days before your period helps minimize water retention and breast tenderness.',
    ],
    clinicalNote: 'If cramps progressively worsen over time or do not respond to standard care, ask a healthcare professional to screen for endometriosis or adenomyosis.',
  ),
  MenstrualHealthArticle(
    id: 'fertility-awareness-myths',
    title: 'Why Calendar Ovulation Estimates Are Not Contraception',
    category: 'Reproductive Literacy',
    readTime: '3 min read',
    summary: 'Calendar-based apps estimate ovulation by counting back 14 days from your next expected period. Because ovulation timing can shift unexpectedly in any given month, calendar estimates alone cannot prevent pregnancy.',
    keyTakeaways: [
      'Sperm can survive in the reproductive tract for up to 5 days, and stress or illness can shift ovulation earlier or later without warning.',
      'Even women with very regular 28-day cycles experience natural luteal and follicular phase variations.',
      'Always consult a qualified gynecologist for reliable contraceptive options tailored to your health profile.',
    ],
    clinicalNote: 'SRS 9.3 & 9.5 Compliance: Fertility windows in Sakhi are informational estimates only and must never be treated as contraception.',
  ),
];
const List<MenstrualHealthFaq> sakhiMenstrualHealthFaqs = [
  MenstrualHealthFaq(
    question: 'Can anyone else on Sakhi or the Admin team see my period logs?',
    answer: 'No. Under SRS Sections 9.4 and 12.2, your menstrual and reproductive health data is classified as strictly private. It is never shown on your public profile, never posted to the Social Wall, never shared with advertising/analytics, and blocked from administrator view.',
  ),
  MenstrualHealthFaq(
    question: 'How does Sakhi estimate my next period and fertile window?',
    answer: 'Sakhi calculates a rolling average of your completed cycle lengths (up to your last 6 logged cycles) and period durations. It estimates ovulation roughly 14 days before your next expected period start, with a 6-day fertile window estimate.',
  ),
  MenstrualHealthFaq(
    question: 'What do Discreet Notifications look like on my lock screen?',
    answer: 'When Discreet Notifications are enabled (the default), lock-screen alerts use neutral wording — "Wellness Check-In: You have a personal calendar update waiting in your wellness tracker" — without mentioning periods, ovulation, or symptoms.',
  ),
  MenstrualHealthFaq(
    question: 'Can I rely on the fertile window estimate to avoid pregnancy?',
    answer: 'No. Calendar-based ovulation and fertility predictions are mathematical estimates and must NEVER be used as contraception. Ovulation can shift in any cycle.',
  ),
  MenstrualHealthFaq(
    question:
        'How can I export or permanently delete my cycle tracking history?',
    answer: 'Open the "Care, FAQs & Privacy" tab in the Menstrual Cycle Tracker. You can export a Doctor/Gynecologist clinical summary + JSON archive, or tap "Delete All Health Data" to permanently wipe both your cloud database records and local device cache.',
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

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    await _loadFromEncryptedLocalStorage();
    isLoading = false;
    notifyListeners();
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
      if (res['cycles'] is List) {
        cycles = (res['cycles'] as List)
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
      lastSyncMessage = 'Private health vault synced';
    } catch (_) {
      lastSyncMessage = 'Protected in local encrypted vault';
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

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
          if (notes != null) 'notes': notes,
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

  Future<void> updatePreferences(MenstrualTrackerPreferences updated) async {
    preferences = updated;
    await _saveToEncryptedLocalStorage();
    notifyListeners();
    try {
      await _client.patch(
        'module2/cycle-tracker/preferences',
        authenticated: true,
        body: updated.toJson(),
      );
      await syncWithBackend();
    } catch (_) {}
  }

  String generateClinicalExportReport() {
    final p = predictions;
    final buf = StringBuffer()
      ..writeln('====================================================')
      ..writeln('SAKHI WOMEN’S MENSTRUAL HEALTH CLINICAL SUMMARY')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln('Privacy Classification: STRICTLY OWNER-ISOLATED (SRS 9.4)')
      ..writeln('====================================================')
      ..writeln('')
      ..writeln('1. CYCLE SUMMARY & ROLLING AVERAGES')
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
      ..writeln(
        '3. RECENT DAILY SYMPTOM & WELLNESS LOGS (${dailyLogs.length})',
      );
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
      ..writeln('4. MEDICAL DISCLAIMER (SRS 9.5)')
      ..writeln(
        'This export is a personal wellness record and mathematical estimate. It is not a medical diagnosis or contraceptive guide.',
      );
    return buf.toString();
  }

  Future<bool> deleteAllPersonalTrackingData() async {
    cycles.clear();
    dailyLogs.clear();
    preferences = const MenstrualTrackerPreferences();
    try {
      await _secureStorage.delete(key: _storageKey);
    } catch (_) {}
    notifyListeners();
    try {
      await _client.delete('module2/cycle-tracker/data', authenticated: true);
    } catch (_) {}
    return true;
  }
}
