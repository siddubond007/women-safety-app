# Sakhi authentication backend integration contract

**Status:** planned contract only. The repository does not currently contain a connected authentication backend or SMS provider.

## Flutter boundary

Implement the existing `AuthService` interface with a backend-backed adapter. Keep widgets independent from HTTP details and map server responses into the typed models in `auth_service.dart`.

Required operations:

1. **Request OTP** — submit country calling code, phone number and purpose; return an opaque request/session ID, expiration time and resend-available time. Never claim that an SMS was sent unless the provider confirms the request.
2. **Resend OTP** — refer to the previous request/session; the server must enforce cooldowns, resend caps and abuse controls.
3. **Verify OTP** — submit the session reference and six-digit code; return a typed result for verified, invalid, expired or rate-limited outcomes and the account state (`existingAccount`, `newAccount`, `pendingVerification` or `restricted`).
4. **Create/update member profile and consent** — submit the verified registration context, display name, date of birth, optional email, optional photo upload reference and the Terms/Privacy version plus acceptance timestamp. Return an `AccountCreationResult` with the account state and a user-safe message so navigation is determined by the actual response.
5. **Optional photo upload** — when a provider and storage policy are approved, upload through an authenticated, authorization-checked flow and pass a returned reference into the profile request. The current UI does not upload photos.

## Server-side requirements

The future backend—not the Flutter UI—must enforce OTP expiration, one-time use, attempt and resend limits, rate limiting, duplicate-number handling, session issuance/revocation, authorization on protected requests, consent records, age-policy validation, and safe handling of sensitive profile data. Do not log OTPs, passwords, access tokens or unnecessary full phone numbers.

`auth_policy.dart` exposes a provisional minimum age of 13 only in debug builds for local flow testing. This is not approved production policy. Release builds keep `minimumRegistrationAgeYears` unset, so registration fails closed until the business/legal team approves the minimum age and a production policy is configured. The Terms and Privacy screens now contain temporary, readable draft copy labelled `DRAFT — NOT APPROVED FOR PRODUCTION`; versions remain `draft`. Replace and approve both documents before launch. The temporary age-13 rule must not be promoted to release by accident.

## Current mode behavior

- Debug builds use `DemoAuthService`: any six digits only simulate the OTP step, with a visible demo banner. No SMS, member account, or authenticated session is created.
- Release builds use `UnconfiguredAuthService`, which fails clearly and does not claim that SMS was sent or account creation succeeded.
- No production OTP, credentials, provider secrets, or API keys are hardcoded.
