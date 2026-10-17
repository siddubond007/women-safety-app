import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_settings_row.dart';
import '../widgets/module2_feature_widgets.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Module2PageBody(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Module2PageTitle('Privacy Settings', subtitle: 'Choose how your profile and content are shared'),
          const SizedBox(height: 8),
          const Text(
            'Your precise live location is hidden by default. These choices are saved to your Sakhi account.',
            style: AppTypography.subtitle,
          ),
          const SizedBox(height: 16),
          for (final item in state.privacySettings) ...[
            SakhiSettingsRow(
              icon: item.icon,
              title: item.title,
              subtitle: item.selectedValue,
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              onTap: () => _chooseValue(context, item.id, item.title, item.selectedValue, item.options),
            ),
            const SizedBox(height: 9),
          ],
          if (state.backend?.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(state.backend!.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12)),
            ),
        ]),
      ),
    );
  }

  Future<void> _chooseValue(
    BuildContext context,
    String settingId,
    String title,
    String selected,
    List<String> options,
  ) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTypography.sectionTitle),
            const SizedBox(height: 7),
            for (final option in options)
              RadioListTile<String>(
                value: option,
                groupValue: selected,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primaryPurple,
                title: Text(option),
                onChanged: (value) => Navigator.of(context).pop(value),
              ),
          ]),
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final state = SakhiPrototypeState.instance;
    final saved = await state.updatePrivacySetting(settingId, choice);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(saved ? 'Privacy preference saved.' : (state.backend?.errorMessage ?? 'Privacy preference could not be saved.')),
    ));
  }
}
