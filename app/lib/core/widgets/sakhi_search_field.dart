import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Soft pill search input matching Screen 1, Screen 3, and Screen 10.
/// Fixes vertical centering of placeholder ("Search people, topics, circles, businesses…")
/// and input text across all text scales, and optionally debounces search changes.
class SakhiSearchField extends StatefulWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final Duration debounceDuration;

  const SakhiSearchField({
    super.key,
    required this.hintText,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onClear,
    this.debounceDuration = const Duration(milliseconds: 260),
  });

  @override
  State<SakhiSearchField> createState() => _SakhiSearchFieldState();
}

class _SakhiSearchFieldState extends State<SakhiSearchField> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleTextChanged(String value) {
    setState(() {});
    final callback = widget.onChanged;
    if (callback == null) return;
    if (widget.debounceDuration == Duration.zero) {
      callback(value);
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        callback(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasText =
        widget.controller != null && widget.controller!.text.isNotEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.searchFieldFill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.90),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: widget.controller,
        onTap: widget.onTap,
        onChanged: _handleTextChanged,
        onSubmitted: (val) {
          _debounceTimer?.cancel();
          widget.onSubmitted?.call(val);
        },
        textAlignVertical: TextAlignVertical.center,
        textInputAction: TextInputAction.search,
        style: AppTypography.bodyRegular.copyWith(
          color: AppColors.textPrimary,
          height: 1.25,
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: AppTypography.subtitle.copyWith(
            height: 1.25,
            color: AppColors.textSecondary,
          ),
          fillColor: Colors.transparent,
          filled: true,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
            minHeight: 44,
          ),
          prefixIcon: const Center(
            widthFactor: 1.0,
            child: Icon(
              Icons.search_rounded,
              color: AppColors.primaryPurple,
              size: 20,
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 44,
          ),
          suffixIcon: hasText
              ? IconButton(
                  tooltip: 'Clear search query',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textMuted,
                  onPressed: () {
                    _debounceTimer?.cancel();
                    widget.onClear?.call();
                    setState(() {});
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }
}
