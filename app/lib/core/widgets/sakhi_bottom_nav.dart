import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// iOS 26 Liquid Glass Bottom Navigation Bar with dead-center '+' Create FAB.
/// Features 4 balanced navigation tabs (Home, Explore | + | Community, Profile)
/// so the central '+' action button is perfectly centered.
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A1958).withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.70),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.88),
                  const Color(0xFFFDF6FC).withValues(alpha: 0.92),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 1.4,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _NavTabItem(
                        key: const Key('bottom-nav-home-tab'),
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Home',
                        isSelected: currentIndex == 0,
                        onTap: () => onTabSelected(0),
                      ),
                    ),
                    Expanded(
                      child: _NavTabItem(
                        key: const Key('bottom-nav-explore-tab'),
                        icon: Icons.search_rounded,
                        activeIcon: Icons.search_rounded,
                        useSearchBadge: true,
                        label: 'Explore',
                        isSelected: currentIndex == 1,
                        onTap: () => onTabSelected(1),
                      ),
                    ),
                    // Dead-center '+' Liquid Glass Create FAB
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: GestureDetector(
                        key: const Key('bottom-nav-create-hub-button'),
                        onTap: onCenterAddTap,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFB548C8),
                                AppColors.primaryPurple,
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.75),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple
                                    .withValues(alpha: 0.36),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _NavTabItem(
                        key: const Key('bottom-nav-community-tab'),
                        icon: Icons.groups_outlined,
                        activeIcon: Icons.groups_rounded,
                        label: 'Community',
                        isSelected: currentIndex == 2,
                        onTap: () => onTabSelected(2),
                      ),
                    ),
                    Expanded(
                      child: _NavTabItem(
                        key: const Key('bottom-nav-profile-tab'),
                        icon: Icons.person_outline_rounded,
                        activeIcon: Icons.person_rounded,
                        label: 'Profile',
                        isSelected: currentIndex == 3,
                        onTap: () => onTabSelected(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? AppColors.primaryPurple.withValues(alpha: 0.10)
              : Colors.transparent,
        ),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
