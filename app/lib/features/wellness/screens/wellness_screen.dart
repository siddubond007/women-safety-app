import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_card.dart';
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

  void _openMentalWellnessBreathingSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var step = 0; // 0 = Inhale 4s, 1 = Hold 7s, 2 = Exhale 8s
        const labels = [
          'Inhale gently through your nose for 4 secondsâ€¦',
          'Hold your breath softly for 7 secondsâ€¦',
          'Exhale slowly through your mouth for 8 secondsâ€¦',
        ];
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
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
                        Icons.self_improvement_rounded,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '4-7-8 Calm Breathing & Grounding',
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
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF3E6FA), Color(0xFFFDECF3)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF7B228E), Color(0xFFD63E85)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33D63E85),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            step == 0
                                ? '4s\nInhale'
                                : step == 1
                                ? '7s\nHold'
                                : '8s\nExhale',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          labels[step],
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  setSheetState(() => step = (step + 1) % 3),
                              icon: const Icon(Icons.skip_next_rounded),
                              label: const Text('Next Breath Phase'),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                _openCycleTracker(initialTab: 1);
                              },
                              icon: const Icon(Icons.mood_rounded, size: 17),
                              label: const Text('Log Mood & Sleep'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openFitnessAndNutritionSheet() {
    final p = _cycleController.predictions;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fitness_center_rounded,
                    color: Color(0xFFD63E85),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cycle-Synced Nutrition & Movement',
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Current Phase Estimate: ${p.currentPhase}',
                style: AppTypography.bodyMedium.copyWith(
                  color: const Color(0xFFD63E85),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              ...p.personalizedSuggestions.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primaryPurple,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tip, style: AppTypography.bodyRegular),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openCycleTracker(initialTab: 1);
                  },
                  icon: const Icon(Icons.local_drink_rounded),
                  label: const Text('Log Todayâ€™s Hydration & Energy'),
                ),
              ),
            ],
          ),
        ),
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
            _openMentalWellnessBreathingSheet,
          ),
          (
            Icons.fitness_center_rounded,
            'Fitness & Nutrition',
            AppColors.pastelMint,
            AppColors.wellnessGreen,
            SakhiFlowerType.eucalyptusSage,
            _openFitnessAndNutritionSheet,
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
            padding: const EdgeInsets.only(top: 8, bottom: 132),
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
                        onPressed: () => _openCycleTracker(initialTab: 0),
                        icon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                        ),
                        label: const Text('Open Tracker'),
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
                                'MODULE 7 â€¢ MENSTRUAL CYCLE TRACKER',
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
                              ? 'Cycle Day ${p.currentCycleDay} â€¢ ${p.currentPhase}'
                              : 'Womenâ€™s Menstrual Cycle & Symptom Tracker',
                          style: AppTypography.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.nextPeriodStart != null
                              ? 'Estimated next period: ${p.nextPeriodStart} (avg ${p.averageCycleLength}-day cycle, ${p.averagePeriodDuration}-day period). Tap to view calendar, log symptoms, or export clinical summary.'
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
                              onPressed: () => _openCycleTracker(initialTab: 0),
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
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
                const SizedBox(height: 16),
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
        return Material(color: AppColors.scaffoldBackground, child: content);
      },
    );
  }
}

