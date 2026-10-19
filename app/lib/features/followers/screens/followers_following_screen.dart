import 'package:flutter/material.dart';
import '../../../core/constants/mock_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_buttons.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_empty_state.dart';
import '../../../core/widgets/sakhi_search_field.dart';

/// Screen 10 — Followers & Following
class FollowersFollowingScreen extends StatefulWidget {
  const FollowersFollowingScreen({super.key});

  @override
  State<FollowersFollowingScreen> createState() =>
      _FollowersFollowingScreenState();
}

class _FollowersFollowingScreenState extends State<FollowersFollowingScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showingFollowingOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = SakhiPrototypeState.instance;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: state,
          builder: (context, _) {
            final query = _searchController.text.trim().toLowerCase();
            final filtered = state.followers.where((u) {
              if (_showingFollowingOnly && !u.isFollowing) return false;
              if (query.isEmpty) return true;
              return u.name.toLowerCase().contains(query) ||
                  u.username.toLowerCase().contains(query);
            }).toList();

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Header Row: Back Arrow + Followers 560 + Filter Toggle
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primaryPurple,
                        ),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showingFollowingOnly ? 'Following' : 'Followers',
                        style: AppTypography.appBarTitle,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _showingFollowingOnly
                            ? '${state.currentUser.followingCount}'
                            : '${state.currentUser.followersCount}',
                        style: AppTypography.sectionTitle.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(
                            () => _showingFollowingOnly = !_showingFollowingOnly,
                          );
                        },
                        child: Text(
                          _showingFollowingOnly ? 'Show All' : 'Following',
                          style: AppTypography.chipLabel,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  SakhiSearchField(
                    hintText: 'Search followers...',
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    onClear: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 14),
                  Expanded(
                    child: filtered.isEmpty
                        ? SakhiEmptyState(
                            icon: Icons.person_search_rounded,
                            title: 'No matching profiles',
                            message:
                                'No followers matched "${_searchController.text}".',
                            actionLabel: 'Clear Search',
                            onAction: () {
                              _searchController.clear();
                              setState(() => _showingFollowingOnly = false);
                            },
                          )
                        : SakhiCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Divider(
                                height: 1,
                                color: AppColors.dividerColor,
                              ),
                              itemBuilder: (context, index) {
                                final person = filtered[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      SakhiAvatar(
                                        imageAsset: person.avatarAsset,
                                        size: 46,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              person.name,
                                              style: AppTypography.cardTitle,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              person.username,
                                              style: AppTypography.subtitle,
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 104,
                                        child: Center(
                                          child: SakhiPillButton(
                                            label: person.isFollowing
                                                ? 'Following'
                                                : 'Follow',
                                            isFilled: person.isFollowing,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 7,
                                            ),
                                            onPressed: () =>
                                                state.toggleFollow(person.id),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
