import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Authentic iOS 26 Liquid Glass Floating Dock Navigation Bar with dead-center '+' Create Orb.
/// Features 4 balanced navigation tabs (Home, Explore | + | Community, Profile)
/// inside a frosted, specular-bordered floating glass capsule.
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF420E4E).withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.85),
                blurRadius: 2,
                spreadRadius: 0.5,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.82),
                      const Color(0xFFFBE9F7).withValues(alpha: 0.72),
                      Colors.white.withValues(alpha: 0.86),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.94),
                    width: 1.6,
                  ),
                ),
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
                    // Dead-center '+' iOS 26 Liquid Glass Jewel Orb
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
                                Color(0xFFC252D8),
                                Color(0xFF7B2190),
                                AppColors.primaryPurpleDark,
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.88),
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryPurple
                                    .withValues(alpha: 0.38),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
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
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.92),
                    const Color(0xFFF3DCF8).withValues(alpha: 0.76),
                  ],
                )
              : null,
          border: isSelected
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.95),
                  width: 1.2,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryPurple.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
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
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.navLabel.copyWith(
                fontSize: 10.5,
                color: color,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
