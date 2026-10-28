import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/widgets/sakhi_botanical_flower.dart';
import '../../../core/widgets/sakhi_quote_loader.dart';
import '../../complaints/screens/complaint_tracking_screens.dart';
import '../../complaints/screens/discreet_complaint_hub_screen.dart';
import '../models/safety_models.dart';
import '../theme/sakhi_module4_theme.dart';
import '../widgets/sakhi_live_osm_map.dart';

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

class _SafetyScreenState extends State<SafetyScreen>
    with SingleTickerProviderStateMixin {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _controller.onDiscreetShortcutTriggered = _handleHardwareShortcutTrigger;
    unawaited(_controller.initializeSafetyState(autoRequestGps: true));
  }

  @override
  void dispose() {
    if (_controller.onDiscreetShortcutTriggered ==
        _handleHardwareShortcutTrigger) {
      _controller.onDiscreetShortcutTriggered = null;
    }
    _pulseController.dispose();
    super.dispose();
  }

  void _handleHardwareShortcutTrigger(String source) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SakhiModule4Colors.sosCrimson,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Discreet Shortcut detected ($source) • Opening 3s SOS Confirmation Guard…',
        ),
      ),
    );
    _openScreen(const SosWorkflowScreen(isTestMode: false));
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
                      // Top-Right Shortcut Gear -> Opens Dedicated DiscreetShortcutConfigScreen!
                      InkWell(
                        key: const Key('safety-shortcut-gear-button'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            _openScreen(const DiscreetShortcutConfigScreen()),
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
                        key: const Key('safety-top-sos-pill-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SakhiModule4Colors.sosCrimson,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => _openScreen(
                          const SosWorkflowScreen(isTestMode: false),
                        ),
                        icon: const Icon(
                          Icons.notifications_active_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'SOS',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Hero Real Live Interactive Map Card with Clean Pulsing Vector SOS Button
                  Stack(
                    children: [
                      SakhiLiveOsmMap(
                        height: 235,
                        latitude: _controller.currentLatitude,
                        longitude: _controller.currentLongitude,
                        hasLiveGps: _controller.hasRecentDeviceLocation,
                        locationLabel: _controller.hasRecentDeviceLocation
                            ? _controller.currentLocationLabel
                            : 'Tap to enable device GPS',
                        accuracyMeters: _controller.currentAccuracyMeters,
                        policeStations: _controller.nearbyPoliceStations,
                        onRequestGpsTap: () =>
                            unawaited(_controller.requestDeviceLocation()),
                        onStationTap: (_) =>
                            _openScreen(const NearestPoliceStationsScreen()),
                        centerOverlay: GestureDetector(
                          key: const Key('safety-hero-tap-sos-card'),
                          onTap: () => _openScreen(
                            const SosWorkflowScreen(isTestMode: false),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 14),
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  final scale =
                                      1.0 + (_pulseController.value * 0.08);
                                  return Transform.scale(
                                    scale: scale,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: SakhiModule4Colors.sosCrimson
                                        .withValues(alpha: 0.14),
                                  ),
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: 78,
                                    height: 78,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: SakhiModule4Colors.sosCrimson
                                          .withValues(alpha: 0.24),
                                    ),
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: 62,
                                      height: 62,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFE53858),
                                            Color(0xFFB81D3B),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Color(0x55C92A49),
                                            blurRadius: 16,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: const Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Icon(
                                            Icons.shield_rounded,
                                            color: Colors.white,
                                            size: 34,
                                          ),
                                          Icon(
                                            Icons.location_on_rounded,
                                            color: Color(0xFFC92A49),
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Tap SOS',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: SakhiModule4Colors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'for emergency help • 3s confirmation guard',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: SakhiModule4Colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 4 Circular Icon Actions Row — Each opens its own DISTINCT screen!
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _CircularSafetyHubAction(
                          key: const Key('circle-action-emergency-contacts'),
                          icon: Icons.people_alt_rounded,
                          tintBg: const Color(0xFFFDE8EC),
                          iconColor: SakhiModule4Colors.sosCrimson,
                          label: 'Emergency\nContacts',
                          onTap: () =>
                              _openScreen(const EmergencyContactsScreen()),
                        ),
                      ),
                      Expanded(
                        child: _CircularSafetyHubAction(
                          key: const Key('circle-action-nearby-police'),
                          icon: Icons.local_police_rounded,
                          tintBg: const Color(0xFFE6F4EE),
                          iconColor: SakhiModule4Colors.verifiedEmerald,
                          label: 'Nearby\nPolice',
                          onTap: () =>
                              _openScreen(const NearestPoliceStationsScreen()),
                        ),
                      ),
                      Expanded(
                        child: _CircularSafetyHubAction(
                          key: const Key('circle-action-safety-tips'),
                          icon: Icons.menu_book_rounded,
                          tintBg: const Color(0xFFFFF3E0),
                          iconColor: const Color(0xFFD97706),
                          label: 'Safety\nTips',
                          onTap: () =>
                              _openScreen(const PersonalSafetyTipsScreen()),
                        ),
                      ),
                      Expanded(
                        child: _CircularSafetyHubAction(
                          key: const Key('circle-action-helplines-112'),
                          icon: Icons.phone_in_talk_rounded,
                          tintBg: const Color(0xFFF2E6F7),
                          iconColor: SakhiModule4Colors.primaryPlum,
                          label: 'Helplines\n(112)',
                          onTap: () =>
                              _openScreen(const NationalEmergency112Screen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Prominent Discreet & Anonymous Complaint Hub Sanctuary Card on Safety Tab
                  Container(
                    key: const Key('safety-module5-discreet-complaint-card'),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFF0F6),
                          Color(0xFFF5E6FA),
                          Color(0xFFEDE0F6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFDCC0E8),
                        width: 1.4,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x145A1868),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        children: [
                          const Positioned(
                            right: -12,
                            top: -12,
                            child: SakhiBotanicalFlower(
                              type: SakhiFlowerType.roseClassic,
                              width: 72,
                              height: 84,
                              opacity: 0.30,
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
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: SizedBox(
                                        width: 82,
                                        height: 82,
                                        child: Image.asset(
                                          'assets/module5/illustrations/01_hero_woman_lotus_safe_voice.jpg',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => Container(
                                            color: const Color(0xFFF2E6F7),
                                            child: const Icon(
                                              Icons.shield_moon_rounded,
                                              size: 36,
                                              color: SakhiModule4Colors.primaryPlum,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 3.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.9),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              '100% PRIVATE • SAFE VOICE',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                color: SakhiModule4Colors.primaryPlum,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Discreet & Anonymous Complaint Hub',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              height: 1.2,
                                              color: SakhiModule4Colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Privately report harassment, stalking, cyberbullying, or workplace issues—anonymously or confidentially.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                              color: SakhiModule4Colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        key: const Key('safety-open-discreet-complaint-hub-button'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: SakhiModule4Colors.primaryPlum,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        onPressed: () => _openScreen(
                                          const DiscreetComplaintHubScreen(),
                                        ),
                                        icon: const Icon(Icons.lock_outline_rounded, size: 16),
                                        label: const Text(
                                          'Report Safely',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        key: const Key('safety-open-complaint-tracker-button'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: SakhiModule4Colors.primaryPlum,
                                          backgroundColor: Colors.white.withValues(alpha: 0.88),
                                          side: const BorderSide(
                                            color: SakhiModule4Colors.primaryPlum,
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                        ),
                                        onPressed: () => _openScreen(
                                          const ComplaintTrackingLookupScreen(),
                                        ),
                                        icon: const Icon(Icons.manage_search_rounded, size: 16),
                                        label: const Text(
                                          'Track My Report',
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Quick Safety Actions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: SakhiModule4Colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 5 Quick Safety Action Rows — Every Row Opens Its Own Dedicated Screen!
                  _QuickActionRowCard(
                    key: const Key('row-action-share-live-location'),
                    icon: Icons.my_location_rounded,
                    iconColor: SakhiModule4Colors.sosCrimson,
                    iconBg: const Color(0xFFFDE8EC),
                    title: 'Share my live location',
                    subtitle: _controller.liveLocationSharingActive
                        ? 'Active (${_controller.selectedDurationLabel}) • Tap to manage link'
                        : 'With selected trusted contacts (Consent & GPS)',
                    onTap: () => _openScreen(const ShareLiveLocationScreen()),
                  ),
                  const SizedBox(height: 10),
                  _QuickActionRowCard(
                    key: const Key('row-action-sos-history'),
                    icon: Icons.history_rounded,
                    iconColor: SakhiModule4Colors.primaryPlum,
                    iconBg: const Color(0xFFF2E6F7),
                    title: 'SOS Activation History',
                    subtitle:
                        'View past emergency alerts & status (${_controller.sosHistory.length} logged)',
                    onTap: () =>
                        _openScreen(const SosActivationHistoryScreen()),
                  ),
                  const SizedBox(height: 10),
                  _QuickActionRowCard(
                    key: const Key('row-action-safety-checklist'),
                    icon: Icons.fact_check_rounded,
                    iconColor: SakhiModule4Colors.verifiedEmerald,
                    iconBg: const Color(0xFFE6F4EE),
                    title: 'Safety Checklist & Discreet Trigger',
                    subtitle: 'Pre-travel checklist, cab plate logger & shortcut status',
                    onTap: () =>
                        _openScreen(const PreTravelSafetyChecklistScreen()),
                  ),
                  const SizedBox(height: 10),
                  _QuickActionRowCard(
                    key: const Key('row-action-emergency-helplines'),
                    icon: Icons.support_agent_rounded,
                    iconColor: const Color(0xFFB81D3B),
                    iconBg: const Color(0xFFFDE8EC),
                    title: 'Emergency Helplines & 112',
                    subtitle: '112 National Emergency, 100 Police, 1091 & 181 Women Helpline',
                    onTap: () =>
                        _openScreen(const VerifiedHelplinesDirectoryScreen()),
                  ),
                  const SizedBox(height: 10),
                  _QuickActionRowCard(
                    key: const Key('row-action-nearest-police-stations'),
                    icon: Icons.local_police_rounded,
                    iconColor: SakhiModule4Colors.primaryPlum,
                    iconBg: const Color(0xFFF2E6F7),
                    title: 'Nearest Police Stations',
                    subtitle: _controller.nearbyPoliceStations.isNotEmpty
                        ? '${_controller.nearbyPoliceStations.length} real stations found near your GPS • Call 100/112'
                        : 'Real live GPS map, verified directory, directions & Call 112',
                    onTap: () =>
                        _openScreen(const NearestPoliceStationsScreen()),
                  ),

                  const SizedBox(height: 16),
                  // Animated Women Quotations Banner (168 curated quotes)
                  SakhiQuoteLoader.banner(
                    statusLabel:
                        'Daily Sakhi Strength • Tap for another inspiration',
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

class _CircularSafetyHubAction extends StatelessWidget {
  final IconData icon;
  final Color tintBg;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _CircularSafetyHubAction({
    super.key,
    required this.icon,
    required this.tintBg,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: tintBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: iconColor.withValues(alpha: 0.2),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D5A1868),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionRowCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionRowCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SakhiModule4Colors.borderSubtle),
            boxShadow: SakhiModule4Colors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SakhiModule4Colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SakhiModule4Colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
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

// ============================================================================
// Screen 2 — SOS Short Confirmation (3s Guard) & Active SOS Workflow Screen
// (`02_SOS_Confirmation_3s_and_Active_Workflow_UI.jpg`)
// ============================================================================
class SosWorkflowScreen extends StatefulWidget {
  final bool isTestMode;

  const SosWorkflowScreen({super.key, this.isTestMode = false});

  @override
  State<SosWorkflowScreen> createState() => _SosWorkflowScreenState();
}

class _SosWorkflowScreenState extends State<SosWorkflowScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;
  int _secondsRemaining = 3;
  bool _sosDispatched = false;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.refreshCurrentLocationIfAlreadyGranted());
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining -= 1;
        });
      } else {
        timer.cancel();
        _triggerSosNow();
      }
    });
  }

  Future<void> _triggerSosNow() async {
    _countdownTimer?.cancel();
    if (_sosDispatched) return;
    setState(() {
      _secondsRemaining = 0;
      _sosDispatched = true;
    });
    await _controller.activateSosEvent(isTestMode: widget.isTestMode);
  }

  void _cancelSosDuringCountdown() {
    _countdownTimer?.cancel();
    _controller.cancelSosDuringCountdown(isTestMode: widget.isTestMode);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: SakhiModule4Colors.verifiedEmerald,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'SOS cancelled safely within 3s confirmation guard • No alert dispatched',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final selectedCount = _controller.selectedContacts.length;
        final contactNames = _controller.selectedContacts
            .map((c) => c.name)
            .join(', ');
        final hasLiveCoords = _controller.hasRecentDeviceLocation;

        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.isTestMode ? 'Safe SOS Test Mode' : 'Emergency SOS',
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            centerTitle: true,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE8EC),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 8,
                      color: SakhiModule4Colors.sosCrimson,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _sosDispatched ? 'Active SOS' : '3s Guard',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: SakhiModule4Colors.sosCrimson,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Short Confirmation Guard Card (Section 6.2)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: SakhiModule4Colors.sosCrimson,
                      width: 1.5,
                    ),
                    boxShadow: SakhiModule4Colors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.isTestMode
                            ? 'Safe Test Mode — Confirm SOS Simulation'
                            : 'Confirm Emergency SOS',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SakhiModule4Colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sosDispatched
                            ? 'SOS workflow active • Prepare emergency actions below'
                            : 'Sending alert & recording location in $_secondsRemaining seconds (Prevents accidental triggers)',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: SakhiModule4Colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFCE8EC),
                          border: Border.all(
                            color: SakhiModule4Colors.sosCrimson,
                            width: 4,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _sosDispatched ? 'SOS' : '0${_secondsRemaining}s',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: SakhiModule4Colors.sosCrimson,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              key: const Key('sos-trigger-now-button'),
                              style: FilledButton.styleFrom(
                                backgroundColor: SakhiModule4Colors.sosCrimson,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
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
                            child: OutlinedButton(
                              key: const Key('sos-cancel-safe-button'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: SakhiModule4Colors.primaryPlum,
                                side: const BorderSide(
                                  color: SakhiModule4Colors.primaryPlum,
                                  width: 1.4,
                                ),
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              onPressed: _cancelSosDuringCountdown,
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

                const Text(
                  'Active SOS Workflow & Verified Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // Step 1: GPS Location Status
                _WorkflowStatusStepCard(
                  icon: hasLiveCoords
                      ? Icons.check_rounded
                      : Icons.location_searching_rounded,
                  iconBg: hasLiveCoords
                      ? SakhiModule4Colors.verifiedEmerald
                      : SakhiModule4Colors.amberWarningText,
                  title: hasLiveCoords
                      ? 'Current Location Captured (GPS Granted)'
                      : 'Current Location Unavailable',
                  subtitle: hasLiveCoords
                      ? '${_controller.currentLocationLabel} • Lat ${_controller.currentLatitude.toStringAsFixed(4)}° N, ${_controller.currentLongitude.toStringAsFixed(4)}° E'
                      : _controller.locationStatusMessage,
                  pillText: hasLiveCoords ? 'Confirmed' : 'Enable GPS',
                  pillBg: hasLiveCoords
                      ? SakhiModule4Colors.verifiedEmeraldTint
                      : SakhiModule4Colors.amberWarningBg,
                  pillTextColor: hasLiveCoords
                      ? SakhiModule4Colors.verifiedEmerald
                      : SakhiModule4Colors.amberWarningText,
                ),
                if (!hasLiveCoords) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _controller.isAcquiringLocation
                        ? null
                        : () => unawaited(_controller.requestDeviceLocation()),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(
                      _controller.isAcquiringLocation
                          ? 'Getting device location…'
                          : 'Enable Device GPS Now',
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                // Step 2: Emergency Contacts Alert Preparation
                _WorkflowStatusStepCard(
                  icon: Icons.people_alt_rounded,
                  iconBg: SakhiModule4Colors.primaryPlum,
                  title: selectedCount > 0
                      ? 'Emergency Contacts ($selectedCount Selected)'
                      : 'No Emergency Contacts Added Yet',
                  subtitle: widget.isTestMode
                      ? 'Safe Test Mode: External SMS/WhatsApp dispatch suppressed'
                      : selectedCount > 0
                      ? '$contactNames • Tap below to send live GPS alert via SMS/WhatsApp'
                      : 'Add trusted contacts in Emergency Contacts to send one-tap SMS/WhatsApp alerts',
                  pillText: widget.isTestMode
                      ? 'Test Mode'
                      : selectedCount > 0
                      ? 'Ready'
                      : 'Configure',
                  pillBg: const Color(0xFFF2E6F7),
                  pillTextColor: SakhiModule4Colors.primaryPlum,
                ),
                const SizedBox(height: 10),

                // Step 3: Safety History Recording
                _WorkflowStatusStepCard(
                  icon: Icons.check_rounded,
                  iconBg: SakhiModule4Colors.verifiedEmerald,
                  title: 'Recorded in Personal Safety History',
                  subtitle: 'Event logged with timestamp & device coordinates for your records',
                  pillText: 'Saved',
                  pillBg: SakhiModule4Colors.verifiedEmeraldTint,
                  pillTextColor: SakhiModule4Colors.verifiedEmerald,
                ),
                const SizedBox(height: 10),

                // Step 4: Mandatory Police Integration Compliance Card (SRS 6.3.8 & 6.4)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: SakhiModule4Colors.amberWarningBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: SakhiModule4Colors.amberWarningBorder,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: SakhiModule4Colors.amberWarningText,
                        child: Text(
                          '!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Official Police Integration Status',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF5C3700),
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Direct police auto-dispatch is not connected. Please tap Call 112 or 100 below to speak directly with emergency responders.',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: Color(0xFF6B4200),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Primary Call 112 CTA (Opens Native SIM Phone Dialer!)
                FilledButton.icon(
                  key: const Key('sos-call-112-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SakhiModule4Colors.sosCrimson,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () => _controller.launchPhoneCall(
                    context,
                    '112',
                    label: '112 National Emergency Response',
                  ),
                  icon: const Icon(Icons.phone_in_talk_rounded),
                  label: const Text(
                    'Call 112 National Emergency Helpline',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary Call 100 CTA (Opens Native SIM Phone Dialer!)
                FilledButton.icon(
                  key: const Key('sos-call-100-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SakhiModule4Colors.primaryPlum,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () => _controller.launchPhoneCall(
                    context,
                    '100',
                    label: '100 Police Control Room',
                  ),
                  icon: const Icon(Icons.local_police_rounded),
                  label: const Text(
                    'Call 100 Direct Police Control Room',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Send / Resend Alert via SMS / WhatsApp
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SakhiModule4Colors.primaryPlum,
                    side: const BorderSide(
                      color: SakhiModule4Colors.primaryPlum,
                    ),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () =>
                      _controller.dispatchSosAlertToContacts(context),
                  icon: const Icon(Icons.share_location_rounded),
                  label: const Text(
                    'Send / Share Live SOS Alert to Contacts',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),

                // Stop Location Sharing & End SOS
                FilledButton.tonal(
                  key: const Key('sos-stop-and-end-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF3E6EE),
                    foregroundColor: SakhiModule4Colors.sosCrimson,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () {
                    _controller.stopLocationSharingAndEndSos();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: SakhiModule4Colors.verifiedEmerald,
                        behavior: SnackBarBehavior.floating,
                        content: Text(
                          'Live location sharing stopped & SOS event marked Resolved Safely.',
                        ),
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Stop Location Sharing & End SOS',
                    style: TextStyle(fontWeight: FontWeight.w800),
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

class _WorkflowStatusStepCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String pillText;
  final Color pillBg;
  final Color pillTextColor;

  const _WorkflowStatusStepCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.pillText,
    required this.pillBg,
    required this.pillTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SakhiModule4Colors.borderSubtle),
        boxShadow: SakhiModule4Colors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: iconBg,
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: SakhiModule4Colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pillText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: pillTextColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Screen 3 — Nearest Police Stations & Real Live Interactive Map Directory
// (`03_Nearest_Police_Stations_and_Verified_Directory_UI.jpg`)
// ============================================================================
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
    unawaited(_initPoliceDiscovery());
  }

  Future<void> _initPoliceDiscovery() async {
    await _controller.refreshCurrentLocationIfAlreadyGranted();
    if (_controller.hasRecentDeviceLocation) {
      await _controller.refreshNearbyPoliceStations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final stations = _controller.nearbyPoliceStations;
        final hasLiveGps = _controller.hasRecentDeviceLocation;

        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Nearest Police Stations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: SakhiModule4Colors.sosCrimson,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: () => _controller.launchPhoneCall(
                    context,
                    '112',
                    label: '112 Emergency',
                  ),
                  icon: const Icon(Icons.call_rounded, size: 14),
                  label: const Text(
                    'Call 112',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
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
                // Mandatory SRS 6.4 Non-Notification Disclaimer Banner
                Container(
                  key: const Key('police-compliance-disclaimer-banner'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SakhiModule4Colors.amberWarningBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: SakhiModule4Colors.amberWarningBorder,
                    ),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: SakhiModule4Colors.amberWarningText,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Important: Finding a police station on the map does NOT automatically notify police. Tap Call Station or Call 112 / 100 for immediate assistance.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                            color: Color(0xFF5C3700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Real Interactive OpenStreetMap with Live User GPS Dot & Real Station Pins
                SakhiLiveOsmMap(
                  height: 220,
                  initialZoom: 14,
                  latitude: _controller.currentLatitude,
                  longitude: _controller.currentLongitude,
                  hasLiveGps: hasLiveGps,
                  locationLabel: hasLiveGps
                      ? _controller.currentLocationLabel
                      : 'Tap to enable live GPS',
                  accuracyMeters: _controller.currentAccuracyMeters,
                  policeStations: stations,
                  onRequestGpsTap: () =>
                      unawaited(_controller.requestDeviceLocation()),
                  onStationTap: (station) =>
                      _controller.launchDirectionsToStation(context, station),
                ),
                const SizedBox(height: 12),

                // Search Radius Selector & Refresh Live GPS Button
                Row(
                  children: [
                    const Text(
                      'Search Radius:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: SakhiModule4Colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    for (final radKm in [10, 25, 45]) ...[
                      ChoiceChip(
                        label: Text('${radKm}km'),
                        selected:
                            _controller.selectedSearchRadiusMeters ==
                            radKm * 1000,
                        selectedColor: SakhiModule4Colors.primaryPlum,
                        labelStyle: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color:
                              _controller.selectedSearchRadiusMeters ==
                                  radKm * 1000
                              ? Colors.white
                              : SakhiModule4Colors.textPrimary,
                        ),
                        onSelected: (_) => unawaited(
                          _controller.refreshNearbyPoliceStations(
                            radiusMeters: radKm * 1000,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Spacer(),
                    IconButton(
                      tooltip: 'Refresh Live GPS & Stations',
                      onPressed: _controller.isLoadingStations
                          ? null
                          : () => unawaited(
                              _controller.refreshNearbyPoliceStations(),
                            ),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: SakhiModule4Colors.primaryPlum,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nearby Police Stations (${stations.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SakhiModule4Colors.textPrimary,
                      ),
                    ),
                    if (hasLiveGps)
                      Text(
                        '${_controller.currentLatitude.toStringAsFixed(4)}, ${_controller.currentLongitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: SakhiModule4Colors.verifiedEmerald,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_controller.isLoadingStations) ...[
                  SakhiQuoteLoader.inline(
                    statusLabel: 'Searching real OpenStreetMap police stations around your live GPS coordinates…',
                  ),
                  const SizedBox(height: 10),
                ],

                if (!hasLiveGps)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: SakhiModule4Colors.borderSubtle,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Live Device Location Required',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SakhiModule4Colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Enable device GPS to calculate nearby stations. Sakhi will not use a sample location.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: SakhiModule4Colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: SakhiModule4Colors.primaryPlum,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _controller.isAcquiringLocation
                              ? null
                              : () async {
                                  final ok = await _controller
                                      .requestDeviceLocation();
                                  if (ok) {
                                    await _controller
                                        .refreshNearbyPoliceStations();
                                  }
                                },
                          icon: const Icon(Icons.my_location_rounded, size: 18),
                          label: Text(
                            _controller.isAcquiringLocation
                                ? 'Acquiring GPS…'
                                : 'Enable Device GPS & Find Stations Near Me',
                          ),
                        ),
                      ],
                    ),
                  )
                else if (stations.isEmpty && !_controller.isLoadingStations)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: SakhiModule4Colors.borderSubtle,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No mapped stations returned within current radius',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: SakhiModule4Colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap "45km" radius above to expand the OpenStreetMap search, or open Google Maps directly for police stations near your GPS.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: SakhiModule4Colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => unawaited(
                                  _controller.refreshNearbyPoliceStations(
                                    radiusMeters: 45000,
                                  ),
                                ),
                                icon: const Icon(Icons.radar_rounded, size: 16),
                                label: const Text('Expand to 45 km'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      SakhiModule4Colors.primaryPlum,
                                ),
                                onPressed: () => _controller.launchPhoneCall(
                                  context,
                                  '100',
                                  label: '100 Police Control',
                                ),
                                icon: const Icon(Icons.call_rounded, size: 16),
                                label: const Text('Call 100 Police'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Real Nearby Police Station Cards
                ...stations.map(
                  (station) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PoliceStationCard(
                      station: station,
                      onDirections: () => _controller.launchDirectionsToStation(
                        context,
                        station,
                      ),
                      onCall: () => _controller.launchPhoneCall(
                        context,
                        station.phoneNumber,
                        label: station.name,
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

class _PoliceStationCard extends StatelessWidget {
  final NearbyPoliceStationModel station;
  final VoidCallback onDirections;
  final VoidCallback onCall;

  const _PoliceStationCard({
    required this.station,
    required this.onDirections,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SakhiModule4Colors.borderSubtle),
        boxShadow: SakhiModule4Colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EBF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_police_rounded,
                  color: SakhiModule4Colors.primaryPlum,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: SakhiModule4Colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${station.address} • Ph: ${station.phoneNumber}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SakhiModule4Colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Source: ${station.dataSource} (${station.latitude?.toStringAsFixed(4)}, ${station.longitude?.toStringAsFixed(4)})',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: SakhiModule4Colors.verifiedEmerald,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: SakhiModule4Colors.verifiedEmeraldTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  station.distanceBadgeText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.verifiedEmerald,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SakhiModule4Colors.primaryPlum,
                    side: const BorderSide(
                      color: SakhiModule4Colors.primaryPlum,
                    ),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_rounded, size: 17),
                  label: const Text(
                    'Directions / Navigate',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: SakhiModule4Colors.primaryPlum,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: onCall,
                  icon: const Icon(Icons.call_rounded, size: 17),
                  label: Text(
                    'Call Station (${station.phoneNumber})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
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

// ============================================================================
// Screen 4 — Emergency Contacts Management & Show/Hide Phone Number Toggle
// (`04_Emergency_Contacts_and_Location_Link_UI.jpg`)
// ============================================================================
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.initializeSafetyState(autoRequestGps: false));
  }

  void _openAddContactModal() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                Icons.arrow_back_ios_new_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Emergency Contacts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            actions: [
              // Show / Hide Phone Numbers Toggle Button
              TextButton.icon(
                key: const Key('toggle-all-contact-numbers-button'),
                onPressed: _controller.toggleShowAllPhoneNumbers,
                icon: Icon(
                  _controller.showAllContactPhoneNumbers
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 16,
                  color: SakhiModule4Colors.primaryPlum,
                ),
                label: Text(
                  _controller.showAllContactPhoneNumbers
                      ? 'Hide Numbers'
                      : 'Show Numbers',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: SakhiModule4Colors.primaryPlum,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  key: const Key('open-add-contact-modal-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SakhiModule4Colors.primaryPlum,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  onPressed: _openAddContactModal,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Add',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6ECF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SakhiModule4Colors.borderSubtle),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Trusted Circle (Max 5 Contacts • Persistent)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: SakhiModule4Colors.primaryPlum,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Contacts you add are saved permanently on your device and synced to your account. Use the eye icon to view or mask mobile numbers anytime.',
                        style: TextStyle(
                          fontSize: 12,
                          color: SakhiModule4Colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Empty State when user hasn't added any contact yet (Zero fake contacts!)
                if (contacts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: SakhiModule4Colors.borderSubtle,
                      ),
                      boxShadow: SakhiModule4Colors.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF2E6F7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1_rounded,
                            color: SakhiModule4Colors.primaryPlum,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Add Your Primary Contact',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: SakhiModule4Colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'No fake or sample contacts are pre-filled. Add your real family members or friends (+91) so they receive your SOS & live location alerts.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: SakhiModule4Colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: SakhiModule4Colors.primaryPlum,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: _openAddContactModal,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text(
                            'Add Primary Contact Now',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Contact Cards List
                ...contacts.map(
                  (contact) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TrustedContactCard(
                      contact: contact,
                      globalShowAll: _controller.showAllContactPhoneNumbers,
                      onTogglePhoneVisibility: () => _controller
                          .toggleSingleContactPhoneVisibility(contact.id),
                      onCallContact: () => _controller.launchPhoneCall(
                        context,
                        contact.phoneE164,
                        label: contact.name,
                      ),
                      onSetPrimary: () =>
                          _controller.setPrimaryContact(contact.id),
                      onToggleSelected: (val) {
                        final ok = _controller.toggleContactSelectedForSos(
                          contact.id,
                          val,
                        );
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Guardrail: At least 1 contact must remain selected for SOS alerts.',
                              ),
                            ),
                          );
                        }
                      },
                      onDelete: () {
                        _controller.removeTrustedContact(contact.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${contact.name} removed from Emergency Contacts.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),

                // Live Location Link & Emergency Dispatch Panel
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: SakhiModule4Colors.primaryPlum,
                      width: 1.4,
                    ),
                    boxShadow: SakhiModule4Colors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Location Link & Emergency Dispatch',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: SakhiModule4Colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _controller.hasRecentDeviceLocation
                            ? 'Payload: Name, Timestamp & Live GPS (${_controller.currentLatitude.toStringAsFixed(4)}, ${_controller.currentLongitude.toStringAsFixed(4)})'
                            : 'Enable device GPS in "Share My Live Location" to attach live coordinates.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: SakhiModule4Colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6ECF8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _controller.liveShareFullUrl.isNotEmpty
                                    ? _controller.liveShareFullUrl
                                    : (_controller.googleMapsPinUrl.isNotEmpty
                                          ? _controller.googleMapsPinUrl
                                          : 'Start Live Location Sharing to generate link'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: SakhiModule4Colors.primaryPlum,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final url =
                                    _controller.liveShareFullUrl.isNotEmpty
                                    ? _controller.liveShareFullUrl
                                    : _controller.googleMapsPinUrl;
                                if (url.isEmpty) {
                                  final started = await _controller
                                      .startLiveLocationSharing();
                                  if (!started || !context.mounted) return;
                                }
                                final linkToCopy =
                                    _controller.liveShareFullUrl.isNotEmpty
                                    ? _controller.liveShareFullUrl
                                    : _controller.googleMapsPinUrl;
                                await Clipboard.setData(
                                  ClipboardData(text: linkToCopy),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Live location tracking link copied to clipboard!',
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Copy Link',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: SakhiModule4Colors.sosCrimson,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () =>
                            _controller.dispatchSosAlertToContacts(context),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text(
                          'Send Emergency Alert to Selected Contacts',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _controller.stopLocationSharingAndEndSos();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Live location sharing stopped.',
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Stop Location Sharing',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const SosActivationHistoryScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Review SOS History',
                                style: TextStyle(
                                  fontSize: 12,
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
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TrustedContactCard extends StatelessWidget {
  final SafetyTrustedContact contact;
  final bool globalShowAll;
  final VoidCallback onTogglePhoneVisibility;
  final VoidCallback onCallContact;
  final VoidCallback onSetPrimary;
  final ValueChanged<bool> onToggleSelected;
  final VoidCallback onDelete;

  const _TrustedContactCard({
    required this.contact,
    required this.globalShowAll,
    required this.onTogglePhoneVisibility,
    required this.onCallContact,
    required this.onSetPrimary,
    required this.onToggleSelected,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isVisible = globalShowAll || contact.isNumberVisible;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: contact.isPrimary
              ? SakhiModule4Colors.primaryPlum
              : SakhiModule4Colors.borderSubtle,
          width: contact.isPrimary ? 1.5 : 1.0,
        ),
        boxShadow: SakhiModule4Colors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  SakhiModule4Assets.trustedContactAvatar,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFF3E6F5),
                    child: Text(
                      contact.name.isNotEmpty ? contact.name[0] : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: SakhiModule4Colors.primaryPlum,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${contact.name} (${contact.relationship})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (contact.isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: SakhiModule4Colors.primaryPlum,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Primary Contact',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.displayPhone(globalShowAll: globalShowAll),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: SakhiModule4Colors.primaryPlum,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: onTogglePhoneVisibility,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVisible
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 15,
                                  color: SakhiModule4Colors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isVisible ? 'Hide' : 'Show',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: SakhiModule4Colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Call ${contact.name}',
                onPressed: onCallContact,
                icon: const Icon(
                  Icons.call_rounded,
                  color: SakhiModule4Colors.verifiedEmerald,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              const Icon(
                Icons.notifications_active_outlined,
                size: 16,
                color: SakhiModule4Colors.primaryPlum,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Selected for SOS Alert',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: SakhiModule4Colors.textPrimary,
                  ),
                ),
              ),
              if (!contact.isPrimary)
                TextButton(
                  onPressed: onSetPrimary,
                  child: const Text(
                    'Set Primary',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              IconButton(
                tooltip: 'Delete contact',
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: SakhiModule4Colors.sosCrimson,
                  size: 20,
                ),
              ),
              Switch(
                value: contact.selectedForSosAlert,
                activeThumbColor: Colors.white,
                activeTrackColor: SakhiModule4Colors.primaryPlum,
                onChanged: onToggleSelected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Screen 5 — Share Live Location & Add Contact Bottom Sheet
// (`05_Share_Live_Location_and_Add_Contact_Modal_UI.jpg`)
// ============================================================================
class ShareLiveLocationScreen extends StatefulWidget {
  const ShareLiveLocationScreen({super.key});

  @override
  State<ShareLiveLocationScreen> createState() =>
      _ShareLiveLocationScreenState();
}

class _ShareLiveLocationScreenState extends State<ShareLiveLocationScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.initializeSafetyState(autoRequestGps: true));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final durations = ['15 Mins', '1 Hour', 'Until I Stop'];
        final hasLiveGps = _controller.hasRecentDeviceLocation;

        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Share My Live Location',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: hasLiveGps
                      ? SakhiModule4Colors.verifiedEmeraldTint
                      : SakhiModule4Colors.amberWarningBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  hasLiveGps ? 'GPS High Accuracy' : 'GPS unavailable',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: hasLiveGps
                        ? SakhiModule4Colors.verifiedEmerald
                        : SakhiModule4Colors.amberWarningText,
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Real Interactive OpenStreetMap with Live User Coordinate Marker
                SakhiLiveOsmMap(
                  height: 210,
                  initialZoom: 16,
                  latitude: _controller.currentLatitude,
                  longitude: _controller.currentLongitude,
                  hasLiveGps: hasLiveGps,
                  locationLabel: hasLiveGps
                      ? _controller.currentLocationLabel
                      : 'Tap to acquire live GPS',
                  accuracyMeters: _controller.currentAccuracyMeters,
                  onRequestGpsTap: () =>
                      unawaited(_controller.requestDeviceLocation()),
                ),
                const SizedBox(height: 14),

                // Live Location Duration & Consent Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SakhiModule4Colors.borderSubtle),
                    boxShadow: SakhiModule4Colors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Sharing Duration',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: SakhiModule4Colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: durations.map((dur) {
                          final selected =
                              _controller.selectedDurationLabel == dur;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ChoiceChip(
                                label: Center(child: Text(dur)),
                                selected: selected,
                                selectedColor: SakhiModule4Colors.primaryPlum,
                                backgroundColor: const Color(0xFFF6ECF8),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: selected
                                      ? Colors.white
                                      : SakhiModule4Colors.primaryPlum,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _controller.selectedDurationLabel = dur;
                                  });
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: SakhiModule4Colors.primaryPlum,
                          value: _controller.includeNameAndProfileInAlert,
                          title: const Text(
                            'Include my Name & Emergency Profile',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onChanged: (val) => setState(() {
                            _controller.includeNameAndProfileInAlert =
                                val ?? true;
                          }),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: SakhiModule4Colors.primaryPlum,
                          value: _controller.includeTimestampAndMapLink,
                          title: const Text(
                            'Include Timestamp & Live Map Link (Consent Granted)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onChanged: (val) => setState(() {
                            _controller.includeTimestampAndMapLink =
                                val ?? true;
                          }),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        key: const Key('start-live-location-sharing-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SakhiModule4Colors.sosCrimson,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: _controller.isAcquiringLocation
                            ? null
                            : () async {
                                final started = await _controller
                                    .startLiveLocationSharing();
                                if (!context.mounted) return;
                                if (!started) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor:
                                          SakhiModule4Colors.sosCrimson,
                                      behavior: SnackBarBehavior.floating,
                                      content: Text(
                                        _controller.locationStatusMessage,
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                await _controller.dispatchSosAlertToContacts(
                                  context,
                                );
                              },
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(
                          _controller.isAcquiringLocation
                              ? 'Acquiring Live GPS…'
                              : _controller.liveLocationSharingActive
                              ? 'Share Active Live Location Link Again'
                              : 'Start Live Location Sharing Now',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (_controller.liveLocationSharingActive) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SakhiModule4Colors.verifiedEmeraldTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: SakhiModule4Colors.verifiedEmerald,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Live Tracking Link Active',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            SakhiModule4Colors.verifiedEmerald,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                _controller.liveShareFullUrl,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: SakhiModule4Colors.primaryPlum,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Inline Add Trusted Contact Form
                const AddTrustedContactCardInline(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddTrustedContactSheet extends StatelessWidget {
  const AddTrustedContactSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 12,
        right: 12,
        top: 24,
      ),
      child: const SingleChildScrollView(child: AddTrustedContactCardInline()),
    );
  }
}

class AddTrustedContactCardInline extends StatefulWidget {
  const AddTrustedContactCardInline({super.key});

  @override
  State<AddTrustedContactCardInline> createState() =>
      _AddTrustedContactCardInlineState();
}

class _AddTrustedContactCardInlineState
    extends State<AddTrustedContactCardInline> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  String _selectedRelationship = 'Mom';
  bool _setAsPrimary = false;
  String? _errorText;

  final List<String> _relationships = const [
    'Mom',
    'Dad',
    'Sister',
    'Husband / Partner',
    'Roommate',
    'Best Friend',
    'Guardian',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _saveContact() {
    final err = SakhiSafetyController.instance.addTrustedContact(
      name: _nameCtrl.text,
      mobileNumber: _phoneCtrl.text,
      relationship: _selectedRelationship,
      setAsPrimary: _setAsPrimary,
    );
    if (err != null) {
      setState(() => _errorText = err);
      return;
    }
    setState(() => _errorText = null);
    _nameCtrl.clear();
    _phoneCtrl.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: SakhiModule4Colors.verifiedEmerald,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Trusted emergency contact saved permanently to your device & account!',
        ),
      ),
    );
    if (Navigator.of(context).canPop()) {
      // Close modal sheet if inside bottom sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SakhiModule4Colors.primaryPlum.withValues(alpha: 0.4),
        ),
        boxShadow: SakhiModule4Colors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Add Trusted Emergency Contact',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: SakhiModule4Colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('add-contact-name-input'),
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'e.g., Meera Verma',
              filled: true,
              fillColor: const Color(0xFFFAF5FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('add-contact-phone-input'),
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Mobile Number (+91)',
              hintText: '98450 99887',
              prefixText: '+91 ',
              filled: true,
              fillColor: const Color(0xFFFAF5FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedRelationship,
            decoration: InputDecoration(
              labelText: 'Relationship',
              filled: true,
              fillColor: const Color(0xFFFAF5FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _relationships
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedRelationship = val);
            },
          ),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: SakhiModule4Colors.primaryPlum,
              value: _setAsPrimary,
              title: const Text(
                'Set as Primary Emergency Contact',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              onChanged: (val) => setState(() => _setAsPrimary = val ?? false),
            ),
          ),
          if (_errorText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _errorText!,
                style: const TextStyle(
                  color: SakhiModule4Colors.sosCrimson,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          FilledButton(
            key: const Key('save-trusted-contact-button'),
            style: FilledButton.styleFrom(
              backgroundColor: SakhiModule4Colors.primaryPlum,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _saveContact,
            child: const Text(
              'Save Trusted Contact',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Dedicated Screen A — Discreet Shortcut Configuration & Live Sensor Test
// (Opened exclusively by the Top-Right `Shortcut` Gear Icon on Safety Hub)
// ============================================================================
class DiscreetShortcutConfigScreen extends StatelessWidget {
  const DiscreetShortcutConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SakhiSafetyController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Discreet SOS Shortcuts',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SakhiModule4Colors.borderSubtle),
                    boxShadow: SakhiModule4Colors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hardware & Gesture SOS Triggers (Section 6.2)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: SakhiModule4Colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Configure how you want to trigger SOS discreetly without unlocking or staring at your phone. Every trigger opens the 3-second confirmation guard first to prevent false alarms.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: SakhiModule4Colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: Colors.white,
                          activeTrackColor: SakhiModule4Colors.primaryPlum,
                          value: controller.powerButtonShortcutEnabled,
                          title: const Text(
                            'Power / Volume Button Triple-Press Shortcut',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: const Text(
                            'Press Volume Up/Down or Power button 3 times rapidly within 2 seconds to open the 3s SOS confirmation guard',
                            style: TextStyle(fontSize: 12),
                          ),
                          onChanged: controller.setPowerButtonShortcut,
                        ),
                      ),
                      const Divider(),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: Colors.white,
                          activeTrackColor: SakhiModule4Colors.primaryPlum,
                          value: controller.discreetShakeTriggerEnabled,
                          title: const Text(
                            'Discreet Shake-to-Trigger SOS',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: const Text(
                            'Shake your phone firmly 3 times using the hardware accelerometer to trigger the 3s SOS guard',
                            style: TextStyle(fontSize: 12),
                          ),
                          onChanged: controller.setDiscreetShakeShortcut,
                        ),
                      ),
                      if (controller.discreetShakeTriggerEnabled) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Shake Sensitivity Threshold:',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${controller.shakeSensitivityG.toStringAsFixed(1)} G (${controller.shakeSensitivityG <= 2.0
                                  ? "High Sensitivity"
                                  : controller.shakeSensitivityG >= 3.0
                                  ? "Firm Shake Only"
                                  : "Balanced"})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.primaryPlum,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: controller.shakeSensitivityG,
                          min: 1.6,
                          max: 3.8,
                          divisions: 11,
                          activeColor: SakhiModule4Colors.primaryPlum,
                          onChanged: controller.setShakeSensitivity,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live Sensor & Hardware Button Diagnostic Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6ECF8),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: SakhiModule4Colors.primaryPlum.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.sensors_rounded,
                            color: SakhiModule4Colors.primaryPlum,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Live Shortcut Diagnostics & Safe Test',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.primaryPlum,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        controller.lastShortcutTriggerSource != null
                            ? 'Last hardware trigger detected: ${controller.lastShortcutTriggerSource} at ${controller.lastShortcutTriggeredAt?.toLocal().toString().substring(11, 19)}'
                            : 'Try pressing your Volume Down/Up button 3 times rapidly right now (or shaking your phone if Shake-to-SOS is enabled), or tap below to test!',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: SakhiModule4Colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('run-safe-test-mode-button'),
                        style: FilledButton.styleFrom(
                          backgroundColor: SakhiModule4Colors.primaryPlum,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const SosWorkflowScreen(isTestMode: true),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                        ),
                        label: const Text(
                          'Run Safe Test Mode (Avoid False Triggers)',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
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

// ============================================================================
// Dedicated Screen B — SOS Activation History Log Screen
// (Opened by Row 2 `SOS Activation History` on Safety Hub)
// ============================================================================
class SosActivationHistoryScreen extends StatefulWidget {
  const SosActivationHistoryScreen({super.key});

  @override
  State<SosActivationHistoryScreen> createState() =>
      _SosActivationHistoryScreenState();
}

class _SosActivationHistoryScreenState
    extends State<SosActivationHistoryScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;
  String _filter = 'ALL'; // 'ALL', 'LIVE', 'TEST'

  void _showEventDetailDialog(SafetySosHistoryItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          item.badgeLabel,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Event ID: ${item.id}'),
            const SizedBox(height: 6),
            Text('Timestamp: ${item.timestampLabel}'),
            const SizedBox(height: 6),
            Text('Location: ${item.locationLabel}'),
            if (item.latitude != null && item.longitude != null) ...[
              const SizedBox(height: 6),
              Text(
                'Coordinates: ${item.latitude!.toStringAsFixed(5)}, ${item.longitude!.toStringAsFixed(5)}',
              ),
            ],
            const SizedBox(height: 8),
            Text(
              item.detailsSummary,
              style: const TextStyle(color: SakhiModule4Colors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final filtered = _controller.sosHistory.where((item) {
          if (_filter == 'LIVE') return !item.isTestMode;
          if (_filter == 'TEST') return item.isTestMode;
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'SOS Activation History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            actions: [
              if (_controller.sosHistory.any((h) => h.isTestMode))
                TextButton(
                  onPressed: _controller.clearLocalTestLogs,
                  child: const Text(
                    'Clear Tests',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: SakhiModule4Colors.sosCrimson,
                    ),
                  ),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ChoiceChip(
                      label: Text('All (${_controller.sosHistory.length})'),
                      selected: _filter == 'ALL',
                      onSelected: (_) => setState(() => _filter = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Live SOS'),
                      selected: _filter == 'LIVE',
                      onSelected: (_) => setState(() => _filter = 'LIVE'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Safe Tests / Cancelled'),
                      selected: _filter == 'TEST',
                      onSelected: (_) => setState(() => _filter = 'TEST'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: SakhiModule4Colors.borderSubtle,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.history_toggle_off_rounded,
                          size: 38,
                          color: SakhiModule4Colors.primaryPlum,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No SOS Events Recorded Yet',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: SakhiModule4Colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'When you trigger SOS or run a Safe Test, the timestamp, GPS coordinates, and status will be logged here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: SakhiModule4Colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    const SosWorkflowScreen(isTestMode: true),
                              ),
                            );
                          },
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('Run a Safe SOS Test Now'),
                        ),
                      ],
                    ),
                  ),

                ...filtered.map((item) {
                  final isCancelledOrTest =
                      item.isTestMode || item.status == 'CANCELLED';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showEventDetailDialog(item),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: SakhiModule4Colors.borderSubtle,
                          ),
                          boxShadow: SakhiModule4Colors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    item.timestampLabel,
                                    style: const TextStyle(
                                      fontSize: 13.5,
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
                                    color: isCancelledOrTest
                                        ? const Color(0xFFF3EBF5)
                                        : SakhiModule4Colors
                                              .verifiedEmeraldTint,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    item.badgeLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: isCancelledOrTest
                                          ? SakhiModule4Colors.primaryPlum
                                          : SakhiModule4Colors.verifiedEmerald,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Location: ${item.locationLabel}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Dedicated Screen C — Pre-Travel Safety Checklist & Cab/Auto Ride Logger
// (Opened by Row 3 `Safety Checklist & Discreet Trigger` on Safety Hub)
// ============================================================================
class PreTravelSafetyChecklistScreen extends StatefulWidget {
  const PreTravelSafetyChecklistScreen({super.key});

  @override
  State<PreTravelSafetyChecklistScreen> createState() =>
      _PreTravelSafetyChecklistScreenState();
}

class _PreTravelSafetyChecklistScreenState
    extends State<PreTravelSafetyChecklistScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;
  final TextEditingController _vehicleCtrl = TextEditingController();
  final TextEditingController _destCtrl = TextEditingController();
  final TextEditingController _customItemCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vehicleCtrl.text = _controller.loggedVehicleNumber;
    _destCtrl.text = _controller.loggedRideDestination;
  }

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _destCtrl.dispose();
    _customItemCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final total = _controller.preTravelChecklist.length;
        final checkedCount = _controller.preTravelChecklist
            .where((c) => c.isChecked)
            .length;

        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Pre-Travel Safety Checklist',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DiscreetShortcutConfigScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.vibration_rounded, size: 16),
                label: const Text('Shortcuts'),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Checklist Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SakhiModule4Colors.borderSubtle),
                    boxShadow: SakhiModule4Colors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Pre-Travel Safety Readiness',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: SakhiModule4Colors.verifiedEmeraldTint,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$checkedCount / $total Ready',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.verifiedEmerald,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._controller.preTravelChecklist.map(
                        (chk) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: SakhiModule4Colors.verifiedEmerald,
                          value: chk.isChecked,
                          title: Text(
                            chk.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onChanged: (val) =>
                              _controller.toggleChecklist(chk.id, val ?? false),
                        ),
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customItemCtrl,
                              decoration: InputDecoration(
                                hintText: 'Add your own safety check item…',
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFFAF5FB),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: SakhiModule4Colors.primaryPlum,
                            ),
                            onPressed: () {
                              _controller.addCustomChecklistItem(
                                _customItemCtrl.text,
                              );
                              _customItemCtrl.clear();
                            },
                            child: const Text('+ Add'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cab / Auto Vehicle Plate Logger Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: SakhiModule4Colors.primaryPlum.withValues(
                        alpha: 0.35,
                      ),
                    ),
                    boxShadow: SakhiModule4Colors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.local_taxi_rounded,
                            color: SakhiModule4Colors.primaryPlum,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cab / Auto Vehicle Plate Logger',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Log the vehicle registration plate before boarding. It will automatically be included in any SOS alert.',
                        style: TextStyle(
                          fontSize: 12,
                          color: SakhiModule4Colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _vehicleCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Vehicle Registration Plate (e.g., AP 21 AB 1234)',
                          filled: true,
                          fillColor: const Color(0xFFFAF5FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _destCtrl,
                        decoration: InputDecoration(
                          labelText: 'Destination / Route Note',
                          filled: true,
                          fillColor: const Color(0xFFFAF5FB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _controller.saveRideLog(
                                  vehicleNumber: _vehicleCtrl.text,
                                  destination: _destCtrl.text,
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Ride details saved & attached to SOS payload!',
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Save Ride Log'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: SakhiModule4Colors.primaryPlum,
                              ),
                              onPressed: () {
                                _controller.saveRideLog(
                                  vehicleNumber: _vehicleCtrl.text,
                                  destination: _destCtrl.text,
                                );
                                _controller.dispatchSosAlertToContacts(context);
                              },
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: const Text('Share with Family'),
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
        );
      },
    );
  }
}

// ============================================================================
// Dedicated Screen D — Personal Safety Tips & Interactive Step-by-Step Guides
// (Opened by Circle 3 `Safety Tips` on Safety Hub — Tapping ANY card opens detail!)
// ============================================================================
class PersonalSafetyTipsScreen extends StatefulWidget {
  const PersonalSafetyTipsScreen({super.key});

  @override
  State<PersonalSafetyTipsScreen> createState() =>
      _PersonalSafetyTipsScreenState();
}

class _PersonalSafetyTipsScreenState extends State<PersonalSafetyTipsScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;
  String _selectedCategory = 'All';

  void _openTipDetail(SafetyTipGuideModel tip) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafetyTipDetailSheet(tip: tip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = <String>[
      'All',
      ...{for (final g in _controller.safetyTipGuides) g.category},
    ];
    final filtered = _selectedCategory == 'All'
        ? _controller.safetyTipGuides
        : _controller.safetyTipGuides
              .where((g) => g.category == _selectedCategory)
              .toList();

    return Scaffold(
      backgroundColor: SakhiModule4Colors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: SakhiModule4Colors.surfaceBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: SakhiModule4Colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Personal Safety Tips & Guides',
          style: TextStyle(
            fontSize: 18,
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
            const Text(
              'Tap any safety guide card below to open the complete step-by-step action checklist, legal rights, and emergency dialer:',
              style: TextStyle(
                fontSize: 12.5,
                color: SakhiModule4Colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final selected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      selectedColor: SakhiModule4Colors.primaryPlum,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected
                            ? Colors.white
                            : SakhiModule4Colors.textPrimary,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedCategory = cat),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            ...filtered.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _InteractiveSafetyTipWideCard(
                  tip: tip,
                  onTap: () => _openTipDetail(tip),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InteractiveSafetyTipWideCard extends StatelessWidget {
  final SafetyTipGuideModel tip;
  final VoidCallback onTap;

  const _InteractiveSafetyTipWideCard({required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SakhiModule4Colors.borderSubtle),
            boxShadow: SakhiModule4Colors.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      tip.illustrationAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Container(color: const Color(0xFFF3EBF5)),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SakhiModule4Colors.primaryPlum.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tip.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: SakhiModule4Colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip.subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SakhiModule4Colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${tip.actionSteps.length} Actionable Steps • Tap to Open Guide',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: SakhiModule4Colors.primaryPlum,
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: SakhiModule4Colors.primaryPlum,
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
    );
  }
}

class SafetyTipDetailSheet extends StatefulWidget {
  final SafetyTipGuideModel tip;

  const SafetyTipDetailSheet({super.key, required this.tip});

  @override
  State<SafetyTipDetailSheet> createState() => _SafetyTipDetailSheetState();
}

class _SafetyTipDetailSheetState extends State<SafetyTipDetailSheet> {
  final Set<int> _completedSteps = <int>{0};

  @override
  Widget build(BuildContext context) {
    final tip = widget.tip;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: SakhiModule4Colors.surfaceBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFF2E6F7),
                  child: Icon(tip.icon, color: SakhiModule4Colors.primaryPlum),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: SakhiModule4Colors.primaryPlum,
                        ),
                      ),
                      Text(
                        tip.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: SakhiModule4Colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 135,
                child: Image.asset(
                  tip.illustrationAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: const Color(0xFFF3EBF5)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Step-by-Step Safety Action Plan (Tap to Check Off):',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(tip.actionSteps.length, (index) {
              final done = _completedSteps.contains(index);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      if (done) {
                        _completedSteps.remove(index);
                      } else {
                        _completedSteps.add(index);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: done
                            ? SakhiModule4Colors.verifiedEmerald
                            : SakhiModule4Colors.borderSubtle,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          done
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: done
                              ? SakhiModule4Colors.verifiedEmerald
                              : SakhiModule4Colors.primaryPlum,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Step ${index + 1}: ${tip.actionSteps[index]}',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                              color: SakhiModule4Colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF6ECF8),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Essential Do’s & Don’ts',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: SakhiModule4Colors.primaryPlum,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...tip.dosAndDonts.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• $d',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: SakhiModule4Colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final text =
                          '${tip.title}\n\n${tip.actionSteps.map((s) => "• $s").join("\n")}\n\nEmergency Helpline: ${tip.emergencyNumber}';
                      SharePlus.instance.share(ShareParams(text: text));
                    },
                    icon: const Icon(Icons.share_rounded, size: 17),
                    label: const Text('Share Guide'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SakhiModule4Colors.sosCrimson,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        SakhiSafetyController.instance.launchPhoneCall(
                          context,
                          tip.emergencyNumber,
                          label: '${tip.emergencyNumber} Emergency Helpline',
                        ),
                    icon: const Icon(Icons.call_rounded, size: 17),
                    label: Text('Call ${tip.emergencyNumber} Now'),
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

// ============================================================================
// Dedicated Screen E — National Emergency 112 Rapid-Dispatch Screen
// (Opened by Circle 4 `Helplines (112)` on Safety Hub)
// ============================================================================
class NationalEmergency112Screen extends StatelessWidget {
  const NationalEmergency112Screen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SakhiSafetyController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hasGps = controller.hasRecentDeviceLocation;
        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: SakhiModule4Colors.textPrimary,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              '112 Emergency Rapid Dispatch',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hero 112 ERSS + 100 Police Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC92A49), Color(0xFF8C1630)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: SakhiModule4Colors.cardShadow,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.emergency_share_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '112 — India National Emergency Number',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Opens your phone’s native SIM dialer immediately for Police, Fire & Medical ERSS dispatch.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: SakhiModule4Colors.sosCrimson,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => controller.launchPhoneCall(
                          context,
                          '112',
                          label: '112 National Emergency Response',
                        ),
                        icon: const Icon(Icons.phone_in_talk_rounded),
                        label: const Text(
                          'Dial 112 in Phone Dialer Now',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => controller.launchPhoneCall(
                          context,
                          '100',
                          label: '100 Direct Police Control Room',
                        ),
                        icon: const Icon(Icons.local_police_rounded),
                        label: const Text(
                          'Dial 100 Direct Police Control Room',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Read My Live GPS Coordinates to the 112 Operator Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SakhiModule4Colors.borderSubtle),
                    boxShadow: SakhiModule4Colors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.record_voice_over_rounded,
                            color: SakhiModule4Colors.primaryPlum,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Read Your Live GPS Location to the 112 Operator',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF5FB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasGps
                                  ? 'Area: ${controller.currentLocationLabel}'
                                  : 'GPS not yet active — tap Refresh GPS below',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasGps
                                  ? 'Coordinates: Lat ${controller.currentLatitude.toStringAsFixed(5)}° N, Lng ${controller.currentLongitude.toStringAsFixed(5)}° E'
                                  : 'Coordinates unavailable',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: SakhiModule4Colors.primaryPlum,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  unawaited(controller.requestDeviceLocation()),
                              icon: const Icon(
                                Icons.my_location_rounded,
                                size: 16,
                              ),
                              label: const Text('Refresh GPS'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: SakhiModule4Colors.primaryPlum,
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const VerifiedHelplinesDirectoryScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.list_alt_rounded,
                                size: 16,
                              ),
                              label: const Text('All Helplines'),
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
        );
      },
    );
  }
}

// ============================================================================
// Dedicated Screen F — Full Verified Helplines Directory & Safety Tips
// (Opened by Row 4 `Emergency Helplines & 112` on Safety Hub)
// ============================================================================
class VerifiedHelplinesDirectoryScreen extends StatefulWidget {
  const VerifiedHelplinesDirectoryScreen({super.key});

  @override
  State<VerifiedHelplinesDirectoryScreen> createState() =>
      _VerifiedHelplinesDirectoryScreenState();
}

class _VerifiedHelplinesDirectoryScreenState
    extends State<VerifiedHelplinesDirectoryScreen> {
  final SakhiSafetyController _controller = SakhiSafetyController.instance;
  String _searchQuery = '';

  void _openTipDetail(SafetyTipGuideModel tip) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafetyTipDetailSheet(tip: tip),
    );
  }

  @override
  Widget build(BuildContext context) {
    final helplines = _controller.verifiedHelplines.where((h) {
      final q = _searchQuery.trim().toLowerCase();
      if (q.isEmpty) return true;
      return h.title.toLowerCase().contains(q) ||
          h.subtitle.toLowerCase().contains(q) ||
          h.number.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: SakhiModule4Colors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: SakhiModule4Colors.surfaceBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: SakhiModule4Colors.textPrimary,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Helplines & Safety Directory',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: SakhiModule4Colors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero 112 & 100 Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECEF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: SakhiModule4Colors.sosCrimson,
                  width: 1.5,
                ),
                boxShadow: SakhiModule4Colors.cardShadow,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: SakhiModule4Colors.sosCrimson,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_in_talk_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '112 — India National Emergency Number',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: SakhiModule4Colors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              '24/7 Police, Fire & Medical Emergency Response (ERSS)',
                              style: TextStyle(
                                fontSize: 12,
                                color: SakhiModule4Colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: SakhiModule4Colors.sosCrimson,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () => _controller.launchPhoneCall(
                            context,
                            '112',
                            label: '112 National Emergency Response',
                          ),
                          icon: const Icon(Icons.call_rounded, size: 17),
                          label: const Text(
                            'Tap to Call 112',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: SakhiModule4Colors.primaryPlum,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () => _controller.launchPhoneCall(
                            context,
                            '100',
                            label: '100 Direct Police Dispatch',
                          ),
                          icon: const Icon(
                            Icons.local_police_rounded,
                            size: 17,
                          ),
                          label: const Text(
                            'Call 100 Police',
                            style: TextStyle(
                              fontSize: 13,
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
            const SizedBox(height: 14),

            // Search Bar
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search helplines (1091, 181, 108, 1930, NCW…)',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: SakhiModule4Colors.borderSubtle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Verified 24/7 Women & Safety Helplines',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            ...helplines.map(
              (hl) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: SakhiModule4Colors.borderSubtle),
                    boxShadow: SakhiModule4Colors.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: hl.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          hl.vectorIcon,
                          color: hl.accentColor,
                          size: 24,
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
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: hl.accentColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        onPressed: () => _controller.launchPhoneCall(
                          context,
                          hl.number,
                          label: hl.title,
                        ),
                        icon: const Icon(Icons.call_rounded, size: 15),
                        label: const Text(
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

            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Essential Personal Safety Tips (Tap to Read)',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: SakhiModule4Colors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PersonalSafetyTipsScreen(),
                      ),
                    );
                  },
                  child: const Text('See All Guides ›'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Tappable Safety Tip Cards — Tapping opens SafetyTipDetailSheet!
            Row(
              children: [
                Expanded(
                  child: _SafetyTipCardTile(
                    key: const Key('tip-card-commute-cab-safety'),
                    tip: _controller.safetyTipGuides[0],
                    onTap: () => _openTipDetail(_controller.safetyTipGuides[0]),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SafetyTipCardTile(
                    key: const Key('tip-card-discreet-sos-safely'),
                    tip: _controller.safetyTipGuides[1],
                    onTap: () => _openTipDetail(_controller.safetyTipGuides[1]),
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

class _SafetyTipCardTile extends StatelessWidget {
  final SafetyTipGuideModel tip;
  final VoidCallback onTap;

  const _SafetyTipCardTile({super.key, required this.tip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SakhiModule4Colors.borderSubtle),
            boxShadow: SakhiModule4Colors.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 92,
                width: double.infinity,
                child: Image.asset(
                  tip.illustrationAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      Container(color: const Color(0xFFF3EBF5)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: SakhiModule4Colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tip.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: SakhiModule4Colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      children: [
                        Text(
                          'Read Guide',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: SakhiModule4Colors.primaryPlum,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 12,
                          color: SakhiModule4Colors.primaryPlum,
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
    );
  }
}

// ============================================================================
// Backward-Compatible Combined Screen Classes for Existing Widget Tests
// (`SafetyHistoryAndSettingsScreen` & `HelplinesAndSafetyTipsScreen`)
// ============================================================================
class SafetyHistoryAndSettingsScreen extends StatelessWidget {
  const SafetyHistoryAndSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = SakhiSafetyController.instance;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: SakhiModule4Colors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: SakhiModule4Colors.surfaceBackground,
            elevation: 0,
            title: const Text(
              'Safety History & Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: SakhiModule4Colors.textPrimary,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SakhiModule4Colors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: controller.powerButtonShortcutEnabled,
                        title: const Text(
                          'Power Button Triple-Press Shortcut',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onChanged: controller.setPowerButtonShortcut,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: controller.discreetShakeTriggerEnabled,
                        title: const Text(
                          'Discreet Shake-to-Trigger SOS (Beta)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onChanged: controller.setDiscreetShakeShortcut,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  const SosWorkflowScreen(isTestMode: true),
                            ),
                          );
                        },
                        icon: const Icon(Icons.verified_user_outlined),
                        label: const Text(
                          'Run Safe Test Mode (Avoid False Triggers)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SakhiModule4Colors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pre-Travel Safety Checklist',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      ...controller.preTravelChecklist.map(
                        (chk) => CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: chk.isChecked,
                          title: Text(chk.title),
                          onChanged: (val) =>
                              controller.toggleChecklist(chk.id, val ?? false),
                        ),
                      ),
                    ],
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

class HelplinesAndSafetyTipsScreen extends StatelessWidget {
  const HelplinesAndSafetyTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const VerifiedHelplinesDirectoryScreen();
  }
}
