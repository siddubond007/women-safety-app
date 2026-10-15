import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/assets/app_assets.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../../shared/widgets/sakhi_action_button.dart';
import '../../shared/widgets/sakhi_brand_logo.dart';
import '../../shared/widgets/sakhi_page_indicator.dart';

class SakhiOnboardingScreen extends StatefulWidget {
  const SakhiOnboardingScreen({super.key, required this.onGetStarted});

  /// Inject the destination from the app shell; no auth route exists yet.
  final VoidCallback onGetStarted;

  @override
  State<SakhiOnboardingScreen> createState() => _SakhiOnboardingScreenState();
}

class _SakhiOnboardingScreenState extends State<SakhiOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      artworkPath: AppAssets.onboardingWelcome,
      title: 'A Safer, Brighter\nTomorrow for Every Woman',
      description: 'Safety • Community • Wellness • Opportunities',
      alignment: Alignment(0, -0.02),
    ),
    _OnboardingSlide(
      artworkPath: AppAssets.onboardingSafety,
      title: 'Safety That Starts\nWith You',
      description: 'Explore practical guidance and support designed to help you feel more prepared and confident.',
      category: 'SAFETY & GUIDANCE',
      alignment: Alignment(0, -0.02),
    ),
    _OnboardingSlide(
      artworkPath: AppAssets.onboardingCommunity,
      title: 'Stronger, Together',
      description: 'A welcoming vision for wellbeing, community support, and new opportunities for every woman.',
      category: 'COMMUNITY & WELLBEING',
      alignment: Alignment(0, -0.02),
    ),
  ];

  void _goToPage(int page) {
    if (!mounted ||
        !_pageController.hasClients ||
        page < 0 ||
        page >= _slides.length ||
        page == _currentPage) {
      return;
    }
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
    );
  }

  void _skip() => _goToPage(_slides.length - 1);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentPage > 0) _goToPage(_currentPage - 1);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: SakhiColors.blush,
          body: PageView.builder(
            key: const Key('sakhi-onboarding-page-view'),
            controller: _pageController,
            itemCount: _slides.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (page) {
              if (mounted) setState(() => _currentPage = page);
            },
            itemBuilder: (context, index) => _SakhiOnboardingPage(
              slide: _slides[index],
              pageIndex: index,
              onSkip: _skip,
              onNext: () => _goToPage(index + 1),
              onPageSelected: _goToPage,
              onGetStarted: widget.onGetStarted,
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.artworkPath,
    required this.title,
    required this.description,
    required this.alignment,
    this.category,
  });

  final String artworkPath;
  final String title;
  final String description;
  final Alignment alignment;
  final String? category;
}

class _SakhiOnboardingPage extends StatelessWidget {
  const _SakhiOnboardingPage({
    required this.slide,
    required this.pageIndex,
    required this.onSkip,
    required this.onNext,
    required this.onPageSelected,
    required this.onGetStarted,
  });

