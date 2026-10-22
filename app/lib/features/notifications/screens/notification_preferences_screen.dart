import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_card.dart';

/// Screen 9 — Notification Preferences
/// Independently controllable switches with functioning local toggle state.
class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Notification Preferences'),
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
          final prefs = state.notificationPreferences;
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: 14,
            ),
            child: SakhiCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: List.generate(prefs.length, (index) {
                  final pref = prefs[index];
                  final isMarketingDivider = index == prefs.length - 1;
                  return Column(
                    children: [
                      if (isMarketingDivider)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          child: Divider(),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: AppColors.pastelLavender,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd,
                                ),
                              ),
                              child: Icon(
                                pref.icon,
                                color: AppColors.primaryPurple,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pref.title,
                                    style: AppTypography.cardTitle.copyWith(
                                      fontSize: 14.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pref.subtitle,
                                    style: AppTypography.subtitle,
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: pref.isEnabled,
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppColors.primaryPurple,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFD9CEE3),
                              onChanged: (val) async {
                                final saved = await state
                                    .toggleNotificationPref(pref.id, val);
                                if (!context.mounted || saved) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Notification preference could not be saved. The previous value was restored.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}
