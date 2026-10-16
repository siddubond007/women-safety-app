import 'package:flutter/foundation.dart' show kDebugMode;

/// Provisional preview settings for Sakhi authentication.
///
/// The product owner has requested age 13 for temporary development testing.
/// This is not an approved production/legal policy. Release builds intentionally
/// keep the age threshold unset until formal business/legal approval is recorded.
abstract final class SakhiAuthPolicy {
  static const int provisionalPreviewMinimumAgeYears = 13;
  static const bool usesProvisionalPreviewPolicy = kDebugMode;
  static const int? minimumRegistrationAgeYears = kDebugMode
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
