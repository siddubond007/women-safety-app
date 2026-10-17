import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class SakhiBottomNav extends StatelessWidget {
  const SakhiBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCenterAddTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCenterAddTap;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.cardSurface,
      boxShadow: AppSpacing.navBarShadow,
      border: const Border(top: BorderSide(color: AppColors.borderSubtle)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(children: [
          _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', selected: currentIndex == 0, onTap: () => onTabSelected(0)),
          _NavItem(icon: Icons.search_rounded, activeIcon: Icons.search_rounded, label: 'Explore', selected: currentIndex == 1, onTap: () => onTabSelected(1)),
          Expanded(
            child: Center(
              child: Semantics(
                button: true,
                label: 'Create post',
                child: GestureDetector(
                  key: const Key('module2-bottom-create'),
                  onTap: onCenterAddTap,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primaryPurpleLight, AppColors.primaryPurple]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
          _NavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups_rounded, label: 'Community', selected: currentIndex == 2, onTap: () => onTabSelected(2)),
          _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', selected: currentIndex == 3, onTap: () => onTabSelected(3)),
        ]),
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryPurple : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        key: Key('module2-nav-' + label.toLowerCase()),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(selected ? activeIcon : icon, color: color, size: 23),
            const SizedBox(height: 2),
            Text(label, style: AppTypography.navLabel.copyWith(color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
