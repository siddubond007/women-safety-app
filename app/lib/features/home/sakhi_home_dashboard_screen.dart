import 'package:flutter/material.dart';

import '../../core/branding/app_brand.dart';
import '../../core/theme/sakhi_design_system.dart';
import '../auth/auth_service.dart';
import '../auth/backend_api_client.dart';
import '../auth/sakhi_login_screen.dart';

/// First integrated screen from the 12-screen Sakhi UI prototype.
///
/// The layout and hero artwork come from the prototype. Profile display name
/// is read from the authenticated development API; content modules remain
/// explicitly unavailable until their service contracts are implemented.
class SakhiHomeDashboardScreen extends StatefulWidget {
  const SakhiHomeDashboardScreen({
    super.key,
    required this.authService,
    this.loadDisplayName,
  });

  final AuthService authService;

  /// Injectable for widget tests. Normal app use reads the authenticated API.
  final Future<String?> Function()? loadDisplayName;

  @override
  State<SakhiHomeDashboardScreen> createState() =>
      _SakhiHomeDashboardScreenState();
}

class _SakhiHomeDashboardScreenState extends State<SakhiHomeDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<String?> _displayNameFuture;
  String _searchQuery = '';
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _displayNameFuture = _readDisplayName();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _readDisplayName() async {
    try {
      if (widget.loadDisplayName != null) {
        return await widget.loadDisplayName!();
      }
      final payload = await BackendApiClient().get(
        'auth/me',
        authenticated: true,
      );
      final profile = payload['profile'];
      if (profile is Map<String, dynamic>) {
        final displayName = profile['displayName'];
        if (displayName is String && displayName.trim().isNotEmpty) {
          return displayName.trim();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  void _showFeatureNotice(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$feature is not connected yet. No data has been changed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showSafetyBoundary() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.sos_rounded,
          size: 38,
          color: Color(0xFFCC3F5A),
        ),
        title: const Text('Safety & SOS preview'),
        content: const Text(
          'Emergency dispatch is not connected in this development build. '
          'No call, SMS, GPS tracking, or alert has been started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    String? warning;
    try {
      await widget.authService.logout();
    } catch (_) {
      warning = 'The backend could not confirm session revocation.';
    }
    if (!mounted) return;
    final warningMessage = warning;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (loginContext) {
          if (warningMessage != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (loginContext.mounted) {
                ScaffoldMessenger.maybeOf(loginContext)?.showSnackBar(
                  SnackBar(content: Text(warningMessage)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SakhiColors.blush,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DashboardHeader(
              signingOut: _signingOut,
              onNotifications: () => _showFeatureNotice('Notifications'),
              onSignOut: _signOut,
            ),
            Expanded(
              child: ListView(
                key: const Key('sakhi-home-dashboard-list'),
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                children: [
                  TextField(
                    key: const Key('home-dashboard-search'),
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search people, topics, groups...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: SakhiColors.progressInactive,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color(0xFFEEDCEB),
                        ),
                      ),
                    ),
                  ),
                  if (_searchQuery.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const _InlineNotice(
                      icon: Icons.info_outline_rounded,
                      message:
                          'Discovery search is not connected yet. Search results are not being retrieved.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  FutureBuilder<String?>(
                    future: _displayNameFuture,
                    builder: (context, snapshot) {
                      final displayName = snapshot.data;
                      return _GreetingHero(
                        greeting: _greeting,
                        displayName: displayName,
                        profileLoading:
                            snapshot.connectionState != ConnectionState.done,
                        onTap: () => _showFeatureNotice('Profile overview'),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Quick access',
                    style: TextStyle(
                      color: SakhiColors.plum,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          key: const Key('home-action-explore'),
                          label: 'Explore',
                          icon: Icons.travel_explore_rounded,
                          tint: const Color(0xFFF2E6FA),
                          accent: SakhiColors.purple,
                          onTap: () => _showFeatureNotice('Explore'),
                        ),
                      ),
                      Expanded(
                        child: _QuickAction(
                          key: const Key('home-action-community'),
                          label: 'Community',
                          icon: Icons.groups_rounded,
                          tint: const Color(0xFFFDE8F1),
                          accent: const Color(0xFFC02668),
                          onTap: () => _showFeatureNotice('Community'),
                        ),
                      ),
                      Expanded(
                        child: _QuickAction(
                          key: const Key('home-action-wellness'),
                          label: 'Wellness',
                          icon: Icons.spa_rounded,
                          tint: const Color(0xFFE6F7EF),
                          accent: const Color(0xFF25855A),
                          onTap: () => _showFeatureNotice('Wellness'),
                        ),
                      ),
                      Expanded(
                        child: _QuickAction(
                          key: const Key('home-action-sos'),
                          label: 'SOS',
                          icon: Icons.sos_rounded,
                          tint: const Color(0xFFFDE8EC),
                          accent: const Color(0xFFCC3F5A),
                          onTap: _showSafetyBoundary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'For you today',
                          style: TextStyle(
                            color: SakhiColors.plum,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showFeatureNotice('Personalized feed'),
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _ForYouCard(
                    icon: Icons.groups_2_rounded,
                    iconColor: const Color(0xFFB34F91),
                    iconBackground: const Color(0xFFFDE8F1),
                    title: 'Community updates',
                    description:
                        'Posts and group activity will appear when the community service is connected.',
                    onTap: () => _showFeatureNotice('Community feed'),
                  ),
                  const SizedBox(height: 10),
                  _ForYouCard(
                    icon: Icons.spa_outlined,
                    iconColor: const Color(0xFF25855A),
                    iconBackground: const Color(0xFFE6F7EF),
                    title: 'Wellness resources',
                    description:
                        'Explore approved wellness content when the wellness service is available.',
                    onTap: () => _showFeatureNotice('Wellness resources'),
                  ),
                  const SizedBox(height: 10),
                  _ForYouCard(
                    icon: Icons.shield_outlined,
                    iconColor: SakhiColors.purple,
                    iconBackground: const Color(0xFFF2E6FA),
                    title: 'Safety guidance',
                    description:
                        'Safety information is a preview here; emergency assistance is not active.',
                    onTap: _showSafetyBoundary,
                  ),
                  const SizedBox(height: 18),
                  const _InlineNotice(
                    icon: Icons.verified_user_outlined,
                    message:
                        'Development preview: your account was allowed into Home by the existing authenticated, verified-session gate. The cards above do not represent live posts, alerts, location tracking, or emergency dispatch.',
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            _DashboardBottomBar(
              onSelect: (label) {
                if (label == 'Home') return;
                if (label == 'Profile') {
                  _showFeatureNotice('Profile overview');
                } else {
                  _showFeatureNotice(label);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.signingOut,
    required this.onNotifications,
    required this.onSignOut,
  });

  final bool signingOut;
  final VoidCallback onNotifications;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 14, 12),
      child: Row(
        children: [
          Image.asset(
            AppBrand.logoAsset,
            width: 106,
            height: 43,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (_, __, ___) => const Text(
              AppBrand.appName,
              style: TextStyle(
                color: SakhiColors.plum,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications,
            icon: const Icon(
              Icons.notifications_none_rounded,
              color: SakhiColors.purple,
              size: 25,
            ),
          ),
          IconButton(
            tooltip: signingOut ? 'Signing out' : 'Sign out',
            onPressed: signingOut ? null : onSignOut,
            icon: signingOut
                ? const SizedBox(
                    height: 19,
                    width: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.logout_rounded,
                    color: SakhiColors.purple,
                  ),
          ),
        ],
      ),
    );
  }
}

class _GreetingHero extends StatelessWidget {
  const _GreetingHero({
    required this.greeting,
    required this.displayName,
    required this.profileLoading,
    required this.onTap,
  });

  final String greeting;
  final String? displayName;
  final bool profileLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          height: 164,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFCE4F0), Color(0xFFF3DCF8)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFEEDCEB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D79318A),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                Positioned(
                  right: -7,
                  bottom: -10,
                  width: 166,
                  height: 164,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/home/greeting_hero_illustration.webp',
                      fit: BoxFit.contain,
                      alignment: Alignment.bottomRight,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 17, 132, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        greeting,
                        style: const TextStyle(
                          color: SakhiColors.plum,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profileLoading
                            ? 'Welcome back'
                            : (displayName?.isNotEmpty == true
                                ? displayName!
                                : 'Welcome back'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SakhiColors.plum,
                          fontSize: 25,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A safer, stronger and more connected you.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SakhiColors.mutedPlum,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.label,
    required this.icon,
    required this.tint,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
          child: Column(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: SakhiColors.plum,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForYouCard extends StatelessWidget {
  const _ForYouCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: SakhiColors.plum,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        color: SakhiColors.mutedPlum,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.chevron_right_rounded,
                color: SakhiColors.mutedPlum,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EDF8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: SakhiColors.purple, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: SakhiColors.mutedPlum,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBottomBar extends StatelessWidget {
  const _DashboardBottomBar({required this.onSelect});

  final ValueChanged<String> onSelect;

  static const _items = <({String label, IconData icon})>[
    (label: 'Home', icon: Icons.home_rounded),
    (label: 'Explore', icon: Icons.travel_explore_rounded),
    (label: 'Community', icon: Icons.groups_rounded),
    (label: 'Profile', icon: Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEFE3ED))),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: Semantics(
                button: true,
                selected: item.label == 'Home',
                label: item.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelect(item.label),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 23,
                          color: item.label == 'Home'
                              ? SakhiColors.purple
                              : SakhiColors.mutedPlum,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: item.label == 'Home'
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: item.label == 'Home'
                                ? SakhiColors.purple
                                : SakhiColors.mutedPlum,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
