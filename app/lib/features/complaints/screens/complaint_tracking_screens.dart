import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/complaint_models.dart';
import '../services/complaint_controller.dart';
import 'discreet_complaint_hub_screen.dart';

/// Screens 23 through 32 — Discreet Complaint Tracking Lookup, All 7 SRS 7.5
/// Status Views, Two-Way Encrypted Reply Modal (Modal 27), Appeal Modal (Modal 32),
/// and Immediate User Evidence Purge (SRS 13.14).
class ComplaintTrackingLookupScreen extends StatefulWidget {
  const ComplaintTrackingLookupScreen({super.key, this.initialReferenceNumber});

  final String? initialReferenceNumber;

  @override
  State<ComplaintTrackingLookupScreen> createState() =>
      _ComplaintTrackingLookupScreenState();
}

class _ComplaintTrackingLookupScreenState
    extends State<ComplaintTrackingLookupScreen> {
  final SakhiComplaintController _controller =
      SakhiComplaintController.instance;
  late final TextEditingController _referenceCtrl;
  DiscreetComplaintModel? _activeCase;
  ComplaintStatus? _previewStatusOverride;

  @override
  void initState() {
    super.initState();
    final initialRef =
        widget.initialReferenceNumber ??
        _controller.complaints.first.referenceNumber;
    _referenceCtrl = TextEditingController(text: initialRef);
    _activeCase = _controller.lookupByReferenceOrSerial(initialRef);
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    super.dispose();
  }

  void _lookupCase([String? explicitRef]) {
    final query = explicitRef ?? _referenceCtrl.text.trim();
    if (explicitRef != null) {
      _referenceCtrl.text = explicitRef;
    }
    final found = _controller.lookupByReferenceOrSerial(query);
    setState(() {
      _activeCase = found;
      _previewStatusOverride = null;
    });
    if (found == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No matching Reference Number or Wellness Quote Serial found.',
          ),
        ),
      );
    }
  }

  void _triggerQuickExit() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const QuickExitWellnessCamouflageScreen(),
      ),
    );
  }

  /// Modal 27 — Two-Way Encrypted Anonymous / Confidential Reply Modal
  Future<void> _openTwoWayReplyModal(DiscreetComplaintModel item) async {
    final replyCtrl = TextEditingController();
    var attachScreenshot = false;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFFFF9FC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.viewInsetsOf(ctx).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encrypted Two-Way Reply (${item.referenceNumber})',
                  style: AppTypography.sectionTitle.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Respond to the Senior Safety Reviewer without revealing your identity. Any new attachment is automatically scrubbed of EXIF metadata.',
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('m5-two-way-reply-input'),
                  controller: replyCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Your Encrypted Reply to Safety Reviewer *',
                    hintText: 'Provide the requested clarification or additional context safely...',
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: attachScreenshot,
                  title: const Text(
                    'Attach additional EXIF-scrubbed screenshot',
                    style: AppTypography.bodyMedium,
                  ),
                  onChanged: (v) =>
                      setModalState(() => attachScreenshot = v ?? false),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('m5-send-two-way-reply-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Send Encrypted Reply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (submitted == true && mounted) {
      final text = replyCtrl.text.trim().isEmpty
          ? 'Here is the additional context requested by the safety reviewer.'
          : replyCtrl.text.trim();
      final extraFiles = attachScreenshot
          ? <SanitizedEvidenceFileModel>[
              _controller.scrubAndCreateEvidence(
                originalFileName: 'FollowUp_Clarification_Screen.png',
                mimeType: 'image/png',
                sizeBytes: 298400,
              ),
            ]
          : const <SanitizedEvidenceFileModel>[];
      final updated = await _controller.sendComplainantReply(
        referenceNumber: item.referenceNumber,
        messageBody: text,
        newEvidence: extraFiles,
      );
      if (updated != null && mounted) {
        setState(() {
          _activeCase = updated;
          _previewStatusOverride = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Encrypted reply delivered to Senior Safety Reviewer!',
            ),
          ),
        );
      }
    }
    replyCtrl.dispose();
  }

  /// Modal 32 — Submit Case Appeal / Request Re-Open Modal
  Future<void> _openAppealModal(DiscreetComplaintModel item) async {
    final appealCtrl = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9FC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Appeal Decision & Request Independent Re-Open',
          style: AppTypography.sectionTitle.copyWith(fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your appeal is routed to a different Senior Ombudsperson Reviewer for an independent reassessment:',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('m5-appeal-reason-input'),
                controller: appealCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Why should this complaint be re-opened? *',
                  hintText: 'Explain new evidence, escalating threats, or policy context...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            key: const Key('m5-submit-appeal-confirm-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.gavel_rounded, size: 16),
            label: const Text('Submit Appeal'),
          ),
        ],
      ),
    );

    if (submitted == true && mounted) {
      final reason = appealCtrl.text.trim().isEmpty
          ? 'Requesting independent senior review with additional threat context.'
          : appealCtrl.text.trim();
      final updated = await _controller.submitCaseAppeal(
        referenceNumber: item.referenceNumber,
        appealReason: reason,
      );
      if (updated != null && mounted) {
        setState(() {
          _activeCase = updated;
          _previewStatusOverride = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Appeal submitted! Case re-opened and assigned to Ombudsperson Panel.',
            ),
          ),
        );
      }
    }
    appealCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final item = _activeCase != null
            ? (_controller.lookupByReferenceOrSerial(
                    _activeCase!.referenceNumber,
                  ) ??
                  _activeCase)
            : null;
        final displayedStatus =
            _previewStatusOverride ?? item?.status ?? ComplaintStatus.submitted;

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8FB),
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Track Complaint Status',
                              style: AppTypography.sectionTitle.copyWith(
                                fontSize: 20,
                              ),
                            ),
                            const Text(
                              'SRS 7.5 • Encrypted Reference # & 7-Stage Tracker',
                              style: AppTypography.subtitle,
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2B6F56),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _triggerQuickExit,
                        icon: const Icon(Icons.spa_rounded, size: 15),
                        label: const Text('Quick Exit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Screen 23 — Reference Number & Disguised Quote Card Lookup Box
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('m5-tracker-reference-input'),
                                controller: _referenceCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Reference # (#SKH-ANON-...) or Quote Serial',
                                  prefixIcon: Icon(
                                    Icons.confirmation_number_outlined,
                                  ),
                                ),
                                onSubmitted: _lookupCase,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              key: const Key('m5-tracker-lookup-button'),
                              onPressed: () => _lookupCase(),
                              child: const Text('Lookup'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Quick Switcher across seeded cases
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _controller.complaints.map((c) {
                              final selected =
                                  item?.referenceNumber == c.referenceNumber;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(
                                    '${c.referenceNumber} (${c.status.label})',
                                  ),
                                  selected: selected,
                                  selectedColor: AppColors.primaryPurple,
                                  labelStyle: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                  onSelected: (_) =>
                                      _lookupCase(c.referenceNumber),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (item != null) ...[
                    // Interactive 7-Stage Status Preview Switcher (Lets user/tester inspect all 7 SRS 7.5 states live!)
                    const Text(
                      'Interactive SRS 7.5 Status Stage Inspector (Tap any of the 7 stages):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ComplaintStatus.values.map((st) {
                          final active = displayedStatus == st;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              key: Key('m5-status-stage-chip-${st.code}'),
                              label: Text(st.label),
                              selected: active,
                              selectedColor: st.badgeText,
                              labelStyle: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                              onSelected: (_) =>
                                  setState(() => _previewStatusOverride = st),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Main Case Status Card (Screens 24–31)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: displayedStatus.badgeText.withValues(
                            alpha: 0.35,
                          ),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: displayedStatus.badgeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  displayedStatus.label.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: displayedStatus.badgeText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.pastelLavender,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.reportingMode.badgeLabel,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                item.severityPriority,
                                style: AppTypography.monoToken,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            item.referenceNumber,
                            style: AppTypography.monoToken.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Category: ${_controller.categoryByCode(item.categoryCode).label} • Assigned: ${item.assignedReviewerName}',
                            style: AppTypography.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: displayedStatus.badgeBg.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              displayedStatus.summary,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: displayedStatus.badgeText,
                              ),
                            ),
                          ),

                          // Status-Specific Callouts (Screens 26, 28, 29, 30, 31)
                          if (displayedStatus ==
                              ComplaintStatus.additionalInfoRequired) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const Key(
                                  'm5-open-two-way-reply-modal-button',
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFA86408),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _openTwoWayReplyModal(item),
                                icon: const Icon(Icons.reply_rounded),
                                label: const Text(
                                  'Reply to Safety Reviewer Anonymously',
                                ),
                              ),
                            ),
                          ],

                          if (displayedStatus == ComplaintStatus.actionTaken &&
                              item.publicResolutionNote != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F5EE),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Resolution Summary: ${item.publicResolutionNote}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A5A3E),
                                ),
                              ),
                            ),
                          ],

                          if (displayedStatus ==
                              ComplaintStatus.rejectedWithReason) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE8EF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.rejectionReasonTitle ??
                                        'Transparent Moderator Explanation',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF8C1D40),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.rejectionReasonDetail ?? 'Insufficient actionable safety violation evidence in initial submission. You may submit an Appeal with additional screenshots.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6E1833),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  FilledButton.icon(
                                    key: const Key(
                                      'm5-open-appeal-modal-button',
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF8C1D40),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _openAppealModal(item),
                                    icon: const Icon(
                                      Icons.gavel_rounded,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Submit Appeal / Request Case Re-Open',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Immediate Evidence Vault Purge & Two-Way Reply Actions
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _openTwoWayReplyModal(item),
                                icon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 16,
                                ),
                                label: const Text('Send Follow-Up Message'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openAppealModal(item),
                                icon: const Icon(Icons.gavel_rounded, size: 16),
                                label: const Text('Appeal / Escalate'),
                              ),
                              if (!item.mediaPurgedByUser &&
                                  item.evidenceFiles.isNotEmpty)
                                OutlinedButton.icon(
                                  key: const Key(
                                    'm5-purge-evidence-media-button',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.sosRed,
                                  ),
                                  onPressed: () async {
                                    final updated = await _controller
                                        .purgeEvidenceVaultMedia(
                                          referenceNumber: item.referenceNumber,
                                        );
                                    if (updated != null && context.mounted) {
                                      setState(() => _activeCase = updated);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'All uploaded evidence media purged from storage (DPDP Right-to-Erasure).',
                                              ),
                                            ),
                                          );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.delete_forever_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Purge My Evidence Now'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Encrypted Two-Way Message Thread (Never shows private internal admin notes!)
                    Text(
                      'Encrypted Two-Way Case Messages (${item.complainantMessages.length})',
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Note: Private internal reviewer notes are strictly separated and never exposed here.',
                      style: AppTypography.subtitle,
                    ),
                    const SizedBox(height: 8),
                    ...item.complainantMessages.map(
                      (msg) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: msg.isFromReviewer
                              ? const Color(0xFFF6ECFA)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    msg.senderBadge,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: msg.isFromReviewer
                                          ? AppColors.primaryPurple
                                          : const Color(0xFF1F6E50),
                                    ),
                                  ),
                                ),
                                Text(
                                  msg.createdAtLabel,
                                  style: AppTypography.caption,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(msg.body, style: AppTypography.bodyRegular),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
