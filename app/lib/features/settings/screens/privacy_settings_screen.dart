import 'package:flutter/material.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_settings_row.dart';

/// Screen 8 — Privacy Settings
/// Any location-visibility control remains a local UI simulation.
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Privacy Settings'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: 14,
            ),
            itemCount: state.privacySettings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = state.privacySettings[index];
              return SakhiSettingsRow(
                icon: item.icon,
                title: item.title,
                subtitle: item.selectedValue,
                onTap: () => _showPrivacySelectionSheet(context, state, item),
              );
            },
          );
        },
      ),
    );
  }

  void _showPrivacySelectionSheet(
    BuildContext context,
    SakhiPrototypeState state,
    PrivacySettingItem item,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title, style: AppTypography.sectionTitle),
              if (item.id == 'show_location') ...[
                const SizedBox(height: 4),
                const Text(
                  'Prototype simulation only — no real GPS coordinates are accessed.',
                  style: AppTypography.subtitle,
                ),
              ],
              const SizedBox(height: 10),
              ...item.options.map(
                (opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(opt, style: AppTypography.bodyMedium),
                  trailing: item.selectedValue == opt
                      ? const Icon(
                          Icons.radio_button_checked_rounded,
                          color: AppColors.primaryPurple,
                        )
                      : const Icon(
                          Icons.radio_button_off_rounded,
                          color: AppColors.textMuted,
                        ),
                  onTap: () {
                    state.updatePrivacySetting(item.id, opt);
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
