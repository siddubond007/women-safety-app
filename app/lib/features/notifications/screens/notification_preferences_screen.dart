import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_dialogs.dart';

/// Screen 9 — Notification Preferences & Quiet Hours (Section 7.2)
/// Independently controllable switches with Quiet Hours non-urgent suppression.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _quietHoursEnabled = true;
  int _quietHoursStart = 22;
  int _quietHoursEnd = 7;

  String _formatHour(int h) => '${h.toString().padLeft(2, '0')}:00';

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Quiet Hours Card (Section 7.2)
                SakhiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                            child: const Icon(
                              Icons.bedtime_rounded,
                              color: AppColors.primaryPurple,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quiet Hours (${_formatHour(_quietHoursStart)} – ${_formatHour(_quietHoursEnd)})',
                                  style: AppTypography.cardTitle,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Silences non-urgent community & circle alerts overnight. Emergency SOS & Safety alerts always deliver immediately.',
                                  style: AppTypography.subtitle,
                                ),
                              ],
                            ),
                          ),
                          Switch.adaptive(
                            value: _quietHoursEnabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppColors.primaryPurple,
                            onChanged: (v) {
                              setState(() => _quietHoursEnabled = v);
                              SakhiDialogs.showPrototypeSnackbar(
                                context,
                                v
                                    ? 'Quiet hours enabled (${_formatHour(_quietHoursStart)} – ${_formatHour(_quietHoursEnd)}).'
                                    : 'Quiet hours disabled.',
                              );
                            },
                          ),
                        ],
                      ),
                      if (_quietHoursEnabled) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            (22, 7, '22:00 – 07:00'),
                            (23, 7, '23:00 – 07:00'),
                            (21, 6, '21:00 – 06:00'),
                          ].map((preset) {
                            final (s, e, label) = preset;
                            final selected =
                                _quietHoursStart == s && _quietHoursEnd == e;
                            return ChoiceChip(
                              label: Text(label),
                              selected: selected,
                              onSelected: (_) {
                                setState(() {
                                  _quietHoursStart = s;
                                  _quietHoursEnd = e;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SakhiCard(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
              ],
            ),
          );
        },
      ),
    );
  }
}
