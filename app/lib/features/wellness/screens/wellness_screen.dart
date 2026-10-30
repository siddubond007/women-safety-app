import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_brand_header.dart';
import '../../../core/widgets/sakhi_dialogs.dart';
import '../../../core/widgets/sakhi_section_header.dart';
import '../../../shared/widgets/sakhi_crisp_art.dart';
import '../widgets/guided_meditation_card.dart';
import '../widgets/wellness_category_tile.dart';

/// Screen 4 — Wellness Hub (iOS 26 Liquid Glass & Zero Unwanted Grid Padding)
class WellnessScreen extends StatelessWidget {
  final bool showBackButton;
  final VoidCallback? onBackTap;

  const WellnessScreen({
    super.key,
    this.showBackButton = false,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 132),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showBackButton || Navigator.of(context).canPop())
                    IconButton(
                      tooltip: 'Back to Home',
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textPrimary,
                      onPressed: () {
                        if (onBackTap != null) {
                          onBackTap!();
                        } else if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  Expanded(
                    child: SakhiBrandHeader(
                      title: 'Wellness',
                      actions: [
                        IconButton(
                          icon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.primaryPurple,
                            size: 24,
                          ),
                          onPressed: () => SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Search wellness articles & guided audio.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Card: "Your Wellbeing Matters" with iOS 26 Liquid Glass specular border
                    Container(
                      height: 164,
                      decoration: BoxDecoration(
                        gradient: AppColors.wellnessBannerGradient,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.92),
                          width: 1.5,
                        ),
                        boxShadow: AppSpacing.cardShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          const Positioned(
                            right: 118,
                            top: -12,
                            child: SakhiBotanicalFlower(
                              type: SakhiFlowerType.orchidBranch,
                              width: 74,
                              height: 92,
                              opacity: 0.55,
                              angle: -0.15,
                            ),
                          ),
                          const Positioned(
                            right: -6,
                            bottom: -14,
                            child: SakhiBotanicalFlower(
                              type: SakhiFlowerType.peonySoft,
                              width: 84,
                              height: 102,
                              opacity: 0.68,
                              angle: -0.10,
                            ),
                          ),
                          const Positioned(
                            right: 4,
                            top: 6,
                            bottom: 0,
                            width: 150,
                            child: SakhiCrispHeroArt(
                              variant: 'wellness',
                              width: 150,
                              height: 158,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              20,
                              20,
                              145,
                              18,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Your Wellbeing\nMatters',
                                  style: AppTypography.heroTitle,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Explore tools and resources\nto feel better, every day.',
                                  style: AppTypography.subtitle.copyWith(
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.88,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    // 4 Wellness Category Tiles (2x2 Grid) — padding: EdgeInsets.zero
                    // prevents MediaQuery.padding.bottom from adding a 108px blank gap!
                    GridView.count(
                      padding: EdgeInsets.zero,
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.05,
                      children: [
                        WellnessCategoryTile(
                          title: 'Menstrual\nHealth',
                          icon: Icons.calendar_today_rounded,
                          iconBgColor: AppColors.pastelPink,
                          iconColor: const Color(0xFFD63E85),
                          flowerType: SakhiFlowerType.roseClassic,
                          onTap: () => SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Opening Menstrual Health tracker & guides.',
                          ),
                        ),
                        WellnessCategoryTile(
                          title: 'Mental\nWellness',
                          icon: Icons.favorite_outline_rounded,
                          iconBgColor: AppColors.pastelBlue,
                          iconColor: AppColors.infoBlue,
                          flowerType: SakhiFlowerType.lavenderSprig,
                          onTap: () => SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Opening Mental Wellness support hub.',
                          ),
                        ),
                        WellnessCategoryTile(
                          title: 'Fitness &\nNutrition',
                          icon: Icons.spa_outlined,
                          iconBgColor: AppColors.pastelMint,
                          iconColor: AppColors.wellnessGreen,
                          flowerType: SakhiFlowerType.eucalyptusSage,
                          onTap: () => SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Opening Fitness & Nutrition plans.',
                          ),
                        ),
                        WellnessCategoryTile(
                          title: 'Expert\nArticles',
                          icon: Icons.article_outlined,
                          iconBgColor: AppColors.pastelPeach,
                          iconColor: AppColors.amberAccent,
                          flowerType: SakhiFlowerType.cherryBlossom,
                          onTap: () => SakhiDialogs.showPrototypeSnackbar(
                            context,
                            'Opening verified Expert Articles.',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    SakhiSectionHeader(
                      title: "Today's Pick",
                      actionLabel: 'See all',
                      onActionTap: () => SakhiDialogs.showPrototypeSnackbar(
                        context,
                        'Viewing all daily wellness picks.',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Guided Meditation Card with Playback Toggle
                    const GuidedMeditationCard(),

                    const SizedBox(height: 16),
                    // Encouraging Message Card with Botanical Accents
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.88),
                            AppColors.pastelQuoteBg.withValues(alpha: 0.90),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.95),
                          width: 1.4,
                        ),
                        boxShadow: AppSpacing.cardShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          const Positioned(
                            left: -6,
                            bottom: -12,
                            child: SakhiBotanicalFlower(
                              type: SakhiFlowerType.babysBreath,
                              width: 56,
                              height: 70,
                              opacity: 0.45,
                              angle: 0.2,
                            ),
                          ),
                          const Positioned(
                            right: -6,
                            top: -12,
                            child: SakhiBotanicalFlower(
                              type: SakhiFlowerType.poppyBlush,
                              width: 56,
                              height: 70,
                              opacity: 0.45,
                              angle: -0.2,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                            child: Center(
                              child: Text(
                                '"You are stronger than you think,\nand you are not alone."',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.primaryPurple,
                                  fontStyle: FontStyle.italic,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
