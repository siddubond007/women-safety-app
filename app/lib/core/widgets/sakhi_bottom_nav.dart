import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Custom Sakhi bottom navigation bar with central purple '+' button and dedicated Safety shield tab.
class SakhiBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCenterAddTap;

  const SakhiBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCenterAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppSpacing.navBarShadow,
        border: const Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavTabItem(
                key: const Key('bottom-nav-home-tab'),
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
                isSelected: currentIndex == 0,
                onTap: () => onTabSelected(0),
              ),
              _NavTabItem(
                key: const Key('bottom-nav-explore-tab'),
                icon: Icons.search_rounded,
                activeIcon: Icons.search_rounded,
                useSearchBadge: true,
                label: 'Explore',
                isSelected: currentIndex == 1,
                onTap: () => onTabSelected(1),
              ),
              // Central '+' action button
              GestureDetector(
                key: const Key('bottom-nav-create-hub-button'),
                onTap: onCenterAddTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryPurpleLight,
                        AppColors.primaryPurple,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              _NavTabItem(
                key: const Key('bottom-nav-safety-tab'),
                icon: Icons.shield_outlined,
                activeIcon: Icons.shield_rounded,
                label: 'Safety',
                isSelected: currentIndex == 4,
                onTap: () => onTabSelected(4),
              ),
              _NavTabItem(
                key: const Key('bottom-nav-community-tab'),
                icon: Icons.groups_outlined,
                activeIcon: Icons.groups_rounded,
                label: 'Community',
                isSelected: currentIndex == 2,
                onTap: () => onTabSelected(2),
              ),
              _NavTabItem(
                key: const Key('bottom-nav-profile-tab'),
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isSelected: currentIndex == 3,
                onTap: () => onTabSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool useSearchBadge;
  final VoidCallback onTap;

  const _NavTabItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    this.useSearchBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primaryPurple : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? (useSearchBadge ? Icons.search_rounded : activeIcon)
                  : icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.navLabel.copyWith(
                fontSize: 10.5,
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
