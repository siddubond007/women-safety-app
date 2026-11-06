import 'dart:async';

import 'package:flutter/foundation.dart';
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
import '../../../core/widgets/sakhi_wellness_illustrations.dart';
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

  void _openMentalWellnessHub() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SakhiMentalWellnessHubScreen(),
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
            _openMentalWellnessHub,
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
            'Period Pain & Articles',
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
                        icon: const Icon(Icons.insights_rounded, size: 16),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.currentCycleDay != null &&
                                            p.currentCycleDay! > 0
                                        ? 'Cycle Day ${p.currentCycleDay} \u2022 ${p.currentPhase}'
                                        : 'Women\u2019s Menstrual Cycle & Symptom Tracker',
                                    style: AppTypography.sectionTitle,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p.nextPeriodStart != null
                                        ? 'Estimated next period: ${p.nextPeriodStart} (avg ${p.averageCycleLength}-day cycle, ${p.averagePeriodDuration}-day period). Personal cycle length (24, 26, 28+ days) & discreet reminders active.'
                                        : 'Record period start/end dates, configure your personal cycle length (24, 26, 28+ days), track symptoms, and receive discreet reminders.',
                                    style: AppTypography.subtitle.copyWith(
                                      height: 1.38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const SakhiGentleWomanIllustration(
                              pose: SakhiWomanPose.cycleCareWarmth,
                              size: 74,
                            ),
                          ],
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
                            OutlinedButton.icon(
                              onPressed: () => _openCycleTracker(initialTab: 3),
                              icon: const Icon(
                                Icons.healing_rounded,
                                size: 17,
                                color: Color(0xFFD63E85),
                              ),
                              label: const Text('Period Pain Help'),
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
                        actionLabel: 'Mental Wellness Hub >',
                        onActionTap: _openMentalWellnessHub,
                      ),
                      const SizedBox(height: 10),
                      GuidedMeditationCard(
                        onOpenFullStudio: _openMentalWellnessHub,
                      ),
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

/// Mental Wellness Hub Screen — Opened when the user taps "Mental Wellness".
/// Gives the user an explicit choice between:
/// 1. Guided Breathing Studio (4-7-8 Deep Calm, Box Breathing 4-4-4-4, Heart Coherence 5-5)
/// 2. Guided Meditation Studio (Miracle of Mind Inner Stillness, Body Scan, Period Comfort, Deep Sleep)
/// Never auto-starts audio without the user's explicit selection.
class SakhiMentalWellnessHubScreen extends StatelessWidget {
  const SakhiMentalWellnessHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Mental Wellness Sanctuary'),
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
            // Hero Header Card with Animated Meditating Woman Illustration
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A1259), Color(0xFF832B96)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppSpacing.cardShadow,
              ),
              child: Row(
                children: [
                  const SakhiGentleWomanIllustration(
                    pose: SakhiWomanPose.meditationLotus,
                    size: 94,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'CHOOSE YOUR PRACTICE',
                            style: TextStyle(
                              color: Color(0xFFFFD6E7),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pause, Breathe & Restore Inner Stillness',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose between rhythmic Breathing Exercises or spoken Guided Meditation with 5 peaceful soundscapes.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Choice Card 1: Guided Breathing Exercises
            SakhiCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SakhiAiMentalWellnessStudioScreen(),
                  ),
                );
              },
              child: Row(
                children: [
                  const SakhiGentleWomanIllustration(
                    pose: SakhiWomanPose.breathingCalm,
                    size: 78,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.pastelLavender,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'OPTION 1 • BREATHWORK',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Guided Breathing Exercises',
                          style: AppTypography.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '4-7-8 Deep Calm, Box Breathing (4-4-4-4), and Heart Coherence (5-5) with expanding visual aura & calm voice cues.',
                          style: AppTypography.subtitle,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const SakhiAiMentalWellnessStudioScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.air_rounded, size: 17),
                          label: const Text('Open Breathing Studio'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Choice Card 2: Guided Meditation Studio
            SakhiCard(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SakhiGuidedMeditationStudioScreen(),
                  ),
                );
              },
              child: Row(
                children: [
                  const SakhiGentleWomanIllustration(
                    pose: SakhiWomanPose.meditationLotus,
                    size: 78,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFD6E7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'OPTION 2 • SPOKEN MEDITATION',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF9D174D),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Guided Meditation Studio',
                          style: AppTypography.sectionTitle,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Miracle of Mind Inner Stillness, Full-Body Scan, Warm Period Cramp Comfort, and Deep Sleep with 5 peaceful soundscapes.',
                          style: AppTypography.subtitle,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD63E85),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const SakhiGuidedMeditationStudioScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.self_improvement_rounded,
                            size: 17,
                          ),
                          label: const Text('Open Meditation Studio'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Quick Player Card
            const Text(
              'Quick Session Player & Soundscape Mixer',
              style: AppTypography.sectionTitle,
            ),
            const SizedBox(height: 8),
            const GuidedMeditationCard(),
          ],
        ),
      ),
    );
  }
}

