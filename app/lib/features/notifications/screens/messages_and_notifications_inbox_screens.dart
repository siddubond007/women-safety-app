import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/mock_data.dart';
import '../../../core/navigation/app_route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_avatar.dart';
import '../../../core/widgets/sakhi_card.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_wellness_illustrations.dart';
import '../../../core/widgets/sakhi_remote_media_image.dart';

/// Module 8 (SRS Section 10.2): Sakhi Persistent Notifications Inbox Screen
class SakhiNotificationsInboxScreen extends StatefulWidget {
  const SakhiNotificationsInboxScreen({super.key});

  @override
  State<SakhiNotificationsInboxScreen> createState() =>
      _SakhiNotificationsInboxScreenState();
}

class _SakhiNotificationsInboxScreenState
    extends State<SakhiNotificationsInboxScreen> {
  final SakhiPrototypeState _state = SakhiPrototypeState.instance;
  String _selectedCategory = 'ALL';
  bool _unreadOnly = false;
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _discreetModeEnabled = true;
  int _unreadCount = 0;
  List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];

  static const List<(String, String)> _categories = [
    ('ALL', 'All'),
    ('DIRECT_MESSAGE', 'Messages'),
    ('PERIOD_REMINDER', 'Wellness & Cycle'),
    ('BUSINESS_ENQUIRY', 'Businesses'),
    ('VERIFICATION_RESULT', 'Verification'),
    ('EMERGENCY_CONTACT_ALERT', 'Safety'),
    ('COMMUNITY_ANNOUNCEMENT', 'Community'),
  ];

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  Future<void> _loadInbox() async {
    setState(() => _isLoading = true);
    final res = await _state.fetchNotificationsInbox(
      category: _selectedCategory,
      unreadOnly: _unreadOnly,
    );
    if (!mounted) return;
    final rawList = res['notifications'] ?? res['items'];
    setState(() {
      _notifications = rawList is List
          ? rawList
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      _unreadCount = (res['unreadCount'] as num?)?.toInt() ?? 0;
      _discreetModeEnabled = res['discreetModeEnabled'] != false;
      _loadFailed = res['loadFailed'] == true;
      _isLoading = false;
    });
  }

  Future<void> _markAllRead() async {
    await _state.markAllNotificationsRead();
    await _loadInbox();
    if (!mounted) return;
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'All notifications marked as read.',
    );
  }

  Future<void> _markOneRead(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isNotEmpty) {
      await _state.markNotificationRead(id);
    }
    await _loadInbox();
  }

  Future<void> _deleteOne(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    if (id.isEmpty) return;
    await _state.deleteNotification(id);
    await _loadInbox();
    if (!mounted) return;
    SakhiDialogs.showPrototypeSnackbar(context, 'Notification removed.');
  }

  void _openDeepLink(Map<String, dynamic> item) {
    unawaited(_markOneRead(item));
    final link = (item['deepLink'] ?? '').toString();
    if (link.startsWith('/messages')) {
      Navigator.of(context).pushNamed(sakhiMessagesInboxRoute);
    } else if (link.contains('menstrual-cycle-tracker')) {
      Navigator.of(context).pushNamed(sakhiMenstrualCycleTrackerRoute);
    }
  }

  IconData _iconForCategory(String category) {
    switch (category.toUpperCase()) {
      case 'DIRECT_MESSAGE':
        return Icons.chat_bubble_rounded;
      case 'PERIOD_REMINDER':
      case 'WELLNESS_REMINDER':
        return Icons.calendar_month_rounded;
      case 'BUSINESS_ENQUIRY':
        return Icons.storefront_rounded;
      case 'VERIFICATION_RESULT':
        return Icons.verified_user_rounded;
      case 'EMERGENCY_CONTACT_ALERT':
      case 'SOS_UPDATE':
        return Icons.shield_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          _unreadCount > 0
              ? 'Notifications ($_unreadCount unread)'
              : 'Notifications Inbox',
        ),
        actions: [
          IconButton(
            tooltip: _unreadOnly ? 'Show all' : 'Show unread only',
            onPressed: () {
              setState(() => _unreadOnly = !_unreadOnly);
              _loadInbox();
            },
            icon: Icon(
              _unreadOnly
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              color: AppColors.primaryPurple,
            ),
          ),
          TextButton.icon(
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('Read All'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_discreetModeEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFFFDF2F8),
              child: const Row(
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 16,
                    color: Color(0xFF9D174D),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Discreet Privacy Mode Active: Period & support alerts use neutral lock-screen wording.',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9D174D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: _categories.map((cat) {
                final (code, label) = cat;
                final selected = _selectedCategory == code;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: selected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    selected: selected,
                    selectedColor: AppColors.primaryPurple,
                    backgroundColor: Colors.white,
                    onSelected: (_) {
                      setState(() => _selectedCategory = code);
                      _loadInbox();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 36,
                            color: AppColors.primaryPurple,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load notifications',
                            style: AppTypography.subtitle,
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _loadInbox,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _notifications.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SakhiGentleWomanIllustration(
                            pose: SakhiWomanPose.greetingWave,
                            size: 88,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Your Notification Inbox is Clear',
                            style: AppTypography.sectionTitle,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _unreadOnly
                                ? 'You have no unread notifications in this category.'
                                : 'New messages, business enquiries, safety updates, and discreet wellness reminders will appear here.',
                            textAlign: TextAlign.center,
                            style: AppTypography.subtitle,
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadInbox,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _notifications[index];
                        final isRead = item['isRead'] == true;
                        final cat = (item['category'] ?? '').toString();
                        return SakhiCard(
                          onTap: () => _openDeepLink(item),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: isRead
                                      ? AppColors.pastelLavender
                                      : const Color(0xFFFFD6E7),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _iconForCategory(cat),
                                  color: isRead
                                      ? AppColors.primaryPurple
                                      : const Color(0xFFD63E85),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            (item['title'] ?? 'Sakhi Update')
                                                .toString(),
                                            style: AppTypography.cardTitle
                                                .copyWith(
                                                  fontWeight: isRead
                                                      ? FontWeight.w700
                                                      : FontWeight.w900,
                                                ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFD63E85),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      (item['body'] ?? '').toString(),
                                      style: AppTypography.bodyRegular,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          (item['timestamp'] ?? 'Just now')
                                              .toString(),
                                          style: AppTypography.caption,
                                        ),
                                        const Spacer(),
                                        if (!isRead)
                                          TextButton(
                                            onPressed: () => _markOneRead(item),
                                            child: const Text('Mark Read'),
                                          ),
                                        IconButton(
                                          tooltip: 'Remove notification',
                                          onPressed: () => _deleteOne(item),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Module 8 (SRS Section 10.1): Sakhi Direct Messages & Message Requests Inbox Screen
class SakhiMessagesInboxScreen extends StatefulWidget {
  const SakhiMessagesInboxScreen({super.key});

  @override
  State<SakhiMessagesInboxScreen> createState() =>
      _SakhiMessagesInboxScreenState();
}

class _SakhiMessagesInboxScreenState extends State<SakhiMessagesInboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final SakhiPrototypeState _state = SakhiPrototypeState.instance;
  bool _isLoading = true;
  bool _loadFailed = false;
  List<Map<String, dynamic>> _conversations = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _requests = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadConversations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    final res = await _state.fetchMessageConversations();
    if (!mounted) return;
    final rawConvs = res['conversations'];
    final rawReqs = res['requests'];
    setState(() {
      _conversations = rawConvs is List
          ? rawConvs
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      _requests = rawReqs is List
          ? rawReqs
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : <Map<String, dynamic>>[];
      _loadFailed = res['loadFailed'] == true;
      _isLoading = false;
    });
  }

  Future<void> _handleRequestAction(
    Map<String, dynamic> reqItem,
    String action,
  ) async {
    final peerId =
        (reqItem['peerAccountId'] ??
                reqItem['peerId'] ??
                reqItem['peerUsername'] ??
                '')
            .toString();
    if (peerId.isEmpty) return;
    await _state.respondToMessageRequest(peerId, action);
    await _loadConversations();
    if (!mounted) return;
    SakhiDialogs.showPrototypeSnackbar(
      context,
      action == 'ACCEPT'
          ? 'Message request accepted.'
          : action == 'BLOCK'
          ? 'Member blocked and request removed.'
          : 'Message request declined.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Direct Messages'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryPurple,
          indicatorColor: const Color(0xFFD63E85),
          tabs: [
            Tab(text: 'Chats (${_conversations.length})'),
            Tab(text: 'Requests (${_requests.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      size: 36,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load your conversations',
                      style: AppTypography.subtitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _loadConversations,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildConversationsList(_conversations, isRequestTab: false),
                _buildConversationsList(_requests, isRequestTab: true),
              ],
            ),
    );
  }

  Widget _buildConversationsList(
    List<Map<String, dynamic>> items, {
    required bool isRequestTab,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SakhiGentleWomanIllustration(
                pose: SakhiWomanPose.greetingWave,
                size: 84,
              ),
              const SizedBox(height: 12),
              Text(
                isRequestTab
                    ? 'No Pending Message Requests'
                    : 'No Active Conversations Yet',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 4),
              Text(
                isRequestTab
                    ? 'Messages from restricted or non-followed members are held here until you accept, decline, or block.'
                    : 'Connect with verified Sakhi members or women-owned businesses from Explore and Community.',
                textAlign: TextAlign.center,
                style: AppTypography.subtitle,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final conv = items[index];
          final peerId =
              (conv['peerAccountId'] ??
                      conv['peerId'] ??
                      conv['peerUsername'] ??
                      '')
                  .toString();
          final peerName = (conv['peerName'] ?? 'Sakhi Member').toString();
          final peerUsername = (conv['peerUsername'] ?? '@member').toString();
          final peerAvatar = (conv['peerAvatar'] ?? '').toString();
          final unreadCount = (conv['unreadCount'] as num?)?.toInt() ?? 0;
          final lastMsg = conv['lastMessage'] is Map
              ? Map<String, dynamic>.from(conv['lastMessage'] as Map)
              : const <String, dynamic>{};

          return SakhiCard(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SakhiDirectConversationScreen(
                    peerId: peerId,
                    peerName: peerName,
                    peerUsername: peerUsername,
                    peerAvatar: peerAvatar,
                  ),
                ),
              );
              _loadConversations();
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SakhiAvatar(
                      imageAsset: peerAvatar,
                      fallbackLabel: peerName,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(peerName, style: AppTypography.cardTitle),
                          Text(peerUsername, style: AppTypography.caption),
                          const SizedBox(height: 4),
                          Text(
                            (lastMsg['body'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyRegular.copyWith(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD63E85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                if (isRequestTab) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                          ),
                          onPressed: () =>
                              _handleRequestAction(conv, 'ACCEPT'),
                          child: const Text('Accept'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              _handleRequestAction(conv, 'DECLINE'),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _handleRequestAction(conv, 'BLOCK'),
                        child: const Text(
                          'Block',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Direct 1:1 Member / Business Conversation Screen (Polished Section 7.1)
class SakhiDirectConversationScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final String peerUsername;
  final String? peerAvatar;

  const SakhiDirectConversationScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.peerUsername,
    this.peerAvatar,
  });

  @override
  State<SakhiDirectConversationScreen> createState() =>
      _SakhiDirectConversationScreenState();
}

class _SakhiDirectConversationScreenState
    extends State<SakhiDirectConversationScreen> {
  final SakhiPrototypeState _state = SakhiPrototypeState.instance;
  final TextEditingController _inputController = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;
  bool _loadFailed = false;
  bool _isPeerBlocked = false;
  List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      await _state.markDirectMessagesRead(widget.peerId);
    } catch (_) {}

    List<Map<String, dynamic>>? items;
    try {
      items = await _state.fetchDirectMessages(widget.peerId);
    } catch (_) {
      items = null;
    }
    if (!mounted) return;
    setState(() {
      _loadFailed = items == null;
      final failedOptimistic = _messages
          .where((m) => m['deliveryState'] == 'FAILED')
          .toList();
      _messages = <Map<String, dynamic>>[
        ...(items ?? <Map<String, dynamic>>[]),
        ...failedOptimistic,
      ];
      _isLoading = false;
    });
  }

  Future<void> _sendMessage({
    String? mediaUploadId,
    String? attachmentType,
    String? retryBody,
    String? retryClientId,
  }) async {
    if (_isPeerBlocked) return;
    final text = (retryBody ?? _inputController.text).trim();
    final hasAttachment = mediaUploadId != null && mediaUploadId.isNotEmpty;
    if ((text.isEmpty && !hasAttachment) || _isSending) return;

    final clientMsgId = retryClientId ??
        'cmsg_${DateTime.now().microsecondsSinceEpoch}_${widget.peerId.hashCode}';

    if (retryBody == null) {
      _inputController.clear();
    }

    setState(() {
      _isSending = true;
      _messages.removeWhere((m) => m['clientMessageId'] == clientMsgId);
      _messages.add(<String, dynamic>{
        'id': clientMsgId,
        'clientMessageId': clientMsgId,
        'body': text,
        'isOwnMessage': true,
        'timestamp': 'Sending…',
        'dateLabel': 'Today',
        'deliveryState': 'SENDING',
      });
    });

    Map<String, dynamic>? sent;
    try {
      sent = await _state.sendDirectMessage(
        recipientId: widget.peerId,
        recipientHandle: widget.peerUsername,
        recipientName: widget.peerName,
        message: text,
        mediaUploadId: mediaUploadId,
        attachmentType: attachmentType,
        clientMessageId: clientMsgId,
      );
    } catch (_) {
      sent = null;
    }

    if (!mounted) return;
    setState(() => _isSending = false);
    if (sent != null) {
      await _loadThread();
    } else {
      setState(() {
        final idx = _messages.indexWhere(
          (m) => m['clientMessageId'] == clientMsgId,
        );
        if (idx >= 0) {
          _messages[idx] = <String, dynamic>{
            ..._messages[idx],
            'timestamp': 'Failed • Tap to retry',
            'deliveryState': 'FAILED',
          };
        }
      });
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'Message could not be sent. Tap Retry on the message bubble.',
      );
    }
  }

  Future<void> _confirmBlockPeer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${widget.peerName}?'),
        content: Text(
          '${widget.peerName} (${widget.peerUsername}) will no longer be able to send you direct messages, view your profile, or interact with your posts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.sosRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block Member'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _state.respondToMessageRequest(widget.peerId, 'BLOCK');
    if (!mounted) return;
    setState(() => _isPeerBlocked = true);
    SakhiDialogs.showPrototypeSnackbar(
      context,
      '${widget.peerName} has been blocked.',
    );
  }

  Future<void> _reportConversationDialog() async {
    String selectedReason = 'Harassment or Unwanted Contact';
    final detailsCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          title: Text('Report ${widget.peerName}'),
          content: RadioGroup<String>(
            groupValue: selectedReason,
            onChanged: (value) {
              if (value != null) {
                setDialogState(() => selectedReason = value);
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select a reason for reporting this conversation to Sakhi Safety Moderation:',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 8),
                for (final reason in const [
                  'Harassment or Unwanted Contact',
                  'Spam, Scam or Solicitations',
                  'Impersonation or Fake Profile',
                  'Safety Threat or Abuse',
                ])
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(reason, style: const TextStyle(fontSize: 12.5)),
                    value: reason,
                  ),
                const SizedBox(height: 6),
                TextField(
                  controller: detailsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional context (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !mounted) return;
    SakhiDialogs.showPrototypeSnackbar(
      context,
      'Report submitted ($selectedReason). Our moderation team will review it promptly.',
    );
  }

  Future<void> _pickAndSendImage() async {
    if (_isSending || _isPeerBlocked) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked == null || !mounted) return;

      final extension = picked.name.toLowerCase().split('.').last;
      const mimeByExtension = <String, String>{
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
      };
      const allowedMimeTypes = <String>{
        'image/jpeg',
        'image/png',
        'image/webp',
      };
      final pickedMimeType = picked.mimeType?.toLowerCase();
      final contentType = pickedMimeType != null &&
              allowedMimeTypes.contains(pickedMimeType)
          ? pickedMimeType
          : mimeByExtension[extension];
      if (contentType == null) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Choose a JPG, PNG or WebP image.',
        );
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'The selected image is empty. Choose another image.',
        );
        return;
      }
      if (bytes.length > 15 * 1024 * 1024) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'Images must be 15 MB or smaller.',
        );
        return;
      }

      setState(() => _isSending = true);
      Map<String, String>? uploaded;
      try {
        uploaded = await _state.uploadMediaFile(
          purpose: 'direct_message',
          fileName: picked.name,
          fileBytes: bytes,
          contentType: contentType,
          categorySlug: 'direct-message',
        );
      } finally {
        if (mounted) setState(() => _isSending = false);
      }
      if (!mounted) return;

      final uploadId = uploaded?['uploadId'];
      if (uploadId == null || uploadId.isEmpty) {
        SakhiDialogs.showPrototypeSnackbar(
          context,
          'The photo could not be uploaded. Please try again.',
        );
        return;
      }
      await _sendMessage(
        mediaUploadId: uploadId,
        attachmentType: contentType,
      );
    } catch (_) {
      if (!mounted) return;
      if (_isSending) setState(() => _isSending = false);
      SakhiDialogs.showPrototypeSnackbar(
        context,
        'The photo could not be selected or sent. Please try again.',
      );
    }
  }

  String _dateGroupForMessage(Map<String, dynamic> msg) {
    final explicit = (msg['dateLabel'] ?? '').toString();
    if (explicit.isNotEmpty) return explicit;
    final rawTs = (msg['createdAt'] ?? msg['timestamp'] ?? '').toString();
    if (rawTs.length >= 10 && rawTs.contains('-')) {
      return rawTs.substring(0, 10);
    }
    return 'Today';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            SakhiAvatar(
              imageAsset: widget.peerAvatar ?? '',
              fallbackLabel: widget.peerName,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.cardTitle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 15,
                        color: AppColors.primaryPurple,
                      ),
                    ],
                  ),
                  Text(
                    '${widget.peerUsername} • Verified Sakhi Member',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Safety & Conversation Options',
            icon: const Icon(
              Icons.shield_outlined,
              color: AppColors.primaryPurple,
            ),
            onSelected: (value) {
              if (value == 'REPORT') {
                _reportConversationDialog();
              } else if (value == 'BLOCK') {
                _confirmBlockPeer();
              } else if (value == 'REFRESH') {
                _loadThread();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'REPORT',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined, color: AppColors.primaryPurple),
                  title: Text('Report Conversation'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'BLOCK',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.block_rounded, color: AppColors.sosRed),
                  title: Text('Block Member'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'REFRESH',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.refresh_rounded),
                  title: Text('Refresh Messages'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Privacy-safe header notice
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: const Color(0xFFF3E8FF),
            child: const Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: AppColors.primaryPurple,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Private member chat • Phone numbers & personal health data are never shared.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isPeerBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFFFEE2E2),
              child: Text(
                'You have blocked ${widget.peerName}. Messaging is disabled in this conversation.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF991B1B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off_rounded,
                            size: 36,
                            color: AppColors.primaryPurple,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to load this conversation',
                            style: AppTypography.subtitle,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check your internet connection and try again.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: _loadThread,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SakhiAvatar(
                            imageAsset: widget.peerAvatar ?? '',
                            fallbackLabel: widget.peerName,
                            size: 64,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Say hello to ${widget.peerName}!',
                            style: AppTypography.sectionTitle,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your messages are visible only to you and the recipient. Use the shield menu above to block or report anytime.',
                            textAlign: TextAlign.center,
                            style: AppTypography.subtitle,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isOwn = msg['isOwnMessage'] == true;
                      final attachmentUrl =
                          (msg['attachmentUrl'] ?? '').toString();
                      final deliveryState =
                          (msg['deliveryState'] ?? 'SENT').toString();
                      final currentGroup = _dateGroupForMessage(msg);
                      final prevGroup = index > 0
                          ? _dateGroupForMessage(_messages[index - 1])
                          : null;
                      final showDateSeparator =
                          index == 0 || currentGroup != prevGroup;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateSeparator)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.borderSubtle,
                                    ),
                                  ),
                                  child: Text(
                                    currentGroup,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Align(
                            alignment: isOwn
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              constraints: const BoxConstraints(maxWidth: 290),
                              decoration: BoxDecoration(
                                color: deliveryState == 'FAILED'
                                    ? const Color(0xFFFEE2E2)
                                    : isOwn
                                    ? AppColors.primaryPurple
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isOwn ? 18 : 4),
                                  bottomRight: Radius.circular(isOwn ? 4 : 18),
                                ),
                                border: isOwn
                                    ? null
                                    : Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (attachmentUrl.isNotEmpty) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SakhiRemoteMediaImage(
                                        source: attachmentUrl,
                                        width: 220,
                                        height: 180,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    (msg['body'] ?? '').toString(),
                                    style: TextStyle(
                                      color: deliveryState == 'FAILED'
                                          ? const Color(0xFF991B1B)
                                          : isOwn
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontSize: 13.5,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        (msg['timestamp'] ?? '').toString(),
                                        style: TextStyle(
                                          color: deliveryState == 'FAILED'
                                              ? const Color(0xFF991B1B)
                                              : isOwn
                                              ? Colors.white70
                                              : AppColors.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                      if (isOwn) ...[
                                        const SizedBox(width: 4),
                                        Icon(
                                          deliveryState == 'SENDING'
                                              ? Icons.schedule_rounded
                                              : deliveryState == 'FAILED'
                                              ? Icons.error_outline_rounded
                                              : Icons.done_all_rounded,
                                          size: 13,
                                          color: deliveryState == 'FAILED'
                                              ? const Color(0xFF991B1B)
                                              : Colors.white70,
                                        ),
                                      ],
                                      if (deliveryState == 'FAILED') ...[
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => _sendMessage(
                                            retryBody: (msg['body'] ?? '').toString(),
                                            retryClientId: (msg['clientMessageId'] ?? '').toString(),
                                          ),
                                          child: const Text(
                                            'Retry',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              decoration: TextDecoration.underline,
                                              color: Color(0xFF991B1B),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach a photo',
                    onPressed: (_isSending || _isPeerBlocked)
                        ? null
                        : _pickAndSendImage,
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      enabled: !_isPeerBlocked,
                      decoration: InputDecoration(
                        hintText: _isPeerBlocked
                            ? 'Messaging disabled'
                            : 'Write a respectful message…',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    onPressed: (_isSending || _isPeerBlocked)
                        ? null
                        : _sendMessage,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
