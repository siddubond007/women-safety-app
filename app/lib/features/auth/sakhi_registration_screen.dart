import 'package:flutter/material.dart';

import '../../core/assets/app_assets.dart';
import 'auth_service.dart';
import 'sakhi_login_screen.dart';
import 'sakhi_mobile_entry_form.dart';
import 'widgets/auth_widgets.dart';

class SakhiRegistrationScreen extends StatelessWidget {
  const SakhiRegistrationScreen({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return SakhiAuthScaffold(
      botanicalAsset: AppAssets.authBotanicalConsent,
      authIsDemo: authService.isDemo,
      authIsDevelopmentBackend: authService.isDevelopmentBackend,
      botanicalHeight: 80,
      child: SakhiMobileEntryForm(
        authService: authService,
        purpose: AuthPurpose.registration,
        onSwitchMethod: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SakhiLoginScreen(authService: authService),
          ),
        ),
      ),
    );
  }
}