/// Full-Screen Spoken Guided Meditation Studio (Miracle of Mind inspired)
/// Features:
/// - 4 Guided Meditation Programs (Inner Stillness, Body Scan, Period Comfort, Deep Sleep)
/// - 5 Rotating Peaceful Polyphonic Soundscapes (no harsh continuous buzz)
/// - Separate Spoken Voice Volume & Ambient Soundscape Volume controls
/// - Animated Gentle Woman in Lotus Meditation Pose
class SakhiGuidedMeditationStudioScreen extends StatefulWidget {
  const SakhiGuidedMeditationStudioScreen({super.key});

  @override
  State<SakhiGuidedMeditationStudioScreen> createState() =>
      _SakhiGuidedMeditationStudioScreenState();
}

class _SakhiGuidedMeditationStudioScreenState
    extends State<SakhiGuidedMeditationStudioScreen> {
  final _session = GuidedMeditationSessionController.instance;

  String _formatMmSs(int seconds) {
    final clamped = seconds.clamp(0, 99999);
    final m = (clamped ~/ 60).toString().padLeft(2, '0');
    final s = (clamped % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _session,
      builder: (context, _) {
        final remaining = (_session.totalSeconds - _session.elapsedSeconds)
            .clamp(0, _session.totalSeconds);
        final progress = _session.totalSeconds > 0
            ? (_session.elapsedSeconds / _session.totalSeconds).clamp(0.0, 1.0)
            : 0.0;

        return Scaffold(
          backgroundColor: const Color(0xFFFDF7FA),
          appBar: AppBar(
            title: const Text('Guided Meditation Studio'),
            actions: [
              IconButton(
                tooltip: _session.voiceGuidanceEnabled
                    ? 'Mute spoken guide'
                    : 'Enable spoken guide',
                onPressed: _session.toggleVoiceGuidance,
                icon: Icon(
                  _session.voiceGuidanceEnabled
                      ? Icons.record_voice_over_rounded
                      : Icons.voice_over_off_rounded,
                  color: AppColors.primaryPurple,
                ),
              ),
              IconButton(
                tooltip: _session.ambientMusicEnabled
                    ? 'Mute ambient soundscape'
                    : 'Enable ambient soundscape',
                onPressed: _session.toggleAmbientMusic,
                icon: Icon(
                  _session.ambientMusicEnabled
                      ? Icons.music_note_rounded
                      : Icons.music_off_rounded,
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
                // 1. Program Selector
                const Text(
                  '1. Choose Guided Meditation Theme',
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: 8),
                for (
                  var i = 0;
                  i <
                      GuidedMeditationSessionController
                          .meditationPrograms
                          .length;
                  i++
                )
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _session.selectProgram(i),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _session.selectedProgramIndex == i
                              ? const Color(0xFFF3E8FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _session.selectedProgramIndex == i
                                ? AppColors.primaryPurple
                                : AppColors.borderSubtle,
                            width: _session.selectedProgramIndex == i ? 1.8 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _session.selectedProgramIndex == i
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: AppColors.primaryPurple,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    GuidedMeditationSessionController
                                        .meditationPrograms[i]['title']!,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    GuidedMeditationSessionController
                                        .meditationPrograms[i]['subtitle']!,
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // 2. Peaceful Soundscape Selector
                const Text(
                  '2. Select Peaceful Ambient Soundscape',
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(
                    GuidedMeditationSessionController.soundscapeTitles.length,
                    (i) {
                      final selected = _session.selectedTrackIndex == i;
                      return ChoiceChip(
                        label: Text(
                          GuidedMeditationSessionController.soundscapeTitles[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        selected: selected,
                        selectedColor: const Color(0xFFD63E85),
                        backgroundColor: Colors.white,
                        onSelected: (_) => _session.selectSoundscapeTrack(i),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),

                // 3. Duration Pills
                const Text(
                  '3. Session Duration',
                  style: AppTypography.cardTitle,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 7, 11, 15, 21].map((mins) {
                    final selected = _session.selectedMinutes == mins;
                    return ChoiceChip(
                      label: Text(
                        '$mins Minutes',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : AppColors.primaryPurple,
                        ),
                      ),
                      selected: selected,
                      selectedColor: AppColors.primaryPurple,
                      backgroundColor: Colors.white,
                      onSelected: (_) => _session.selectDuration(mins),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 4. Center Meditation Stage
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF6EAFC), Color(0xFFFFECF4)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppColors.primaryPurple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SakhiGentleWomanIllustration(
                        pose: SakhiWomanPose.meditationLotus,
                        size: 132,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatMmSs(remaining),
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _session.isPlaying
                            ? 'Spoken Guidance + ${GuidedMeditationSessionController.soundscapeTitles[_session.selectedTrackIndex]}'
                            : 'Ready when you are • Tap Start Guided Meditation',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFD63E85),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '“${_session.currentSpokenPrompt}”',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            height: 1.42,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Slider(
                        value: progress,
                        activeColor: AppColors.primaryPurple,
                        onChanged: (v) => _session.seek(v),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.record_voice_over_rounded,
                            size: 18,
                            color: AppColors.primaryPurple,
                          ),
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 90,
                            child: Text(
                              'Voice Guide',
                              style: AppTypography.caption,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _session.voiceVolume,
                              activeColor: AppColors.primaryPurple,
                              onChanged: _session.setVoiceVolume,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.music_note_rounded,
                            size: 18,
                            color: Color(0xFFD63E85),
                          ),
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 90,
                            child: Text(
                              'Soundscape',
                              style: AppTypography.caption,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _session.volume,
                              activeColor: const Color(0xFFD63E85),
                              onChanged: _session.setVolume,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _session.isPlaying
                                    ? const Color(0xFFD63E85)
                                    : AppColors.primaryPurple,
                                minimumSize: const Size.fromHeight(50),
                              ),
                              onPressed: _session.togglePlayPause,
                              icon: Icon(
                                _session.isPlaying
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                              ),
                              label: Text(
                                _session.isPlaying
                                    ? 'Pause Meditation'
                                    : 'Start Guided Meditation',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                              ),
                              onPressed: _session.resetSession,
                              icon: const Icon(Icons.replay_rounded, size: 18),
                              label: const Text('Reset'),
                            ),
                          ),
                        ],
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
      Duration(
        days: (_controller.preferences.averagePeriodDuration - 1).clamp(1, 9),
      ),
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
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
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
                          final isFertile = _controller.isFertileWindowDay(iso);
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
/// - 3 selectable breathing techniques (4-7-8 Deep Calm, Box Breathing 4-4-4-4, Heart Coherence 5-5)
/// - Selectable session duration (1 Min, 3 Min, 5 Min, 10 Min)
/// - 5 selectable peaceful soundscapes (no harsh continuous buzz)
/// - Natural female TTS voice guidance with calm speech rate (0.39) & pitch (0.96)
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

  int _selectedPatternIndex = 0;
  int _selectedTrackIndex = 0;
  int _selectedDurationMinutes = 3;
  int _remainingSessionSeconds = 180;
  bool _isRunning = false;
  bool _ambientSoundEnabled = true;
  bool _voiceGuidanceEnabled = true;

  final FlutterTts _voiceEngine = FlutterTts();
  late final Future<void> _voiceInitialization;
  int _voiceRequestId = 0;

  // 0 = Inhale, 1 = Hold, 2 = Exhale
  int _phaseIndex = 0;
  int _phaseSecondsLeft = 4;
  int _completedCycles = 0;
  Timer? _timer;

  static const List<Map<String, dynamic>> _breathingPatterns = [
    {
      'title': '4-7-8 Deep Calm',
      'durations': [4, 7, 8],
    },
    {
      'title': 'Box Breath 4-4-4',
      'durations': [4, 4, 4],
    },
    {
      'title': 'Coherence 5-2-5',
      'durations': [5, 2, 5],
    },
  ];

  List<int> get _phaseDurations =>
      (_breathingPatterns[_selectedPatternIndex]['durations'] as List<int>);

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
      } catch (_) {}
    }

    try {
      final dynamic voices = await _voiceEngine.getVoices;
      if (voices is List) {
        Map<dynamic, dynamic>? preferredVoice;
        for (final raw in voices) {
          if (raw is Map) {
            final name = (raw['name'] ?? '').toString().toLowerCase();
            final locale = (raw['locale'] ?? '')
                .toString()
                .replaceAll('_', '-')
                .toLowerCase();
            final isEnglish =
                locale.startsWith('en-in') ||
                locale.startsWith('en-gb') ||
                locale.startsWith('en-us');
            final isFemale =
                name.contains('female') ||
                name.contains('veena') ||
                name.contains('lekha') ||
                name.contains('samantha') ||
                name.contains('en-in-x-end');
            if (isEnglish && isFemale) {
              preferredVoice = raw;
              if (locale.startsWith('en-in')) break;
            }
          }
        }
        if (preferredVoice != null) {
          await _voiceEngine.setVoice({
            'name': preferredVoice['name'].toString(),
            'locale': preferredVoice['locale'].toString(),
          });
        } else {
          await _voiceEngine.setLanguage('en-IN');
        }
      }
    } catch (_) {}

    try {
      await _voiceEngine.setSpeechRate(0.39);
      await _voiceEngine.setPitch(0.96);
      await _voiceEngine.setVolume(0.92);
    } catch (_) {}
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
    } catch (_) {}
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
      await _voiceEngine.speak(_spokenCompletionGuidance);
    } catch (_) {}
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
        'volume': 0.62,
        'trackIndex': _selectedTrackIndex,
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
        title: const Text('Guided Breathing Studio'),
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
                ? 'Mute peaceful soundscape'
                : 'Enable peaceful soundscape',
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
                  const SakhiGentleWomanIllustration(
                    pose: SakhiWomanPose.breathingCalm,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sakhi AI Calm Companion \u2022 ${_breathingPatterns[_selectedPatternIndex]['title']}',
                          style: const TextStyle(
                            color: Color(0xFFFFB3D1),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isRunning
                              ? _aiVoicePrompts[_phaseIndex]
                              : 'Choose your breathing rhythm, peaceful soundscape, and duration below, then tap Start.',
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

            // Breathing Pattern Picker
            Text(
              'Select Breathing Technique',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_breathingPatterns.length, (i) {
                final selected = _selectedPatternIndex == i;
                return ChoiceChip(
                  label: Text(
                    _breathingPatterns[i]['title'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: selected ? Colors.white : AppColors.primaryPurple,
                    ),
                  ),
                  selected: selected,
                  selectedColor: const Color(0xFFD63E85),
                  backgroundColor: Colors.white,
                  onSelected: (_) {
                    setState(() {
                      _selectedPatternIndex = i;
                      _phaseIndex = 0;
                      _phaseSecondsLeft = _phaseDurations[0];
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 12),

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
            const SizedBox(height: 12),

            // Soundscape Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(
                  GuidedMeditationSessionController.soundscapeTitles.length,
                  (i) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        GuidedMeditationSessionController.soundscapeTitles[i],
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _selectedTrackIndex == i
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      selected: _selectedTrackIndex == i,
                      selectedColor: AppColors.primaryPurple,
                      backgroundColor: Colors.white,
                      onSelected: (_) {
                        setState(() => _selectedTrackIndex = i);
                        if (_isRunning && _ambientSoundEnabled) {
                          _startAmbientAudio();
                        }
                      },
                    ),
                  ),
                ),
              ),
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
                          Icon(Icons.spa_rounded, size: 18, color: accent),
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
