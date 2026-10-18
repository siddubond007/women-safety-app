import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../widgets/module2_feature_widgets.dart';

class WellnessScreen extends StatefulWidget {
  const WellnessScreen({super.key, this.onNavigateRoute});
  final ValueChanged<String>? onNavigateRoute;

  @override
  State<WellnessScreen> createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  static const int _sessionSeconds = 10 * 60;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  bool _showBreathing = false;
  int _breathSecond = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _navigate(String route) {
    final handler = widget.onNavigateRoute;
    if (handler != null) {
      handler(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  void _toggleMeditation() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
      return;
    }
    if (_elapsedSeconds >= _sessionSeconds) {
      setState(() => _elapsedSeconds = 0);
    }
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_elapsedSeconds >= _sessionSeconds) {
        timer.cancel();
        setState(() => _isRunning = false);
      } else {
        setState(() => _elapsedSeconds++);
      }
    });
  }

  String _time(int seconds) {
    final remaining = (_sessionSeconds - seconds).clamp(0, _sessionSeconds);
    final minutes = remaining ~/ 60;
    final secs = remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Module2PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Module2PageTitle('Wellness', subtitle: 'Small, steady steps for everyday wellbeing')),
            IconButton(
              tooltip: 'Safety guidance',
              onPressed: () => _navigate(AppRoutes.safety),
              icon: const Icon(Icons.shield_outlined, color: AppColors.primaryPurple),
            ),
          ]),
          const SizedBox(height: 13),
          Container(
            height: 156,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppColors.wellnessBannerGradient,
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(children: [
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 172,
                child: Image.asset(
                  AppAssets.wellnessHeroIllustration,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 15, 135, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Your Wellbeing Matters', style: AppTypography.heroTitle.copyWith(fontSize: 19)),
                  const SizedBox(height: 7),
                  Text('Explore tools and resources to feel better, every day.', style: AppTypography.subtitle.copyWith(height: 1.4)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          const SakhiSectionHeader(title: 'Explore wellness'),
          const SizedBox(height: 11),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.05,
            children: [
              _WellnessCategory(label: 'Menstrual Health', icon: Icons.favorite_rounded, color: AppColors.pastelPink, description: 'Cycle-aware education and self-care ideas'),
              _WellnessCategory(label: 'Mental Wellness', icon: Icons.psychology_rounded, color: AppColors.pastelBlue, description: 'Grounding and stress-management routines'),
              _WellnessCategory(label: 'Fitness & Nutrition', icon: Icons.fitness_center_rounded, color: AppColors.pastelMint, description: 'Gentle movement and balanced habits'),
              _WellnessCategory(label: 'Expert Articles', icon: Icons.article_outlined, color: AppColors.pastelPeach, description: 'Read curated wellbeing guidance'),
            ],
          ),
          const SizedBox(height: 22),
          const SakhiSectionHeader(title: 'Today’s Pick'),
          const SizedBox(height: 10),
          SakhiCard(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(
                    AppAssets.guidedMeditationThumb,
                    width: 91,
                    height: 86,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 91, height: 86, color: AppColors.pastelLavender, child: const Icon(Icons.spa_rounded, color: AppColors.primaryPurple, size: 32)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Guided Meditation', style: AppTypography.cardTitle),
                  const SizedBox(height: 4),
                  Text(_isRunning ? 'Session in progress' : (_elapsedSeconds >= _sessionSeconds ? 'Session complete' : '10 min · guided timer')),
                  const SizedBox(height: 9),
                  Row(children: [
                    IconButton.filled(
                      tooltip: _isRunning ? 'Pause session' : 'Start session',
                      onPressed: _toggleMeditation,
                      icon: Icon(_isRunning ? Icons.pause_rounded : (_elapsedSeconds >= _sessionSeconds ? Icons.replay_rounded : Icons.play_arrow_rounded)),
                    ),
                    const SizedBox(width: 6),
                    Text(_time(_elapsedSeconds), style: AppTypography.subtitle.copyWith(fontFeatures: const [])),
                  ]),
                ])),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _elapsedSeconds / _sessionSeconds,
                minHeight: 5,
                borderRadius: BorderRadius.circular(99),
                backgroundColor: AppColors.pastelLavender,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(height: 8),
              const Text(
                'This is a timed quiet-session aid; it does not stream audio. Pause or resume the timer at any time.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.35),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          SakhiCard(
            padding: const EdgeInsets.all(15),
            backgroundColor: AppColors.pastelQuoteBg,
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.primaryPurple),
              SizedBox(width: 10),
              Expanded(child: Text('You are stronger than you think, and you do not have to do everything at once.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.45, fontStyle: FontStyle.italic))),
            ]),
          ),
          const SizedBox(height: 18),
          const SakhiSectionHeader(title: 'Breathing exercises'),
          const SizedBox(height: 10),
          SakhiCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppColors.pastelMint, shape: BoxShape.circle), child: const Icon(Icons.air_rounded, color: AppColors.wellnessGreen)),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Gentle 4–4 breathing', style: AppTypography.cardTitle),
                  SizedBox(height: 3),
                  Text('Breathe in for four, breathe out for four.', style: AppTypography.subtitle),
                ])),
                IconButton(
                  tooltip: _showBreathing ? 'Stop breathing timer' : 'Start breathing timer',
                  onPressed: () => setState(() {
                    _showBreathing = !_showBreathing;
                    _breathSecond = 0;
                  }),
                  icon: Icon(_showBreathing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: AppColors.primaryPurple, size: 30),
                ),
              ]),
              if (_showBreathing) ...[
                const SizedBox(height: 12),
                Center(child: Text(_breathSecond % 8 < 4 ? 'Breathe in' : 'Breathe out', style: AppTypography.sectionTitle.copyWith(color: AppColors.wellnessGreen))),
                const SizedBox(height: 6),
                Center(child: Text('Cycle timer: ${(_breathSecond % 8) + 1}s', style: AppTypography.subtitle)),
                const SizedBox(height: 9),
                FilledButton.tonal(
                  onPressed: () => setState(() => _breathSecond++),
                  child: const Text('Next breathing step'),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _WellnessCategory extends StatelessWidget {
  const _WellnessCategory({required this.label, required this.icon, required this.color, required this.description});
  final String label;
  final IconData icon;
  final Color color;
  final String description;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(icon, color: AppColors.primaryPurple, size: 27), const SizedBox(width: 10), Expanded(child: Text(label, style: AppTypography.sectionTitle))]),
              const SizedBox(height: 12),
              Text(description, style: AppTypography.bodyRegular),
              const SizedBox(height: 10),
              const Text('Content is educational and not a substitute for professional medical advice.', style: AppTypography.subtitle),
            ]),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          Container(width: 35, height: 35, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.primaryPurple)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
        ]),
      ),
    ),
  );
}
