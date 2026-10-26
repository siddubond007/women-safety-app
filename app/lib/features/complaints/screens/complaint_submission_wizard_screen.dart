import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../models/complaint_models.dart';
import '../services/complaint_controller.dart';
import 'complaint_tracking_screens.dart';
import 'discreet_complaint_hub_screen.dart';

/// Complete 5-Step Discreet & Anonymous Complaint Submission Wizard
/// Covers UI Reference Screens 04 through 21:
/// - Step 1 (Screens 04, 05, Sheet 06): Mode Selection (Anonymous vs Confidential)
/// - Step 2 (Screens 07, 08, Modal 09): Category Grid (10 categories), Other/Business inline fields, Category Safety Guidance Modal
/// - Step 3 (Screens 10, Modal 11, Sheet 12, Modal 13): Incident Description, Real-Time Identity-Reveal Warning & Auto-Redaction, Approximate Date/Time Window Picker, Coarse 5 km General Location Picker
/// - Step 4 (Screens 14, Modal 15, Sheet 16, Modal 17): Evidence Vault Upload, Evidence Safety Guidance, Automatic EXIF Scrubber & Blur Inspection Sheet, Supporting Links & Post/Profile Linker
/// - Step 5 (Screens 18, Dialog 19, Screen 20, Modal 21): Updates Preference & Pre-Submission Review, Final Confirmation Dialog, Anonymous Reference Receipt (`#SKH-ANON-...`), Disguised Wellness Quote Card Backup Modal
class ComplaintSubmissionWizardScreen extends StatefulWidget {
  const ComplaintSubmissionWizardScreen({
    super.key,
    this.initialMode = ComplaintReportingMode.anonymous,
    this.initialCategoryCode,
    this.initialLinkedPostId,
    this.initialLinkedProfileHandle,
    this.initialLinkedBusinessId,
  });

  final ComplaintReportingMode initialMode;
  final String? initialCategoryCode;
  final String? initialLinkedPostId;
  final String? initialLinkedProfileHandle;
  final String? initialLinkedBusinessId;

  @override
  State<ComplaintSubmissionWizardScreen> createState() =>
      _ComplaintSubmissionWizardScreenState();
}

