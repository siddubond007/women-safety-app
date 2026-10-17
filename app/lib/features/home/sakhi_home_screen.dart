import 'package:flutter/material.dart';

import '../../core/branding/app_brand.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/auth_service.dart';
import '../auth/sakhi_login_screen.dart';
import '../eligibility/eligibility_verification_models.dart';

/// The verified-member landing shell. It intentionally does not imply that
/// preview cards are live emergency, community, location, or wellness services.
/// Server APIs must independently enforce eligibility and authorization.
class SakhiHomeScreen extends StatefulWidget {
  const SakhiHomeScreen({
    super.key,
    required this.authService,
    required this.verifiedStatus,
  });

  final AuthService authService;
  final EligibilityStatusResult verifiedStatus;

  @override
  State<SakhiHomeScreen> createState() => _SakhiHomeScreenState();
}

class _SakhiHomeScreenState extends State<SakhiHomeScreen> {
  bool _isSigningOut = false;

  static const List<_HomeFeature> _features = [
    _HomeFeature(
      keyName: 'home-feature-safety-support',
      title: 'Safety & support',
      description: 'Practical guidance and resources for safer everyday choices.',
      icon: Icons.shield_outlined,
      accent: Color(0xFF8B4D9C),
      previewDetails:
          'This is a UI preview only. The related service and backend integration are not implemented yet. Emergency SOS, live location sharing and dispatch are not active in this build.',
    ),
    _HomeFeature(
      keyName: 'home-feature-trusted-contacts',
      title: 'Trusted contacts',
      description: 'Plan the people you may want to reach for support.',
      icon: Icons.favorite_border_rounded,
      accent: Color(0xFFC64C91),
      previewDetails:
          'Trusted-contact management and alert delivery are still being developed. No contact has been saved or notified from this preview.',
    ),
    _HomeFeature(
      keyName: 'home-feature-community',
      title: 'Community',
      description: 'A future space for verified-member conversations and updates.',
      icon: Icons.diversity_3_outlined,
      accent: Color(0xFFB25A96),
      previewDetails:
          'The community feed, posts, comments, messaging, reporting and moderation are not active yet. This preview does not publish or retrieve community content.',
    ),
    _HomeFeature(
      keyName: 'home-feature-wellness',
      title: 'Wellness',
      description: 'Wellbeing resources designed with privacy in mind.',
      icon: Icons.spa_outlined,
      accent: Color(0xFF9A6CB3),
      previewDetails:
          'Wellness content, private reminders and health-related features are not connected in this build. No health information or reminders are created here.',
    ),
    _HomeFeature(
      keyName: 'home-feature-business-discovery',
      title: 'Discover businesses',
      description: 'Explore a future directory of women-owned businesses.',
      icon: Icons.storefront_outlined,
      accent: Color(0xFF7A5CA5),
      previewDetails:
          'Business discovery, listings, products, services and enquiries are not connected yet. No listing data is being searched or displayed.',
    ),
    _HomeFeature(
      keyName: 'home-feature-report-concern',
      title: 'Report a concern',
      description: 'Learn about the planned reporting and support workflow.',
      icon: Icons.flag_outlined,
      accent: Color(0xFFB84769),
      previewDetails:
          'The reporting workflow is not available in this build. This preview does not send a report or alert any responder.',
    ),
  ];

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    String? warning;

    try {
      await widget.authService.logout();
    } catch (_) {
      warning =
          'The local session was cleared as far as this client could, but the backend could not confirm sign-out.';
    }

