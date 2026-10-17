import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SakhiSearchField extends StatelessWidget {
  const SakhiSearchField({super.key, required this.hintText, this.controller, this.onChanged, this.onClear, this.onSubmitted});
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.subtitle,
        filled: true,
        fillColor: Colors.transparent,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPurple, size: 20),
        suffixIcon: controller != null && controller!.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear)
            : null,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    ),
  );
}
