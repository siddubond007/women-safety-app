import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../models/menstrual_cycle_models.dart';
import '../widgets/guided_meditation_card.dart';
import '../widgets/wellness_category_tile.dart';
import 'menstrual_cycle_tracker_screen.dart';

class WellnessScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBackTap;

  const WellnessScreen({
    super.key,
    this.showBackButton = false,
    this.onBackTap,
  });

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  final MenstrualCycleController _cycleController =
      MenstrualCycleController.instance;

  @override
  void initState() {
    super.initState();
    _cycleController.initialize();
  }

  void _openCycleTracker({int initialTab = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MenstrualCycleTrackerScreen(initialTabIndex: initialTab),
      ),
    );
  }

  void _openDedicatedCycleCalendarScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CycleInteractiveCalendarScreen(),
      ),
    );
  }

  void _openAiMentalWellnessStudio() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SakhiAiMentalWellnessStudioScreen(),
      ),
    );
  }

  void _openCycleFitnessNutritionScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CycleSyncedFitnessNutritionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _cycleController,
      builder: (context, _) {
        final p = _cycleController.predictions;
        final categories = [
          (
            Icons.water_drop_rounded,
            'Period Tracker',
            AppColors.pastelPink,
            const Color(0xFFD63E85),
            SakhiFlowerType.cherryBlossom,
            () => _openCycleTracker(initialTab: 0),
          ),
          (
            Icons.self_improvement_rounded,
            'Mental Wellness',
            AppColors.pastelLavender,
            AppColors.primaryPurple,
            SakhiFlowerType.lavenderSprig,
            _openAiMentalWellnessStudio,
          ),
          (
            Icons.fitness_center_rounded,
            'Fitness & Nutrition',
            AppColors.pastelMint,
            AppColors.wellnessGreen,
            SakhiFlowerType.eucalyptusSage,
            _openCycleFitnessNutritionScreen,
          ),
          (
            Icons.menu_book_rounded,
            'Expert Articles & FAQs',
            AppColors.pastelPeach,
            const Color(0xFFB45309),
            SakhiFlowerType.roseClassic,
            () => _openCycleTracker(initialTab: 3),
          ),
        ];

        final content = SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 8, bottom: 124),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      if (widget.showBackButton) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.primaryPurple,
                            size: 20,
                          ),
                          onPressed:
                              widget.onBackTap ??
                              () => Navigator.maybePop(context),
                        ),
                        const SizedBox(width: 4),
                      ],
                      const Expanded(
                        child: Text(
                          'Your Wellbeing & Cycle Hub',
                          style: AppTypography.appBarTitle,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _openCycleTracker(initialTab: 2),
                        icon: const Icon(
                          Icons.insights_rounded,
                          size: 16,
                        ),
                        label: const Text('Cycle Insights'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: SakhiCard(
                    onTap: () => _openCycleTracker(initialTab: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD63E85),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'PRIVATE HEALTH VAULT \u2022 CYCLE TRACKER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Private Vault',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          p.currentCycleDay != null && p.currentCycleDay! > 0
                              ? 'Cycle Day ${p.currentCycleDay} \u2022 ${p.currentPhase}'
                              : 'Women\u2019s Menstrual Cycle & Symptom Tracker',
                          style: AppTypography.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.nextPeriodStart != null
                              ? 'Estimated next period: ${p.nextPeriodStart} (avg ${p.averageCycleLength}-day cycle, ${p.averagePeriodDuration}-day period). Tap to view phase insights, calendar, or log symptoms.'
                              : 'Record period start/end dates, view your monthly cycle calendar, track cramps/mood/energy/hydration, and receive discreet reminders.',
                          style: AppTypography.subtitle.copyWith(height: 1.38),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFD63E85),
                              ),
                              onPressed: _openDedicatedCycleCalendarScreen,
                              icon: const Icon(
                                Icons.calendar_month_rounded,
                                size: 17,
                              ),
                              label: const Text('Cycle Calendar'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _openCycleTracker(initialTab: 1),
                              icon: const Icon(
                                Icons.edit_calendar_rounded,
                                size: 17,
                              ),
                              label: const Text('Log Symptoms & Flow'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.15,
                        ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final (icon, title, bgColor, iconColor, flower, onTap) =
                          categories[index];
                      return WellnessCategoryTile(
                        icon: icon,
                        title: title,
                        iconBgColor: bgColor,
                        iconColor: iconColor,
                        flowerType: flower,
                        onTap: onTap,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SakhiSectionHeader(
                        title: "Today's Wellness & Meditation",
                        actionLabel: 'All Articles >',
                        onActionTap: () => _openCycleTracker(initialTab: 3),
                      ),
                      const SizedBox(height: 10),
                      const GuidedMeditationCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        if (widget.showBackButton) {
          return Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            body: content,
          );
        }
        return Material(
          color: AppColors.scaffoldBackground,
          child: content,
        );
      },
    );
  }
}

