import 'package:flutter/material.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_brand_header.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../widgets/safety_map_card.dart';
import '../widgets/safety_quick_action_tile.dart';

/// Screen 5 — Safety & SOS
class SafetyScreen extends StatelessWidget {
  final bool showBackButton;

  const SafetyScreen({super.key, this.showBackButton = false});

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showBackButton && Navigator.of(context).canPop())
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textPrimary,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  Expanded(
                    child: SakhiBrandHeader(
                      title: 'Safety',
                      useShieldEmblem: true,
                      actions: [
                        SakhiPillButton(
                          label: 'SOS',
                          icon: Icons.notifications_active_outlined,
                          backgroundColor: AppColors.sosRed,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          onPressed: () =>
                              SakhiDialogs.showSosPrototypeDialog(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Map-like visual area with central emergency action
                    SafetyMapCard(
                      onSosTap: () =>
                          SakhiDialogs.showSosPrototypeDialog(context),
                    ),

                    const SizedBox(height: 18),
                    // 4 Circular Safety Categories
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SafetyCircleItem(
                          label: 'Emergency\nContacts',
                          icon: Icons.people_alt_rounded,
                          bgColor: AppColors.sosRedSoft,
                          iconColor: AppColors.sosRed,
                          onTap: () => SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Trusted Contacts (${state.emergencyContacts.length}): ${state.emergencyContacts.map((c) => c.name).join(", ")}',
                          ),
                        ),
                        _SafetyCircleItem(
                          label: 'Nearby\nHelp',
                          icon: Icons.location_on_rounded,
                          bgColor: AppColors.pastelMint,
                          iconColor: AppColors.wellnessGreen,
                          onTap: () => SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Nearby Help stations around ${state.currentUser.location}.',
                          ),
                        ),
                        _SafetyCircleItem(
                          label: 'Safety\nTips',
                          icon: Icons.shield_rounded,
                          bgColor: AppColors.pastelPeach,
                          iconColor: AppColors.amberAccent,
                          onTap: () => SakhiDialogs.showPrototypeSnackbar(
                            context,
                            "Opening Women's Safety Tips & Checklists.",
                          ),
                        ),
                        _SafetyCircleItem(
                          label: 'Helpline\nNumbers',
                          icon: Icons.phone_in_talk_rounded,
                          bgColor: AppColors.pastelLavender,
                          iconColor: AppColors.primaryPurple,
                          onTap: () => SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Helpline Directory: 112 (Emergency) • 1091 (Women) • 181',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),
                    const SakhiSectionHeader(title: 'Quick Safety Actions'),
                    const SizedBox(height: 12),

                    SafetyQuickActionTile(
                      icon: Icons.my_location_rounded,
                      iconColor: const Color(0xFFD63E85),
                      iconBgColor: AppColors.pastelPink,
                      title: 'Share my live location',
                      subtitle: 'with trusted contacts',
                      onTap: () => SakhiDialogs.showConfirmationDialog(
                        context: context,
                        title: 'Share Live Location',
                        description:
                            'Share your live location session with your ${state.emergencyContacts.length} trusted emergency contacts?',
                        confirmLabel: 'Start Sharing',
                        onConfirmed: () {
                          state.recordSafetyEvent(
                            'LIVE_LOCATION_SHARE',
                            locationLabel: state.currentUser.location,
                          );
                          SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Live location share session recorded for trusted contacts.',
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    SafetyQuickActionTile(
                      icon: Icons.fact_check_outlined,
                      iconColor: AppColors.primaryPurple,
                      iconBgColor: AppColors.pastelLavender,
                      title: 'Safety checklist',
                      subtitle: 'Before travelling or meeting someone',
                      onTap: () {
                        state.recordSafetyEvent('CHECKLIST_COMPLETED');
                        SakhiDialogs.showPrototypeSnackbar(
                          context,
                          'Opening Travel & Meeting Safety Checklist.',
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    SafetyQuickActionTile(
                      icon: Icons.support_agent_rounded,
                      iconColor: AppColors.sosRed,
                      iconBgColor: AppColors.sosRedSoft,
                      title: 'Emergency helplines',
                      subtitle: "Police, ambulance, women's helpline",
                      onTap: () => SakhiDialogs.showConfirmationDialog(
                        context: context,
                        title: 'Emergency Helplines',
                        description:
                            "• National Emergency Number: 112\n• Women's Helpline (All India): 1091\n• Domestic Abuse Helpline: 181",
                        confirmLabel: 'OK',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyCircleItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _SafetyCircleItem({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.subtitle.copyWith(
                fontSize: 11.5,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
