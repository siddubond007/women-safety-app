import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_quote_loader.dart';
import '../../safety/screens/safety_screen.dart';
import '../models/complaint_models.dart';
import '../services/complaint_controller.dart';
import 'complaint_admin_console_screen.dart';
import 'complaint_submission_wizard_screen.dart';
import 'complaint_tracking_screens.dart';

/// Screen 02 — Discreet & Anonymous Complaint Hub Landing Dashboard
/// Includes:
/// - Bespoke illustration `AppAssets.module5HeroSafeVoice` (`01_hero_woman_lotus_safe_voice.jpg`)
/// - Reusable hand-drawn `SakhiBotanicalFlower` accents
/// - Top-Right "Quick Exit" (Camouflage to Evening Chamomile Journal — Screen 22)
/// - Mandatory Legal / Police Non-FIR Notice Banner + Modal 03 Bottom Sheet
/// - "Start Discreet Report Now" CTA -> Step 1 Wizard (Screens 04–21)
/// - "Track Complaint by Reference #" Card -> Tracker (Screens 23–32)
/// - "Sakhi Anonymity & Privacy Promise" Card -> Sheet 06
/// - "Admin Complaint Console (Role-Restricted)" Card -> Screens 33–40
class DiscreetComplaintHubScreen extends StatefulWidget {
  const DiscreetComplaintHubScreen({
    super.key,
    this.initialLinkedPostId,
    this.initialLinkedProfileHandle,
    this.initialLinkedBusinessId,
    this.initialCategoryCode,
  });

  final String? initialLinkedPostId;
  final String? initialLinkedProfileHandle;
  final String? initialLinkedBusinessId;
  final String? initialCategoryCode;

  @override
  State<DiscreetComplaintHubScreen> createState() =>
      _DiscreetComplaintHubScreenState();
}

