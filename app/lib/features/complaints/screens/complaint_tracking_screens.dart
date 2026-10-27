import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/backend_api_client.dart';
import '../models/complaint_models.dart';
import '../services/complaint_controller.dart';
import 'discreet_complaint_hub_screen.dart';

/// Screens 23 through 32 — Discreet Complaint Tracking Lookup (Passkey-Protected),
/// Read-Only 7-Stage Status Timeline (SRS 7.5), Two-Way Encrypted Reply Modal (Modal 27),
/// Appeal Modal (Modal 32), and DPDP Immediate Evidence Media Purge (SRS 13.14).
class ComplaintTrackingLookupScreen extends StatefulWidget {
  const ComplaintTrackingLookupScreen({
    super.key,
    this.initialReferenceNumber,
    this.initialPasskey,
    this.initialPreloadedComplaint,
  });

  final String? initialReferenceNumber;
  final String? initialPasskey;
  final DiscreetComplaintModel? initialPreloadedComplaint;

  @override
  State<ComplaintTrackingLookupScreen> createState() =>
      _ComplaintTrackingLookupScreenState();
}

class _ComplaintTrackingLookupScreenState
    extends State<ComplaintTrackingLookupScreen> {
  final SakhiComplaintController _controller =
      SakhiComplaintController.instance;
  late final TextEditingController _referenceCtrl;
  late final TextEditingController _passkeyCtrl;

  DiscreetComplaintModel? _activeCase;
  String? _lookupError;
  bool _isLookingUp = false;

  @override
  void initState() {
    super.initState();
    final ref =
        widget.initialReferenceNumber ??
        widget.initialPreloadedComplaint?.referenceNumber ??
        '';
    final pass =
        widget.initialPasskey ??
        widget.initialPreloadedComplaint?.passkey ??
        (ref.isNotEmpty ? (_controller.passkeyForReference(ref) ?? '') : '');

    _referenceCtrl = TextEditingController(text: ref);
    _passkeyCtrl = TextEditingController(text: pass);
    _activeCase = widget.initialPreloadedComplaint;

    if (_activeCase == null && ref.isNotEmpty && pass.isNotEmpty) {
      unawaited(_lookupCaseOnServer());
    }
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _passkeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupCaseOnServer() async {
    final query = _referenceCtrl.text.trim();
    final pass = _passkeyCtrl.text.trim();
    setState(() {
      _lookupError = null;
      _isLookingUp = true;
    });
    try {
      final found = await _controller.lookupComplaintOnServer(
        referenceOrSerial: query,
        passkey: pass,
      );
      if (!mounted) return;
      setState(() {
        _activeCase = found;
        if (found.passkey.isNotEmpty && _passkeyCtrl.text.trim().isEmpty) {
          _passkeyCtrl.text = found.passkey;
        }
      });
    } on BackendApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _activeCase = null;
        _lookupError = err.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _activeCase = null;
        _lookupError =
            'Could not reach the Sakhi backend server to look up this reference number.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLookingUp = false);
      }
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
    String? modalError;
    bool sending = false;

    final updated = await showModalBottomSheet<DiscreetComplaintModel>(
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
                  style: AppTypography.editorialSection.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Respond to the Senior Safety Reviewer using your passkey without revealing your identity.',
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('m5-two-way-reply-input'),
                  controller: replyCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: 'Your Encrypted Reply to Safety Reviewer *',
                    hintText:
                        'Provide the requested clarification or additional context safely...',
                    errorText: modalError,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: sending
                            ? null
                            : () => Navigator.of(ctx).pop(),
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
                        onPressed: sending
                            ? null
                            : () async {
                                final text = replyCtrl.text.trim();
                                if (text.length < 2) {
                                  setModalState(
                                    () => modalError =
                                        'Please enter a reply message.',
                                  );
                                  return;
                                }
                                setModalState(() {
                                  sending = true;
                                  modalError = null;
                                });
                                try {
                                  final res = await _controller
                                      .sendComplainantReply(
                                        referenceNumber: item.referenceNumber,
                                        passkey: _passkeyCtrl.text
                                            .trim()
                                            .isNotEmpty
                                            ? _passkeyCtrl.text.trim()
                                            : item.passkey,
                                        messageBody: text,
                                      );
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop(res);
                                  }
                                } on BackendApiException catch (err) {
                                  setModalState(() {
                                    sending = false;
                                    modalError = err.message;
                                  });
                                } catch (_) {
                                  setModalState(() {
                                    sending = false;
                                    modalError =
                                        'Failed to send reply to server.';
                                  });
                                }
                              },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          sending ? 'Sending...' : 'Send Encrypted Reply',
                        ),
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

    replyCtrl.dispose();
    if (updated != null && mounted) {
      setState(() => _activeCase = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Encrypted reply confirmed and saved by server.'),
        ),
      );
    }
  }

  /// Modal 32 — Submit Case Appeal / Request Re-Open Modal
  Future<void> _openAppealModal(DiscreetComplaintModel item) async {
    final appealCtrl = TextEditingController();
    String? modalError;
    bool sending = false;

    final updated = await showDialog<DiscreetComplaintModel>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF9FC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Appeal Decision & Request Independent Re-Open',
            style: AppTypography.editorialSection.copyWith(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your appeal is routed to an independent Senior Escalation Reviewer (#EL-01):',
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('m5-appeal-reason-input'),
                  controller: appealCtrl,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText:
                        'Why should this complaint be re-opened? (min 10 chars) *',
                    hintText:
                        'Explain new evidence, escalating threats, or policy context...',
                    errorText: modalError,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('m5-submit-appeal-confirm-button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              onPressed: sending
                  ? null
                  : () async {
                      final reason = appealCtrl.text.trim();
                      if (reason.length < 10) {
                        setModalState(
                          () => modalError =
                              'Please enter at least 10 characters.',
                        );
                        return;
                      }
                      setModalState(() {
                        sending = true;
                        modalError = null;
                      });
                      try {
                        final res = await _controller.submitCaseAppeal(
                          referenceNumber: item.referenceNumber,
                          passkey: _passkeyCtrl.text.trim().isNotEmpty
                              ? _passkeyCtrl.text.trim()
                              : item.passkey,
                          appealReason: reason,
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop(res);
                        }
                      } on BackendApiException catch (err) {
                        setModalState(() {
                          sending = false;
                          modalError = err.message;
                        });
                      } catch (_) {
                        setModalState(() {
                          sending = false;
                          modalError = 'Failed to submit appeal to server.';
                        });
                      }
                    },
              icon: const Icon(Icons.gavel_rounded, size: 16),
              label: Text(sending ? 'Submitting...' : 'Submit Appeal'),
            ),
          ],
        ),
      ),
    );

    appealCtrl.dispose();
    if (updated != null && mounted) {
      setState(() => _activeCase = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Appeal confirmed by server! Case escalated to Senior Escalation Lead (#EL-01).',
          ),
        ),
      );
    }
  }

  Future<void> _handlePurgeEvidence(DiscreetComplaintModel item) async {
    setState(() => _lookupError = null);
    try {
      final updated = await _controller.purgeEvidenceVaultMedia(
        referenceNumber: item.referenceNumber,
        passkey: _passkeyCtrl.text.trim().isNotEmpty
            ? _passkeyCtrl.text.trim()
            : item.passkey,
      );
      if (!mounted) return;
      setState(() => _activeCase = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All uploaded evidence media purged on server (DPDP Right-to-Erasure).',
          ),
        ),
      );
    } on BackendApiException catch (err) {
      if (!mounted) return;
      setState(() => _lookupError = err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final item = _activeCase;

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8FB),
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                              style: AppTypography.editorialSection.copyWith(
                                fontSize: 20,
                              ),
                            ),
                            const Text(
                              'SRS 7.5 • Passkey-Protected Reference Lookup',
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

                  // Screen 23 — Reference Number + Passkey Lookup Card
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
                        TextField(
                          key: const Key('m5-tracker-reference-input'),
                          controller: _referenceCtrl,
                          decoration: const InputDecoration(
                            labelText:
                                'Reference # (#SKH-ANON-2026-...) or Disguised Quote Serial *',
                            prefixIcon: Icon(
                              Icons.confirmation_number_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('m5-tracker-passkey-input'),
                                controller: _passkeyCtrl,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Check-In Passkey (e.g. LOTUS-123-SAFE) *',
                                  prefixIcon: Icon(Icons.key_rounded),
                                ),
                                onSubmitted: (_) => _lookupCaseOnServer(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              key: const Key('m5-tracker-lookup-button'),
                              onPressed: _isLookingUp
                                  ? null
                                  : _lookupCaseOnServer,
                              icon: _isLookingUp
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.search_rounded, size: 18),
                              label: Text(_isLookingUp ? '...' : 'Lookup'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_lookupError != null)
                    Container(
                      key: const Key('m5-tracker-error-banner'),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE8EC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF3B4C0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.sosRed,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _lookupError!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF8C1D35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (item == null && !_isLookingUp)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.lock_clock_rounded,
                            size: 36,
                            color: AppColors.primaryPurple,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Enter Your Server-Issued Reference Number & Passkey',
                            textAlign: TextAlign.center,
                            style: AppTypography.cardTitle,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'For your privacy, Sakhi never displays pre-populated complaints without a valid Reference Number and Check-In Passkey.',
                            textAlign: TextAlign.center,
                            style: AppTypography.subtitle,
                          ),
                        ],
                      ),
                    ),

                  if (item != null) ...[
                    // Read-Only 7-Stage SRS 7.5 Status Timeline
                    const Text(
                      'Official SRS Section 7.5 Status Timeline (Server-Verified):',
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
                          final isCurrent = item.status == st;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Container(
                              key: Key('m5-status-stage-chip-${st.code}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrent ? st.badgeText : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isCurrent
                                      ? st.badgeText
                                      : AppColors.borderSubtle,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCurrent) ...[
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    st.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isCurrent
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      color: isCurrent
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
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
                          color: item.status.badgeText.withValues(alpha: 0.35),
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
                                  color: item.status.badgeBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.status.label.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: item.status.badgeText,
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
                                style: AppTypography.technicalToken,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            item.referenceNumber,
                            style: AppTypography.referenceToken.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Category: ${item.categoryTitle} • Assigned: ${item.assignedReviewerName}',
                            style: AppTypography.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: item.status.badgeBg.withValues(
                                alpha: 0.55,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              item.publicResolutionNote ?? item.status.summary,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: item.status.badgeText,
                              ),
                            ),
                          ),

                          if (item.status ==
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

                          if (item.status ==
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
                                        'Moderator Rejection Reason',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF8C1D40),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.rejectionReasonDetail ??
                                        'Closed with reason. You may submit an Appeal below.',
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
                                icon: const Icon(
                                  Icons.gavel_rounded,
                                  size: 16,
                                ),
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
                                  onPressed: () => _handlePurgeEvidence(item),
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

                    Text(
                      'Encrypted Two-Way Case Messages (${item.complainantMessages.length})',
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Private internal reviewer notes are strictly separated on the backend and never exposed here.',
                      style: AppTypography.subtitle,
                    ),
                    const SizedBox(height: 8),
                    if (item.complainantMessages.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: const Text(
                          'No messages exchanged yet. Use "Send Follow-Up Message" above to add context at any time.',
                          style: AppTypography.subtitle,
                        ),
                      )
                    else
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
