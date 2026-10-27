import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../auth/backend_api_client.dart';
import '../models/complaint_models.dart';
import '../services/complaint_controller.dart';
import 'complaint_tracking_screens.dart';
import 'discreet_complaint_hub_screen.dart';

/// Complete 5-Step Discreet & Anonymous Complaint Submission Wizard
/// - Enforces strict step-by-step validation (cannot skip ahead past incomplete steps).
/// - Starts with clean, empty user inputs (zero pre-filled fake descriptions or fake attachments).
/// - Uploads and scrubs real picked file bytes via the backend EXIF scrubber.
/// - Submits to `POST /api/v1/complaints` and only displays a receipt when the server confirms creation.
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
  final ImagePicker _imagePicker = ImagePicker();

  int _currentStep = 0; // 0..4 for steps 1..5
  int _highestCompletedStep = 0;
  String? _validationError;
  bool _isUploadingEvidence = false;
  bool _isSubmitting = false;

  late ComplaintReportingMode _reportingMode;
  late String _selectedCategoryCode;
  String _urgencyLevel = 'PAST_INCIDENT';
  bool _acknowledgedLegalNotice = true;
  bool _piiGuardRedacted = false;

  final TextEditingController _customCategoryCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _linkedProfileCtrl = TextEditingController();
  final TextEditingController _linkedPostCtrl = TextEditingController();
  final TextEditingController _linkedBusinessCtrl = TextEditingController();

  String _approximateDateLabel = 'Today / Within the last 24 hours';
  String _approximateTimeWindow = 'Evening (5 PM – 9 PM)';
  String _locationType = 'COARSE_AREA';
  String _generalAreaText = 'Online / Inside Sakhi App';
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
    final initialCat = widget.initialCategoryCode != null
        ? _controller.categoryByCode(widget.initialCategoryCode!).code
        : _controller.enabledCategories.first.code;
    _selectedCategoryCode = initialCat;

    if (widget.initialLinkedProfileHandle != null &&
        widget.initialLinkedProfileHandle!.trim().isNotEmpty) {
      _linkedProfileCtrl.text = widget.initialLinkedProfileHandle!.trim();
      _supportingLinks.add(
        'sakhi://profile/${widget.initialLinkedProfileHandle!.trim()}',
      );
    }
    if (widget.initialLinkedPostId != null &&
        widget.initialLinkedPostId!.trim().isNotEmpty) {
      _linkedPostCtrl.text = widget.initialLinkedPostId!.trim();
      _supportingLinks.add(
        'sakhi://post/${widget.initialLinkedPostId!.trim()}',
      );
    }
    if (widget.initialLinkedBusinessId != null &&
        widget.initialLinkedBusinessId!.trim().isNotEmpty) {
      _linkedBusinessCtrl.text = widget.initialLinkedBusinessId!.trim();
      _supportingLinks.add(
        'sakhi://business/${widget.initialLinkedBusinessId!.trim()}',
      );
    }
    unawaited(_controller.syncCategoriesFromServer());
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

  /// Validates the fields of `[step]` and returns `null` if valid, or a user-facing error message.
  String? _validateStep(int step) {
    if (step == 0) {
      if (!_acknowledgedLegalNotice) {
        return 'Please acknowledge the non-police / emergency channels legal notice before continuing.';
      }
      return null;
    }
    if (step == 1) {
      final cat = _controller.categoryByCode(_selectedCategoryCode);
      if (!cat.enabled) {
        return 'Please select an enabled complaint category.';
      }
      if (cat.code == 'other' && _customCategoryCtrl.text.trim().length < 3) {
        return 'Please enter a custom category description (at least 3 characters) when selecting "Other".';
      }
      return null;
    }
    if (step == 2) {
      final cleanDesc = _descriptionCtrl.text.trim();
      if (cleanDesc.isEmpty) {
        return 'Incident description is required and cannot be blank or whitespace-only.';
      }
      if (cleanDesc.length < 20) {
        return 'Please provide at least 20 characters describing what happened (${cleanDesc.length}/20 typed).';
      }
      if (cleanDesc.length > 4000) {
        return 'Incident description cannot exceed 4,000 characters.';
      }
      return null;
    }
    if (step == 3) {
      if (_evidenceFiles.length > kMaxComplaintEvidenceFiles) {
        return 'You can attach a maximum of $kMaxComplaintEvidenceFiles evidence files.';
      }
      for (final link in _supportingLinks) {
        final err = SakhiComplaintController.validateSupportingLinkUrl(link);
        if (err != null) return err;
      }
      return null;
    }
    return null;
  }

  void _handleStepChipTap(int targetStep) {
    setState(() => _validationError = null);
    if (targetStep <= _currentStep) {
      setState(() => _currentStep = targetStep);
      return;
    }
    // Validate every step from _currentStep up to targetStep - 1
    for (var s = _currentStep; s < targetStep; s++) {
      final err = _validateStep(s);
      if (err != null) {
        setState(() {
          _currentStep = s;
          _validationError = err;
        });
        return;
      }
    }
    setState(() {
      _currentStep = targetStep;
      if (targetStep > _highestCompletedStep) {
        _highestCompletedStep = targetStep;
      }
    });
  }

  void _handleBackStep() {
    setState(() => _validationError = null);
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
    setState(() => _validationError = null);
    final err = _validateStep(_currentStep);
    if (err != null) {
      setState(() => _validationError = err);
      return;
    }

    if (_currentStep == 2) {
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
            _piiGuardRedacted = true;
          });
        }
      }
    }

    if (_currentStep < 4) {
      setState(() {
        _currentStep++;
        if (_currentStep > _highestCompletedStep) {
          _highestCompletedStep = _currentStep;
        }
      });
      return;
    }

    // Validate all steps 0..3 before final submission
    for (var s = 0; s < 4; s++) {
      final stepErr = _validateStep(s);
      if (stepErr != null) {
        setState(() {
          _currentStep = s;
          _validationError = stepErr;
        });
        return;
      }
    }

    final confirmed = await _showFinalSubmissionConfirmDialog();
    if (!mounted || confirmed != true) return;

    setState(() {
      _isSubmitting = true;
      _validationError = null;
    });

    try {
      final created = await _controller.submitComplaint(
        reportingMode: _reportingMode,
        categoryCode: _selectedCategoryCode,
        customCategoryNote: _customCategoryCtrl.text.trim().isEmpty
            ? null
            : _customCategoryCtrl.text.trim(),
        urgencyLevel: _urgencyLevel,
        description: _descriptionCtrl.text.trim(),
        approximateDateLabel: _approximateDateLabel,
        approximateTimeWindow: _approximateTimeWindow,
        locationType: _locationType,
        generalAreaText: _locationType == 'PREFER_NOT_TO_SAY'
            ? null
            : _generalAreaText,
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
        acknowledgedNonPoliceLegalNotice: _acknowledgedLegalNotice,
        evidenceFiles: List<SanitizedEvidenceFileModel>.from(_evidenceFiles),
        piiGuardRedacted: _piiGuardRedacted,
      );

      if (!mounted) return;
      setState(() {
        _submittedReceipt = created;
      });
    } on BackendApiException catch (apiErr) {
      if (!mounted) return;
      setState(() {
        _validationError = apiErr.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validationError =
            'Could not submit complaint to backend server. Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// Picks a real image/screenshot via ImagePicker and sends its bytes to the backend EXIF scrubber.
  Future<void> _pickAndUploadImageEvidence(ImageSource source) async {
    if (_evidenceFiles.length >= kMaxComplaintEvidenceFiles) {
      setState(() {
        _validationError =
            'Maximum of $kMaxComplaintEvidenceFiles evidence files reached.';
      });
      return;
    }
    setState(() => _validationError = null);
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final name = picked.name.isNotEmpty ? picked.name : 'evidence_photo.jpg';
      final ext = name.split('.').last.toLowerCase();
      final mime = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
          ? 'image/webp'
          : 'image/jpeg';

      setState(() => _isUploadingEvidence = true);
      final scrubbed = await _controller.uploadAndScrubEvidenceOnServer(
        originalFileName: name,
        mimeType: mime,
        fileBytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _evidenceFiles.add(scrubbed);
      });
    } on BackendApiException catch (err) {
      if (!mounted) return;
      setState(() => _validationError = err.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _validationError =
            'Could not pick or scrub the selected image. Verify permissions and backend connectivity.';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingEvidence = false);
      }
    }
  }

  /// Allows attaching a real text/PDF/audio evidence payload or custom file for scrubbing on the backend.
  Future<void> _openDocumentOrAudioUploadDialog() async {
    if (_evidenceFiles.length >= kMaxComplaintEvidenceFiles) {
      setState(() {
        _validationError =
            'Maximum of $kMaxComplaintEvidenceFiles evidence files reached.';
      });
      return;
    }
    final fileNameCtrl = TextEditingController(text: 'incident_statement.pdf');
    final contentCtrl = TextEditingController();
    String selectedMime = 'application/pdf';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF9FC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Attach Document / Transcript for Server Scrubbing',
            style: AppTypography.editorialSection.copyWith(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: fileNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'File Name *',
                    hintText: 'chat_log.pdf or voice_note.m4a',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedMime,
                  decoration: const InputDecoration(labelText: 'File Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'application/pdf',
                      child: Text('PDF Document (application/pdf)'),
                    ),
                    DropdownMenuItem(
                      value: 'image/png',
                      child: Text('PNG Screenshot (image/png)'),
                    ),
                    DropdownMenuItem(
                      value: 'image/jpeg',
                      child: Text('JPEG Photo (image/jpeg)'),
                    ),
                    DropdownMenuItem(
                      value: 'audio/mp4',
                      child: Text('Audio Recording (audio/mp4)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => selectedMime = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: contentCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Transcript / Document Excerpt Bytes *',
                    hintText:
                        'Paste chat transcript or document content to hash & scrub on backend...',
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
              child: const Text('Upload & Scrub on Server'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final rawName = fileNameCtrl.text.trim();
      final rawContent = contentCtrl.text.trim();
      if (rawName.isEmpty || rawContent.isEmpty) {
        setState(() {
          _validationError =
              'Both a file name and non-empty content are required to upload evidence.';
        });
      } else {
        setState(() {
          _isUploadingEvidence = true;
          _validationError = null;
        });
        try {
          final bytes = Uint8List.fromList(rawContent.codeUnits);
          final scrubbed = await _controller.uploadAndScrubEvidenceOnServer(
            originalFileName: rawName,
            mimeType: selectedMime,
            fileBytes: bytes,
          );
          if (mounted) {
            setState(() => _evidenceFiles.add(scrubbed));
          }
        } on BackendApiException catch (err) {
          if (mounted) setState(() => _validationError = err.message);
        } finally {
          if (mounted) setState(() => _isUploadingEvidence = false);
        }
      }
    }
    fileNameCtrl.dispose();
    contentCtrl.dispose();
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
                style: AppTypography.editorialSection.copyWith(fontSize: 18),
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
                style: AppTypography.editorialSection.copyWith(fontSize: 18),
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
              '• Reported Party Visibility: Hidden (Never disclosed)',
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
                'The server will issue a unique Reference Number (#SKH-...) and Passkey once your report is saved to the database.',
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

            // Validated Step Selector Pills
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
                      onSelected: (_) => _handleStepChipTap(index),
                    ),
                  );
                }),
              ),
            ),

            // Validation / API Error Banner
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Container(
                  key: const Key('m5-wizard-validation-error-banner'),
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
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _validationError!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8C1D35),
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () =>
                            setState(() => _validationError = null),
                      ),
                    ],
                  ),
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
                      onPressed: _isSubmitting ? null : _handleBackStep,
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
                      onPressed: _isSubmitting ? null : _handleNextStep,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _currentStep == 4
                                  ? Icons.lock_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                      label: Text(
                        _isSubmitting
                            ? 'Submitting to Server...'
                            : _currentStep == 4
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
          style: AppTypography.editorialHeadline.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 6),
        const Text(
          'Both modes guarantee your identity is never disclosed to the reported user, business, or public community.',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: 14),

        _buildModeChoiceTile(
          mode: ComplaintReportingMode.anonymous,
          illustration: AppAssets.m5AnonymousShield,
          highlights: const <String>[
            'No account ID, phone number, or profile name stored on the complaint record',
            'Server issues a Reference Token (#SKH-ANON-...) and Passkey for two-way updates',
            'Note: Minimal blinded rate-limit bucket logs exist for anti-spam protection (SRS 7.4)',
          ],
        ),
        const SizedBox(height: 12),

        _buildModeChoiceTile(
          mode: ComplaintReportingMode.confidential,
          illustration: AppAssets.m5CompassionateTeam,
          highlights: const <String>[
            'Hidden from the reported member, public feed, and standard moderators',
            'Authorised Senior Safety Reviewer can verify your session for direct follow-up',
            'Requires an active signed-in Sakhi member session',
          ],
        ),
        const SizedBox(height: 12),

        CheckboxListTile(
          key: const Key('m5-ack-legal-notice-checkbox'),
          contentPadding: EdgeInsets.zero,
          value: _acknowledgedLegalNotice,
          activeColor: AppColors.primaryPurple,
          title: const Text(
            'I understand that an in-app complaint is for Sakhi moderation/support and does not automatically register a Police FIR (Dial 112 / 1091 in emergencies).',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          onChanged: (v) =>
              setState(() => _acknowledgedLegalNotice = v ?? false),
        ),
        const SizedBox(height: 8),

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
          style: AppTypography.editorialHeadline.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 4),
        const Text(
          'Select one of the 10 SRS 7.2 categories below. Tap the ⓘ icon on any card for safety & helpline guidance.',
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
            final isSelected = cat.code == selectedCat.code;
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
                key: const Key('m5-custom-category-input'),
                controller: _customCategoryCtrl,
                decoration: InputDecoration(
                  labelText: selectedCat.code == 'other'
                      ? 'Specify custom category details (Required) *'
                      : 'Optional sub-category / POSH or business context',
                  hintText:
                      'e.g., Unsolicited messages in community circle',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Incident Pattern / Urgency',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: <Map<String, String>>[
                  {'code': 'PAST_INCIDENT', 'label': 'Past Incident'},
                  {'code': 'REPEATED_PATTERN', 'label': 'Repeated Pattern'},
                  {'code': 'HAPPENING_NOW', 'label': 'Happening Now (Urgent)'},
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
                style: AppTypography.editorialSection.copyWith(fontSize: 18),
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
            const SizedBox(height: 8),
            Text(
              cat.legalHelplineNote,
              style: AppTypography.subtitle.copyWith(fontSize: 11.5),
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
    final charCount = _descriptionCtrl.text.trim().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Describe What Happened Safely',
          style: AppTypography.editorialHeadline.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter at least 20 characters describing what happened. Our live PII Guard watches for accidental self-identifying phone numbers, emails, or door numbers.',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: 14),

        TextField(
          key: const Key('m5-incident-description-input'),
          controller: _descriptionCtrl,
          minLines: 4,
          maxLines: 6,
          maxLength: 4000,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Incident Description (Required, min 20 chars) *',
            helperText: '$charCount / 20 minimum characters',
            hintText:
                'Describe the messages, behaviour, or safety concern without typing your own phone number or flat number...',
          ),
        ),
        const SizedBox(height: 10),

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
                      _piiGuardRedacted = true;
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
          title: 'Incident Date & Approximate Time Window',
          valueText: '$_approximateDateLabel • $_approximateTimeWindow',
          subtitle: 'Approximate window prevents exact timestamp correlation',
          onTap: _openDateWindowSheet,
        ),
        const SizedBox(height: 10),

        // Modal 13 — Coarse 5 km General Area Picker Row (Never Live Home GPS)
        _PickerSelectionCard(
          key: const Key('m5-open-coarse-location-modal'),
          icon: Icons.location_city_rounded,
          title: 'General Location / Neighbourhood (Optional)',
          valueText: '$_locationType • $_generalAreaText',
          subtitle: 'Coarse ~5 km area only • Never captures exact home GPS',
          onTap: _openCoarseLocationModal,
        ),
      ],
    );
  }

  /// Sheet 12 — Approximate Date & Time Window Picker Bottom Sheet
  Future<void> _openDateWindowSheet() async {
    const datePresets = <String>[
      'Today / Within the last 24 hours',
      'Yesterday',
      'Earlier This Week',
      'Last Week',
      'Earlier This Month',
    ];
    const windowPresets = <String>[
      'Morning (6 AM – 12 PM)',
      'Afternoon (12 PM – 5 PM)',
      'Evening (5 PM – 9 PM)',
      'Night (9 PM – 6 AM)',
      'Prefer Not to Specify Window',
    ];
    var tempDate = _approximateDateLabel;
    var tempWindow = _approximateTimeWindow;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF9FC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Approximate Incident Date & Window',
                  style: AppTypography.editorialSection.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: datePresets.contains(tempDate)
                      ? tempDate
                      : datePresets.first,
                  decoration: const InputDecoration(
                    labelText: 'Approximate Date (Past or Today only)',
                  ),
                  items: datePresets
                      .map(
                        (d) => DropdownMenuItem(value: d, child: Text(d)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => tempDate = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: windowPresets.contains(tempWindow)
                      ? tempWindow
                      : windowPresets[2],
                  decoration: const InputDecoration(
                    labelText: 'Approximate Time Window',
                  ),
                  items: windowPresets
                      .map(
                        (w) => DropdownMenuItem(value: w, child: Text(w)),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => tempWindow = v);
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Save Date & Time Window'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _approximateDateLabel = tempDate;
        _approximateTimeWindow = tempWindow;
      });
    }
  }

  /// Modal 13 — Coarse 5 km General Location Picker Modal
  Future<void> _openCoarseLocationModal() async {
    final customAreaCtrl = TextEditingController(text: _generalAreaText);
    var tempLocType = _locationType;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF9FC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Coarse 5 km Area (Zero Home GPS)',
            style: AppTypography.editorialSection.copyWith(fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Module 5 never records your precise home coordinates. Choose how much location context to share:',
                  style: AppTypography.subtitle,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: tempLocType,
                  decoration: const InputDecoration(labelText: 'Location Scope'),
                  items: const [
                    DropdownMenuItem(
                      value: 'ONLINE_IN_APP',
                      child: Text('Online / Inside Sakhi App Only'),
                    ),
                    DropdownMenuItem(
                      value: 'COARSE_AREA',
                      child: Text('Coarse 5 km Neighbourhood / City'),
                    ),
                    DropdownMenuItem(
                      value: 'PREFER_NOT_TO_SAY',
                      child: Text('Prefer Not to Share Location'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setModalState(() => tempLocType = v);
                  },
                ),
                const SizedBox(height: 10),
                if (tempLocType != 'PREFER_NOT_TO_SAY')
                  TextField(
                    controller: customAreaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'General neighbourhood or city label',
                      hintText: 'e.g., Indiranagar, Bengaluru (~5 km zone)',
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
              child: const Text('Save Location Preference'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _locationType = tempLocType;
        _generalAreaText = tempLocType == 'PREFER_NOT_TO_SAY'
            ? 'Prefer Not to Say'
            : (customAreaCtrl.text.trim().isEmpty
                  ? 'Online / Inside Sakhi App'
                  : customAreaCtrl.text.trim());
      });
    }
    customAreaCtrl.dispose();
  }

  /// Screens 14, Modal 15, Sheet 16, Modal 17 — Step 4: Evidence Vault & EXIF Scrubber
  Widget _buildStep4EvidenceVault() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    AppAssets.m5EvidenceVaultExif,
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
                      'Encrypted Evidence Vault & Server EXIF Scrubber',
                      style: AppTypography.cardTitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Every selected photo, screenshot, audio clip, or PDF is stripped of binary EXIF GPS/device metadata and SHA-256 hashed on the server.',
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

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const Key('m5-add-evidence-screenshot-button'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
              ),
              onPressed: _isUploadingEvidence
                  ? null
                  : () => _pickAndUploadImageEvidence(ImageSource.gallery),
              icon: _isUploadingEvidence
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_photo_alternate_rounded, size: 17),
              label: const Text('Pick Photo / Screenshot'),
            ),
            FilledButton.tonalIcon(
              key: const Key('m5-add-evidence-audio-pdf-button'),
              onPressed: _isUploadingEvidence
                  ? null
                  : _openDocumentOrAudioUploadDialog,
              icon: const Icon(Icons.upload_file_rounded, size: 17),
              label: const Text('Attach PDF / Transcript'),
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

        Text(
          'Sanitized Evidence Files (${_evidenceFiles.length} / $kMaxComplaintEvidenceFiles)',
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
              'No evidence files attached yet. Attachments are optional—pick a photo/screenshot or attach a transcript above if you have supporting proof.',
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
                          style: AppTypography.technicalToken,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${ev.formattedSize} • ${ev.removedTags.length} metadata tags stripped',
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
                  const Expanded(
                    child: Text(
                      'Linked Sakhi Profile, Post or Business',
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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
          style: AppTypography.editorialSection.copyWith(fontSize: 18),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Capture Full Context: Include the @handle, date, and message thread in screenshots.\n'
              '2. Automatic EXIF Scrubbing: Sakhi strips binary JPEG APP1/EXIF/GPS markers and PNG metadata chunks on upload.\n'
              '3. Blurred-by-Default Admin Vault: Even Senior Reviewers see a blurred preview first and must log an audited justification to unblur.\n'
              '4. Cybercrime 1930 Preservation: Keep original files on your device if you plan to file an official police FIR.',
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
                style: AppTypography.editorialSection.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Sanitized Vault Name: ${ev.sanitizedFileName}',
                style: AppTypography.technicalToken,
              ),
              const SizedBox(height: 4),
              Text(
                'SHA-256 Integrity Hash: ${ev.sha256Hash.length > 28 ? '${ev.sha256Hash.substring(0, 28)}…' : ev.sha256Hash}',
                style: AppTypography.technicalHash,
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
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F6E50),
                          ),
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

  /// Modal 17 — Supporting Links & In-App Reference Modal (Validates URL before adding!)
  Future<void> _openSupportingLinksModal() async {
    final linkCtrl = TextEditingController();
    String? modalError;

    final added = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFFFFF9FC),
          title: Text(
            'Add Supporting Link or In-App Reference',
            style: AppTypography.editorialSection.copyWith(fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: linkCtrl,
                decoration: InputDecoration(
                  labelText:
                      'https://, http://, or sakhi:// Reference Link *',
                  hintText: 'https://... or sakhi://post/123',
                  errorText: modalError,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final candidate = linkCtrl.text.trim();
                final err =
                    SakhiComplaintController.validateSupportingLinkUrl(
                      candidate,
                    );
                if (err != null) {
                  setModalState(() => modalError = err);
                  return;
                }
                Navigator.of(ctx).pop(candidate);
              },
              child: const Text('Attach Link'),
            ),
          ],
        ),
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
          style: AppTypography.editorialHeadline.copyWith(fontSize: 21),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose how you want to check status updates so lock-screen notifications never put you at risk.',
          style: AppTypography.subtitle,
        ),
        const SizedBox(height: 14),

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
                  'Allows you to read reviewer responses and reply using your Reference # & Passkey',
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
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _discreetNotificationMode = v);
                  }
                },
                child: Column(
                  children: [
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
              _buildSummaryLine(
                'Incident Window',
                '$_approximateDateLabel • $_approximateTimeWindow',
              ),
              _buildSummaryLine('Location Scope', '$_locationType ($_generalAreaText)'),
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
                'Hidden (SRS 7.4 Enforced)',
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

  /// Screen 20 & Modal 21 — Server-Confirmed Complaint Receipt Screen
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
                    'Complaint Sealed & Saved',
                    style: AppTypography.editorialSection.copyWith(
                      fontSize: 19,
                    ),
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

              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 170,
                  width: double.infinity,
                  child: Image.asset(
                    AppAssets.m5ReferenceTokenCard,
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
                      'Server-Issued Reference Number',
                      style: AppTypography.subtitle,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      receipt.referenceNumber,
                      key: const Key('m5-receipt-reference-number'),
                      style: AppTypography.referenceToken,
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      'Check-In Passkey: ${receipt.passkey}',
                      key: const Key('m5-receipt-passkey'),
                      style: AppTypography.technicalToken,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Save both your Reference Number and Passkey—they are required to check status updates or reply.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
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
                                      'Reference: ${receipt.referenceNumber} | Passkey: ${receipt.passkey}',
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
                          initialPasskey: receipt.passkey,
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
          style: AppTypography.editorialSection.copyWith(fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'If someone checks your phone, this card looks like a normal Sakhi Daily Botanical Quote while encoding your lookup serial at the bottom:',
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
                    '“Peace begins the moment you choose to honour your own boundaries.”',
                    textAlign: TextAlign.center,
                    style: AppTypography.editorialQuote,
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    receipt.disguisedSerialTag,
                    style: AppTypography.technicalHash.copyWith(fontSize: 10.5),
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
                    'Camouflaged Wellness Quote Card serial copied!',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.download_done_rounded, size: 16),
            label: const Text('Copy Disguised Serial'),
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