class _ComplaintSubmissionWizardScreenState
    extends State<ComplaintSubmissionWizardScreen> {
  final SakhiComplaintController _controller =
      SakhiComplaintController.instance;

  int _currentStep = 0; // 0..4 for steps 1..5
  late ComplaintReportingMode _reportingMode;
  late String _selectedCategoryCode;
  String _urgencyLevel = 'HIGH';

  final TextEditingController _customCategoryCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _linkedProfileCtrl = TextEditingController();
  final TextEditingController _linkedPostCtrl = TextEditingController();
  final TextEditingController _linkedBusinessCtrl = TextEditingController();

  String _incidentDateWindow = 'Yesterday • Evening (6 PM – 10 PM)';
  String _generalAreaText = 'Indiranagar, Bengaluru (~5 km coarse zone)';
  bool _wantsFollowUp = true;
  String _discreetNotificationMode = 'SILENT_VAULT_ONLY';

  final List<SanitizedEvidenceFileModel> _evidenceFiles =
      <SanitizedEvidenceFileModel>[];
  final List<String> _supportingLinks = <String>[];

  DiscreetComplaintModel? _submittedReceipt;

  @override
  void initState() {
    super.initState();
    _reportingMode = widget.initialMode;
    _selectedCategoryCode =
        widget.initialCategoryCode ?? _controller.enabledCategories.first.code;
    if (widget.initialLinkedProfileHandle != null) {
      _linkedProfileCtrl.text = widget.initialLinkedProfileHandle!;
      _supportingLinks.add(
        'sakhi://profile/${widget.initialLinkedProfileHandle}',
      );
    }
    if (widget.initialLinkedPostId != null) {
      _linkedPostCtrl.text = widget.initialLinkedPostId!;
      _supportingLinks.add('sakhi://post/${widget.initialLinkedPostId}');
    }
    if (widget.initialLinkedBusinessId != null) {
      _linkedBusinessCtrl.text = widget.initialLinkedBusinessId!;
      _supportingLinks.add(
        'sakhi://business/${widget.initialLinkedBusinessId}',
      );
    }
    // Pre-populate sample description so user can test immediately or edit freely
    _descriptionCtrl.text = 'Repeated intimidating messages and unwelcome comments from a suspicious account after I participated in a community safety thread.';
    // Pre-populate 1 scrubbed sample evidence file so user can inspect Sheet 16 immediately
    _evidenceFiles.add(
      _controller.scrubAndCreateEvidence(
        originalFileName: 'Screenshot_Harassment_Chat.png',
        mimeType: 'image/png',
        sizeBytes: 394240,
      ),
    );
  }

  @override
  void dispose() {
    _customCategoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _linkedProfileCtrl.dispose();
    _linkedPostCtrl.dispose();
    _linkedBusinessCtrl.dispose();
    super.dispose();
  }

  void _triggerQuickExit() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const QuickExitWellnessCamouflageScreen(),
      ),
    );
  }

  void _handleBackStep() {
    if (_submittedReceipt != null) {
      Navigator.of(context).pop();
      return;
    }
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleNextStep() async {
    if (_currentStep == 2) {
      // Check for accidental self-identifying PII in description (Modal 11)
      final piiCheck = _controller.analyzeTextForSelfIdentifyingClues(
        _descriptionCtrl.text,
      );
      if (piiCheck.hasPotentialPii &&
          _reportingMode == ComplaintReportingMode.anonymous) {
        final action = await _showPiiWarningModal(piiCheck);
        if (!mounted || action == null) return;
        if (action == 'REDACT') {
          setState(() {
            _descriptionCtrl.text = piiCheck.redactedText;
          });
        }
      }
    }

    if (_currentStep < 4) {
      setState(() => _currentStep++);
      return;
    }

    // Step 5 -> Show Final Confirmation Dialog (Dialog 19)
    final confirmed = await _showFinalSubmissionConfirmDialog();
    if (!mounted || confirmed != true) return;

    final created = await _controller.submitComplaint(
      reportingMode: _reportingMode,
      categoryCode: _selectedCategoryCode,
      customCategoryNote: _customCategoryCtrl.text.trim().isEmpty
          ? null
          : _customCategoryCtrl.text.trim(),
      urgencyLevel: _urgencyLevel,
      description: _descriptionCtrl.text.trim().isEmpty
          ? 'Discreet safety concern reported via Sakhi Module 5.'
          : _descriptionCtrl.text.trim(),
      incidentDateWindow: _incidentDateWindow,
      generalAreaText: _generalAreaText,
      supportingLinks: List<String>.from(_supportingLinks),
      linkedPostId: _linkedPostCtrl.text.trim().isEmpty
          ? null
          : _linkedPostCtrl.text.trim(),
      linkedProfileHandle: _linkedProfileCtrl.text.trim().isEmpty
          ? null
          : _linkedProfileCtrl.text.trim(),
      linkedBusinessId: _linkedBusinessCtrl.text.trim().isEmpty
          ? null
          : _linkedBusinessCtrl.text.trim(),
      wantsFollowUp: _wantsFollowUp,
      discreetNotificationMode: _discreetNotificationMode,
      evidenceFiles: List<SanitizedEvidenceFileModel>.from(_evidenceFiles),
    );

    if (!mounted) return;
    setState(() {
      _submittedReceipt = created;
    });
  }

  /// Modal 11 — Real-Time Identity-Reveal Warning & One-Tap Auto-Redaction Modal
  Future<String?> _showPiiWarningModal(PiiCheckResultModel piiCheck) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9FC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(
              Icons.privacy_tip_rounded,
              color: Color(0xFFB85C00),
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Self-Identifying Info Detected',
                style: AppTypography.sectionTitle.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You selected Anonymous Mode, but your description appears to contain clues that could reveal your identity:',
                style: AppTypography.bodyRegular,
              ),
              const SizedBox(height: 10),
              ...piiCheck.detectedItems.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF2C57C)),
                  ),
                  child: Text(
                    '• ${item.type}: "${item.snippet}" → ${item.replacement}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A4100),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Would you like Sakhi to auto-redact these details before continuing?',
                style: AppTypography.subtitle,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('KEEP'),
            child: const Text('Keep As Written'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
            ),
            onPressed: () => Navigator.of(ctx).pop('REDACT'),
            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
            label: const Text('Auto-Redact My PII'),
          ),
        ],
      ),
    );
  }

  /// Dialog 19 — Final Pre-Submission Confirmation Dialog
  Future<bool?> _showFinalSubmissionConfirmDialog() {
    final cat = _controller.categoryByCode(_selectedCategoryCode);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9FC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(
              Icons.shield_rounded,
              color: AppColors.primaryPurple,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Seal & Submit ${_reportingMode == ComplaintReportingMode.anonymous ? 'Anonymous' : 'Confidential'} Report?',
                style: AppTypography.sectionTitle.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• Mode: ${_reportingMode.title}\n'
              '• Category: ${cat.label}\n'
              '• Evidence Files: ${_evidenceFiles.length} (EXIF & GPS stripped)\n'
              '• Reported Party Visibility: 0% (Never disclosed)',
              style: AppTypography.bodyRegular.copyWith(height: 1.45),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'You will receive a unique Reference Number (#SKH-...) on the next screen to track status and reply safely.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Review Again'),
          ),
          FilledButton.icon(
            key: const Key('m5-dialog-confirm-submit-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: const Text('Confirm & Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submittedReceipt != null) {
      return _buildSubmittedReceiptScreen(_submittedReceipt!);
    }

    const stepTitles = <String>[
      'Step 1 of 5 • Reporting Mode',
      'Step 2 of 5 • Complaint Category',
      'Step 3 of 5 • Incident Details & Privacy Guard',
      'Step 4 of 5 • Evidence Vault & EXIF Scrubber',
      'Step 5 of 5 • Updates & Final Review',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Persistent Top Bar with Back, Step Progress, and Quick Exit
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('m5-wizard-back-button'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: _handleBackStep,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stepTitles[_currentStep],
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: (_currentStep + 1) / 5.0,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFEAD8F2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.primaryPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2B6F56),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    onPressed: _triggerQuickExit,
                    icon: const Icon(Icons.spa_rounded, size: 14),
                    label: const Text(
                      'Quick Exit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Step Selector Pills (Allows jumping directly to any step for easy review)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: List<Widget>.generate(5, (index) {
                  final labels = <String>[
                    '1. Mode',
                    '2. Category',
                    '3. Details',
                    '4. Evidence',
                    '5. Review',
                  ];
                  final active = _currentStep == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key: Key('m5-step-chip-${index + 1}'),
                      label: Text(labels[index]),
                      selected: active,
                      selectedColor: AppColors.primaryPurple,
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : AppColors.textPrimary,
                      ),
                      onSelected: (_) => setState(() => _currentStep = index),
                    ),
                  );
                }),
              ),
            ),

            // Main Step Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                child: switch (_currentStep) {
                  0 => _buildStep1ReportingMode(),
                  1 => _buildStep2CategoryGrid(),
                  2 => _buildStep3IncidentDetails(),
                  3 => _buildStep4EvidenceVault(),
                  _ => _buildStep5PreSubmissionReview(),
                },
              ),
            ),

            // Bottom Navigation Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.borderSubtle)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleBackStep,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        _currentStep == 0 ? 'Back to Hub' : 'Previous Step',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      key: const Key('m5-wizard-primary-next-button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: _handleNextStep,
                      icon: Icon(
                        _currentStep == 4
                            ? Icons.lock_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _currentStep == 4
                            ? 'Submit Discreet Complaint'
                            : 'Continue to Step ${_currentStep + 2}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Screens 04 & 05 — Step 1: Reporting Mode Selection (Anonymous vs Confidential)
  Widget _buildStep1ReportingMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Privacy & Protection Mode',
          style: AppTypography.heroTitle.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 6),
        const Text(
          'Both modes guarantee your identity is NEVER shown to the reported user, business, or public community.',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: 14),

        // Anonymous Mode Option Card (Screen 04)
        _buildModeChoiceTile(
          mode: ComplaintReportingMode.anonymous,
          illustration: AppAssets.module5AnonymousShieldEnvelope,
          highlights: const <String>[
            'Zero account ID, phone number, or profile name stored on complaint record',
            'Assigned a cryptographic Reference Token (#SKH-ANON-...) for two-way updates',
            'Ideal when you want complete detachment from your Sakhi profile',
          ],
        ),
        const SizedBox(height: 12),

        // Confidential Mode Option Card (Screen 05)
        _buildModeChoiceTile(
          mode: ComplaintReportingMode.confidential,
          illustration: AppAssets.module5CompassionateReviewCounselors,
          highlights: const <String>[
            'Completely hidden from the reported member, public feed, and standard moderators',
            'Authorised Senior Female Safety Reviewer can view sealed contact for follow-up',
            'Ideal for workplace POSH guidance, legal escalation, or account recovery',
          ],
        ),
        const SizedBox(height: 14),

        // Button to open Sheet 06 (Anonymity & Technical Logs Transparency)
        OutlinedButton.icon(
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AnonymityTransparencyBottomSheet(),
            );
          },
          icon: const Icon(Icons.info_outline_rounded, size: 18),
          label: const Text(
            'Compare Modes & Technical Log Disclosure (SRS 7.4)',
          ),
        ),
      ],
    );
  }

  Widget _buildModeChoiceTile({
    required ComplaintReportingMode mode,
    required String illustration,
    required List<String> highlights,
  }) {
    final selected = _reportingMode == mode;
    return InkWell(
      key: Key('m5-mode-select-${mode.code.toLowerCase()}'),
      borderRadius: BorderRadius.circular(22),
      onTap: () => setState(() => _reportingMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF8EEFC) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primaryPurple : AppColors.borderSubtle,
            width: selected ? 2.2 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: Image.asset(
                      illustration,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.pastelLavender,
                        child: const Icon(
                          Icons.shield_rounded,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          mode.badgeLabel,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryPurple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(mode.title, style: AppTypography.cardTitle),
                      Text(mode.subtitle, style: AppTypography.subtitle),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? AppColors.primaryPurple
                      : AppColors.textMuted,
                  size: 26,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(mode.description, style: AppTypography.bodyRegular),
            const SizedBox(height: 8),
            ...highlights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: AppColors.primaryPurple,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Screens 07, 08 & Modal 09 — Step 2: Configurable 10-Category Selection Grid
  Widget _buildStep2CategoryGrid() {
    final categories = _controller.enabledCategories;
    final selectedCat = _controller.categoryByCode(_selectedCategoryCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What Kind of Concern Are You Reporting?',
          style: AppTypography.heroTitle.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select one of the 10 SRS 7.3 categories below. Tap the ⓘ icon on any card for POSH / legal safety tips.',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: 14),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.26,
          ),
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = cat.code == _selectedCategoryCode;
            return InkWell(
              key: Key('m5-cat-card-${cat.code}'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() => _selectedCategoryCode = cat.code),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF6E8FC) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryPurple
                        : AppColors.borderSubtle,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      bottom: -10,
                      child: SakhiBotanicalFlower(
                        type: cat.flowerType,
                        width: 48,
                        height: 56,
                        opacity: 0.25,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryPurple
                                    : AppColors.pastelLavender,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                cat.icon,
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primaryPurple,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Category Safety Guidance',
                              icon: const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: AppColors.primaryPurple,
                              ),
                              onPressed: () =>
                                  _showCategorySafetyGuidanceModal(cat),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          cat.shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: Text(
                            cat.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),

        // Screen 08 — Inline Expansion for Selected Category, Custom Note & Urgency Selector
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    color: AppColors.primaryPurple,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Selected: ${selectedCat.label}',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                selectedCat.safetyGuidance,
                style: AppTypography.subtitle.copyWith(height: 1.38),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customCategoryCtrl,
                decoration: InputDecoration(
                  labelText: _selectedCategoryCode == 'OTHER'
                      ? 'Specify custom category details *'
                      : 'Optional sub-category / POSH or business context',
                  hintText:
                      'e.g., Unsolicited messages in Bengaluru Moms Circle',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Urgency Level',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children:
                    <Map<String, String>>[
                      {'code': 'LOW', 'label': 'Standard (24h)'},
                      {'code': 'HIGH', 'label': 'High Priority (12h)'},
                      {'code': 'CRITICAL', 'label': 'Critical Safety (4h SLA)'},
                    ].map((u) {
                      final active = _urgencyLevel == u['code'];
                      return ChoiceChip(
                        label: Text(u['label']!),
                        selected: active,
                        selectedColor: AppColors.primaryPurple,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppColors.textPrimary,
                        ),
                        onSelected: (_) =>
                            setState(() => _urgencyLevel = u['code']!),
                      );
                    }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Modal 09 — Category Safety & POSH Guidance Popup Modal
  void _showCategorySafetyGuidanceModal(ComplaintCategoryInfo cat) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9FC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(cat.icon, color: AppColors.primaryPurple),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${cat.label} • Safety Guidance',
                style: AppTypography.sectionTitle.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cat.subtitle, style: AppTypography.bodyMedium),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EBF9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                cat.safetyGuidance,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.42,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Default Admin Queue Priority: ${cat.defaultSeverity}',
              style: AppTypography.monoToken,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _selectedCategoryCode = cat.code);
              Navigator.of(ctx).pop();
            },
            child: const Text('Select This Category'),
          ),
        ],
      ),
    );
  }

  /// Screens 10, Modal 11, Sheet 12, Modal 13 — Step 3: Incident Description, Date Window & Coarse Location
  Widget _buildStep3IncidentDetails() {
    final piiPreview = _controller.analyzeTextForSelfIdentifyingClues(
      _descriptionCtrl.text,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Describe What Happened Safely',
          style: AppTypography.heroTitle.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 4),
        const Text(
          'Share what happened in your own words. Our live PII Guard watches for accidental self-identifying phone numbers, emails, or door numbers.',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: 14),

        TextField(
          key: const Key('m5-incident-description-input'),
          controller: _descriptionCtrl,
          minLines: 4,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Incident Description *',
            hintText: 'Describe the messages, behaviour, or safety concern without typing your own phone number or flat number...',
          ),
        ),
        const SizedBox(height: 10),

        // Real-Time Identity-Reveal Guard Status Banner (Modal 11 trigger)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: piiPreview.hasPotentialPii
                ? const Color(0xFFFFF3E0)
                : const Color(0xFFE9F7EF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: piiPreview.hasPotentialPii
                  ? const Color(0xFFF0B86E)
                  : const Color(0xFFA9DFBF),
            ),
          ),
          child: Row(
            children: [
              Icon(
                piiPreview.hasPotentialPii
                    ? Icons.warning_amber_rounded
                    : Icons.verified_user_rounded,
                color: piiPreview.hasPotentialPii
                    ? const Color(0xFFB85C00)
                    : const Color(0xFF1E7E48),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  piiPreview.hasPotentialPii
                      ? '${piiPreview.detectedItems.length} self-identifying clue(s) detected in text. Tap "Auto-Redact" to strip your personal info.'
                      : 'Zero self-identifying phone/email/ID patterns detected in your description.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: piiPreview.hasPotentialPii
                        ? const Color(0xFF7D4000)
                        : const Color(0xFF1A5A3E),
                  ),
                ),
              ),
              if (piiPreview.hasPotentialPii)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _descriptionCtrl.text = piiPreview.redactedText;
                    });
                  },
                  child: const Text('Auto-Redact'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Sheet 12 — Approximate Date & Time Window Picker Row
        _PickerSelectionCard(
          key: const Key('m5-open-date-window-sheet'),
          icon: Icons.calendar_today_rounded,
          title: 'Incident Date / Time Window (Optional)',
          valueText: _incidentDateWindow,
          subtitle: 'Approximate window prevents exact timestamp correlation',
          onTap: _openDateWindowSheet,
        ),
        const SizedBox(height: 10),

        // Modal 13 — Coarse 5 km General Area Picker Row (Never Live Home GPS)
        _PickerSelectionCard(
          key: const Key('m5-open-coarse-location-modal'),
          icon: Icons.location_city_rounded,
          title: 'General Location / Neighbourhood (Optional)',
          valueText: _generalAreaText,
          subtitle: 'Coarse ~5 km area only • Never captures exact home GPS',
          onTap: _openCoarseLocationModal,
        ),
      ],
    );
  }

  /// Sheet 12 — Approximate Date & Time Window Picker Bottom Sheet
  Future<void> _openDateWindowSheet() async {
    const presets = <String>[
      'Today • Within the last few hours',
      'Yesterday • Evening (6 PM – 10 PM)',
      'Earlier This Week • Afternoon (12 PM – 5 PM)',
      'Last Week • Ongoing Repeated Incidents',
      'Earlier This Month • Approximate Window',
      'Prefer Not to Share Timestamp',
    ];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFFFFF9FC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Approximate Incident Window',
                style: AppTypography.sectionTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              const Text(
                'Using an approximate window protects your anonymity against timing correlation.',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 12),
              ...presets.map(
                (p) => ListTile(
                  dense: true,
                  leading: Icon(
                    p == _incidentDateWindow
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: AppColors.primaryPurple,
                  ),
                  title: Text(p, style: AppTypography.bodyMedium),
                  onTap: () => Navigator.of(ctx).pop(p),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null && mounted) {
      setState(() => _incidentDateWindow = chosen);
    }
  }

  /// Modal 13 — Coarse 5 km General Location Picker Modal
  Future<void> _openCoarseLocationModal() async {
    final customAreaCtrl = TextEditingController(text: _generalAreaText);
    const coarseZones = <String>[
      'Online / Inside Sakhi App Only (No Physical Location)',
      'Indiranagar, Bengaluru (~5 km coarse zone)',
      'HITEC City, Hyderabad (~5 km coarse zone)',
      'Adyar, Chennai (~5 km coarse zone)',
      'Bandra West, Mumbai (~5 km coarse zone)',
      'Connaught Place, New Delhi (~5 km coarse zone)',
    ];
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9FC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Coarse 5 km Area (Zero Home GPS)',
          style: AppTypography.sectionTitle.copyWith(fontSize: 18),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'For your privacy, Module 5 never records your precise home coordinates. Choose a general city/zone or select "Online Only":',
                style: AppTypography.subtitle,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: customAreaCtrl,
                decoration: const InputDecoration(
                  labelText: 'General neighbourhood or city',
                ),
              ),
              const SizedBox(height: 10),
              ...coarseZones.map(
                (z) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: AppColors.primaryPurple,
                  ),
                  title: Text(z, style: const TextStyle(fontSize: 12.5)),
                  onTap: () => Navigator.of(ctx).pop(z),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(customAreaCtrl.text.trim()),
            child: const Text('Save General Area'),
          ),
        ],
      ),
    );
    customAreaCtrl.dispose();
    if (chosen != null && chosen.isNotEmpty && mounted) {
      setState(() => _generalAreaText = chosen);
    }
  }

  /// Screens 14, Modal 15, Sheet 16, Modal 17 — Step 4: Evidence Vault & EXIF Scrubber
  Widget _buildStep4EvidenceVault() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Banner with Bespoke Illustration 03 (`03_evidence_vault_exif_scrubber.jpg`)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF7ECFC), Color(0xFFEDE0F6)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCC2E8)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: Image.asset(
                    AppAssets.module5EvidenceVaultScrubber,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.pastelLavender,
                      child: const Icon(
                        Icons.enhanced_encryption_rounded,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encrypted Evidence Vault & Auto-EXIF Scrubber',
                      style: AppTypography.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Every screenshot, photo, audio clip, or PDF is stripped of GPS coordinates, camera serials, and owner metadata before upload.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action Buttons to Add Scrubbed Evidence or Open Evidence Safety Guidance (Modal 15)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('m5-add-evidence-screenshot-button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              onPressed: () {
                final added = _controller.scrubAndCreateEvidence(
                  originalFileName:
                      'Chat_Evidence_${_evidenceFiles.length + 1}.png',
                  mimeType: 'image/png',
                  sizeBytes: 348120 + (_evidenceFiles.length * 42000),
                );
                setState(() => _evidenceFiles.add(added));
              },
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 17),
              label: const Text('Attach Screenshot / Photo'),
            ),
            FilledButton.tonalIcon(
              key: const Key('m5-add-evidence-audio-pdf-button'),
              onPressed: () {
                final added = _controller.scrubAndCreateEvidence(
                  originalFileName:
                      'VoiceNote_Recording_${_evidenceFiles.length + 1}.m4a',
                  mimeType: 'audio/mp4',
                  sizeBytes: 612400,
                );
                setState(() => _evidenceFiles.add(added));
              },
              icon: const Icon(Icons.mic_rounded, size: 17),
              label: const Text('Attach Audio / PDF'),
            ),
            OutlinedButton.icon(
              key: const Key('m5-open-evidence-guidance-button'),
              onPressed: _showEvidenceSafetyGuidanceModal,
              icon: const Icon(Icons.help_outline_rounded, size: 17),
              label: const Text('Evidence Safety Tips'),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Attached Scrubbed Evidence Files List (Tap to open Sheet 16 EXIF Inspection)
        Text(
          'Sanitized Evidence Files (${_evidenceFiles.length})',
          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        if (_evidenceFiles.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Text(
              'No evidence files attached yet. You may submit a complaint with or without attachments.',
              style: AppTypography.subtitle,
            ),
          )
        else
          ..._evidenceFiles.map(
            (ev) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6F5EE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFF1F6E50),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ev.sanitizedFileName,
                          style: AppTypography.monoToken,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Original: ${ev.originalLabel} (${ev.formattedSize}) • ${ev.removedTags.length} EXIF tags stripped',
                          style: AppTypography.subtitle.copyWith(
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openExifScrubberInspectionSheet(ev),
                    child: const Text('Inspect EXIF'),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.sosRed,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _evidenceFiles.remove(ev)),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),

        // Modal 17 — Supporting Links & In-App Post/Profile/Business Linker
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Linked Sakhi Profile, Post or Business',
                    style: AppTypography.cardTitle,
                  ),
                  TextButton.icon(
                    key: const Key('m5-open-supporting-links-modal-button'),
                    onPressed: _openSupportingLinksModal,
                    icon: const Icon(Icons.add_link_rounded, size: 18),
                    label: const Text('Add Link'),
                  ),
                ],
              ),
              TextField(
                controller: _linkedProfileCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reported Member @handle (optional)',
                  hintText: '@handle_to_review',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _linkedPostCtrl,
                decoration: const InputDecoration(
                  labelText: 'Linked Community Post or Comment ID (optional)',
                  hintText: 'post-id or comment reference',
                ),
              ),
              if (_supportingLinks.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _supportingLinks
                      .map(
                        (lnk) => Chip(
                          label: Text(
                            lnk,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onDeleted: () =>
                              setState(() => _supportingLinks.remove(lnk)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Modal 15 — Evidence Safety Guidance Modal
  void _showEvidenceSafetyGuidanceModal() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9FC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Evidence Preservation & Safety Guide',
          style: AppTypography.sectionTitle.copyWith(fontSize: 18),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Capture Full Context: Include the @handle, date, and message thread in screenshots.\n'
              '2. Automatic EXIF Scrubbing: Sakhi removes GPS coordinates, iPhone/Android device model, and owner tags automatically.\n'
              '3. Blurred-by-Default Admin Vault: Even Senior Reviewers see a blurred preview first and must log an audited reason to unblur.\n'
              '4. Cybercrime 1930 Preservation: Keep original files in a locked folder if you plan to file an official police FIR.',
              style: TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  /// Sheet 16 — Automatic EXIF Metadata Scrubber & Visual Blur Inspection Sheet
  void _openExifScrubberInspectionSheet(SanitizedEvidenceFileModel ev) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF9FC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EXIF Metadata Scrubber Verification',
                style: AppTypography.sectionTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Sanitized Vault Name: ${ev.sanitizedFileName}',
                style: AppTypography.monoToken,
              ),
              const SizedBox(height: 4),
              Text(
                'SHA-256 Integrity Hash: ${ev.sha256Hash.substring(0, 28)}…',
                style: AppTypography.monoToken,
              ),
              const SizedBox(height: 12),
              const Text(
                'Stripped Device & Location Metadata Tags:',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 6),
              ...ev.removedTags.map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF1F6E50),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$t → REMOVED',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F6E50),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Verified • Close Inspector'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modal 17 — Supporting Links & In-App Reference Modal
  Future<void> _openSupportingLinksModal() async {
    final linkCtrl = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9FC),
        title: Text(
          'Add Supporting Link or In-App Reference',
          style: AppTypography.sectionTitle.copyWith(fontSize: 18),
        ),
        content: TextField(
          controller: linkCtrl,
          decoration: const InputDecoration(
            labelText: 'Post URL, Profile Handle, or External Evidence Link',
            hintText: 'https://... or sakhi://post/123',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(linkCtrl.text.trim()),
            child: const Text('Attach Link'),
          ),
        ],
      ),
    );
    linkCtrl.dispose();
    if (added != null && added.isNotEmpty && mounted) {
      setState(() => _supportingLinks.add(added));
    }
  }

  /// Screen 18 — Step 5: Updates Preference & Pre-Submission Summary Review
  Widget _buildStep5PreSubmissionReview() {
    final cat = _controller.categoryByCode(_selectedCategoryCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Discreet Updates & Final Review',
          style: AppTypography.heroTitle.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose how you want to check status updates so lock-screen notifications never put you at risk.',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: 14),

        // Updates & Notification Safety Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Enable Two-Way Status Updates & Reviewer Replies',
                  style: AppTypography.bodyMedium,
                ),
                subtitle: const Text(
                  'Allows you to read reviewer responses and reply using your Reference #',
                  style: AppTypography.subtitle,
                ),
                value: _wantsFollowUp,
                activeThumbColor: AppColors.primaryPurple,
                onChanged: (val) => setState(() => _wantsFollowUp = val),
              ),
              const Divider(),
              const Text(
                'Lock-Screen Notification Camouflage',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 6),
              RadioGroup<String>(
                groupValue: _discreetNotificationMode,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _discreetNotificationMode = value);
                  }
                },
                child: Column(
                  children: <Widget>[
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: 'SILENT_VAULT_ONLY',
                      title: const Text(
                        'Silent In-App Vault Only (Zero Push Notifications)',
                      ),
                      subtitle: const Text(
                        'Safest option: nothing ever appears on your phone lock screen',
                      ),
                    ),
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: 'DISCREET_GENERIC_WELLNESS_ALERT',
                      title: const Text(
                        'Disguised Wellness Reminder ("New Sakhi Daily Quote")',
                      ),
                      subtitle: const Text(
                        'Never mentions the word "Complaint" or "Report" on lock screen',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Pre-Submission Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F1FC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDCC2E8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pre-Submission Privacy Audit Summary',
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.primaryPurple,
                ),
              ),
              const SizedBox(height: 10),
              _buildSummaryLine('Reporting Mode', _reportingMode.title),
              _buildSummaryLine('Category', '${cat.label} ($_urgencyLevel)'),
              _buildSummaryLine('Incident Window', _incidentDateWindow),
              _buildSummaryLine('Coarse Location', _generalAreaText),
              _buildSummaryLine(
                'Scrubbed Evidence',
                '${_evidenceFiles.length} file(s) • EXIF GPS Removed',
              ),
              _buildSummaryLine(
                'Supporting Links',
                '${_supportingLinks.length} reference(s)',
              ),
              _buildSummaryLine(
                'Reported User Visibility',
                'HIDDEN FOREVER (SRS 7.4 Guaranteed)',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Screen 20 & Modal 21 — Complaint Submitted Anonymous Reference Receipt Screen
  Widget _buildSubmittedReceiptScreen(DiscreetComplaintModel receipt) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Complaint Sealed & Submitted',
                    style: AppTypography.sectionTitle.copyWith(fontSize: 19),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2B6F56),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _triggerQuickExit,
                    icon: const Icon(Icons.spa_rounded, size: 15),
                    label: const Text('Clear & Quick Exit'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bespoke Illustration 06 (`06_anonymous_reference_token_card.jpg`)
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Image.asset(
                    AppAssets.module5ReferenceTokenCard,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.pastelLavender,
                      child: const Icon(
                        Icons.verified_user_rounded,
                        size: 54,
                        color: AppColors.primaryPurple,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primaryPurple,
                    width: 1.6,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x165A1868),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F5EE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${receipt.reportingMode.badgeLabel} • STATUS: ${receipt.status.label.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F6E50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your Encrypted Reference Number',
                      style: AppTypography.subtitle,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      receipt.referenceNumber,
                      key: const Key('m5-receipt-reference-number'),
                      style: AppTypography.monoToken,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Two-Way Reply Passkey: ${receipt.passkey}',
                      style: AppTypography.monoToken,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(
                                  text:
                                      '${receipt.referenceNumber} (Passkey: ${receipt.passkey})',
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reference Number & Passkey copied!',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            label: const Text('Copy Token'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            key: const Key(
                              'm5-open-disguised-backup-modal-button',
                            ),
                            onPressed: () =>
                                _showDisguisedWellnessBackupModal(receipt),
                            icon: const Icon(Icons.style_rounded, size: 16),
                            label: const Text('Save Disguised Card'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('m5-receipt-track-status-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => ComplaintTrackingLookupScreen(
                          initialReferenceNumber: receipt.referenceNumber,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.track_changes_rounded),
                  label: const Text(
                    'Track Complaint Status & Two-Way Messages',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Return to Discreet Complaint Hub'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Modal 21 — Save Discreet Reference Backup Modal (Camouflaged as a Daily Wellness Quote Card)
  void _showDisguisedWellnessBackupModal(DiscreetComplaintModel receipt) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF9FC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Camouflaged Wellness Quote Backup Card',
          style: AppTypography.sectionTitle.copyWith(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'If someone checks your phone gallery, this card looks like a normal Sakhi Daily Botanical Quote—while quietly storing your lookup serial at the bottom:',
              style: AppTypography.subtitle,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF1F6), Color(0xFFF3E4F8)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDCC2E8)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.spa_rounded,
                    color: AppColors.primaryPurple,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '“She stood in the storm, and when the wind did not blow her way, she adjusted her sails.”',
                    textAlign: TextAlign.center,
                    style: AppTypography.editorialQuote,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Daily Reflection Edition • ${receipt.disguisedSerialTag}',
                    style: AppTypography.monoToken.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: receipt.disguisedSerialTag),
              );
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Camouflaged Wellness Quote Card serial saved!',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.download_done_rounded, size: 16),
            label: const Text('Save Disguised Card'),
          ),
        ],
      ),
    );
  }
}

class _PickerSelectionCard extends StatelessWidget {
  const _PickerSelectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.valueText,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String valueText;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.pastelLavender,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primaryPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.subtitle),
                    const SizedBox(height: 2),
                    Text(
                      valueText,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryPurple,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
