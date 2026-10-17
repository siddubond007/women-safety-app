import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_settings_row.dart';
import '../widgets/module2_feature_widgets.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key, this.onNavigateRoute});
  final ValueChanged<String>? onNavigateRoute;

  void _navigate(BuildContext context, String route) {
    final handler = onNavigateRoute;
    if (handler != null) {
      handler(route);
    } else {
      Navigator.of(context).pushNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Module2PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(child: Module2PageTitle('Safety', subtitle: 'Practical guidance and options to prepare ahead')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed, foregroundColor: Colors.white),
              onPressed: () => SakhiDialogs.showSosPrototypeDialog(context),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.sos_rounded, size: 18),
                SizedBox(width: 4),
                Text('SOS'),
              ]),
            ),
          ]),
          const SizedBox(height: 13),
          _SafetyMapCard(onSos: () => SakhiDialogs.showSosPrototypeDialog(context)),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: _SafetyCircle(icon: Icons.people_alt_rounded, color: const Color(0xFFD63E72), title: 'Emergency\ncontacts', onTap: () => _showContactInfo(context))),
            Expanded(child: _SafetyCircle(icon: Icons.location_searching_rounded, color: AppColors.wellnessGreen, title: 'Nearby\nhelp', onTap: () => _showNearbyInfo(context))),
            Expanded(child: _SafetyCircle(icon: Icons.health_and_safety_rounded, color: AppColors.amberAccent, title: 'Safety\nchecklist', onTap: () => _showChecklist(context))),
            Expanded(child: _SafetyCircle(icon: Icons.call_rounded, color: AppColors.infoBlue, title: 'Help\nlines', onTap: () => _showHelplines(context))),
          ]),
          const SizedBox(height: 22),
          const Text('Quick Safety Actions', style: AppTypography.sectionTitle),
          const SizedBox(height: 11),
          SakhiSettingsRow(
            icon: Icons.people_alt_rounded,
            title: 'Emergency Contacts',
            subtitle: 'Review trusted contacts outside Sakhi',
            iconBgColor: AppColors.pastelPink,
            iconColor: const Color(0xFFD63E72),
            onTap: () => _showContactInfo(context),
          ),
          const SizedBox(height: 9),
          SakhiSettingsRow(
            icon: Icons.checklist_rounded,
            title: 'Safety Checklist',
            subtitle: 'Before travelling or meeting someone',
            iconBgColor: AppColors.pastelLavender,
            onTap: () => _showChecklist(context),
          ),
          const SizedBox(height: 9),
          SakhiSettingsRow(
            icon: Icons.call_outlined,
            title: 'Emergency helplines',
            subtitle: 'National emergency and women’s assistance',
            iconBgColor: AppColors.pastelPeach,
            iconColor: AppColors.amberAccent,
            onTap: () => _showHelplines(context),
          ),
          const SizedBox(height: 12),
          const Text(
            'Important: SOS dispatch, live GPS sharing and automatic phone/SMS alerts are not enabled by the current configured services. No emergency action is triggered from this screen.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  void _showContactInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency contacts'),
        content: const Text('Keep trusted people’s contact details saved in your phone and agree on a clear check-in plan. Sakhi’s contact storage and emergency dispatch are not configured in this version, so no contacts have been added or contacted here.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showNearbyInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nearby help'),
        content: const Text('This map is a design surface only; it does not access your location or query live services. For location-based help, use your device’s maps or an emergency service directly.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showChecklist(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const _SafetyChecklistSheet(),
    );
  }

  void _showHelplines(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency helplines'),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('112  ·  National Emergency Number'),
          SizedBox(height: 9),
          Text('181  ·  Women Helpline (where available)'),
          SizedBox(height: 9),
          Text('1091  ·  Women Police Helpline (regional availability varies)'),
          SizedBox(height: 12),
          Text('Numbers and availability can vary by location. This panel only displays information; it does not place a call.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }
}

class _SafetyMapCard extends StatelessWidget {
  const _SafetyMapCard({required this.onSos});
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) => Container(
    height: 235,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      border: Border.all(color: AppColors.borderSubtle),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(alignment: Alignment.center, children: [
      Positioned.fill(
        child: Image.asset(
          AppAssets.safetyMapBg,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.pastelLavender, AppColors.pastelPink])),
          ),
        ),
      ),
      Container(
        width: 178,
        height: 178,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .22), border: Border.all(color: AppColors.primaryPurple.withValues(alpha: .35), width: 2)),
      ),
      Container(
        width: 126,
        height: 126,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.pastelPink.withValues(alpha: .48), border: Border.all(color: const Color(0xFFDFA8C8))),
      ),
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .92), boxShadow: const [BoxShadow(color: Color(0x1A79318A), blurRadius: 12)]),
        child: IconButton(
          tooltip: 'Open SOS information',
          onPressed: onSos,
          icon: const Icon(Icons.location_on_rounded, color: AppColors.sosRed, size: 36),
        ),
      ),
      const Positioned(bottom: 16, child: Column(children: [
        Text('Tap SOS', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        Text('for emergency guidance', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
      ])),
    ]),
  );
}

class _SafetyCircle extends StatelessWidget {
  const _SafetyCircle({required this.icon, required this.color, required this.title, required this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(17),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: Column(children: [
        Container(width: 53, height: 53, decoration: BoxDecoration(color: color.withValues(alpha: .12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
        const SizedBox(height: 7),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600, height: 1.2)),
      ]),
    ),
  );
}

class _SafetyChecklistSheet extends StatefulWidget {
  const _SafetyChecklistSheet();

  @override
  State<_SafetyChecklistSheet> createState() => _SafetyChecklistSheetState();
}

class _SafetyChecklistSheetState extends State<_SafetyChecklistSheet> {
  final Set<int> _checked = <int>{};
  static const items = [
    'Tell a trusted person where you are going.',
    'Keep your phone charged and emergency numbers available.',
    'Use a well-lit public meeting location where possible.',
    'Arrange a check-in time and a way to leave independently.',
    'Trust your instincts and seek help if you feel unsafe.',
  ];

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Safety checklist', style: AppTypography.sectionTitle),
      const SizedBox(height: 5),
      const Text('A personal planning aid. It does not share information or send alerts.', style: AppTypography.subtitle),
      const SizedBox(height: 10),
      ...List.generate(items.length, (index) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _checked.contains(index),
        onChanged: (checked) => setState(() {
          if (checked == true) {
            _checked.add(index);
          } else {
            _checked.remove(index);
          }
        }),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.primaryPurple,
        title: Text(items[index], style: AppTypography.bodyRegular.copyWith(fontSize: 13)),
      )),
      Align(alignment: Alignment.centerRight, child: SakhiPillButton(label: 'Done', onPressed: () => Navigator.pop(context))),
    ]),
  );
}
