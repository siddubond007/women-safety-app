import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/backend_api_client.dart';
import '../models/complaint_models.dart';
import '../services/complaint_controller.dart';

/// Screens 33 through 40 — Role-Restricted Admin Complaint Console
/// Connects directly to `/api/v1/admin-review/complaints*` using the reviewer token.
/// Displays real database records (or an empty queue state when the database has 0 complaints).
class ComplaintAdminConsoleScreen extends StatefulWidget {
  const ComplaintAdminConsoleScreen({super.key});

  @override
  State<ComplaintAdminConsoleScreen> createState() =>
      _ComplaintAdminConsoleScreenState();
}

class _ComplaintAdminConsoleScreenState
    extends State<ComplaintAdminConsoleScreen> {
  final SakhiComplaintController _controller =
      SakhiComplaintController.instance;
  late final TextEditingController _adminTokenCtrl;

  String _modeFilter = 'ALL'; // ALL, ANONYMOUS, CONFIDENTIAL
  String? _selectedComplaintRef;
  int _activeWorkspaceTab =
      0; // 0: Queue & Case Detail, 1: Audit Trail, 2: Categories & DPDP Retention

  final Map<String, String> _unblurredEvidenceWatermarks = <String, String>{};
  String? _consoleNotice;
  String? _consoleError;

  @override
  void initState() {
    super.initState();
    _adminTokenCtrl = TextEditingController(
      text: _controller.adminReviewerToken,
    );
    unawaited(_refreshFromServer());
  }

  @override
  void dispose() {
    _adminTokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshFromServer() async {
    setState(() {
      _consoleError = null;
    });
    _controller.setAdminReviewerToken(_adminTokenCtrl.text);
    try {
      final loaded = await _controller.loadAdminDashboardQueue(
        reportingMode: _modeFilter,
      );
      if (!mounted) return;
      setState(() {
        if (loaded.isNotEmpty &&
            (_selectedComplaintRef == null ||
                !loaded.any(
                  (c) => c.referenceNumber == _selectedComplaintRef,
                ))) {
          _selectedComplaintRef = loaded.first.referenceNumber;
        }
      });
    } on BackendApiException catch (err) {
      if (!mounted) return;
      setState(() => _consoleError = err.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _consoleError =
            'Could not connect to backend Admin Complaint API. Verify server status and reviewer token.';
      });
    }
  }

  DiscreetComplaintModel? get _selectedCase {
    if (_controller.complaints.isEmpty) return null;
    for (final c in _controller.complaints) {
      if (c.referenceNumber == _selectedComplaintRef) return c;
    }
    return _controller.complaints.first;
  }

  /// Modal 35 — Reviewer Assignment & Severity Priority Modal
  Future<void> _openAssignmentAndSeverityModal(
    DiscreetComplaintModel item,
  ) async {
    var reviewerId = 'SR-04';
    var reviewerName = 'Meera Krishnan (#SR-04 • Senior Trust & Safety Officer)';
    var severity = item.severity.isNotEmpty ? item.severity : 'S2_HIGH';
    var priority = item.priority.isNotEmpty ? item.priority : 'P1_URGENT';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF9FC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Assign Reviewer & Priority (${item.referenceNumber})',
            style: AppTypography.editorialSection.copyWith(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      const <String>[
                        'S1_CRITICAL',
                        'S2_HIGH',
                        'S3_MODERATE',
                        'S4_LOW',
                      ].contains(severity)
                      ? severity
                      : 'S2_HIGH',
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(
                      value: 'S1_CRITICAL',
                      child: Text('S1_CRITICAL'),
                    ),
                    DropdownMenuItem(value: 'S2_HIGH', child: Text('S2_HIGH')),
                    DropdownMenuItem(
                      value: 'S3_MODERATE',
                      child: Text('S3_MODERATE'),
                    ),
                    DropdownMenuItem(value: 'S4_LOW', child: Text('S4_LOW')),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => severity = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                      const <String>[
                        'P1_URGENT',
                        'P2_HIGH',
                        'P3_STANDARD',
                        'P4_ROUTINE',
                      ].contains(priority)
                      ? priority
                      : 'P1_URGENT',
                  decoration: const InputDecoration(labelText: 'Queue Priority'),
                  items: const [
                    DropdownMenuItem(
                      value: 'P1_URGENT',
                      child: Text('P1_URGENT (<4h SLA)'),
                    ),
                    DropdownMenuItem(
                      value: 'P2_HIGH',
                      child: Text('P2_HIGH (<12h SLA)'),
                    ),
                    DropdownMenuItem(
                      value: 'P3_STANDARD',
                      child: Text('P3_STANDARD (<24h SLA)'),
                    ),
                    DropdownMenuItem(
                      value: 'P4_ROUTINE',
                      child: Text('P4_ROUTINE (<72h SLA)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => priority = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: reviewerId,
                  decoration: const InputDecoration(
                    labelText: 'Authorised Safety Reviewer',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'SR-04',
                      child: Text('Meera Krishnan (#SR-04 • Senior Officer)'),
                    ),
                    DropdownMenuItem(
                      value: 'EL-01',
                      child: Text('Dr. Kavita Rao (#EL-01 • Escalation Lead)'),
                    ),
                    DropdownMenuItem(
                      value: 'SR-07',
                      child: Text('Anjali Menon (#SR-07 • Safety Reviewer)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() {
                        reviewerId = v;
                        reviewerName = v == 'EL-01'
                            ? 'Dr. Kavita Rao (#EL-01 • Escalation Lead)'
                            : v == 'SR-07'
                            ? 'Anjali Menon (#SR-07 • Safety Reviewer)'
                            : 'Meera Krishnan (#SR-04 • Senior Trust & Safety Officer)';
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _consoleError = null;
        _consoleNotice = null;
      });
      try {
        await _controller.adminAssignAndClassifyOnServer(
          referenceNumber: item.referenceNumber,
          assignedReviewerId: reviewerId,
          assignedReviewerName: reviewerName,
          severity: severity,
          priority: priority,
        );
        if (!mounted) return;
        setState(() {
          _consoleNotice =
              'Assigned ${item.referenceNumber} to $reviewerName ($priority • $severity).';
        });
      } on BackendApiException catch (err) {
        if (!mounted) return;
        setState(() => _consoleError = err.message);
      }
    }
  }

  /// Screen 37 — Status Transition + Separated Private Internal Notes vs Complainant Message Modal
  Future<void> _openStatusAndNotesModal(DiscreetComplaintModel item) async {
    final allowedStatuses = item.status.allowedTransitions;
    var nextStatus = allowedStatuses.first;
    final publicMsgCtrl = TextEditingController();
    final privateInternalNoteCtrl = TextEditingController();
    final rejectionCtrl = TextEditingController(
      text: '#OUTSIDE-SCOPE-OR-UNVERIFIED',
    );
    String? modalError;

    final saved = await showModalBottomSheet<bool>(
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
                  'Update Status & Add Separated Notes (${item.referenceNumber})',
                  style: AppTypography.editorialSection.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ComplaintStatus>(
                  initialValue: nextStatus,
                  decoration: InputDecoration(
                    labelText:
                        'Allowed Next Status (from ${item.status.label})',
                  ),
                  items: allowedStatuses
                      .map(
                        (st) =>
                            DropdownMenuItem(value: st, child: Text(st.label)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => nextStatus = v);
                  },
                ),
                const SizedBox(height: 10),
                if (nextStatus == ComplaintStatus.rejectedWithReason)
                  TextField(
                    controller: rejectionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mandatory Rejection Reason Code *',
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('m5-admin-private-note-input'),
                  controller: privateInternalNoteCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText:
                        'PRIVATE INTERNAL REVIEWER NOTE (Hidden from Complainant & Public)',
                    hintText:
                        'Internal investigation findings, cluster IDs, or legal notes...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('m5-admin-public-message-input'),
                  controller: publicMsgCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText:
                        nextStatus == ComplaintStatus.additionalInfoRequired
                        ? 'Required Follow-Up Question for Complainant *'
                        : 'Message Visible to Complainant in Tracker (Optional)',
                    errorText: modalError,
                  ),
                ),
                const SizedBox(height: 14),
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
                      child: FilledButton(
                        key: const Key('m5-admin-save-status-notes-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                        ),
                        onPressed: () {
                          if (nextStatus ==
                                  ComplaintStatus.additionalInfoRequired &&
                              publicMsgCtrl.text.trim().length < 5) {
                            setModalState(
                              () => modalError =
                                  'Enter a follow-up question for the complainant.',
                            );
                            return;
                          }
                          Navigator.of(ctx).pop(true);
                        },
                        child: const Text('Apply on Server'),
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

    if (saved == true && mounted) {
      setState(() {
        _consoleError = null;
        _consoleNotice = null;
      });
      try {
        if (privateInternalNoteCtrl.text.trim().length >= 3) {
          await _controller.adminAddInternalNoteOnServer(
            referenceNumber: item.referenceNumber,
            noteText: privateInternalNoteCtrl.text.trim(),
          );
        }
        await _controller.adminUpdateStatusOnServer(
          referenceNumber: item.referenceNumber,
          newStatus: nextStatus,
          publicMessageToComplainant: publicMsgCtrl.text.trim(),
          rejectionReasonCode: nextStatus == ComplaintStatus.rejectedWithReason
              ? rejectionCtrl.text.trim()
              : null,
        );
        if (!mounted) return;
        setState(() {
          _consoleNotice =
              'Updated ${item.referenceNumber} status to ${nextStatus.label} on backend.';
        });
      } on BackendApiException catch (err) {
        if (!mounted) return;
        setState(() => _consoleError = err.message);
      }
    }
    publicMsgCtrl.dispose();
    privateInternalNoteCtrl.dispose();
    rejectionCtrl.dispose();
  }

  /// Modal 39 & Modal 40 — Duplicate Cluster Merge & Malicious Abuse Blinded Throttle
  Future<void> _openDuplicateAndAbuseModal(DiscreetComplaintModel item) async {
    final mergeRefCtrl = TextEditingController();
    final reasonCtrl = TextEditingController(
      text: 'Coordinated spam flood from same blinded bucket',
    );
    var flagMalicious = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF9FC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Duplicate Cluster Merge & Anti-Abuse Guard',
            style: AppTypography.editorialSection.copyWith(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: mergeRefCtrl,
                  decoration: const InputDecoration(
                    labelText:
                        'Duplicate Reference # to Merge Into This Case (Optional)',
                    hintText: '#SKH-ANON-2026-...',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Throttle Blinded Bucket (Malicious Spam)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Applies 72h rate-limit to the blinded token hash without unmasking user identity',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  value: flagMalicious,
                  onChanged: (v) => setModalState(() => flagMalicious = v),
                ),
                if (flagMalicious)
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Audit Justification Reason *',
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
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Execute on Server'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() {
        _consoleError = null;
        _consoleNotice = null;
      });
      try {
        if (mergeRefCtrl.text.trim().isNotEmpty) {
          await _controller.adminMergeDuplicatesOnServer(
            primaryReferenceNumber: item.referenceNumber,
            duplicateReferenceNumbers: <String>[mergeRefCtrl.text.trim()],
          );
        }
        if (flagMalicious) {
          await _controller.adminHandleMaliciousOnServer(
            referenceNumber: item.referenceNumber,
            reason: reasonCtrl.text.trim(),
          );
        }
        if (!mounted) return;
        setState(() {
          _consoleNotice = 'Governance action confirmed & audit-logged.';
        });
      } on BackendApiException catch (err) {
        if (!mounted) return;
        setState(() => _consoleError = err.message);
      }
    }
    mergeRefCtrl.dispose();
    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final filtered = _controller.complaints.where((c) {
          if (_modeFilter != 'ALL' && c.reportingMode.code != _modeFilter) {
            return false;
          }
          return true;
        }).toList();

        final selected = _selectedCase;

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFF8FB),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Complaint Console',
                  style: AppTypography.editorialSection.copyWith(fontSize: 19),
                ),
                Text(
                  'Role: ${_controller.activeAdminRole} • Server RBAC Active',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh from Server',
                onPressed: _controller.isSyncing ? null : _refreshFromServer,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reviewer Token & RBAC Clearance Bar
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E4F8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD7B8E8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('m5-admin-token-input'),
                              controller: _adminTokenCtrl,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText:
                                    'Reviewer Token (x-sakhi-admin-token)',
                              ),
                              onSubmitted: (_) => _refreshFromServer(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: _refreshFromServer,
                            child: const Text('Sync Queue'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'RBAC Clearance Level (Enforced on Backend per SRS 7.6):',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: <String>[
                          'SENIOR_REVIEWER',
                          'SUPER_ADMIN',
                          'STANDARD_MODERATOR',
                        ].map((role) {
                          final active = _controller.activeAdminRole == role;
                          return ChoiceChip(
                            key: Key('m5-admin-role-chip-$role'),
                            label: Text(role.replaceAll('_', ' ')),
                            selected: active,
                            selectedColor: AppColors.primaryPurple,
                            labelStyle: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: active
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                            onSelected: (_) {
                              _controller.setActiveAdminRole(role);
                              unawaited(_refreshFromServer());
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                if (_consoleNotice != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F5EE),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _consoleNotice!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F6E50),
                      ),
                    ),
                  ),

                if (_consoleError != null)
                  Container(
                    key: const Key('m5-admin-error-banner'),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE8EC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _consoleError!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8C1D35),
                      ),
                    ),
                  ),

                // Workspace Sub-Navigation Tabs
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        key: const Key('m5-admin-tab-queue'),
                        label: const Text('1. Queue & Case Vault'),
                        selected: _activeWorkspaceTab == 0,
                        onSelected: (_) =>
                            setState(() => _activeWorkspaceTab = 0),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        key: const Key('m5-admin-tab-audit'),
                        label: const Text('2. Immutable Audit Log'),
                        selected: _activeWorkspaceTab == 1,
                        onSelected: (_) =>
                            setState(() => _activeWorkspaceTab = 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        key: const Key('m5-admin-tab-config'),
                        label: const Text('3. Categories & DPDP'),
                        selected: _activeWorkspaceTab == 2,
                        onSelected: (_) =>
                            setState(() => _activeWorkspaceTab = 2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_activeWorkspaceTab == 0)
                  _buildQueueAndCaseDetailView(filtered, selected)
                else if (_activeWorkspaceTab == 1)
                  _buildImmutableAuditView(selected)
                else
                  _buildCategoriesAndRetentionManager(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQueueAndCaseDetailView(
    List<DiscreetComplaintModel> filtered,
    DiscreetComplaintModel? selected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Modes'),
                selected: _modeFilter == 'ALL',
                onSelected: (_) {
                  setState(() => _modeFilter = 'ALL');
                  unawaited(_refreshFromServer());
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Anonymous Only'),
                selected: _modeFilter == 'ANONYMOUS',
                onSelected: (_) {
                  setState(() => _modeFilter = 'ANONYMOUS');
                  unawaited(_refreshFromServer());
                },
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Confidential Only'),
                selected: _modeFilter == 'CONFIDENTIAL',
                onSelected: (_) {
                  setState(() => _modeFilter = 'CONFIDENTIAL');
                  unawaited(_refreshFromServer());
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (filtered.isEmpty)
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
                  Icons.inbox_rounded,
                  size: 36,
                  color: AppColors.primaryPurple,
                ),
                SizedBox(height: 8),
                Text(
                  'No Complaints in Queue (0 Database Records)',
                  style: AppTypography.cardTitle,
                ),
                SizedBox(height: 4),
                Text(
                  'No fabricated complaints are shown when the database is empty. Submit a report from the Discreet Complaint Wizard, then tap Sync Queue.',
                  textAlign: TextAlign.center,
                  style: AppTypography.subtitle,
                ),
              ],
            ),
          )
        else ...[
          ...filtered.map((item) {
            final isSelected = item.referenceNumber == selected?.referenceNumber;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF7ECFC) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryPurple
                      : AppColors.borderSubtle,
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: ListTile(
                onTap: () =>
                    setState(() => _selectedComplaintRef = item.referenceNumber),
                title: Row(
                  children: [
                    Text(
                      item.referenceNumber,
                      style: AppTypography.technicalToken,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: item.status.badgeBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: item.status.badgeText,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '${item.categoryTitle} • ${item.reportingMode.badgeLabel} • ${item.severityPriority}',
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            );
          }),
          const SizedBox(height: 14),

          if (selected != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.primaryPurple, width: 1.4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Case: ${selected.referenceNumber}',
                        style: AppTypography.cardTitle,
                      ),
                      Text(
                        'SLA: ${selected.slaTargetHours}h',
                        style: AppTypography.technicalToken,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          selected.reportingMode ==
                              ComplaintReportingMode.anonymous
                          ? const Color(0xFFE6F5EE)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          color:
                              selected.reportingMode ==
                                  ComplaintReportingMode.anonymous
                              ? const Color(0xFF1F6E50)
                              : const Color(0xFF9C5708),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selected.reportingMode ==
                                    ComplaintReportingMode.anonymous
                                ? 'ANONYMOUS RECORD: Complainant User ID, Name & Phone are NULL in database.'
                                : _controller.canViewConfidentialContact
                                ? 'CONFIDENTIAL RECORD (Senior Clearance): ${selected.maskedConfidentialContact ?? "Protected Vault"} • Hidden from Target.'
                                : 'CONFIDENTIAL RECORD (Standard Moderator View): [REDACTED — Requires Senior Reviewer Clearance]',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(selected.description, style: AppTypography.bodyRegular),
                  const SizedBox(height: 8),
                  Text(
                    'Window: ${selected.incidentDateWindow} • Area: ${selected.generalAreaText}',
                    style: AppTypography.subtitle,
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        key: const Key('m5-admin-update-status-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                        ),
                        onPressed: () => _openStatusAndNotesModal(selected),
                        icon: const Icon(Icons.edit_note_rounded, size: 17),
                        label: const Text('Update Status & Notes'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('m5-admin-assign-reviewer-button'),
                        onPressed: () =>
                            _openAssignmentAndSeverityModal(selected),
                        icon: const Icon(
                          Icons.assignment_ind_rounded,
                          size: 17,
                        ),
                        label: const Text('Assign & Priority'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('m5-admin-merge-abuse-button'),
                        onPressed: () => _openDuplicateAndAbuseModal(selected),
                        icon: const Icon(Icons.merge_type_rounded, size: 17),
                        label: const Text('Merge / Anti-Abuse'),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Text(
                    'Controlled Evidence Vault (${selected.evidenceFiles.length} Scrubbed Files)',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...selected.evidenceFiles.map((ev) {
                    final wm = _unblurredEvidenceWatermarks[ev.id];
                    final isUnblurred = wm != null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBF6FD),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${ev.sanitizedFileName} (${ev.formattedSize})',
                                  style: AppTypography.technicalToken,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: ev.isPurged
                                    ? null
                                    : () async {
                                        if (isUnblurred) {
                                          setState(() {
                                            _unblurredEvidenceWatermarks.remove(
                                              ev.id,
                                            );
                                          });
                                          return;
                                        }
                                        try {
                                          final stamp = await _controller
                                              .adminAccessEvidenceOnServer(
                                                referenceNumber:
                                                    selected.referenceNumber,
                                                evidenceId: ev.id,
                                                action: 'REVEAL_VIEWER',
                                                justificationReason:
                                                    'Safety reviewer verification of complaint attachment',
                                              );
                                          if (!mounted) return;
                                          setState(() {
                                            _unblurredEvidenceWatermarks[ev
                                                    .id] =
                                                stamp;
                                          });
                                        } on BackendApiException catch (err) {
                                          if (!mounted) return;
                                          setState(
                                            () => _consoleError = err.message,
                                          );
                                        }
                                      },
                                icon: Icon(
                                  isUnblurred
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  ev.isPurged
                                      ? 'Purged'
                                      : isUnblurred
                                      ? 'Re-Blur'
                                      : 'Unblur (Audited)',
                                ),
                              ),
                            ],
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  height: 90,
                                  width: double.infinity,
                                  child: Image.asset(
                                    AppAssets.m5EvidenceVaultExif,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (!isUnblurred)
                                  Positioned.fill(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Container(
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'BLURRED BY DEFAULT • TAP UNBLUR TO LOG ACCESS',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    color: Colors.black54,
                                    child: Text(
                                      wm,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 22),

                  Text(
                    'Private Internal Reviewer Notes (${selected.internalNotes.length}) • Hidden from Complainant',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF8C1D40),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (selected.internalNotes.isEmpty)
                    const Text(
                      'No internal notes visible for current role.',
                      style: AppTypography.subtitle,
                    )
                  else
                    ...selected.internalNotes.map(
                      (n) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4F7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF3C6D3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${n.authorLabel} • ${n.createdAtLabel}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF8C1D40),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(n.note, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// Screen 38 — Immutable SHA-256 Case Audit History
  Widget _buildImmutableAuditView(DiscreetComplaintModel? selected) {
    if (selected == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Text(
          'Immutable Case Audit History: Select or sync a complaint in Tab 1 to inspect its SHA-256 audit chain.',
          style: AppTypography.bodyRegular,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Immutable Case Audit History (${selected.referenceNumber})',
            style: AppTypography.cardTitle,
          ),
          const SizedBox(height: 4),
          const Text(
            'Every status change, assignment, evidence unblur, and note is chained with a SHA-256 integrity hash (SRS Section 13.10).',
            style: AppTypography.subtitle,
          ),
          const SizedBox(height: 12),
          ...selected.auditTrail.map(
            (entry) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFBF7FC),
                borderRadius: BorderRadius.circular(14),
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
                          entry.action,
                          style: AppTypography.technicalToken,
                        ),
                      ),
                      Text(entry.timestampLabel, style: AppTypography.caption),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Actor: ${entry.actorBadge}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(entry.detail, style: AppTypography.bodyRegular),
                  const SizedBox(height: 4),
                  Text(entry.integrityHash, style: AppTypography.technicalHash),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Screen 40 — Configurable Categories & DPDP Retention Policy Manager
  Widget _buildCategoriesAndRetentionManager() {
    final policy = _controller.retentionPolicy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DPDP Act 2023 Data Retention & Auto-Purge Policy (SRS 13.14)',
                style: AppTypography.cardTitle,
              ),
              const SizedBox(height: 8),
              Text(
                '• Closed Case Archive Retention: ${policy.closedCaseRetentionDays} days\n'
                '• Rejected Case Retention: ${policy.rejectedCaseRetentionDays} days\n'
                '• Raw Evidence Auto-Purge Window: ${policy.autoPurgeRawMediaAfterDays} days\n'
                '• Ephemeral Blinded Anti-Spam Hash Expiry: ${policy.scrubIpLogsAfterHours} hours',
                style: AppTypography.bodyRegular.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Configurable Complaint Categories (SRS 7.2 — 10 Categories)',
          style: AppTypography.cardTitle,
        ),
        const SizedBox(height: 8),
        ..._controller.categories.map(
          (cat) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: SwitchListTile(
              title: Text(
                '${cat.label} (${cat.defaultPriority} • ${cat.defaultSeverity})',
                style: AppTypography.bodyMedium,
              ),
              subtitle: Text(cat.subtitle, style: AppTypography.subtitle),
              value: cat.enabled,
              onChanged: (v) async {
                try {
                  await _controller.toggleCategoryEnabledOnServer(cat, v);
                } on BackendApiException catch (err) {
                  if (mounted) setState(() => _consoleError = err.message);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
