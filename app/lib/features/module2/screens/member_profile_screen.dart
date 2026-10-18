import 'dart:async';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_chip.dart';
import '../module2_scope.dart';
import '../module2_state.dart';
import '../widgets/module2_feature_widgets.dart';

/// Read-only public profile detail for another verified Sakhi member.
/// Private contact data, phone numbers and dates of birth are never shown.
class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key, required this.accountId});

  final String accountId;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  Module2State? _state;
  String? _requestedAccountId;
  bool _followingAction = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = Module2Scope.of(context).state;
    if (!identical(_state, state) || _requestedAccountId != widget.accountId) {
      _state = state;
      _requestedAccountId = widget.accountId;
      unawaited(state.loadMemberProfile(widget.accountId));
    }
  }

  @override
  void didUpdateWidget(covariant MemberProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountId != widget.accountId && _state != null) {
      _requestedAccountId = widget.accountId;
      unawaited(_state!.loadMemberProfile(widget.accountId));
    }
  }

  Future<void> _toggleFollow(Module2State state) async {
    final member = state.memberProfile;
    if (member == null || _followingAction) return;
    setState(() => _followingAction = true);
    final success = await state.setMemberFollowing(
      accountId: member.accountId,
      follow: !member.isFollowing,
    );
    if (!mounted) return;
    setState(() => _followingAction = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage ?? 'Follow status could not be updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state ?? Module2Scope.of(context).state;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final profile = state.memberProfileAccountId == widget.accountId
            ? state.memberProfile
            : null;
        if (state.isLoadingMemberProfile && profile == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (profile == null) {
          return Module2PageBody(
            child: Module2EmptyPanel(
              icon: Icons.person_off_outlined,
              title: 'Profile unavailable',
              message: state.errorMessage ??
                  'This member is unavailable or their profile is not visible to your account.',
              actionLabel: 'Retry',
              onAction: () => unawaited(state.loadMemberProfile(widget.accountId)),
            ),
          );
        }

        return Module2PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.heroBannerGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Column(
                  children: [
                    SakhiAvatar(
                      imageAsset: profile.profilePhotoRef?.startsWith('https://') == true ? profile.profilePhotoRef! : '',
                      size: 98,
                      fallbackLabel: profile.displayName,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      profile.displayName,
                      textAlign: TextAlign.center,
                      style: AppTypography.heroTitle.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 7),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, color: AppColors.verifiedGreenText, size: 16),
                        SizedBox(width: 5),
                        Text('Verified Sakhi member', style: AppTypography.subtitle),
                      ],
                    ),
                    const SizedBox(height: 13),
                    SizedBox(
                      width: double.infinity,
                      child: profile.isFollowing
                          ? OutlinedButton.icon(
                              onPressed: _followingAction ? null : () => _toggleFollow(state),
                              icon: const Icon(Icons.person_remove_alt_1_rounded),
                              label: Text(_followingAction ? 'Updating…' : 'Following · Unfollow'),
                            )
                          : FilledButton.icon(
                              onPressed: _followingAction ? null : () => _toggleFollow(state),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(_followingAction ? 'Updating…' : 'Follow'),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ProfileCount(value: profile.postsCount, label: 'Posts'),
                  _ProfileCount(value: profile.followersCount, label: 'Followers'),
                  _ProfileCount(value: profile.followingCount, label: 'Following'),
                ],
              ),
              const SizedBox(height: 15),
              const SakhiSectionHeader(title: 'About'),
              const SizedBox(height: 7),
              Text(
                (profile.bio ?? '').trim().isEmpty
                    ? 'This member has not added a bio.'
                    : profile.bio!,
                style: AppTypography.bodyRegular.copyWith(color: AppColors.textPrimary),
              ),
              if ((profile.locationCity ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.primaryPurple, size: 17),
                    const SizedBox(width: 4),
                    Text(profile.locationCity!, style: AppTypography.subtitle),
                  ],
                ),
              ],
              const SizedBox(height: 15),
              const SakhiSectionHeader(title: 'Interests'),
              const SizedBox(height: 7),
              if (profile.interests.isEmpty)
                const Text('No interests have been added yet.', style: AppTypography.subtitle)
              else
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: profile.interests.map((interest) => SakhiChip(label: interest)).toList(),
                ),
              const SizedBox(height: 14),
              const Text(
                'Only profile information allowed by this member’s current privacy settings is displayed. Phone number, date of birth and private contact details are not shared here.',
                style: AppTypography.subtitle,
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(state.errorMessage!, style: const TextStyle(color: AppColors.sosRed, fontSize: 12)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProfileCount extends StatelessWidget {
  const _ProfileCount({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value.toString(), style: AppTypography.cardTitle.copyWith(fontSize: 18)),
        const SizedBox(height: 3),
        Text(label, style: AppTypography.subtitle),
      ],
    ),
  );
}
