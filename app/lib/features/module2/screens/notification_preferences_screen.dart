import 'package:flutter/material.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/module2_feature_widgets.dart';

class NotificationPreferencesScreen extends StatelessWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Module2PageBody(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Module2PageTitle('Notification Preferences', subtitle: 'Control the types of updates you receive'),
          const SizedBox(height: 8),
          const Text('These preferences are saved to your account. Delivery requires a configured notification provider.', style: AppTypography.subtitle),
          const SizedBox(height: 16),
          for (final pref in state.notificationPreferences) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderSubtle)),
              child: SwitchListTile(
                value: pref.isEnabled,
                onChanged: (value) => _handleToggle(context, pref.id, value),
                activeColor: AppColors.primaryPurple,
                secondary: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.pastelLavender, borderRadius: BorderRadius.circular(12)),
                  child: Icon(pref.icon, color: AppColors.primaryPurple, size: 21),
                ),
                title: Text(pref.title, style: AppTypography.cardTitle.copyWith(fontSize: 13.5)),
                subtitle: Text(pref.subtitle, style: AppTypography.subtitle),
              ),
            ),
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

  Future<void> _handleToggle(BuildContext context, String id, bool value) async {
    final state = SakhiPrototypeState.instance;
    if (id == 'marketing_updates' && value && state.backend?.notificationPreferences['marketingConsentAccepted'] != true) {
      final consent = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Optional marketing consent'),
          content: const Text('Allow optional product updates and marketing communications from Sakhi? You can withdraw this consent later. This choice is stored separately from required Terms and Privacy acknowledgement.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('I agree')),
          ],
        ),
      );
      if (!context.mounted || consent != true) return;
      final savedConsent = await state.setMarketingConsent(true);
      if (!savedConsent) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.backend?.errorMessage ?? 'Consent could not be saved.')));
        }
        return;
      }
    }
    if (id == 'marketing_updates' && !value && state.backend?.notificationPreferences['marketingConsentAccepted'] == true) {
      // Disabling delivery does not withdraw consent. The user can explicitly
      // withdraw optional consent using this confirmation flow.
      final withdraw = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Marketing updates'),
          content: const Text('Turn off marketing notifications only, or also withdraw optional product-updates consent?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Notifications only')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Withdraw consent')),
          ],
        ),
      );
      if (!context.mounted) return;
      if (withdraw == true) {
        final ok = await state.setMarketingConsent(false);
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.backend?.errorMessage ?? 'Consent could not be updated.')));
          return;
        }
      }
    }
    final saved = await state.toggleNotificationPref(id, value);
    if (!context.mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.backend?.errorMessage ?? 'Notification preference could not be saved.')));
    }
  }
}
