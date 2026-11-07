import 'package:flutter/foundation.dart' show kDebugMode;

/// Provisional preview settings for Sakhi authentication.
///
/// The local debug preview uses a temporary age-13 rule. A staging-test APK
/// opts in explicitly with SAKHI_STAGING_TEST_MODE=true and uses age 18.
/// Neither rule is an approved production/legal policy.
abstract final class SakhiAuthPolicy {
  static const int provisionalPreviewMinimumAgeYears = 13;
  static const int stagingTestMinimumAgeYears = 18;
  static const bool isStagingTestBuild = bool.fromEnvironment(
    'SAKHI_STAGING_TEST_MODE',
    defaultValue: false,
  );
  static const bool usesProvisionalPreviewPolicy =
      kDebugMode && !isStagingTestBuild;
  static const int? minimumRegistrationAgeYears = isStagingTestBuild
      ? stagingTestMinimumAgeYears
      : kDebugMode
      ? provisionalPreviewMinimumAgeYears
      : null;

  // Replace these draft markers with approved legal-document versions before launch.
  static const String termsVersion = 'draft';
  static const String privacyVersion = 'draft';
}

bool isAtLeastMinimumAge(DateTime dateOfBirth, DateTime today, int minimumAge) {
  var age = today.year - dateOfBirth.year;
  final birthdayHasNotOccurred =
      today.month < dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day < dateOfBirth.day);
  if (birthdayHasNotOccurred) age--;
  return age >= minimumAge;
}
