import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class SakhiCard extends StatelessWidget {
  const SakhiCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.backgroundColor,
    this.gradient,
    this.borderRadius = AppSpacing.radiusLg,
    this.onTap,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Gradient? gradient;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? AppColors.cardSurface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? AppColors.borderSubtle),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(borderRadius), child: card),
    );
  }
}
