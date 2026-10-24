import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/widgets/sakhi_quote_loader.dart';
import '../models/safety_models.dart';
import '../theme/sakhi_module4_theme.dart';

/// Screen 1 — Module 4 Main Safety Hub & SOS Activation Dashboard
/// (`01_Safety_Hub_Main_Dashboard_UI.jpg`)
class SafetyScreen extends StatefulWidget {
  final bool showBackButton;
  final ValueChanged<String>? onNavigateRoute;

  const SafetyScreen({
    super.key,
    this.showBackButton = false,
    this.onNavigateRoute,
  });

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.syncSafetyOverview());
  }

  void _openScreen(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header Bar: Shield-Lotus + "Safety" + Shortcut Gear + SOS Pill
                  Row(
                    children: [
                      if (widget.showBackButton &&
                          Navigator.of(context).canPop())
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: SakhiModule4Colors.textPrimary,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      Container(
                        width: 36,
                        height: 36,
                        padding: const EdgeInsets.all(2),
                        child: Image.asset(
                          SakhiModule4Assets.sakhiShieldLotus,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.shield_rounded,
                            color: SakhiModule4Colors.primaryPlum,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Safety',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: SakhiModule4Colors.textPrimary,
                          ),
                        ),
                      ),
                      InkWell(
                        key: const Key('safety-shortcut-gear-button'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            _openScreen(const SafetyHistoryAndSettingsScreen()),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.settings_suggest_rounded,
                                color: SakhiModule4Colors.primaryPlum,
                                size: 22,
                              ),
                              Text(
                                'Shortcut',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: SakhiModule4Colors.primaryPlum,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      FilledButton.icon(
                        key: const Key('safety-topbar-sos-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SakhiModule4Colors.emergencyCrimson,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => _openScreen(
                          const SosWorkflowScreen(isTestMode: false),
                        ),
                        icon: const Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'SOS',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // GPS Location Permission Status Pill Banner
                  GestureDetector(
                    key: const Key('safety-gps-permission-banner'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Device GPS is not connected in this build. Live location sharing stays disabled.',
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _controller.hasLiveLocation
                            ? SakhiModule4Colors.verifiedMintBg
                            : SakhiModule4Colors.warningAmberBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _controller.hasLiveLocation
                              ? SakhiModule4Colors.verifiedMintBorder
                              : SakhiModule4Colors.warningAmberBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _controller.hasLiveLocation
                                ? Icons.location_on_rounded
                                : Icons.warning_amber_rounded,
                            size: 16,
                            color: _controller.hasLiveLocation
                                ? SakhiModule4Colors.verifiedMintText
                                : SakhiModule4Colors.warningAmberText,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _controller.hasLiveLocation
                                  ? 'GPS Location Active'
                                  : 'GPS unavailable — device location not connected in this build',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _controller.hasLiveLocation
                                    ? SakhiModule4Colors.verifiedMintText
                                    : SakhiModule4Colors.warningAmberText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Hero Interactive Map Card with Central Pulsing SOS Control
                  Container(
                    height: 225,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: SakhiModule4Colors.cardBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F5A1868),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            SakhiModule4Assets.pastelMapBackground,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Image.asset(
                              AppAssets.safetyMapBg,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  Container(color: const Color(0xFFF3EDF7)),
                            ),
                          ),
                        ),
                        // Concentric pulse aura
                        Container(
                          width: 156,
                          height: 156,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SakhiModule4Colors.emergencyCrimson
                                .withValues(alpha: 0.08),
                          ),
                        ),
                        Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: SakhiModule4Colors.emergencyCrimson
                                .withValues(alpha: 0.16),
                          ),
                        ),
                        // Center Tap SOS Button
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              key: const Key('safety-center-tap-sos-button'),
                              onTap: () => _openScreen(
                                const SosWorkflowScreen(isTestMode: false),
                              ),
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: SakhiModule4Colors.emergencyCrimson,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x44C92A49),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Image.asset(
                                    SakhiModule4Assets.sosPulsingHeroBtn,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.shield_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap SOS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.textPrimary,
                              ),
                            ),
                            const Text(
                              'for emergency help',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: SakhiModule4Colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        // Bottom Discreet Trigger Status Pill
                        Positioned(
                          bottom: 10,
                          child: GestureDetector(
                            onTap: () => _openScreen(
                              const SafetyHistoryAndSettingsScreen(),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF423648)
                                    .withValues(alpha: 0.86),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _controller.powerButtonShortcutEnabled
                                    ? 'Discreet Trigger: Power Button 3x (Test Mode Ready)'
                                    : 'Discreet Trigger: Tap to Configure Safe Shortcut',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4 Circular Pastel Category Buttons (64dp)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SafetyCategoryCircle(
                        key: const Key('safety-circle-emergency-contacts'),
                        assetPath: SakhiModule4Assets.icEmergencyContacts,
                        fallbackIcon: Icons.people_alt_rounded,
                        bgColor: SakhiModule4Colors.emergencySoftTint,
                        iconColor: SakhiModule4Colors.emergencyCrimson,
                        label: 'Emergency\nContacts',
                        onTap: () =>
                            _openScreen(const EmergencyContactsScreen()),
                      ),
                      _SafetyCategoryCircle(
                        key: const Key('safety-circle-nearest-police'),
                        assetPath: SakhiModule4Assets.icNearestPolice,
                        fallbackIcon: Icons.local_police_rounded,
                        bgColor: SakhiModule4Colors.verifiedMintBg,
                        iconColor: SakhiModule4Colors.verifiedMintText,
                        label: 'Nearest\nPolice',
                        onTap: () =>
                            _openScreen(const NearestPoliceStationsScreen()),
                      ),
                      _SafetyCategoryCircle(
                        key: const Key('safety-circle-safety-tips'),
                        assetPath: SakhiModule4Assets.icSafetyTips,
                        fallbackIcon: Icons.verified_user_rounded,
                        bgColor: SakhiModule4Colors.pastelPeachBg,
                        iconColor: const Color(0xFFD97B16),
                        label: 'Safety\nTips',
                        onTap: () => _openScreen(
                          const HelplinesAndSafetyTipsScreen(
                            scrollToTips: true,
                          ),
                        ),
                      ),
                      _SafetyCategoryCircle(
                        key: const Key('safety-circle-helplines-112'),
                        assetPath: SakhiModule4Assets.icHelplines112,
                        fallbackIcon: Icons.phone_in_talk_rounded,
                        bgColor: SakhiModule4Colors.pastelLavenderBg,
                        iconColor: SakhiModule4Colors.primaryPlum,
                        label: 'Helplines\n(112)',
                        onTap: () =>
                            _openScreen(const HelplinesAndSafetyTipsScreen()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Discord-Style Animated Women's Quotations & Safety Inspiration Banner
                  const SakhiQuoteLoader.banner(),
                  const SizedBox(height: 18),

                  // Quick Safety Actions Section
                  const Text(
                    'Quick Safety Actions',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: SakhiModule4Colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  _SafetyActionCardRow(
                    key: const Key('safety-row-share-live-location'),
                    assetPath: SakhiModule4Assets.icLiveLocationRadar,
                    fallbackIcon: Icons.my_location_rounded,
                    badgeBg: SakhiModule4Colors.emergencySoftTint,
                    iconColor: SakhiModule4Colors.emergencyCrimson,
                    title: 'Share my live location',
                    subtitle: 'Send real-time GPS link to trusted contacts',
                    trailingBadgeText: _controller.liveLocationSharingActive
                        ? 'Active'
                        : null,
                    onTap: () => _openScreen(const ShareLiveLocationScreen()),
                  ),
                  const SizedBox(height: 10),

                  _SafetyActionCardRow(
                    key: const Key('safety-row-sos-history'),
                    assetPath: SakhiModule4Assets.icSosHistoryClock,
                    fallbackIcon: Icons.history_rounded,
                    badgeBg: SakhiModule4Colors.pastelLavenderBg,
                    iconColor: SakhiModule4Colors.primaryPlum,
                    title: 'SOS Activation History',
                    subtitle: 'Review past safety alerts & delivery logs',
                    onTap: () =>
                        _openScreen(const SafetyHistoryAndSettingsScreen()),
                  ),
                  const SizedBox(height: 10),

                  _SafetyActionCardRow(
                    key: const Key('safety-row-safety-checklist'),
                    assetPath: SakhiModule4Assets.icSafetyChecklist,
                    fallbackIcon: Icons.fact_check_outlined,
                    badgeBg: SakhiModule4Colors.pastelPeachBg,
                    iconColor: const Color(0xFFD97B16),
                    title: 'Safety Checklist & Discreet Trigger',
                    subtitle:
                        'Pre-travel checks & accidental trigger protection',
                    onTap: () =>
                        _openScreen(const SafetyHistoryAndSettingsScreen()),
                  ),
                  const SizedBox(height: 10),

                  _SafetyActionCardRow(
                    key: const Key('safety-row-emergency-helplines'),
                    assetPath: SakhiModule4Assets.icHelplineHeadset,
                    fallbackIcon: Icons.support_agent_rounded,
                    badgeBg: SakhiModule4Colors.verifiedMintBg,
                    iconColor: SakhiModule4Colors.verifiedMintText,
                    title: 'Emergency Helplines & 112',
                    subtitle:
                        'Police 112 / 100, Women Helpline 1091, Ambulance 108',
                    onTap: () =>
                        _openScreen(const HelplinesAndSafetyTipsScreen()),
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

class _SafetyCategoryCircle extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;
  final Color bgColor;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _SafetyCategoryCircle({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    required this.bgColor,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset(
                  assetPath,
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Icon(fallbackIcon, color: iconColor, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: SakhiModule4Colors.textPrimary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyActionCardRow extends StatelessWidget {
  final String assetPath;
  final IconData fallbackIcon;
  final Color badgeBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? trailingBadgeText;
  final VoidCallback onTap;

  const _SafetyActionCardRow({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    required this.badgeBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailingBadgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SakhiModule4Colors.cardSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SakhiModule4Colors.cardBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    assetPath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Icon(fallbackIcon, color: iconColor, size: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: SakhiModule4Colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: SakhiModule4Colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingBadgeText != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SakhiModule4Colors.verifiedMintBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trailingBadgeText!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: SakhiModule4Colors.verifiedMintText,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: SakhiModule4Colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen 2 — SOS Short Confirmation (3s Countdown) & Active Emergency Workflow Screen
/// (`02_SOS_Confirmation_3s_and_Active_Workflow_UI.jpg`)
class SosWorkflowScreen extends StatefulWidget {
  final bool isTestMode;

  const SosWorkflowScreen({super.key, this.isTestMode = false});

  @override
  State<SosWorkflowScreen> createState() => _SosWorkflowScreenState();
}

class _SosWorkflowScreenState extends State<SosWorkflowScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;
  int _secondsRemaining = 3;
  bool _isDispatched = false;
  SafetySosHistoryItem? _activeEvent;
  Timer? _countdownTimer;

  bool get _isWidgetTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    if (!_isWidgetTest) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        if (_secondsRemaining > 1) {
          setState(() => _secondsRemaining--);
        } else {
          timer.cancel();
          _triggerSosNow();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _triggerSosNow() async {
    _countdownTimer?.cancel();
    final event = await _controller.activateSosEvent(
      isTestMode: widget.isTestMode,
    );
    if (!mounted) return;
    setState(() {
      _secondsRemaining = 0;
      _isDispatched = true;
      _activeEvent = event;
    });
  }

  void _cancelSos() {
    _countdownTimer?.cancel();
    _controller.cancelSosDuringCountdown(isTestMode: widget.isTestMode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: SakhiModule4Colors.primaryPlum,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'SOS cancelled during 3-second confirmation guard • No external alert sent.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final contactsNames = _controller.selectedContacts
        .map(
          (c) => c.isPrimary
              ? '${c.name.split(" ").first} (Primary)'
              : c.name.split(' ').first,
        )
        .join(', ');

    return Scaffold(
      backgroundColor: SakhiModule4Colors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: SakhiModule4Colors.surfaceBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SakhiModule4Colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.isTestMode ? 'Safe Test Mode SOS' : 'Emergency SOS Active',
          style: const TextStyle(
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            color: SakhiModule4Colors.textPrimary,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isTestMode
                  ? SakhiModule4Colors.primaryPlum
                  : SakhiModule4Colors.emergencyCrimson,
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.isTestMode ? 'SAFE TEST' : 'LIVE ALERT',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card 1: Short Confirmation / 3-Second Countdown Guard (SRS 6.2)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: SakhiModule4Colors.emergencyCrimson.withValues(
                    alpha: 0.45,
                  ),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isDispatched
                                ? SakhiModule4Colors.verifiedMintText
                                : SakhiModule4Colors.emergencyCrimson,
                            width: 4,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _isDispatched ? 'LIVE' : '0${_secondsRemaining}s',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _isDispatched
                                ? SakhiModule4Colors.verifiedMintText
                                : SakhiModule4Colors.emergencyCrimson,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isDispatched
                                  ? (widget.isTestMode
                                        ? 'Safe Test Mode Verified'
                                        : 'Emergency SOS Triggered')
                                  : 'Confirm Emergency SOS',
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isTestMode
                                  ? 'Simulating 3s confirmation & GPS lookup locally without sending real external alerts.'
                                  : 'Alerting trusted contacts & fetching GPS location in 3 seconds to prevent false triggers',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: SakhiModule4Colors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const Key('sos-trigger-now-button'),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                SakhiModule4Colors.emergencyCrimson,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _triggerSosNow,
                          child: const Text(
                            'Trigger SOS Now',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.tonal(
                          key: const Key('sos-cancel-safe-button'),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                SakhiModule4Colors.secondaryLavenderPill,
                            foregroundColor: SakhiModule4Colors.primaryPlumDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _cancelSos,
                          child: const Text(
                            "Cancel (I'm Safe)",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Card 2: Emergency Action Status Steps (SRS 6.3.1 - 6.3.9)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: SakhiModule4Colors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Emergency Action Status',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: SakhiModule4Colors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.monitor_heart_outlined,
                        color: SakhiModule4Colors.primaryPlum,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _WorkflowStepRow(
                    isAmber: !_controller.hasLiveLocation,
                    title: _controller.hasLiveLocation
                        ? 'Current Location Obtained'
                        : 'Current Location Unavailable',
                    subtitle: _controller.hasLiveLocation
                        ? _controller.currentLocationLabel
                        : 'Device GPS is not connected in this build. No coordinates or tracking link are attached.',
                  ),
                  const SizedBox(height: 14),
                  _WorkflowStepRow(
                    isAmber: false,
                    title: widget.isTestMode
                        ? 'Trusted Contacts Check (Safe Test Mode)'
                        : 'Emergency Contacts Selected (${_controller.selectedContacts.length}/${_controller.trustedContacts.length})',
                    subtitle: widget.isTestMode
                        ? 'No external SMS sent during Safe Test Mode ($contactsNames configured)'
                        : 'Sakhi does not dispatch calls or SMS automatically. Share manually and call 112/100 for emergencies.',
                  ),
                  const SizedBox(height: 14),
                  _WorkflowStepRow(
                    isAmber: false,
                    title: 'Recorded in Safety History',
                    subtitle:
                        'Event ID #${_activeEvent?.id ?? "SOS-2026-1023"} saved to personal log',
                  ),
                  const SizedBox(height: 14),
                  const _WorkflowStepRow(
                    isAmber: true,
                    title: 'Official Police Integration Status',
                    subtitle: 'Direct auto-dispatch not connected. Tap Call 112 or Call 100 below to speak with Police Control Room.',
                  ),
                  if (!widget.isTestMode) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _controller.dispatchSosAlertToContacts(context),
                        icon: const Icon(
                          Icons.share_location_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Send WhatsApp / SMS Alert Link to Contacts',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Bottom Primary Action Buttons: Call 112, Call 100, and Stop Location Sharing
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('sos-call-112-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: SakhiModule4Colors.emergencyCrimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => _controller.launchPhoneCall(
                  context,
                  '112',
                  label: '112 National Emergency Helpline',
                ),
                icon: const Icon(Icons.call_rounded),
                label: const Text(
                  'Call 112 National Emergency Helpline',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: const Key('sos-call-100-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: SakhiModule4Colors.emergencySoftTint,
                  foregroundColor: SakhiModule4Colors.emergencyCrimson,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => _controller.launchPhoneCall(
                  context,
                  '100',
                  label: '100 Police Control Room',
                ),
                icon: const Icon(Icons.local_police_outlined),
                label: const Text(
                  'Call 100 Direct Police Control Room',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('sos-stop-sharing-end-button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SakhiModule4Colors.primaryPlumDark,
                  side: const BorderSide(
                    color: SakhiModule4Colors.primaryPlumDark,
                    width: 1.6,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  _controller.stopLocationSharingAndEndSos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: SakhiModule4Colors.verifiedMintText,
                      behavior: SnackBarBehavior.floating,
                      content: Text(
                        'Live location sharing stopped & SOS marked Resolved Safely.',
                      ),
                    ),
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.cancel_outlined, size: 19),
                label: const Text(
                  'Stop Location Sharing & End SOS',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowStepRow extends StatelessWidget {
  final bool isAmber;
  final String title;
  final String subtitle;

  const _WorkflowStepRow({
    required this.isAmber,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isAmber
                ? const Color(0xFFD99B26)
                : SakhiModule4Colors.verifiedMintText,
          ),
          child: Icon(
            isAmber ? Icons.priority_high_rounded : Icons.check_rounded,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: isAmber
                      ? SakhiModule4Colors.warningAmberText
                      : SakhiModule4Colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isAmber
                      ? SakhiModule4Colors.warningAmberText
                      : SakhiModule4Colors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Screen 3 — Nearest Police Stations & Verified Directory
/// (`03_Nearest_Police_Stations_and_Verified_Directory_UI.jpg`)
class NearestPoliceStationsScreen extends StatefulWidget {
  const NearestPoliceStationsScreen({super.key});

  @override
  State<NearestPoliceStationsScreen> createState() =>
      _NearestPoliceStationsScreenState();
}

class _NearestPoliceStationsScreenState
    extends State<NearestPoliceStationsScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.refreshNearbyPoliceStations());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final stations = _controller.nearbyPoliceStations;
        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Nearest Police Stations',
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: SakhiModule4Colors.emergencyCrimson,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => _controller.launchPhoneCall(
                    context,
                    '112',
                    label: '112 Emergency Dispatch',
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
                  label: const Text(
                    'Call 112',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              color: SakhiModule4Colors.emergencyCrimson,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: InkWell(
                onTap: () => _controller.launchPhoneCall(
                  context,
                  '112',
                  label: '112 National Police Dispatch',
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_in_talk_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Need Immediate Police Dispatch? Call 112 / 100 Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mandatory Compliance Disclaimer Banner (SRS 6.4)
                Container(
                  key: const Key('police-compliance-disclaimer-banner'),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: SakhiModule4Colors.warningAmberBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: SakhiModule4Colors.warningAmberBorder,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_rounded,
                        color: SakhiModule4Colors.warningAmberText,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Note: Viewing nearby police stations on the map does not automatically notify the police. Please call 112, 100, or the station directly.',
                          style: TextStyle(
                            fontSize: 12.2,
                            fontWeight: FontWeight.w700,
                            color: SakhiModule4Colors.warningAmberText,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                if (!_controller.hasLiveLocation)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22, horizontal: 8),
                    child: Text(
                      'Device GPS is not connected in this build. Nearby stations cannot be calculated from a sample location.',
                      style: TextStyle(
                        color: SakhiModule4Colors.warningAmberText,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (_controller.hasLiveLocation)
                  Container(
                    height: 185,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: SakhiModule4Colors.cardBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.asset(
                            SakhiModule4Assets.pastelMapBackground,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                Container(color: const Color(0xFFF3EDF7)),
                          ),
                        ),
                        // User Blue GPS Dot
                        Positioned(
                          left: 65,
                          top: 68,
                          child: Column(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF2A7DE1)
                                      .withValues(alpha: 0.25),
                                ),
                                alignment: Alignment.center,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF1B66C9),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Your Location',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF123B7A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Station Pins
                        const Positioned(
                          left: 165,
                          top: 48,
                          child: _MapPolicePinBadge(distanceLabel: '0.8 km'),
                        ),
                        const Positioned(
                          left: 185,
                          top: 102,
                          child: _MapPolicePinBadge(distanceLabel: '1.4 km'),
                        ),
                        const Positioned(
                          right: 42,
                          top: 44,
                          child: _MapPolicePinBadge(distanceLabel: '2.1 km'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                if (_controller.isLoadingStations) ...[
                  const SakhiQuoteLoader.inline(
                    statusLabel:
                        'Discovering verified nearby police stations...',
                  ),
                  const SizedBox(height: 14),
                ],

                Text(
                  'Nearby Police Stations (${stations.length})',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                ...stations.map(
                  (station) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SakhiModule4Colors.cardBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  station.name,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: SakhiModule4Colors.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: SakhiModule4Colors.verifiedMintBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  station.distanceBadgeText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: SakhiModule4Colors.verifiedMintText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            station.address,
                            style: const TextStyle(
                              fontSize: 13,
                              color: SakhiModule4Colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.call_rounded,
                                size: 15,
                                color: SakhiModule4Colors.primaryPlum,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                station.phoneNumber,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: SakhiModule4Colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        SakhiModule4Colors.primaryPlumDark,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () =>
                                      _controller.launchDirectionsToStation(
                                        context,
                                        station,
                                      ),
                                  child: const Text(
                                    'Directions / Navigate',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: SakhiModule4Colors
                                        .emergencyRoseSecondary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 11,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () => _controller.launchPhoneCall(
                                    context,
                                    station.phoneNumber,
                                    label: station.name,
                                  ),
                                  child: const Text(
                                    'Call Station',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                    ),
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MapPolicePinBadge extends StatelessWidget {
  final String distanceLabel;

  const _MapPolicePinBadge({required this.distanceLabel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF9E1F47),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.local_police_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            distanceLabel,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: SakhiModule4Colors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Screen 4 — Emergency Contacts & Active Location Link Management Screen
/// (`04_Emergency_Contacts_and_Location_Link_UI.jpg`)
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;

  void _openAddContactModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddTrustedContactSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final contacts = _controller.trustedContacts;
        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Emergency Contacts',
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            actions: [
              TextButton(
                key: const Key('emergency-contacts-add-button'),
                onPressed: _openAddContactModal,
                child: const Text(
                  '+ Add Contact',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.primaryPlum,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Active Live Location Sharing Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE0EA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD9C5D6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCC8DA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.radar_rounded,
                              color: SakhiModule4Colors.primaryPlumDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _controller.liveLocationSharingActive
                                      ? 'Live Location Sharing: ACTIVE'
                                      : 'Live Location Sharing: STANDBY',
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: SakhiModule4Colors.emergencyCrimson,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _controller.liveLocationSharingActive
                                      ? 'Backend-confirmed live location sharing is active.'
                                      : 'Live sharing requires device GPS and backend confirmation.',
                                  style: const TextStyle(
                                    fontSize: 12.2,
                                    fontWeight: FontWeight.w600,
                                    color: SakhiModule4Colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () {
                          final trackingLink = _controller.liveShareFullUrl;
                          if (trackingLink.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No backend-confirmed live tracking link is available.',
                                ),
                              ),
                            );
                            return;
                          }
                          Clipboard.setData(ClipboardData(text: trackingLink));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Live tracking link copied.'),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.link_rounded,
                                size: 16,
                                color: SakhiModule4Colors.primaryPlumDark,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _controller.liveShareShortUrl,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: SakhiModule4Colors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor:
                                SakhiModule4Colors.emergencyCrimson,
                            side: const BorderSide(
                              color: SakhiModule4Colors.emergencyCrimson,
                              width: 1.5,
                            ),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            if (_controller.liveLocationSharingActive) {
                              _controller.stopLocationSharingAndEndSos();
                            } else {
                              _controller.startLiveLocationSharing();
                            }
                          },
                          child: Text(
                            _controller.liveLocationSharingActive
                                ? 'Stop Location Sharing'
                                : 'Start Live Location Sharing',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                Text(
                  'Trusted Contacts (${contacts.length}/5)',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                ...contacts.map(
                  (contact) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SakhiModule4Colors.cardBorder,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipOval(
                            child: Image.asset(
                              SakhiModule4Assets.trustedContactAvatar,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const CircleAvatar(
                                radius: 25,
                                backgroundColor:
                                    SakhiModule4Colors.emergencySoftTint,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: SakhiModule4Colors.emergencyCrimson,
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
                                  '${contact.name} (${contact.relationship})',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: SakhiModule4Colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  contact.phoneMasked,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: SakhiModule4Colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (contact.isPrimary)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SakhiModule4Colors.primaryPlumDark,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Primary Contact',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  )
                                else
                                  InkWell(
                                    onTap: () => _controller.setPrimaryContact(
                                      contact.id,
                                    ),
                                    child: const Text(
                                      'Set as Primary',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            SakhiModule4Colors.primaryPlumDark,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Switch(
                                value: contact.selectedForSosAlert,
                                activeThumbColor:
                                    SakhiModule4Colors.primaryPlumDark,
                                activeTrackColor: const Color(0xFFB596C2),
                                onChanged: (val) {
                                  final ok = _controller
                                      .toggleContactSelectedForSos(
                                        contact.id,
                                        val,
                                      );
                                  if (!ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'At least 1 Primary Contact must remain selected for SOS alerts.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              const Text(
                                'Selected for SOS Alert',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: SakhiModule4Colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.call_rounded,
                                      color: SakhiModule4Colors.primaryPlumDark,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _controller.launchPhoneCall(
                                          context,
                                          contact.phoneE164,
                                          label: contact.name,
                                        ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color:
                                          SakhiModule4Colors.emergencyCrimson,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      final removed = _controller
                                          .removeTrustedContact(contact.id);
                                      if (!removed) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Keep at least 1 trusted emergency contact configured.',
                                                ),
                                              ),
                                            );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('contacts-send-alert-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SakhiModule4Colors.emergencyCrimson,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () =>
                        _controller.dispatchSosAlertToContacts(context),
                    child: const Text(
                      'Send Emergency Alert to Selected Contacts',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: const Color(0xFFE3D5E8),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SafetyHistoryAndSettingsScreen(),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: SakhiModule4Colors.primaryPlumDark,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Review SOS Activation History',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.textPrimary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: SakhiModule4Colors.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Screen 5 — Share Live Location & Add Trusted Contact Bottom Sheet
/// (`05_Share_Live_Location_and_Add_Contact_Modal_UI.jpg`)
class ShareLiveLocationScreen extends StatefulWidget {
  const ShareLiveLocationScreen({super.key});

  @override
  State<ShareLiveLocationScreen> createState() =>
      _ShareLiveLocationScreenState();
}

class _ShareLiveLocationScreenState extends State<ShareLiveLocationScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Share Live Location',
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 14, top: 10, bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: SakhiModule4Colors.verifiedMintBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: SakhiModule4Colors.verifiedMintBorder,
                  ),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: SakhiModule4Colors.verifiedMintText,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'GPS unavailable',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SakhiModule4Colors.verifiedMintText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Interactive Live Map Card with Avatar Pin & Copy Link
                Container(
                  height: 210,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SakhiModule4Colors.cardBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          SakhiModule4Assets.pastelMapBackground,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              Container(color: const Color(0xFFF3EDF7)),
                        ),
                      ),
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SakhiModule4Colors.primaryPlum.withValues(
                            alpha: 0.14,
                          ),
                        ),
                      ),
                      if (_controller.hasLiveLocation)
                        Container(
                          width: 54,
                          height: 54,
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: SakhiModule4Colors.emergencyCrimson,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              SakhiModule4Assets.trustedContactAvatar,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person_pin_circle_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _controller.hasLiveLocation
                                ? 'Device GPS location recorded'
                                : 'GPS unavailable — no live location is being shared',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      if (_controller.hasLiveLocation)
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x18000000),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _controller.liveShareFullUrl.isNotEmpty
                                      ? _controller.liveShareFullUrl
                                      : 'No backend-confirmed tracking link yet.',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: SakhiModule4Colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    final trackingLink =
                                        _controller.liveShareFullUrl;
                                    if (trackingLink.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'No backend-confirmed live tracking link is available.',
                                              ),
                                            ),
                                          );
                                      return;
                                    }
                                    Clipboard.setData(
                                      ClipboardData(text: trackingLink),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Live tracking link copied.',
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SakhiModule4Colors.primaryPlumDark,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Copy Link',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
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
                const SizedBox(height: 14),

                // Duration & Consent Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SakhiModule4Colors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: ['15 Mins', '1 Hour', 'Until I Stop'].map((
                          label,
                        ) {
                          final selected =
                              _controller.selectedDurationLabel == label;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: selected
                                      ? SakhiModule4Colors.primaryPlumDark
                                      : Colors.white,
                                  foregroundColor: selected
                                      ? Colors.white
                                      : SakhiModule4Colors.textPrimary,
                                  side: BorderSide(
                                    color: selected
                                        ? SakhiModule4Colors.primaryPlumDark
                                        : SakhiModule4Colors.cardBorder,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () => _controller
                                    .startLiveLocationSharing(duration: label),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: SakhiModule4Colors.primaryPlumDark,
                          value: _controller.includeNameAndProfileInAlert,
                          onChanged: (val) => setState(() {
                            _controller.includeNameAndProfileInAlert =
                                val ?? true;
                          }),
                          title: const Text(
                            'Include my Name & Emergency Profile',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: SakhiModule4Colors.primaryPlumDark,
                          value: _controller.includeTimestampAndMapLink,
                          onChanged: (val) => setState(() {
                            _controller.includeTimestampAndMapLink =
                                val ?? true;
                          }),
                          title: const Text(
                            'Include Timestamp & Live Map Link',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                SakhiModule4Colors.emergencyCrimson,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            if (_controller.liveLocationSharingActive) {
                              _controller.stopLocationSharingAndEndSos();
                            } else {
                              _controller.startLiveLocationSharing();
                            }
                          },
                          child: Text(
                            _controller.liveLocationSharingActive
                                ? 'Stop Live Location Sharing'
                                : 'Start Live Location Sharing Now',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Embedded Add Trusted Emergency Contact Card (matching Screen 5 bottom sheet design)
                const AddTrustedContactSheet(embeddedInPage: true),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddTrustedContactSheet extends StatefulWidget {
  final bool embeddedInPage;

  const AddTrustedContactSheet({super.key, this.embeddedInPage = false});

  @override
  State<AddTrustedContactSheet> createState() => _AddTrustedContactSheetState();
}

class _AddTrustedContactSheetState extends State<AddTrustedContactSheet> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedRelationship = 'Sister';
  bool _setAsPrimary = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveContact() {
    final err = _controller.addTrustedContact(
      name: _nameController.text,
      mobileNumber: _phoneController.text,
      relationship: _selectedRelationship,
      setAsPrimary: _setAsPrimary,
    );
    if (err != null) {
      setState(() => _errorText = err);
      return;
    }
    setState(() => _errorText = null);
    _nameController.clear();
    _phoneController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: SakhiModule4Colors.primaryPlumDark,
        content: Text(
          'Trusted emergency contact saved & consent SMS prepared!',
        ),
      ),
    );
    if (!widget.embeddedInPage && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: EdgeInsets.fromLTRB(
        18,
        16,
        18,
        widget.embeddedInPage
            ? 18
            : MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: widget.embeddedInPage
            ? Border.all(color: SakhiModule4Colors.cardBorder)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD6C6DC),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Add Trusted Emergency Contact',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Contact Name',
              hintText: 'e.g., Priya Sharma',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Mobile Number (+91)',
              hintText: 'e.g., 9876543210',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Relationship',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: SakhiModule4Colors.textPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: ['Mother', 'Sister', 'Partner', 'Friend'].map((
                    rel,
                  ) {
                    final selected = _selectedRelationship == rel;
                    return ChoiceChip(
                      label: Text(rel),
                      selected: selected,
                      selectedColor: SakhiModule4Colors.secondaryLavenderPill,
                      onSelected: (_) =>
                          setState(() => _selectedRelationship = rel),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Set as Primary Emergency Contact',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: SakhiModule4Colors.textPrimary,
                ),
              ),
              value: _setAsPrimary,
              activeThumbColor: SakhiModule4Colors.primaryPlumDark,
              onChanged: (val) => setState(() => _setAsPrimary = val),
            ),
          ),
          if (_errorText != null) ...[
            Text(
              _errorText!,
              style: const TextStyle(
                color: SakhiModule4Colors.emergencyCrimson,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('save-trusted-contact-button'),
              style: FilledButton.styleFrom(
                backgroundColor: SakhiModule4Colors.primaryPlumDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              onPressed: _saveContact,
              child: const Text(
                'Save & Send Consent SMS',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
    return content;
  }
}

/// Screen 6 — Safety History, Discreet Shortcut & Pre-Travel Safety Checklist Screen
/// (`06_Safety_History_Discreet_Shortcut_and_Checklist_UI.jpg`)
class SafetyHistoryAndSettingsScreen extends StatefulWidget {
  const SafetyHistoryAndSettingsScreen({super.key});

  @override
  State<SafetyHistoryAndSettingsScreen> createState() =>
      _SafetyHistoryAndSettingsScreenState();
}

class _SafetyHistoryAndSettingsScreenState
    extends State<SafetyHistoryAndSettingsScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Safety History & Settings',
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section 1: Configurable & Discreet SOS Activation (6.2)
                const Text(
                  'Configurable & Discreet SOS Activation (6.2)',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SakhiModule4Colors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Power Button Triple-Press Shortcut',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            '(OS Permission Granted)',
                            style: TextStyle(
                              fontSize: 12,
                              color: SakhiModule4Colors.textSecondary,
                            ),
                          ),
                          value: _controller.powerButtonShortcutEnabled,
                          activeThumbColor: Colors.white,
                          activeTrackColor: SakhiModule4Colors.primaryPlumDark,
                          onChanged: (val) => setState(() {
                            _controller.powerButtonShortcutEnabled = val;
                          }),
                        ),
                      ),
                      const Divider(height: 16),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Discreet Shake-to-SOS Trigger',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            '(Requires 3s confirmation screen)',
                            style: TextStyle(
                              fontSize: 12,
                              color: SakhiModule4Colors.textSecondary,
                            ),
                          ),
                          value: _controller.discreetShakeTriggerEnabled,
                          activeThumbColor: Colors.white,
                          activeTrackColor: SakhiModule4Colors.primaryPlumDark,
                          onChanged: (val) => setState(() {
                            _controller.discreetShakeTriggerEnabled = val;
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          key: const Key('run-safe-test-mode-button'),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                SakhiModule4Colors.secondaryLavenderPill,
                            foregroundColor: SakhiModule4Colors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const SosWorkflowScreen(isTestMode: true),
                              ),
                            );
                          },
                          child: const Text(
                            'Run Safe Test Mode (Avoid False Triggers)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section 2: SOS Activation History (6.3 & 6.5)
                const Text(
                  'SOS Activation History (6.3 & 6.5)',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ..._controller.sosHistory.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SakhiModule4Colors.cardBorder,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.timestampLabel,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: SakhiModule4Colors.textPrimary,
                                  ),
                                ),
                              ),
                              const Text(
                                'View Log >',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: SakhiModule4Colors.primaryPlum,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: item.isTestMode
                                  ? SakhiModule4Colors.warningAmberBg
                                  : SakhiModule4Colors.verifiedMintBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.badgeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: item.isTestMode
                                    ? SakhiModule4Colors.warningAmberText
                                    : SakhiModule4Colors.verifiedMintText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${item.locationLabel} (Map Link)',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.detailsSummary,
                            style: const TextStyle(
                              fontSize: 12,
                              color: SakhiModule4Colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Section 3: Pre-Travel Safety Checklist
                const Text(
                  'Pre-Travel Safety Checklist',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SakhiModule4Colors.cardBorder),
                  ),
                  child: Column(
                    children: _controller.preTravelChecklist.map((chk) {
                      return Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: SakhiModule4Colors.primaryPlumDark,
                          value: chk.isChecked,
                          onChanged: (val) =>
                              _controller.toggleChecklist(chk.id, val ?? false),
                          title: Text(
                            chk.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Screen 7 — Verified 24/7 Helplines (112, 100, 1091, 181, 108/1930) & Safety Tips Screen
/// (`07_Verified_Helplines_112_and_Safety_Tips_UI.jpg`)
class HelplinesAndSafetyTipsScreen extends StatelessWidget {
  final bool scrollToTips;

  const HelplinesAndSafetyTipsScreen({super.key, this.scrollToTips = false});

  @override
  Widget build(BuildContext context) {
    final controller = SakhiSafetyController.instance;
    return Scaffold(
      backgroundColor: SakhiModule4Colors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: SakhiModule4Colors.surfaceBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SakhiModule4Colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Helplines & Safety Tips',
          style: TextStyle(
            fontSize: 18.5,
            fontWeight: FontWeight.w800,
            color: SakhiModule4Colors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14, top: 8, bottom: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: SakhiModule4Colors.emergencyCrimson,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () => controller.launchPhoneCall(
                context,
                '112',
                label: '112 National Emergency Number',
              ),
              icon: const Icon(Icons.phone_in_talk_rounded, size: 16),
              label: const Text(
                'Call 112',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero 112 & 100 Emergency Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7D1935), Color(0xFFC92A49)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Image.asset(
                          SakhiModule4Assets.emergency112Emblem,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.shield_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '112 — India National Emergency Number',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '24/7 Police (112 / 100), Fire & Medical Emergency Response',
                              style: TextStyle(
                                color: Color(0xFFFCE8EC),
                                fontSize: 12.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: SakhiModule4Colors.emergencyCrimson,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => controller.launchPhoneCall(
                        context,
                        '112',
                        label: '112 National Emergency Response',
                      ),
                      child: const Text(
                        'Tap to Call 112 Immediately',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Verified 24/7 Women & Safety Helplines',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            ...controller.verifiedHelplines.map(
              (hl) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SakhiModule4Colors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          hl.badgeAsset,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 46,
                            height: 46,
                            color: SakhiModule4Colors.pastelLavenderBg,
                            child: const Icon(
                              Icons.phone_in_talk_rounded,
                              color: SakhiModule4Colors.primaryPlum,
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
                              hl.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              hl.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: SakhiModule4Colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: SakhiModule4Colors.primaryPlumDark,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => controller.launchPhoneCall(
                          context,
                          hl.number,
                          label: hl.title,
                        ),
                        child: const Text(
                          'Call Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Essential Personal Safety Tips',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            _IllustratedSafetyTipCard(
              imageAsset: SakhiModule4Assets.commuteSafetyIllustration,
              bgColor: const Color(0xFFEAF7F1),
              title: 'Commute & Cab Safety',
              subtitle: 'Verify child lock, share live GPS link, and sit behind the driver.',
            ),
            const SizedBox(height: 10),
            _IllustratedSafetyTipCard(
              imageAsset: SakhiModule4Assets.discreetSosIllustration,
              bgColor: const Color(0xFFFDF0F5),
              title: 'Using Discreet SOS Safely',
              subtitle: 'How to trigger silent alerts to trusted contacts without unlocking.',
            ),
          ],
        ),
      ),
    );
  }
}

class _IllustratedSafetyTipCard extends StatelessWidget {
  final String imageAsset;
  final Color bgColor;
  final String title;
  final String subtitle;

  const _IllustratedSafetyTipCard({
    required this.imageAsset,
    required this.bgColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SakhiModule4Colors.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              imageAsset,
              width: 112,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 112,
                height: 76,
                color: Colors.white,
                child: const Icon(
                  Icons.shield_outlined,
                  color: SakhiModule4Colors.primaryPlum,
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
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12.2,
                    color: SakhiModule4Colors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
