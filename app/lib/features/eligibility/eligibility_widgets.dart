import 'package:flutter/material.dart';

import '../../core/theme/sakhi_design_system.dart';

/// Native Flutter-only eligibility visuals. No screenshot crops or rasterized
/// UI elements are used, so controls and illustration shapes remain crisp.
class EligibilityStepIndicator extends StatelessWidget {
  const EligibilityStepIndicator({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.label,
  });

  final int step;
  final int totalSteps;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: SakhiTypography.categoryLabel.copyWith(fontSize: 10),
              ),
            ),
            Text(
              'STEP $step OF $totalSteps',
              style: const TextStyle(
                color: SakhiColors.mutedPlum,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.45,
              ),
            ),
          ],
        ),
        const SizedBox(height: SakhiSpacing.xs),
        Row(
          children: List<Widget>.generate(totalSteps, (index) {
            final complete = index < step;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 4,
                  decoration: BoxDecoration(
                    color: complete
                        ? SakhiColors.purple
                        : SakhiColors.progressInactive.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class EligibilityVectorHero extends StatelessWidget {
  const EligibilityVectorHero({
    super.key,
    this.icon = Icons.verified_user_outlined,
    this.caption = 'Private by design. Clear by choice.',
  });

  final IconData icon;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SakhiColors.lavender.withValues(alpha: 0.96),
            const Color(0xFFFFE8F0).withValues(alpha: 0.9),
            SakhiColors.ivory,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -34,
            right: -20,
            child: _SoftCircle(
              size: 112,
              color: SakhiColors.purple.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            left: -18,
            bottom: -48,
            child: _SoftCircle(
              size: 118,
              color: SakhiColors.pink.withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            right: 30,
            bottom: 19,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: SakhiColors.pinkAccent.withValues(alpha: 0.82),
              size: 19,
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.2),
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: SakhiColors.ivory,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: SakhiColors.plum.withValues(alpha: 0.09),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(icon, size: 40, color: SakhiColors.purple),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: SakhiColors.plum,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class EligibilityPrincipleCard extends StatelessWidget {
  const EligibilityPrincipleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor = SakhiColors.purple,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SakhiSpacing.sm),
      decoration: BoxDecoration(
        color: SakhiColors.ivory,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: SakhiColors.progressInactive.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: SakhiSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: SakhiColors.plum,
                      fontSize: 13.2,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: SakhiTypography.body.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EligibilityDisclosureTile extends StatelessWidget {
  const EligibilityDisclosureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: SakhiSpacing.xs),
      padding: const EdgeInsets.all(SakhiSpacing.sm),
      decoration: BoxDecoration(
        color: SakhiColors.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SakhiColors.progressInactive.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: SakhiColors.lavender.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: SakhiColors.purple),
          ),
          const SizedBox(width: SakhiSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: SakhiColors.plum,
                    fontSize: 12.8,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: SakhiTypography.body.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EligibilityBullet extends StatelessWidget {
  const EligibilityBullet({
    super.key,
    required this.text,
    this.icon = Icons.check_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SakhiSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 23,
            height: 23,
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(
              color: SakhiColors.lavender,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SakhiColors.purple, size: 14),
          ),
          const SizedBox(width: SakhiSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: SakhiTypography.body.copyWith(fontSize: 12.8),
            ),
          ),
        ],
      ),
    );
  }
}
