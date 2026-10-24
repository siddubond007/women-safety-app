// Sakhi — Module 4: Emergency SOS & Personal Safety Design System & Asset Tokens (Screen 9)
import 'package:flutter/material.dart';
import '../../../core/assets/app_assets.dart';

abstract final class SakhiModule4Colors {
  static const Color surfaceBackground = Color(0xFFFDF8FB);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFEFE3EE);
  static const Color primaryPlum = Color(0xFF5A1868);
  static const Color primaryPlumDark = Color(0xFF3B0D47);
  static const Color secondaryLavenderPill = Color(0xFFF3E8F6);
  static const Color emergencyCrimson = Color(0xFFC92A49);
  static const Color emergencyRoseSecondary = Color(0xFFCF5C72);
  static const Color emergencySoftTint = Color(0xFFFCE8EC);
  static const Color verifiedMintText = Color(0xFF1E7E55);
  static const Color verifiedMintBg = Color(0xFFE3F7ED);
  static const Color verifiedMintBorder = Color(0xFFA3DFC1);
  static const Color warningAmberText = Color(0xFF8A5300);
  static const Color warningAmberBg = Color(0xFFFFF3DC);
  static const Color warningAmberBorder = Color(0xFFF5D08A);
  static const Color pastelPeachBg = Color(0xFFFFF1DB);
  static const Color pastelLavenderBg = Color(0xFFEFE6F7);
  static const Color textPrimary = Color(0xFF2A1930);
  static const Color textSecondary = Color(0xFF6E6275);
}

abstract final class SakhiModule4Dimensions {
  static const double cardBorderRadius = 16.0;
  static const double pillBorderRadius = 999.0;
  static const double quickActionCircleSize = 64.0;
  static const double listRowIconBadgeSize = 44.0;
  static const double sosHeroButtonSize = 88.0;
  static const int sosCountdownSeconds = 3;
}

abstract final class SakhiModule4Assets {
  // Standalone Illustrations & Emblems
  static const String sakhiShieldLotus = AppAssets.module4ShieldLotus;
  static const String sosPulsingHeroBtn = AppAssets.module4SosHeroButton;
  static const String emergency112Emblem = AppAssets.module4Emergency112Emblem;
  static const String trustedContactAvatar = AppAssets.module4TrustedContactAvatar;
  static const String commuteSafetyIllustration = AppAssets.module4CommuteSafetyIllustration;
  static const String discreetSosIllustration = AppAssets.module4DiscreetSosIllustration;
  static const String pastelMapBackground = AppAssets.module4PastelMapCanvas;

  // @3x Transparent PNG Category & Row Badges
  static const String icEmergencyContacts = AppAssets.icM4EmergencyContacts;
  static const String icNearestPolice = AppAssets.icM4NearestPolice;
  static const String icSafetyTips = AppAssets.icM4SafetyTips;
  static const String icHelplines112 = AppAssets.icM4Helplines112;
  static const String icLiveLocationRadar = AppAssets.icM4LiveLocationRadar;
  static const String icSosHistoryClock = AppAssets.icM4SosHistoryClock;
  static const String icSafetyChecklist = AppAssets.icM4SafetyChecklist;
  static const String icHelplineHeadset = AppAssets.icM4HelplineHeadset;
  static const String icWomenPolice1091 = AppAssets.icM4WomenPolice1091;
  static const String icDomesticSupport181 = AppAssets.icM4DomesticSupport181;
  static const String icMedicalCyber108 = AppAssets.icM4MedicalCyber108;
  static const String icAdminSecurityLock = AppAssets.icM4AdminSecurityLock;

  // Reusable PNG Controls
  static const String btnSosPulsingCenter = AppAssets.btnM4SosPulsingCenter;
  static const String togglePlumOn = AppAssets.toggleM4PlumOn;
  static const String togglePlumOff = AppAssets.toggleM4PlumOff;
  static const String womenQuotesJson = AppAssets.module4WomenQuotesJson;
}