  final _OnboardingSlide slide;
  final int pageIndex;
  final VoidCallback onSkip;
  final VoidCallback onNext;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final isLastPage = pageIndex == 2;
    final isSafetyPage = pageIndex == 1;
    final size = MediaQuery.sizeOf(context);
    final shortScreen = size.height < 740;
    final titleStyle = SakhiTypography.onboardingTitle.copyWith(
      fontSize: size.width < 360 ? 24 : (size.width < 400 ? 26 : 29),
    );
    final descriptionStyle = pageIndex == 0
        ? SakhiTypography.body
        : SakhiTypography.body.copyWith(
            color: SakhiColors.plum.withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            slide.artworkPath,
            key: Key('onboarding-artwork-$pageIndex'),
            fit: BoxFit.cover,
            alignment: slide.alignment,
            filterQuality: FilterQuality.high,
          ),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.42, 0.62, 0.82, 1.0],
                colors: [
                  Color(0x00FFF5FA),
                  Color(0x00FFF5FA),
                  Color(0x08FFF4F7),
                  Color(0x25FFF4F7),
                  Color(0x45FFF4F7),
                ],
              ),
            ),
          ),
        ),
        if (pageIndex > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size.height * (shortScreen ? 0.50 : 0.46),
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.0, 0.30, 1.0],
                    colors: [
                      Color(0x00FFF5FA),
                      Color(0x82FFF5FA),
                      Color(0xE8FFF5FA),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (isSafetyPage) ...[
          Positioned(
            top: size.height * (shortScreen ? 0.27 : 0.30),
            left: size.width * 0.025,
            width: size.width * 0.43,
            child: const _SafetyFeatureCallout(
              semanticsKey: Key('safety-callout-emergency-sos'),
              label: 'Emergency SOS',
              icon: Icons.phone_in_talk_rounded,
              accent: SakhiColors.pink,
              semanticsLabel: 'Emergency SOS introductory feature',
            ),
          ),
          Positioned(
            top: size.height * (shortScreen ? 0.21 : 0.24),
            right: size.width * 0.025,
            width: size.width * 0.43,
            child: const _SafetyFeatureCallout(
              semanticsKey: Key('safety-visual-cue'),
              label: 'Trusted Contacts',
              icon: Icons.people_alt_rounded,
              accent: SakhiColors.purple,
              semanticsLabel: 'Trusted Contacts introductory feature',
            ),
          ),
          Positioned(
            top: size.height * (shortScreen ? 0.36 : 0.41),
            left: size.width * 0.025,
            width: size.width * 0.43,
            child: const _SafetyFeatureCallout(
              semanticsKey: Key('safety-callout-find-nearby-help'),
              label: 'Find Nearby Help',
              icon: Icons.location_on_rounded,
              accent: SakhiColors.purple,
              semanticsLabel: 'Find Nearby Help introductory feature',
            ),
          ),
          Positioned(
            top: size.height * (shortScreen ? 0.33 : 0.38),
            right: size.width * 0.025,
            width: size.width * 0.43,
            child: const _SafetyFeatureCallout(
              semanticsKey: Key('safety-callout-report-concern'),
              label: 'Report a Concern',
              icon: Icons.chat_bubble_outline_rounded,
              accent: SakhiColors.pink,
              semanticsLabel: 'Report a Concern introductory feature',
            ),
          ),
        ],
        SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              SakhiSpacing.lg,
              SakhiSpacing.xs,
              SakhiSpacing.lg,
              shortScreen ? SakhiSpacing.xxs : SakhiSpacing.xs,
            ),
            child: Column(
              children: [
                Center(
                  child: SakhiBrandLogo(
                    width: shortScreen ? 126 : 142,
                    height: shortScreen ? 103 : 116,
                  ),
                ),
                Spacer(flex: shortScreen ? 2 : 4),
                if (slide.category != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SakhiSpacing.md,
                      vertical: SakhiSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(SakhiRadii.pill),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Text(
                      slide.category!,
                      textAlign: TextAlign.center,
                      style: SakhiTypography.categoryLabel,
                    ),
                  ),
                  const SizedBox(height: SakhiSpacing.md),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: titleStyle,
                  ),
                ),
                const SizedBox(height: SakhiSpacing.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    slide.description,
                    textAlign: TextAlign.center,
                    style: descriptionStyle,
                  ),
                ),
                const SizedBox(height: SakhiSpacing.md),
                SakhiPageIndicator(
                  currentPage: pageIndex,
                  onSelected: onPageSelected,
                ),
                const SizedBox(height: SakhiSpacing.xs),
                if (isLastPage)
                  SakhiPrimaryButton(
                    key: const Key('get-started-button'),
                    label: 'Get started',
                    onPressed: onGetStarted,
                    expand: true,
                  )
                else
                  Row(
                    children: [
                      TextButton(
                        key: const Key('skip-onboarding-button'),
                        onPressed: onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: SakhiColors.plum,
                          minimumSize: const Size(76, 54),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: size.width < 360 ? 132 : 150,
                        child: SakhiPrimaryButton(
                          key: const Key('next-onboarding-button'),
                          label: 'Next',
                          onPressed: onNext,
                          expand: true,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Decorative onboarding callout. It introduces a feature without implying
/// that an emergency service or external integration is already active.
class _SafetyFeatureCallout extends StatelessWidget {
  const _SafetyFeatureCallout({
    required this.semanticsKey,
    required this.label,
    required this.icon,
    required this.accent,
    required this.semanticsLabel,
  });

  final Key semanticsKey;
  final String label;
  final IconData icon;
  final Color accent;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: semanticsKey,
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: SakhiSpacing.xs,
            vertical: SakhiSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: const Color(0xF7FFFBFD),
            borderRadius: BorderRadius.circular(SakhiRadii.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.94)),
            boxShadow: [
              BoxShadow(
                color: SakhiColors.plum.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: SakhiSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: SakhiColors.plum,
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
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
