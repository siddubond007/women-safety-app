/// Business/legal settings that must be approved before launch.
///
/// Deliberately null until the product owner supplies the approved rule.
/// Do not infer a minimum age from a common default such as 18.
abstract final class SakhiAuthPolicy {
  static const int? minimumRegistrationAgeYears = null;

  // Replace these draft markers with the approved legal-document versions.
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
