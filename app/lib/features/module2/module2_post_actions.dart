import 'package:flutter/material.dart';

import '../../core/constants/mock_data.dart';
import '../complaints/screens/discreet_complaint_hub_screen.dart';

/// Shared moderation/ownership actions for posts across Community, Explore,
/// and the signed-in member's Profile. Visibility and ownership are confirmed
/// by the authenticated server; the client menu is only a convenience layer.
Future<void> showModule2PostActions(
  BuildContext context,
  FeedPostModel post,
) async {
  if (post.id.isEmpty) return;

  final result = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          if (post.isOwnPost)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text('Delete this post'),
              onTap: () => Navigator.pop(sheetContext, 'delete'),
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report this post'),
              onTap: () => Navigator.pop(sheetContext, 'report'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_moon_rounded),
              title: const Text('File Discreet / Anonymous Complaint'),
              onTap: () => Navigator.pop(sheetContext, 'discreet_complaint'),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: const Text('Block this member'),
              onTap: () => Navigator.pop(sheetContext, 'block'),
            ),
          ],
        ],
      ),
    ),
  );
  if (!context.mounted || result == null) return;

  final state = SakhiPrototypeState.instance;
  if (result == 'delete') {
    if (!post.isOwnPost) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text(
          'The post will be removed from feeds and saved lists. Its visible comments will be scrubbed as part of the deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep post'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete post'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    final success = await state.deletePost(post);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (state.backend?.actionMessage ?? 'Post deleted.')
              : (state.backend?.errorMessage ?? 'Post could not be deleted.'),
        ),
      ),
    );
    return;
  }

  if (result == 'discreet_complaint') {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DiscreetComplaintHubScreen(
          initialLinkedPostId: post.id,
          initialLinkedProfileHandle: post.authorUsername,
        ),
      ),
    );
    return;
  }
  if (post.isOwnPost || post.authorAccountId.isEmpty) return;
  if (result == 'report') {
    final success = await state.reportMember(
      accountId: post.authorAccountId,
      postId: post.id,
      reason: 'UNSAFE_CONTENT',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (state.backend?.actionMessage ?? 'Report submitted for review.')
              : (state.backend?.errorMessage ?? 'Report could not be submitted.'),
        ),
      ),
    );
    return;
  }

  if (result == 'block') {
    final members = state.backend?.discoveredMembers
            .where((member) => member.accountId == post.authorAccountId)
            .toList() ??
        [];
    final success = await state.backend?.blockMemberByAccountId(
          post.authorAccountId,
          displayName: members.isNotEmpty ? members.first.displayName : null,
        ) ??
        false;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (state.backend?.actionMessage ?? 'Member blocked.')
              : (state.backend?.errorMessage ?? 'Member could not be blocked.'),
        ),
      ),
    );
  }
}