    if (!mounted) return;
    setState(() => _isSigningOut = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (loginContext) {
          if (warning != null) {
            final message = warning;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (loginContext.mounted) {
                ScaffoldMessenger.maybeOf(loginContext)?.showSnackBar(
                  SnackBar(content: Text(message)),
                );
              }
            });
          }
          return SakhiLoginScreen(authService: widget.authService);
        },
      ),
      (_) => false,
    );
  }

  void _openPreview(_HomeFeature feature) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _HomeFeaturePreviewScreen(feature: feature),
      ),
    );
  }

  bool get _hasTrustedVerifiedStatus =>
      verifiedStatus.status == EligibilityStatus.verified &&
      !verifiedStatus.isDemo;

  @override
  Widget build(BuildContext context) {
    if (!_hasTrustedVerifiedStatus) {
      return Scaffold(
        backgroundColor: SakhiColors.blush,
        appBar: AppBar(
          backgroundColor: SakhiColors.blush,
          title: const Text(AppBrand.appName),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SakhiSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  color: SakhiColors.purple,
                  size: 44,
                ),
                const SizedBox(height: SakhiSpacing.md),
                const Text(
                  'Sakhi Home is not available',
                  textAlign: TextAlign.center,
                  style: SakhiTypography.onboardingTitle,
                ),
                const SizedBox(height: SakhiSpacing.sm),
                const Text(
                  'This screen requires a current, non-demo Verified status from the trusted backend. No protected area was opened.',
                  textAlign: TextAlign.center,
                  style: SakhiTypography.body,
                ),
                const SizedBox(height: SakhiSpacing.md),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SakhiColors.blush,
      appBar: AppBar(
        backgroundColor: SakhiColors.blush,
        titleSpacing: SakhiSpacing.md,
        title: Row(
          children: [
            Image.asset(
              AppBrand.logoAsset,
              key: const Key('home-sakhi-logo'),
              height: 34,
              width: 106,
              fit: BoxFit.contain,
              semanticLabel: AppBrand.logoSemanticsLabel,
              errorBuilder: (context, error, stackTrace) => Text(
                AppBrand.appName,
                style: const TextStyle(
                  color: SakhiColors.plum,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('home-sign-out-button'),
            tooltip: _isSigningOut ? 'Signing out' : 'Sign out',
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: SakhiSpacing.xs),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 860
                ? 3
                : constraints.maxWidth >= 560
                ? 3
                : 2;
            return ListView(
              key: const Key('sakhi-home-dashboard-list'),
              padding: const EdgeInsets.fromLTRB(
                SakhiSpacing.md,
                SakhiSpacing.sm,
                SakhiSpacing.md,
                SakhiSpacing.xl,
              ),
              children: [
                Container(
                  padding: const EdgeInsets.all(SakhiSpacing.lg),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF0DDF7),
                        Color(0xFFFFE8F0),
                        Color(0xFFFFF8F4),
                      ],
                    ),
                    border: Border.all(
                      color: SakhiColors.progressInactive.withValues(alpha: 0.65),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SakhiSpacing.sm,
                          vertical: SakhiSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.78),
                          borderRadius: BorderRadius.circular(SakhiRadii.pill),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              color: SakhiColors.purple,
                              size: 15,
                            ),
                            SizedBox(width: SakhiSpacing.xs),
                            Text(
                              'SAFETY · COMMUNITY · WELLNESS',
                              style: TextStyle(
                                color: SakhiColors.plum,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.75,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: SakhiSpacing.md),
                      const Text(
                        'A space that supports you.',
                        style: SakhiTypography.onboardingTitle,
                      ),
                      const SizedBox(height: SakhiSpacing.xs),
                      const Text(
                        'Find your next step, explore what Sakhi is building, and keep your safety choices in your hands.',
                        style: SakhiTypography.body,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SakhiSpacing.md),
                Container(
                  key: const Key('home-verified-status-card'),
                  padding: const EdgeInsets.all(SakhiSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFB9DCC8),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6EF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF286749),
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: SakhiSpacing.sm),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Eligibility verified',
                              style: TextStyle(
                                color: SakhiColors.plum,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: SakhiSpacing.xxs),
                            Text(
                              'Sakhi confirmed the current status with its backend. Protected services must also check access on the server.',
                              style: TextStyle(
                                color: SakhiColors.mutedPlum,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SakhiSpacing.lg),
                const Text(
                  'Explore Sakhi',
                  style: TextStyle(
                    color: SakhiColors.plum,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: SakhiSpacing.xxs),
                const Text(
                  'These areas are previews while their services are being built.',
                  style: SakhiTypography.body,
                ),
                const SizedBox(height: SakhiSpacing.md),
                GridView.builder(
                  key: const Key('home-feature-grid'),
                  itemCount: _features.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: SakhiSpacing.sm,
                    mainAxisSpacing: SakhiSpacing.sm,
                    childAspectRatio: constraints.maxWidth < 360 ? 0.78 : 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final feature = _features[index];
                    return _HomeFeatureTile(
                      feature: feature,
                      onTap: () => _openPreview(feature),
                    );
                  },
                ),
                const SizedBox(height: SakhiSpacing.md),
                Container(
                  key: const Key('home-development-boundary'),
                  padding: const EdgeInsets.all(SakhiSpacing.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0E5),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFFF0D1B7)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF8C4D23),
                        size: 21,
                      ),
                      SizedBox(width: SakhiSpacing.sm),
                      Expanded(
                        child: Text(
                          'Development preview only. Emergency SOS, live location, incident reporting, community publishing and wellness services are not active. Do not rely on this build for emergency assistance.',
                          style: TextStyle(
                            color: Color(0xFF78431F),
                            fontSize: 12.5,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeFeature {
  const _HomeFeature({
    required this.keyName,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.previewDetails,
  });

  final String keyName;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final String previewDetails;
}

class _HomeFeatureTile extends StatelessWidget {
  const _HomeFeatureTile({
    required this.feature,
    required this.onTap,
  });

  final _HomeFeature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key(feature.keyName),
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Padding(
          padding: const EdgeInsets.all(SakhiSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: feature.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(feature.icon, color: feature.accent, size: 25),
              ),
              const Spacer(),
              Text(
                feature.title,
                style: const TextStyle(
                  color: SakhiColors.plum,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: SakhiSpacing.xxs),
              Text(
                feature.description,
                style: const TextStyle(
                  color: SakhiColors.mutedPlum,
                  fontSize: 11.5,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: SakhiSpacing.xs),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: feature.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: SakhiSpacing.xxs),
                  const Text(
                    'PREVIEW',
                    style: TextStyle(
                      color: SakhiColors.mutedPlum,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeFeaturePreviewScreen extends StatelessWidget {
  const _HomeFeaturePreviewScreen({required this.feature});

  final _HomeFeature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakhiColors.blush,
      appBar: AppBar(
        backgroundColor: SakhiColors.blush,
        title: Text('${feature.title} preview'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SakhiSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              padding: const EdgeInsets.all(SakhiSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: SakhiColors.progressInactive.withValues(alpha: 0.75),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: feature.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      feature.icon,
                      color: feature.accent,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: SakhiSpacing.md),
                  Text(
                    feature.title,
                    textAlign: TextAlign.center,
                    style: SakhiTypography.onboardingTitle.copyWith(fontSize: 23),
                  ),
                  const SizedBox(height: SakhiSpacing.sm),
                  Text(
                    feature.previewDetails,
                    textAlign: TextAlign.center,
                    style: SakhiTypography.body,
                  ),
                  const SizedBox(height: SakhiSpacing.lg),
                  FilledButton.tonalIcon(
                    key: const Key('home-preview-back-button'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Back to Sakhi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