class _DiscreetComplaintHubScreenState
    extends State<DiscreetComplaintHubScreen> {
  final SakhiComplaintController _controller =
      SakhiComplaintController.instance;

  void _triggerQuickExitCamouflage() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => const QuickExitWellnessCamouflageScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _openLegalDisclaimerModal({
    bool proceedToWizardAfterAck = false,
    ComplaintReportingMode initialMode = ComplaintReportingMode.anonymous,
  }) async {
    final acknowledged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LegalEmergencyDisclaimerSheet(),
    );

    if (!mounted) return;
    if (proceedToWizardAfterAck && acknowledged == true) {
      _openSubmissionWizard(initialMode: initialMode);
    }
  }

  void _openSubmissionWizard({
    ComplaintReportingMode initialMode = ComplaintReportingMode.anonymous,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComplaintSubmissionWizardScreen(
          initialMode: initialMode,
          initialCategoryCode: widget.initialCategoryCode,
          initialLinkedPostId: widget.initialLinkedPostId,
          initialLinkedProfileHandle: widget.initialLinkedProfileHandle,
          initialLinkedBusinessId: widget.initialLinkedBusinessId,
        ),
      ),
    );
  }

  void _openTracker({String? initialReference}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComplaintTrackingLookupScreen(
          initialReferenceNumber: initialReference,
        ),
      ),
    );
  }

  void _openAdminConsole() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ComplaintAdminConsoleScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final recentCases = _controller.complaints;
        return Scaffold(
          backgroundColor: const Color(0xFFFFF8FB),
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header with Back Button + Title + Quick Exit Camouflage Button
                  Row(
                    children: [
                      if (Navigator.of(context).canPop())
                        IconButton(
                          key: const Key('m5-hub-back-button'),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppColors.textPrimary,
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Discreet Complaint Hub',
                              style: AppTypography.sectionTitle.copyWith(
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              'Module 5 • Anonymous & Confidential Safety Desk',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primaryPurple,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        key: const Key('m5-quick-exit-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2B6F56),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: _triggerQuickExitCamouflage,
                        icon: const Icon(Icons.spa_rounded, size: 15),
                        label: const Text(
                          'Quick Exit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // If launched from a specific post, profile, or business, show context pill
                  if (widget.initialLinkedPostId != null ||
                      widget.initialLinkedProfileHandle != null ||
                      widget.initialLinkedBusinessId != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EBF9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD7BDE8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link_rounded,
                            color: AppColors.primaryPurple,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pre-linked context ready: '
                              '${[if (widget.initialLinkedProfileHandle != null) widget.initialLinkedProfileHandle!, if (widget.initialLinkedPostId != null) 'Post ${widget.initialLinkedPostId}', if (widget.initialLinkedBusinessId != null) 'Business ${widget.initialLinkedBusinessId}'].join(' • ')}',
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 12.5,
                                color: AppColors.primaryPurple,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Hero Sanctuary Card with Bespoke Illustration 01 + Hand-Drawn Flowers
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFF1F6),
                          Color(0xFFF5E6FA),
                          Color(0xFFEDE0F6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2C6EC)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x145A1868),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        children: [
                          const Positioned(
                            right: -12,
                            top: -12,
                            child: SakhiBotanicalFlower(
                              type: SakhiFlowerType.roseClassic,
                              width: 82,
                              height: 96,
                              opacity: 0.34,
                              angle: -0.2,
                            ),
                          ),
                          const Positioned(
                            left: -14,
                            bottom: -14,
                            child: SakhiBotanicalFlower(
                              type: SakhiFlowerType.cherryBlossom,
                              width: 72,
                              height: 84,
                              opacity: 0.28,
                              angle: 0.22,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.88,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.verified_user_rounded,
                                                  size: 14,
                                                  color:
                                                      AppColors.primaryPurple,
                                                ),
                                                SizedBox(width: 5),
                                                Text(
                                                  'ZERO-JUDGMENT SANCTUARY',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.6,
                                                    color:
                                                        AppColors.primaryPurple,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            'Speak Up Safely, On Your Own Terms',
                                            style: AppTypography.heroTitle
                                                .copyWith(fontSize: 22),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Report harassment, stalking, cyberbullying, blackmail, POSH workplace issues, or fake accounts—either 100% Anonymously or Confidentially.',
                                            style: AppTypography.bodyRegular
                                                .copyWith(
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: SizedBox(
                                        width: 108,
                                        height: 128,
                                        child: Image.asset(
                                          AppAssets.module5HeroSafeVoice,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: AppColors.pastelLavender,
                                            child: const Icon(
                                              Icons.shield_moon_rounded,
                                              size: 44,
                                              color: AppColors.primaryPurple,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                // 3 Privacy & Security Pills
                                const Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _SanctuaryFeaturePill(
                                      icon: Icons.visibility_off_rounded,
                                      label: 'Never Shown to Reported Party',
                                    ),
                                    _SanctuaryFeaturePill(
                                      icon: Icons.auto_fix_high_rounded,
                                      label: 'Auto EXIF & GPS Scrubber',
                                    ),
                                    _SanctuaryFeaturePill(
                                      icon: Icons.lock_clock_rounded,
                                      label: 'Two-Way Encrypted Reference #',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        key: const Key(
                                          'm5-start-discreet-report-button',
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              AppColors.primaryPurple,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _openSubmissionWizard(
                                          initialMode:
                                              ComplaintReportingMode.anonymous,
                                        ),
                                        icon: const Icon(
                                          Icons.shield_outlined,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Start Discreet Report Now',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // SRS 7.2 Mandatory Legal / Non-FIR Notice Banner (Tappable -> Modal 03)
                  InkWell(
                    key: const Key('m5-legal-disclaimer-banner'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openLegalDisclaimerModal(
                      proceedToWizardAfterAck: false,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5E5),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFF0C987)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFCE3B4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.gavel_rounded,
                              color: Color(0xFF9C5708),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Important Legal & Emergency Notice (Tap for 112 / FIR Info)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF6B3800),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'In-app complaints are for Sakhi platform moderation & safety support and do not replace an official Police FIR, 112 emergency call, or 1930 cybercrime complaint.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.38,
                                    color: Color(0xFF7D480D),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'View Official Helplines (112 • 1091 • 181 • 1930) & Legal Rights →',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Two Side-by-Side Reporting Mode Cards (Anonymous vs Confidential)
                  Text(
                    'Choose How You Want to Report',
                    style: AppTypography.sectionTitle.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _ModePreviewCard(
                          key: const Key('m5-hub-anonymous-mode-card'),
                          badge: 'ZERO IDENTITY',
                          title: 'Anonymous Mode',
                          subtitle: 'No account ID, name, or phone linked. Track via #SKH-ANON token.',
                          illustrationAsset:
                              AppAssets.module5AnonymousShieldEnvelope,
                          accentColor: AppColors.primaryPurple,
                          buttonLabel: 'File Anonymous',
                          onTap: () => _openSubmissionWizard(
                            initialMode: ComplaintReportingMode.anonymous,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModePreviewCard(
                          key: const Key('m5-hub-confidential-mode-card'),
                          badge: 'SENIOR TEAM ONLY',
                          title: 'Confidential Mode',
                          subtitle: 'Hidden from reported user & public; Senior Female Reviewer can follow up.',
                          illustrationAsset:
                              AppAssets.module5CompassionateReviewCounselors,
                          accentColor: const Color(0xFFB8296B),
                          buttonLabel: 'File Confidential',
                          onTap: () => _openSubmissionWizard(
                            initialMode: ComplaintReportingMode.confidential,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Track Existing Complaint Card (Screen 23–32)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F5A1868),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 58,
                                height: 58,
                                child: Image.asset(
                                  AppAssets.module5ReferenceTokenCard,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: AppColors.pastelLavender,
                                    child: const Icon(
                                      Icons.confirmation_number_rounded,
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
                                  const Text(
                                    'Track Complaint & Two-Way Reply',
                                    style: AppTypography.cardTitle,
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Check all 7 status stages, respond to reviewer questions, appeal decisions, or purge evidence.',
                                    style: AppTypography.subtitle,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Quick Reference Chips for immediate testing & navigation
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: recentCases.take(4).map((item) {
                            return ActionChip(
                              backgroundColor: item.status.badgeBg,
                              side: BorderSide.none,
                              avatar: Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: item.status.badgeText,
                              ),
                              label: Text(
                                '${item.referenceNumber} • ${item.status.label}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: item.status.badgeText,
                                ),
                              ),
                              onPressed: () => _openTracker(
                                initialReference: item.referenceNumber,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const Key('m5-open-tracker-button'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryPurple,
                              side: const BorderSide(
                                color: AppColors.primaryPurple,
                                width: 1.3,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed: () => _openTracker(),
                            icon: const Icon(
                              Icons.manage_search_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Track by Reference Number or Quote Card',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Privacy & Technical Transparency Promise Card (Opens Sheet 06)
                  _ActionNavigationCard(
                    key: const Key('m5-open-transparency-sheet-card'),
                    icon: Icons.verified_user_outlined,
                    iconBg: const Color(0xFFE6F5EE),
                    iconColor: const Color(0xFF1F6E50),
                    title: 'How Sakhi Protects Your Identity (SRS 7.4)',
                    subtitle: 'View our clear explanation of what is hidden, what minimal anti-abuse bucket logs exist, and EXIF scrubbing.',
                    trailingLabel: 'Inspect',
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) =>
                            const AnonymityTransparencyBottomSheet(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Role-Restricted Admin Complaint Console Entry Card (Screens 33–40)
                  _ActionNavigationCard(
                    key: const Key('m5-open-admin-console-card'),
                    icon: Icons.admin_panel_settings_rounded,
                    iconBg: const Color(0xFFF3E4F8),
                    iconColor: AppColors.primaryPurple,
                    title: 'Admin Complaint Console (Role-Restricted)',
                    subtitle: 'Senior Safety Reviewer & Super Admin queue: PII masking, blurred evidence vault, internal notes, audit log & category config.',
                    trailingLabel: 'Open Console',
                    onTap: _openAdminConsole,
                  ),
                  const SizedBox(height: 16),

                  // Daily Sakhi Inspiration Banner
                  SakhiQuoteLoader.banner(
                    statusLabel: 'Your voice matters • Every report is handled with dignity',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SanctuaryFeaturePill extends StatelessWidget {
  const _SanctuaryFeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5CCE8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryPurple),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModePreviewCard extends StatelessWidget {
  const _ModePreviewCard({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.illustrationAsset,
    required this.accentColor,
    required this.buttonLabel,
    required this.onTap,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String illustrationAsset;
  final Color accentColor;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D5A1868),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 88,
                  width: double.infinity,
                  child: Image.asset(
                    illustrationAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppColors.pastelLavender,
                      child: Icon(Icons.shield_rounded, color: accentColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: AppTypography.cardTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.subtitle.copyWith(
                  fontSize: 11.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onTap,
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionNavigationCard extends StatelessWidget {
  const _ActionNavigationCard({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailingLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.subtitle.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pastelLavender,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trailingLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal 03 — Legal & Emergency Channels Disclaimer Bottom Sheet (SRS 7.2)
class LegalEmergencyDisclaimerSheet extends StatelessWidget {
  const LegalEmergencyDisclaimerSheet({super.key});

  Future<void> _dialNumber(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri);
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening phone dialer for $number…'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const emergencyNumbers = <Map<String, String>>[
      {
        'number': '112',
        'title': '112 • National Emergency Response (ERSS)',
        'subtitle': 'Immediate police, ambulance & field dispatch across India',
      },
      {
        'number': '1091',
        'title': '1091 • Women in Distress Police Helpline',
        'subtitle': '24×7 dedicated women safety police control room',
      },
      {
        'number': '181',
        'title': '181 • Abhayam / Sakhi One-Stop Women Helpline',
        'subtitle': 'Domestic abuse, shelter, legal & counselling assistance',
      },
      {
        'number': '1930',
        'title': '1930 • National Cybercrime Reporting Helpline',
        'subtitle': 'Blackmail, morphing, financial extortion & cyber stalking',
      },
      {
        'number': '7827170170',
        'title': '7827-170-170 • National Commission for Women (NCW)',
        'subtitle': 'Statutory women rights & POSH escalation helpline',
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8C2E3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDE4EC),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.gavel_rounded,
                    color: Color(0xFFB81D3B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Official Police, Legal & Emergency Channels',
                        style: AppTypography.sectionTitle.copyWith(
                          fontSize: 18,
                        ),
                      ),
                      const Text(
                        'Mandatory SRS Section 7.2 Transparency Notice',
                        style: AppTypography.subtitle,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEC584)),
              ),
              child: const Text(
                '• Submitting a complaint inside Sakhi triggers platform safety review, account/post moderation, and support guidance.\n'
                '• It does NOT automatically register a Police First Information Report (FIR) under Bharatiya Nagarik Suraksha Sanhita (BNSS) or dispatch emergency vehicles.\n'
                '• If you face immediate physical danger, please trigger Sakhi SOS or call 112 / 1091 directly below.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: Color(0xFF6B3A00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            ...emergencyNumbers.map((item) {
              final numStr = item['number']!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']!,
                              style: AppTypography.bodyMedium.copyWith(
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['subtitle']!,
                              style: AppTypography.subtitle.copyWith(
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC92A49),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () => _dialNumber(context, numStr),
                        icon: const Icon(Icons.call_rounded, size: 15),
                        label: Text(
                          'Dial $numStr',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const SafetyScreen(showBackButton: true),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shield_rounded, size: 16),
                    label: const Text('Open SOS Hub'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    key: const Key('m5-disclaimer-acknowledge-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('I Understand • Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet 06 — Anonymity & Technical Logs Transparency Bottom Sheet (SRS 7.4)
class AnonymityTransparencyBottomSheet extends StatelessWidget {
  const AnonymityTransparencyBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8C2E3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.primaryPurple,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sakhi Anonymity & Technical Log Transparency',
                    style: AppTypography.sectionTitle.copyWith(fontSize: 18),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Per SRS Section 7.4, Sakhi never makes misleading privacy promises. Here is the exact technical boundary between Anonymous and Confidential modes:',
              style: AppTypography.subtitle,
            ),
            const SizedBox(height: 14),
            _buildRow(
              attribute: 'Visible to Reported User / Public',
              anonVal: 'NEVER (0%)',
              confVal: 'NEVER (0%)',
            ),
            _buildRow(
              attribute: 'Visible to Standard Moderators',
              anonVal: 'NEVER (Zero User ID)',
              confVal: 'MASKED (Redacted)',
            ),
            _buildRow(
              attribute: 'Visible to Senior Safety Reviewer',
              anonVal: 'NO (Only #SKH-ANON Token)',
              confVal: 'YES (For Direct Follow-up)',
            ),
            _buildRow(
              attribute: 'Evidence EXIF / GPS / Camera Tags',
              anonVal: 'Stripped Before Storage',
              confVal: 'Stripped Before Storage',
            ),
            _buildRow(
              attribute: 'Anti-Spam Technical Log',
              anonVal: 'Ephemeral 24h Blinded Hash',
              confVal: 'Encrypted Audit Record',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF1FAF5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFB7E1CB)),
              ),
              child: const Text(
                'Honest Technical Disclosure: To prevent automated bot attacks without identifying you, our gateway computes a one-way daily rotating blinded bucket hash that expires after 24 hours. Raw IP addresses and phone numbers are never written to anonymous complaint rows.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF1A5A3E),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got It • Back to Safe Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required String attribute,
    required String anonVal,
    required String confVal,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            attribute,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Anonymous: $anonVal',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Confidential: $confVal',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB8296B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Screen 22 — Quick-Exit Wellness Camouflage Screen
/// ("Evening Chamomile & Gratitude Journal" — zero complaint keywords on screen;
/// double-tap the subtle lotus icon in the header to return to Discreet Complaint Hub)
class QuickExitWellnessCamouflageScreen extends StatefulWidget {
  const QuickExitWellnessCamouflageScreen({super.key});

  @override
  State<QuickExitWellnessCamouflageScreen> createState() =>
      _QuickExitWellnessCamouflageScreenState();
}

class _QuickExitWellnessCamouflageScreenState
    extends State<QuickExitWellnessCamouflageScreen> {
  final TextEditingController _gratitudeCtrl = TextEditingController(
    text: '1. Warm cup of chamomile tea after a long afternoon\n2. Taking five slow mindful breaths\n3. Peaceful evening walk',
  );
  int _waterGlasses = 6;

  @override
  void dispose() {
    _gratitudeCtrl.dispose();
    super.dispose();
  }

  void _resumeDiscreetHub() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const DiscreetComplaintHubScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6FBF7),
        title: Row(
          children: [
            GestureDetector(
              key: const Key('m5-camouflage-secret-lotus'),
              onDoubleTap: _resumeDiscreetHub,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F2E8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.spa_rounded,
                  color: Color(0xFF2B6F56),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Evening Chamomile & Gratitude',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F4D3A),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Home'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Image.asset(
                  AppAssets.module5QuickExitChamomileJournal,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFE0F2E8),
                    child: const Icon(
                      Icons.local_cafe_rounded,
                      size: 48,
                      color: Color(0xFF2B6F56),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFCFE6D8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Calm Reflection',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F4D3A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Write three small moments that brought you peace today:',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF4F7363)),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _gratitudeCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF7FBF8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Hydration Tracker: $_waterGlasses / 8 glasses',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2B6F56),
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => setState(() {
                          if (_waterGlasses < 12) _waterGlasses++;
                        }),
                        child: const Text('+1 Glass'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton.icon(
                key: const Key('m5-camouflage-resume-button'),
                onPressed: _resumeDiscreetHub,
                icon: const Icon(
                  Icons.lock_open_rounded,
                  size: 14,
                  color: Color(0xFF6B8A7A),
                ),
                label: const Text(
                  'Double-tap the green lotus icon or tap here when safe to return',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B8A7A)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
