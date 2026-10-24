from pathlib import Path
import re
root = Path(r"D:\Development\Projects\women_safety_app")
p = root / "app/lib/features/profile/screens/profile_screen.dart"
s = p.read_text(encoding="utf-8")
pattern = r"(?s)                // Display Name, Verification Badge, Username & Edit Profile\n                Padding\(.*?\n                \),\n\n                const SizedBox\(height: 16\),"
replacement = r"""                // Center the identity and actions as one cohesive profile header.
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              textAlign: TextAlign.center,
                              style: AppTypography.appBarTitle.copyWith(
                                fontSize: 21,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.verificationStatus == 'VERIFIED') ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.primaryPurple,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.username.isEmpty ? '@sakhi_member' : user.username,
                        style: AppTypography.subtitle,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          SakhiPillButton(
                            label: 'Edit Profile',
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            onPressed: () =>
                                _navigateTo(context, AppRoutes.editProfile),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              final handle = user.username.isEmpty
                                  ? '@sakhi_member'
                                  : user.username;
                              SakhiDialogs.showPrototypeSnackbar(
                                context,
                                'Profile sharing for $handle will be enabled when public profile links are available.',
                              );
                            },
                            icon: const Icon(Icons.share_outlined, size: 17),
                            label: const Text('Share Profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryPurple,
                              side: const BorderSide(
                                color: AppColors.borderSubtle,
                              ),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),"""
s2, n = re.subn(pattern, replacement, s, count=1)
if n != 1: raise SystemExit(f"identity block replaced {n}")
s = s2
old = "onTap: () => _navigateTo(context, AppRoutes.followers),\n                      ),\n                    ],\n                  ),\n                ),\n\n                const SizedBox(height: 14),"
if s.count(old) != 1: raise SystemExit(f"following stat pattern count {s.count(old)}")
s=s.replace(old, "onTap: () => _navigateTo(context, AppRoutes.following),\n                      ),\n                    ],\n                  ),\n                ),\n\n                const SizedBox(height: 14),",1)
old = """        return const SakhiEmptyState(
          icon: Icons.grid_on_outlined,
          title: 'No Posts Yet',
          message: 'Your published photos and posts will appear here.',
        );"""
new = """        return SakhiEmptyState(
          icon: Icons.grid_on_outlined,
          title: 'No Posts Yet',
          message: 'Share your first photo, thought, or question with the Sakhi community.',
          actionLabel: '+ Create First Post',
          onAction: widget.onCreateTap ??
              () => _navigateTo(context, AppRoutes.community),
        );"""
if s.count(old) != 1: raise SystemExit(f"posts empty count {s.count(old)}")
s=s.replace(old,new,1)
old = """        return const SakhiEmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'No Saved Posts Yet',
          message: 'Bookmark posts from the Community feed to find them here.',
        );"""
new = """        return SakhiEmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'No Saved Posts Yet',
          message: 'Your bookmarked wellness tips, safety resources, and community stories will appear here.',
          actionLabel: 'Explore Community',
          onAction: widget.onNavigateTab != null
              ? () => widget.onNavigateTab!(2)
              : () => _navigateTo(context, AppRoutes.community),
        );"""
if s.count(old) != 1: raise SystemExit(f"saved empty count {s.count(old)}")
s=s.replace(old,new,1)
old = """    } else {
      return Column(
        children: state.groups
            .map("""
new = """    } else {
      if (state.groups.isEmpty) {
        return SakhiEmptyState(
          icon: Icons.groups_outlined,
          title: "You Haven't Joined Any Circles Yet",
          message: 'Join supportive circles for career, wellness, hobbies, and local safety.',
          actionLabel: 'Browse Circles',
          onAction: widget.onNavigateTab != null
              ? () => widget.onNavigateTab!(1)
              : () => _navigateTo(context, AppRoutes.explore),
        );
      }
      return Column(
        children: state.groups
            .map("""
if s.count(old) != 1: raise SystemExit(f"groups empty insertion count {s.count(old)}")
s=s.replace(old,new,1)
p.write_text(s,encoding="utf-8",newline="")
print("Profile identity, stat navigation and all three tab empty-state actions patched")
