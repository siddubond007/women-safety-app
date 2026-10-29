import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Reusable iOS 26 Liquid Glass card with specular white top/left rim,
/// translucent lavender-pearl gradient sheen, and soft ambient shadow.
class SakhiCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Gradient? gradient;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? borderColor;

  const SakhiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.backgroundColor,
    this.gradient,
    this.borderRadius = AppSpacing.radiusLg,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ??
        (backgroundColor == null
            ? AppColors.liquidGlassCardGradient
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  backgroundColor!.withValues(alpha: 0.90),
                  backgroundColor!.withValues(alpha: 0.78),
                ],
              ));

    final cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: effectiveGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.glassSpecularBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A155B).withValues(alpha: 0.065),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.85),
            blurRadius: 1.5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Material(color: Colors.transparent, child: child),
    );

    if (onTap == null) return cardContent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: cardContent,
      ),
    );
  }
}