/// Dedicated Interactive Monthly Cycle Calendar & Date Logger Screen
/// Opened when the user taps the "Cycle Calendar" button on the Wellness Hub.
class CycleInteractiveCalendarScreen extends StatefulWidget {
  const CycleInteractiveCalendarScreen({super.key});

  @override
  State<CycleInteractiveCalendarScreen> createState() =>
      _CycleInteractiveCalendarScreenState();
}

class _CycleInteractiveCalendarScreenState
    extends State<CycleInteractiveCalendarScreen> {
  final MenstrualCycleController _controller =
      MenstrualCycleController.instance;
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _selectedDateIso = CyclePredictionEngine.formatIsoDate(DateTime.now());

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  Future<void> _openPeriodDateLoggerDialog() async {
    DateTime start = CyclePredictionEngine.parseIsoDate(_selectedDateIso);
    DateTime end = start.add(
      Duration(days: (_controller.preferences.averagePeriodDuration - 1).clamp(1, 9)),
    );
    String flowIntensity = 'Medium';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.water_drop_rounded,
                        color: Color(0xFFD63E85),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Log Period Start & End Dates',
                          style: AppTypography.sectionTitle,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primaryPurple,
                    ),
                    title: const Text('Period Start Date'),
                    subtitle: Text(CyclePredictionEngine.formatIsoDate(start)),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: sheetCtx,
                          initialDate: start,
                          firstDate: DateTime(2024),
                          lastDate: DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            start = picked;
                            if (end.isBefore(start)) {
                              end = start.add(const Duration(days: 4));
                            }
                          });
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_available_rounded,
                      color: AppColors.primaryPurple,
                    ),
                    title: const Text('Period End Date'),
                    subtitle: Text(CyclePredictionEngine.formatIsoDate(end)),
                    trailing: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: sheetCtx,
                          initialDate: end,
                          firstDate: start,
                          lastDate: start.add(const Duration(days: 14)),
                        );
                        if (picked != null) {
                          setSheetState(() => end = picked);
                        }
                      },
                      child: const Text('Change'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Typical Flow Intensity',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['Light', 'Medium', 'Heavy', 'Spotting'].map((f) {
                      final selected = flowIntensity == f;
                      return ChoiceChip(
                        label: Text(f),
                        selected: selected,
                        selectedColor: const Color(0xFFFFD6E7),
                        onSelected: (_) =>
                            setSheetState(() => flowIntensity = f),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD63E85),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      await _controller.upsertCycle(
                        startDate: CyclePredictionEngine.formatIsoDate(start),
                        endDate: CyclePredictionEngine.formatIsoDate(end),
                        flowIntensity: flowIntensity,
                      );
                      if (!mounted) return;
                      SakhiDialogs.showPrototypeSnackbar(
                        context,
                        'Period dates saved and cycle predictions updated!',
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Save Period Dates'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final p = _controller.predictions;
        final firstDayOfMonth = DateTime(
          _focusedMonth.year,
          _focusedMonth.month,
          1,
        );
        final daysInMonth = DateTime(
          _focusedMonth.year,
          _focusedMonth.month + 1,
          0,
        ).day;
        final leadingEmpty = (firstDayOfMonth.weekday - 1) % 7;
        final selectedLog = _controller.dailyLogForDate(_selectedDateIso);

        return Scaffold(
          backgroundColor: AppColors.scaffoldBackground,
          appBar: AppBar(
            title: const Text('Interactive Cycle Calendar'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.tonalIcon(
                  onPressed: _openPeriodDateLoggerDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Log Period'),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              12,
              AppSpacing.screenPaddingH,
              36,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SakhiCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() {
                              _focusedMonth = DateTime(
                                _focusedMonth.year,
                                _focusedMonth.month - 1,
                              );
                            }),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                              textAlign: TextAlign.center,
                              style: AppTypography.sectionTitle,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              final now = DateTime.now();
                              _focusedMonth = DateTime(now.year, now.month);
                              _selectedDateIso =
                                  CyclePredictionEngine.formatIsoDate(now);
                            }),
                            child: const Text('Today'),
                          ),
                          IconButton(
                            onPressed: () => setState(() {
                              _focusedMonth = DateTime(
                                _focusedMonth.year,
                                _focusedMonth.month + 1,
                              );
                            }),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          Text('Mon', style: AppTypography.caption),
                          Text('Tue', style: AppTypography.caption),
                          Text('Wed', style: AppTypography.caption),
                          Text('Thu', style: AppTypography.caption),
                          Text('Fri', style: AppTypography.caption),
                          Text('Sat', style: AppTypography.caption),
                          Text('Sun', style: AppTypography.caption),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: leadingEmpty + daysInMonth,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                            ),
                        itemBuilder: (context, idx) {
                          if (idx < leadingEmpty) {
                            return const SizedBox.shrink();
                          }
                          final dayNum = idx - leadingEmpty + 1;
                          final dt = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month,
                            dayNum,
                          );
                          final iso = CyclePredictionEngine.formatIsoDate(dt);
                          final isSelected = iso == _selectedDateIso;
                          final isLoggedPeriod = _controller.isLoggedPeriodDay(
                            iso,
                          );
                          final isPredictedPeriod = _controller
                              .isPredictedPeriodDay(iso);
                          final isFertile = _controller.isFertileWindowDay(
                            iso,
                          );
                          final isOvulation = p.estimatedOvulationDate == iso;
                          final hasDailyLog =
                              _controller.dailyLogForDate(iso) != null;

                          Color bg = Colors.white;
                          Color fg = AppColors.textPrimary;
                          if (isLoggedPeriod) {
                            bg = const Color(0xFFD63E85);
                            fg = Colors.white;
                          } else if (isPredictedPeriod) {
                            bg = const Color(0xFFFFD6E7);
                            fg = const Color(0xFF9D174D);
                          } else if (isOvulation) {
                            bg = const Color(0xFFFEF3C7);
                            fg = const Color(0xFFB45309);
                          } else if (isFertile) {
                            bg = const Color(0xFFF3E8FF);
                            fg = AppColors.primaryPurple;
                          }

                          return GestureDetector(
                            onTap: () => setState(() => _selectedDateIso = iso),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryPurple
                                      : AppColors.borderSubtle,
                                  width: isSelected ? 2.2 : 1.0,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    '$dayNum',
                                    style: TextStyle(
                                      color: fg,
                                      fontWeight: isSelected || isLoggedPeriod
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  if (hasDailyLog)
                                    Positioned(
                                      bottom: 4,
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: isLoggedPeriod
                                              ? Colors.white
                                              : const Color(0xFF0D9488),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: const [
                          _CalendarLegendDot(
                            color: Color(0xFFD63E85),
                            label: 'Logged Period',
                          ),
                          _CalendarLegendDot(
                            color: Color(0xFFFFB3D1),
                            label: 'Estimated Period',
                          ),
                          _CalendarLegendDot(
                            color: Color(0xFFC084FC),
                            label: 'Fertile Window (Est.)',
                          ),
                          _CalendarLegendDot(
                            color: Color(0xFFF59E0B),
                            label: 'Ovulation (Est.)',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SakhiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.event_note_rounded,
                            color: AppColors.primaryPurple,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Selected Date: $_selectedDateIso',
                              style: AppTypography.cardTitle,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const MenstrualCycleTrackerScreen(
                                        initialTabIndex: 1,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.edit_rounded, size: 16),
                            label: const Text('Log Day Symptoms'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        selectedLog != null
                            ? 'Mood: ${selectedLog.mood ?? "Calm"} \u2022 Flow: ${selectedLog.flowIntensity ?? "None"} \u2022 Cramps: ${selectedLog.crampsSeverity ?? "None"} \u2022 Hydration: ${selectedLog.hydrationGlasses} glasses'
                            : 'No daily symptom log recorded for $_selectedDateIso yet. Tap "Log Day Symptoms" or "Log Period" above.',
                        style: AppTypography.subtitle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalendarLegendDot extends StatelessWidget {
  const _CalendarLegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.caption),
      ],
    );
  }
}

/// Dedicated Interactive Sakhi AI Voice/Text-Guided Breathing & Grounding Studio
/// Features:
/// - Selectable session duration (1 Min, 3 Min, 5 Min, 10 Min)
/// - Automatic Timer.periodic countdown that transitions smoothly through
///   Inhale (4s) -> Hold (7s) -> Exhale (8s) without manual button clicks
/// - Smoothly expanding & contracting radial gradient circle synchronized to
///   each breath phase
/// - Optional 432Hz + 528Hz harmonic singing bowl audio via native channel
class SakhiAiMentalWellnessStudioScreen extends StatefulWidget {
  const SakhiAiMentalWellnessStudioScreen({super.key});

  @override
  State<SakhiAiMentalWellnessStudioScreen> createState() =>
      _SakhiAiMentalWellnessStudioScreenState();
}

class _SakhiAiMentalWellnessStudioScreenState
    extends State<SakhiAiMentalWellnessStudioScreen> {
  static const MethodChannel _nativeChannel = MethodChannel(
    'sakhi/native_actions',
  );

  int _selectedDurationMinutes = 3;
  int _remainingSessionSeconds = 180;
  bool _isRunning = false;
  bool _ambientSoundEnabled = true;
  bool _voiceGuidanceEnabled = true;

  final FlutterTts _voiceEngine = FlutterTts();
  late final Future<void> _voiceInitialization;
  int _voiceRequestId = 0;

  // 0 = Inhale (4s), 1 = Hold (7s), 2 = Exhale (8s)
  int _phaseIndex = 0;
  int _phaseSecondsLeft = 4;
  int _completedCycles = 0;
  Timer? _timer;

  static const List<int> _phaseDurations = [4, 7, 8];
  static const List<String> _phaseTitles = [
    'Inhale Gently',
    'Hold Softly',
    'Exhale Slowly',
  ];
  static const List<String> _aiVoicePrompts = [
    'Sakhi AI: Breathe in softly through your nose\u2026 feel your chest and ribs expand with calm energy.',
    'Sakhi AI: Hold your breath gently\u2026 relax your jaw, drop your shoulders, and let your heart rate settle.',
    'Sakhi AI: Exhale slowly through your mouth\u2026 release every bit of stress and tension as the circle contracts.',
  ];
  static const List<String> _spokenPhaseGuidance = [
    'Breathe in gently through your nose.',
    'Hold softly. Relax your jaw and shoulders.',
    'Breathe out slowly through your mouth.',
  ];
  static const String _spokenCompletionGuidance =
      'Your breathing session is complete. Take a comfortable, natural breath.';

  @override
  void initState() {
    super.initState();
    _voiceInitialization = _configureVoiceGuidance();
  }

  Future<void> _configureVoiceGuidance() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _voiceEngine.setSharedInstance(true);
        await _voiceEngine.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          const [],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      } catch (_) {
        // Native speech setup must not prevent the breathing screen from opening.
      }
    }

    try {
      final dynamic languages = await _voiceEngine.getLanguages;
      final installedLanguages = languages is List
          ? languages
                .map(
                  (language) => language
                      .toString()
                      .replaceAll('_', '-')
                      .toLowerCase(),
                )
                .toSet()
          : <String>{};
      final preferredLanguage = installedLanguages.contains('en-in')
          ? 'en-IN'
          : installedLanguages.contains('en-us')
          ? 'en-US'
          : null;
      if (preferredLanguage != null) {
        await _voiceEngine.setLanguage(preferredLanguage);
      }
    } catch (_) {
      // Use the device's default language if language discovery is unavailable.
    }

    try {
      await _voiceEngine.setSpeechRate(0.43);
      await _voiceEngine.setPitch(1.0);
      await _voiceEngine.setVolume(1.0);
    } catch (_) {
      // Retain device defaults if a platform rejects an optional voice setting.
    }
  }

  bool get _canSpeakGuidance =>
      mounted && _isRunning && _voiceGuidanceEnabled;

  Future<void> _speakCurrentPhase() async {
    if (!_canSpeakGuidance) return;
    final requestId = ++_voiceRequestId;
    final phaseIndex = _phaseIndex;

    try {
      await _voiceInitialization;
      if (!_canSpeakGuidance ||
          requestId != _voiceRequestId ||
          phaseIndex != _phaseIndex) {
        return;
      }
      await _voiceEngine.stop();
      if (!_canSpeakGuidance ||
          requestId != _voiceRequestId ||
          phaseIndex != _phaseIndex) {
        return;
      }
      await _voiceEngine.speak(_spokenPhaseGuidance[phaseIndex]);
    } catch (_) {
      // Visual countdown and prompts continue when system TTS is unavailable.
    }
  }

  Future<void> _speakCompletionGuidance() async {
    if (!mounted || !_voiceGuidanceEnabled) return;
    final requestId = ++_voiceRequestId;
    try {
      await _voiceInitialization;
      if (!mounted ||
          !_voiceGuidanceEnabled ||
          requestId != _voiceRequestId) {
        return;
      }
      await _voiceEngine.stop();
      if (!mounted ||
          !_voiceGuidanceEnabled ||
          requestId != _voiceRequestId) {
        return;
      }
      await _voiceEngine.speak(_spokenCompletionGuidance);
    } catch (_) {
      // Completion is still shown visually when device TTS is unavailable.
    }
  }

  Future<void> _stopVoiceGuidance() async {
    _voiceRequestId++;
    try {
      await _voiceEngine.stop();
    } catch (_) {}
  }

  void _toggleVoiceGuidance() {
    final enable = !_voiceGuidanceEnabled;
    setState(() => _voiceGuidanceEnabled = enable);
    if (enable && _isRunning) {
      unawaited(_speakCurrentPhase());
    } else if (!enable) {
      unawaited(_stopVoiceGuidance());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopAmbientAudio();
    unawaited(_stopVoiceGuidance());
    super.dispose();
  }

  Future<void> _startAmbientAudio() async {
    if (!_ambientSoundEnabled) return;
    try {
      await _nativeChannel.invokeMethod('startMeditationAudio', {
        'volume': 0.65,
      });
    } catch (_) {}
  }

  Future<void> _stopAmbientAudio() async {
    try {
      await _nativeChannel.invokeMethod('stopMeditationAudio');
    } catch (_) {}
  }

  void _selectDuration(int minutes) {
    _timer?.cancel();
    _stopAmbientAudio();
    unawaited(_stopVoiceGuidance());
    setState(() {
      _selectedDurationMinutes = minutes;
      _remainingSessionSeconds = minutes * 60;
      _isRunning = false;
      _phaseIndex = 0;
      _phaseSecondsLeft = _phaseDurations[0];
      _completedCycles = 0;
    });
  }

  void _toggleSession() {
    if (_isRunning) {
      _timer?.cancel();
      _stopAmbientAudio();
      setState(() => _isRunning = false);
      unawaited(_stopVoiceGuidance());
      return;
    }

    if (_remainingSessionSeconds <= 0) {
      _remainingSessionSeconds = _selectedDurationMinutes * 60;
    }
    setState(() => _isRunning = true);
    _startAmbientAudio();
    unawaited(_speakCurrentPhase());
    HapticFeedback.lightImpact();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      var phaseChanged = false;
      var sessionCompleted = false;
      setState(() {
        if (_remainingSessionSeconds > 1) {
          _remainingSessionSeconds--;
        } else {
          _remainingSessionSeconds = 0;
          _isRunning = false;
          timer.cancel();
          sessionCompleted = true;
          return;
        }

        if (_phaseSecondsLeft > 1) {
          _phaseSecondsLeft--;
        } else {
          _phaseIndex = (_phaseIndex + 1) % 3;
          _phaseSecondsLeft = _phaseDurations[_phaseIndex];
          phaseChanged = true;
          if (_phaseIndex == 0) {
            _completedCycles++;
          }
          HapticFeedback.selectionClick();
        }
      });

      if (sessionCompleted) {
        _stopAmbientAudio();
        HapticFeedback.mediumImpact();
        unawaited(_speakCompletionGuidance());
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Sakhi AI Guided Breathing session complete! Well done.',
        );
      } else if (phaseChanged) {
        unawaited(_speakCurrentPhase());
      }
    });
  }

  void _skipToNextPhase() {
    setState(() {
      _phaseIndex = (_phaseIndex + 1) % 3;
      _phaseSecondsLeft = _phaseDurations[_phaseIndex];
    });
    if (_isRunning) {
      unawaited(_speakCurrentPhase());
    }
    HapticFeedback.selectionClick();
  }

  String _formatClock(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Circle expands on Inhale (0), stays expanded on Hold (1), contracts on Exhale (2)
    final double targetDiameter = !_isRunning
        ? 150.0
        : _phaseIndex == 0
        ? 216.0
        : _phaseIndex == 1
        ? 222.0
        : 122.0;

    final List<Color> phaseGradient = switch (_phaseIndex) {
      0 => const [Color(0xFFD63E85), Color(0xFF9333EA), Color(0xFFFF8DA1)],
      1 => const [Color(0xFF7B228E), Color(0xFF6D28D9), Color(0xFFC084FC)],
      _ => const [Color(0xFF0D9488), Color(0xFF4F46E5), Color(0xFF818CF8)],
    };

    final animDuration = Duration(
      milliseconds: !_isRunning
          ? 500
          : _phaseIndex == 0
          ? 3800
          : _phaseIndex == 1
          ? 900
          : 7600,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFDF7FA),
      appBar: AppBar(
        title: const Text('Sakhi AI Mental Wellness Studio'),
        actions: [
          IconButton(
            tooltip: _voiceGuidanceEnabled
                ? 'Turn voice guidance off'
                : 'Turn voice guidance on',
            onPressed: _toggleVoiceGuidance,
            icon: Icon(
              _voiceGuidanceEnabled
                  ? Icons.record_voice_over_rounded
                  : Icons.voice_over_off_rounded,
              color: AppColors.primaryPurple,
            ),
          ),
          IconButton(
            tooltip: _ambientSoundEnabled
                ? 'Mute singing bowl audio'
                : 'Enable singing bowl audio',
            onPressed: () {
              setState(() => _ambientSoundEnabled = !_ambientSoundEnabled);
              if (_ambientSoundEnabled && _isRunning) {
                _startAmbientAudio();
              } else {
                _stopAmbientAudio();
              }
            },
            icon: Icon(
              _ambientSoundEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: AppColors.primaryPurple,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          12,
          AppSpacing.screenPaddingH,
          36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sakhi AI Companion Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A1259), Color(0xFF832B96)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sakhi AI Calm Companion \u2022 4-7-8 Rhythm',
                          style: TextStyle(
                            color: Color(0xFFFFB3D1),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRunning
                              ? _aiVoicePrompts[_phaseIndex]
                              : 'Choose your session duration below and tap "Start AI Guided Session" for automatic breathing transitions.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Duration Picker Chips
            Text(
              'Select Guided Session Duration',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                (1, '1 Min Quick Reset'),
                (3, '3 Min Calm Breath'),
                (5, '5 Min Deep Grounding'),
                (10, '10 Min Sleep Wind-Down'),
              ].map((item) {
                final (mins, label) = item;
                final selected = _selectedDurationMinutes == mins;
                return ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: selected ? Colors.white : AppColors.primaryPurple,
                    ),
                  ),
                  selected: selected,
                  selectedColor: AppColors.primaryPurple,
                  backgroundColor: Colors.white,
                  onSelected: (_) => _selectDuration(mins),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Animated Expanding & Contracting Radial Gradient Breathing Stage
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF6EAFC), Color(0xFFFFECF4)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: AppColors.primaryPurple.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Remaining: ${_formatClock(_remainingSessionSeconds)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Cycles Completed: $_completedCycles',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFFD63E85),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 248,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer soft ripple aura
                          AnimatedContainer(
                            duration: animDuration,
                            curve: Curves.easeInOut,
                            width: targetDiameter + 34,
                            height: targetDiameter + 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  phaseGradient.first.withValues(alpha: 0.24),
                                  phaseGradient.last.withValues(alpha: 0.02),
                                ],
                              ),
                            ),
                          ),
                          // Inner expanding / contracting gradient circle
                          AnimatedContainer(
                            duration: animDuration,
                            curve: Curves.easeInOut,
                            width: targetDiameter,
                            height: targetDiameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: phaseGradient,
                                radius: 0.85,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: phaseGradient.first.withValues(
                                    alpha: 0.36,
                                  ),
                                  blurRadius: 28,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${_phaseSecondsLeft}s',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _phaseTitles[_phaseIndex],
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _phaseIndex == 0
                                      ? 'Expanding\u2026'
                                      : _phaseIndex == 1
                                      ? 'Steady Glow\u2026'
                                      : 'Contracting\u2026',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _aiVoicePrompts[_phaseIndex],
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _isRunning
                                ? const Color(0xFFD63E85)
                                : AppColors.primaryPurple,
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: _toggleSession,
                          icon: Icon(
                            _isRunning
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                          ),
                          label: Text(
                            _isRunning
                                ? 'Pause AI Guidance'
                                : 'Start AI Guided Session',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                          onPressed: _skipToNextPhase,
                          icon: const Icon(Icons.skip_next_rounded, size: 18),
                          label: const Text('Skip Phase'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SakhiCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.sentiment_satisfied_alt_rounded,
                    color: AppColors.primaryPurple,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Record Post-Session Mood & Rest',
                          style: AppTypography.cardTitle,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Log how you feel after your grounding session in your private wellness log.',
                          style: AppTypography.subtitle,
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const MenstrualCycleTrackerScreen(
                            initialTabIndex: 1,
                          ),
                        ),
                      );
                    },
                    child: const Text('Log Mood'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated Cycle-Synced Fitness & Nutrition Planner Screen
/// Opened when the user taps the "Fitness & Nutrition" card on the Wellness Hub.
class CycleSyncedFitnessNutritionScreen extends StatefulWidget {
  const CycleSyncedFitnessNutritionScreen({super.key});

  @override
  State<CycleSyncedFitnessNutritionScreen> createState() =>
      _CycleSyncedFitnessNutritionScreenState();
}

class _CycleSyncedFitnessNutritionScreenState
    extends State<CycleSyncedFitnessNutritionScreen> {
  final MenstrualCycleController _controller =
      MenstrualCycleController.instance;
  int _selectedPhaseTab = 0;

  static const List<Map<String, dynamic>> _phaseGuides = [
    {
      'phase': 'Menstrual Phase (Days 1\u20135)',
      'tagline': 'Restorative Movement & Iron Replenishment',
      'color': Color(0xFFD63E85),
      'workouts': [
        '20-Min Restorative Yin Yoga & Pelvic Floor Relaxation',
        'Gentle Evening Walk & Diaphragmatic Stretching (15\u201325 mins)',
        'Child\u2019s Pose, Cat-Cow & Supine Butterfly for Cramp Relief',
      ],
      'nutrition': [
        'Iron-Rich Foods: Spinach (Palak), lentils (Dal), ragi, dates, and pomegranate',
        'Vitamin C Pairing: Amla or lemon juice with meals to boost iron absorption',
        'Soothing Herbal Teas: Warm ginger, chamomile, or cinnamon infusion',
      ],
    },
    {
      'phase': 'Follicular Phase (Days 6\u201313)',
      'tagline': 'Rising Estrogen, Strength Building & Fresh Energy',
      'color': Color(0xFF7B228E),
      'workouts': [
        '35-Min Progressive Strength Training (Squats, Lunges & Core)',
        'Brisk Outdoor Jogging, Dance Cardio, or Cycling (30 mins)',
        'Dynamic Mobility & Sun Salutations (Surya Namaskar \u2014 12 rounds)',
      ],
      'nutrition': [
        'Lean Proteins & Sprouts: Moong sprouts, paneer, tofu, eggs, and chickpeas',
        'Probiotic & Fermented Foods: Homemade curd/yogurt and idli/dosa batters',
        'Fresh Seeds (Seed Cycling): 1 tbsp ground flaxseeds + pumpkin seeds daily',
      ],
    },
    {
      'phase': 'Ovulatory Phase (Days 14\u201316)',
      'tagline': 'Peak Stamina, High-Energy Flow & Antioxidant Support',
      'color': Color(0xFFD97706),
      'workouts': [
        '40-Min High-Energy Circuit, Zumba, or Power Vinyasa Flow',
        'Full-Body Resistance Training & Core Stability',
        'Active Group Walk or Badminton Session',
      ],
      'nutrition': [
        'Cruciferous Veggies & Fiber: Broccoli, cabbage, leafy greens, and berries',
        'Hydration Boost: Coconut water, cucumber-mint infused water (8\u201310 glasses)',
        'Healthy Omega-3 Fats: Walnuts, chia seeds, and sesame seeds',
      ],
    },
    {
      'phase': 'Luteal Phase (Days 17\u201328)',
      'tagline': 'Steady Pilates, Magnesium Support & PMS Care',
      'color': Color(0xFF0D9488),
      'workouts': [
        '30-Min Low-Impact Mat Pilates & Posture Strengthening',
        'Moderate Strength Training with Longer Rest Intervals',
        'Evening Legs-Up-The-Wall (Viparita Karani) for Bloating Relief',
      ],
      'nutrition': [
        'Magnesium-Rich Foods: Dark chocolate (70%+), bananas, almonds, and pumpkin seeds',
        'Complex Carbohydrates: Sweet potato, brown rice, oats, and millets (Jowar/Bajra)',
        'Reduce Excess Salt & Caffeine to minimize premenstrual water retention',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    final phase = _controller.predictions.currentPhase.toLowerCase();
    if (phase.contains('follicular')) {
      _selectedPhaseTab = 1;
    } else if (phase.contains('ovulat')) {
      _selectedPhaseTab = 2;
    } else if (phase.contains('luteal')) {
      _selectedPhaseTab = 3;
    } else {
      _selectedPhaseTab = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeGuide = _phaseGuides[_selectedPhaseTab];
    final Color accent = activeGuide['color'] as Color;
    final List<String> workouts = activeGuide['workouts'] as List<String>;
    final List<String> nutrition = activeGuide['nutrition'] as List<String>;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Cycle-Synced Fitness & Nutrition'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          12,
          AppSpacing.screenPaddingH,
          36,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_phaseGuides.length, (i) {
                  final selected = i == _selectedPhaseTab;
                  final label = (_phaseGuides[i]['phase'] as String)
                      .split(' (')
                      .first;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      selected: selected,
                      selectedColor: _phaseGuides[i]['color'] as Color,
                      backgroundColor: Colors.white,
                      onSelected: (_) => setState(() => _selectedPhaseTab = i),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeGuide['phase'] as String,
                    style: AppTypography.sectionTitle.copyWith(color: accent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activeGuide['tagline'] as String,
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SakhiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.fitness_center_rounded, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Recommended Movement & Workouts',
                        style: AppTypography.cardTitle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final w in workouts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(w, style: AppTypography.bodyRegular),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SakhiCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant_menu_rounded, color: accent),
                      const SizedBox(width: 8),
                      Text(
                        'Phase-Tailored Nutrition & Meals',
                        style: AppTypography.cardTitle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final n in nutrition)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.spa_rounded,
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(n, style: AppTypography.bodyRegular),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const MenstrualCycleTrackerScreen(
                      initialTabIndex: 1,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.local_drink_rounded),
              label: const Text('Log Today\u2019s Hydration & Energy Level'),
            ),
          ],
        ),
      ),
    );
  }
}
