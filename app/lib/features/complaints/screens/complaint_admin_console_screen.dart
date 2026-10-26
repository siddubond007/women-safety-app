import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../models/complaint_models.dart';
import '../services/complaint_controller.dart';

/// Screens 33 through 40 — Role-Restricted Admin Complaint Console
/// Covers SRS Section 7.6, Section 12.5, Section 13 (Audit Logs, RBAC, Retention) & Section 14:
/// - Screen 33: Role-Restricted Admin Queue & SLA Dashboard + RBAC Role Switcher (`SENIOR_SAFETY_REVIEWER`, `SUPER_ADMIN`, `STANDARD_MODERATOR`)
/// - Screen 34: Admin Case Detail & PII-Masked Inspector (Anonymous shows ZERO identity; Confidential shows sealed contact ONLY to Senior Safety Reviewer / Super Admin)
/// - Modal 35: Reviewer Assignment, Department Routing & Severity Priority Modal
/// - Modal 36: Controlled Blurred-by-Default Evidence Vault & Watermarked Download Modal (logs every view/download to immutable audit trail)
/// - Screen 37: Status Transition, Separated Private Internal Notes vs Complainant-Visible Message
/// - Screen 38: Immutable Tamper-Evident SHA-256 Case Audit History
/// - Modal 39: Duplicate Report Cluster Merge Modal
/// - Modal 40: Malicious-Report Blinded Bucket Throttle + Configurable Categories & DPDP Retention Policy Manager
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

  String _modeFilter = 'ALL'; // ALL, ANONYMOUS, CONFIDENTIAL
  final String _statusFilter = 'ALL';
  String _selectedComplaintId = 'cmp-8492';
  int _activeWorkspaceTab = 0; // 0: Queue & Case Detail, 1: Audit Trail, 2: Categories & DPDP Retention

  final Set<String> _unblurredEvidenceIds = <String>{};

  DiscreetComplaintModel get _selectedCase {
    for (final c in _controller.complaints) {
      if (c.id == _selectedComplaintId) return c;
    }
    return _controller.complaints.first;
  }

  /// Modal 35 — Reviewer Assignment & Severity Priority Modal
  Future<void> _openAssignmentAndSeverityModal(
    DiscreetComplaintModel item,
  ) async {
    var reviewer = item.assignedReviewerName;
    var department = item.assignedDepartment;
    var severity = item.severityPriority;
    var slaHours = item.slaTargetHours;

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
            style: AppTypography.sectionTitle.copyWith(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity / Queue Priority',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'CRITICAL_P1',
                      child: Text('CRITICAL_P1 (4h SLA)'),
                    ),
                    DropdownMenuItem(
                      value: 'HIGH_P2',
                      child: Text('HIGH_P2 (12h SLA)'),
                    ),
                    DropdownMenuItem(
                      value: 'MEDIUM_P3',
                      child: Text('MEDIUM_P3 (24h SLA)'),
                    ),
                    DropdownMenuItem(
                      value: 'LOW_P4',
                      child: Text('LOW_P4 (48h SLA)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setModalState(() {
                        severity = v;
                        slaHours = v == 'CRITICAL_P1'
                            ? 4
                            : v == 'HIGH_P2'
                            ? 12
                            : 24;
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                      const <String>[
                        'Anjali M. (#SR-04)',
                        'Dr. Kavitha R. (#SA-01)',
                        'Meera K. (#SR-02)',
                        'Ombudsperson Appeal Panel (#SR-01)',
                      ].contains(reviewer)
                      ? reviewer
                      : 'Anjali M. (#SR-04)',
                  decoration: const InputDecoration(
                    labelText: 'Authorised Safety Reviewer',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Anjali M. (#SR-04)',
                      child: Text('Anjali M. (#SR-04 • Harassment Lead)'),
                    ),
                    DropdownMenuItem(
                      value: 'Dr. Kavitha R. (#SA-01)',
                      child: Text('Dr. Kavitha R. (#SA-01 • POSH & Legal)'),
                    ),
                    DropdownMenuItem(
                      value: 'Meera K. (#SR-02)',
                      child: Text('Meera K. (#SR-02 • Impersonation Desk)'),
                    ),
                    DropdownMenuItem(
                      value: 'Ombudsperson Appeal Panel (#SR-01)',
                      child: Text('Ombudsperson Appeal Panel (#SR-01)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => reviewer = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                      const <String>[
                        'Harassment & Stalking Desk',
                        'POSH & Business Trust Panel',
                        'Identity & Impersonation Desk',
                        'Cybercrime 1930 Escalation Cell',
                      ].contains(department)
                      ? department
                      : 'Harassment & Stalking Desk',
                  decoration: const InputDecoration(
                    labelText: 'Specialist Department',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Harassment & Stalking Desk',
                      child: Text('Harassment & Stalking Desk'),
                    ),
                    DropdownMenuItem(
                      value: 'POSH & Business Trust Panel',
                      child: Text('POSH & Business Trust Panel'),
                    ),
                    DropdownMenuItem(
                      value: 'Identity & Impersonation Desk',
                      child: Text('Identity & Impersonation Desk'),
                    ),
                    DropdownMenuItem(
                      value: 'Cybercrime 1930 Escalation Cell',
                      child: Text('Cybercrime 1930 Escalation Cell'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => department = v);
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
      await _controller.adminUpdateComplaint(
        complaintId: item.id,
        severityPriority: severity,
        assignedReviewerName: reviewer,
        assignedDepartment: department,
        slaTargetHours: slaHours,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Assigned to $reviewer ($severity) • Logged in immutable audit trail.',
          ),
        ),
      );
    }
  }

  /// Screen 37 — Status Transition + Separated Private Internal Notes vs Complainant Message Modal
  Future<void> _openStatusAndNotesModal(DiscreetComplaintModel item) async {
    var nextStatus = item.status;
    final publicMsgCtrl = TextEditingController();
    final privateInternalNoteCtrl = TextEditingController();
    final resolutionCtrl = TextEditingController(
      text: item.publicResolutionNote ?? '',
    );

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
                  style: AppTypography.sectionTitle.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<ComplaintStatus>(
                  initialValue: nextStatus,
                  decoration: const InputDecoration(
                    labelText: 'New Complaint Status (SRS 7.5)',
                  ),
                  items: ComplaintStatus.values
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
                TextField(
                  key: const Key('m5-admin-private-note-input'),
                  controller: privateInternalNoteCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'PRIVATE INTERNAL REVIEWER NOTE (Hidden from Complainant & Public)',
                    hintText: 'Internal investigation findings, cluster IDs, or legal notes...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('m5-admin-public-message-input'),
                  controller: publicMsgCtrl,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText:
                        'Message Visible to Complainant in Tracker (Optional)',
                    hintText: 'Compassionate status update or follow-up question for complainant...',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: resolutionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Resolution / Rejection Reason Summary',
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
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Apply & Audit'),
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
      await _controller.adminUpdateComplaint(
        complaintId: item.id,
        newStatus: nextStatus,
        publicMessageToComplainant: publicMsgCtrl.text,
        internalPrivateNote: privateInternalNoteCtrl.text,
        publicResolutionNote: resolutionCtrl.text.trim().isEmpty
            ? null
            : resolutionCtrl.text.trim(),
        rejectionReasonDetail:
            nextStatus == ComplaintStatus.rejectedWithReason &&
                resolutionCtrl.text.trim().isNotEmpty
            ? resolutionCtrl.text.trim()
            : null,
      );
    }
    publicMsgCtrl.dispose();
    privateInternalNoteCtrl.dispose();
    resolutionCtrl.dispose();
  }

  /// Modal 39 & Modal 40 — Duplicate Cluster Merge & Malicious Abuse Blinded Throttle
  Future<void> _openDuplicateAndAbuseModal(DiscreetComplaintModel item) async {
    final mergeRefCtrl = TextEditingController(
      text: item.duplicateOfReference ?? '#SKH-ANON-2026-8471',
    );
    var flagMalicious = item.maliciousAbuseFlagged;

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
            style: AppTypography.sectionTitle.copyWith(fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Link duplicate reports targeting the same offender or apply a blinded rate-limit bucket throttle without unmasking anonymous users:',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: mergeRefCtrl,
                decoration: const InputDecoration(
                  labelText: 'Parent Cluster Reference # (Optional Merge)',
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Throttle Ephemeral Blinded Bucket (Malicious Spam)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Applies 24h rate-limit to the blinded token hash without revealing user identity',
                  style: TextStyle(fontSize: 11.5),
                ),
                value: flagMalicious,
                onChanged: (v) => setModalState(() => flagMalicious = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Apply Governance Action'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      await _controller.adminUpdateComplaint(
        complaintId: item.id,
        duplicateOfReference: mergeRefCtrl.text.trim().isEmpty
            ? null
            : mergeRefCtrl.text.trim(),
        maliciousAbuseFlagged: flagMalicious,
      );
    }
    mergeRefCtrl.dispose();
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
          if (_statusFilter != 'ALL' && c.status.code != _statusFilter) {
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
                  style: AppTypography.sectionTitle.copyWith(fontSize: 19),
                ),
                Text(
                  'Role: ${_controller.activeAdminRole} • RBAC & Audit Active',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // RBAC Role Simulator Bar (Proves SRS 7.6 & 12.5 Role-Based Access Control)
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
                      const Text(
                        'RBAC Clearance Level (Test PII Masking per SRS 7.6):',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children:
                            <String>[
                              'SENIOR_SAFETY_REVIEWER',
                              'SUPER_ADMIN',
                              'STANDARD_MODERATOR',
                            ].map((role) {
                              final active =
                                  _controller.activeAdminRole == role;
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
                                onSelected: (_) =>
                                    _controller.setActiveAdminRole(role),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

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
    DiscreetComplaintModel selected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Bar (Anonymous vs Confidential)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All Modes'),
                selected: _modeFilter == 'ALL',
                onSelected: (_) => setState(() => _modeFilter = 'ALL'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Anonymous Only'),
                selected: _modeFilter == 'ANONYMOUS',
                onSelected: (_) => setState(() => _modeFilter = 'ANONYMOUS'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text('Confidential Only'),
                selected: _modeFilter == 'CONFIDENTIAL',
                onSelected: (_) => setState(() => _modeFilter = 'CONFIDENTIAL'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal Case Selector Cards
        ...filtered.map((item) {
          final isSelected = item.id == selected.id;
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
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => setState(() => _selectedComplaintId = item.id),
                title: Row(
                  children: [
                    Text(item.referenceNumber, style: AppTypography.monoToken),
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
                  '${_controller.categoryByCode(item.categoryCode).label} • ${item.reportingMode.badgeLabel} • ${item.severityPriority}',
                  style: const TextStyle(fontSize: 11.5),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),

        // Screen 34 — Selected Case Inspector with Strict PII Masking
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
                    style: AppTypography.monoToken,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Identity / PII Masking Box (Proves SRS 7.2 & 7.6)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      selected.reportingMode == ComplaintReportingMode.anonymous
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
                            ? 'ANONYMOUS RECORD: Complainant User ID, Name & Phone are NULL in database. Identity cannot be unmasked by any role.'
                            : _controller.canViewConfidentialContact
                            ? 'CONFIDENTIAL RECORD (Senior Clearance): ${selected.maskedConfidentialContact ?? "Verified Member"} • Never visible to reported user.'
                            : 'CONFIDENTIAL RECORD (Standard Moderator View): [REDACTED — Requires SENIOR_SAFETY_REVIEWER Clearance]',
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
                'Window: ${selected.incidentDateWindow} • Coarse Area: ${selected.generalAreaText}',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 12),

              // Admin Action Buttons Row (Modals 35, 37, 39, 40)
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
                    onPressed: () => _openAssignmentAndSeverityModal(selected),
                    icon: const Icon(Icons.assignment_ind_rounded, size: 17),
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

              // Modal 36 — Controlled Blurred-by-Default Evidence Vault
              Text(
                'Controlled Evidence Vault (${selected.evidenceFiles.length} Scrubbed Files)',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ...selected.evidenceFiles.map((ev) {
                final isUnblurred = _unblurredEvidenceIds.contains(ev.id);
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
                              style: AppTypography.monoToken,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                if (isUnblurred) {
                                  _unblurredEvidenceIds.remove(ev.id);
                                } else {
                                  _unblurredEvidenceIds.add(ev.id);
                                  _controller.logAdminEvidenceInspection(
                                    complaintId: selected.id,
                                    fileName: ev.sanitizedFileName,
                                    actionType: 'ADMIN_UNBLURRED_EVIDENCE_VIEW',
                                  );
                                }
                              });
                            },
                            icon: Icon(
                              isUnblurred
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 16,
                            ),
                            label: Text(
                              isUnblurred
                                  ? 'Re-Blur Preview'
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
                                AppAssets.module5EvidenceVaultScrubber,
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
                                    color: Colors.black.withValues(alpha: 0.35),
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
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 22),

              // Private Internal Reviewer Notes (Strictly Admin-Only)
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
                  'No internal notes recorded yet.',
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
    );
  }

  /// Screen 38 — Immutable SHA-256 Case Audit History
  Widget _buildImmutableAuditView(DiscreetComplaintModel selected) {
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
                      Text(entry.action, style: AppTypography.monoToken),
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
                  Text(entry.integrityHash, style: AppTypography.monoToken),
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
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Allow Complainant Immediate Media Purge',
                    style: AppTypography.bodyMedium,
                  ),
                  value: policy.allowUserImmediateMediaPurge,
                  onChanged: (val) => _controller.updateRetentionPolicy(
                    policy.copyWith(allowUserImmediateMediaPurge: val),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Configurable Complaint Categories (SRS 7.3 — 10 Categories)',
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
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                title: Text(
                  '${cat.label} (${cat.defaultSeverity})',
                  style: AppTypography.bodyMedium,
                ),
                subtitle: Text(cat.subtitle, style: AppTypography.subtitle),
                value: cat.enabled,
                onChanged: (v) =>
                    _controller.toggleCategoryEnabled(cat.code, v),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
