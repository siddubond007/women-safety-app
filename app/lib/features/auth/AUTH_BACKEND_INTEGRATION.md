# Sakhi authentication backend integration

**Current status:** the local development backend adapter is implemented in stacked PR #9. Session restoration and sign-out are added in draft PR #11. The integration is for development/test only; it is not a production authentication or SMS provider.

## Flutter boundary

The widgets depend on the typed `AuthService` interface. The backend adapter handles HTTP, response validation, secure token storage and user-safe error mapping.

Implemented development operations:

1. **Request OTP** — submits country calling code, phone number and purpose and returns an opaque challenge ID, expiry, resend time and the code deliberately echoed by the local dev/test backend.
2. **Resend OTP** — refers to the prior challenge; the backend enforces the cooldown, resend and attempt limits.
3. **Verify OTP** — submits the challenge reference and six-digit code and handles verified, invalid, expired and rate-limited outcomes.
4. **Save profile and draft-policy acknowledgement** — submits display name, date of birth, optional email, draft Terms/Privacy versions and acknowledgement metadata. The backend records the receipt time itself and separately stores the optional product-update preference. Photo selection is still a UI-only preview; no photo is uploaded.
5. **Restore saved session** — reads the bearer token from Flutter secure storage and validates it with `GET /api/v1/auth/me`. A valid response restores only the account state reported by the backend; it never implies eligibility or protected access.
6. **Sign out** — calls `POST /api/v1/auth/logout` to revoke the server session, then clears the locally stored token. If the server cannot confirm revocation, the app still clears the local credential and reports that limitation.
7. **Eligibility endpoints** — the development adapter calls configuration/status/start, but the backend remains fail-closed and reports provider unavailable.

## Server-side requirements

The backend—not Flutter—enforces challenge expiration, one-time use, attempt and resend limits, account state, session issuance/revocation, authorization on protected requests, consent records, development age-policy checks and safe handling of profile data. Do not log OTPs, passwords, bearer tokens or unnecessary full phone numbers.

The local backend accepts OTP codes only in explicit development/test mode bound to loopback. The displayed code is not SMS delivery or carrier verification. The backend stores a digest of the code and a digest of the session token, not the raw values.

`auth_policy.dart` exposes a provisional minimum age of 13 only for debug preview testing. This is not approved production policy. Release builds keep `minimumRegistrationAgeYears` unset and fail closed until the business/legal team approves the production age policy. Terms and Privacy versions remain `draft` and are explicitly identified as not approved for production; replace them with legal-reviewed, published versions before launch.

## Build modes

- **Debug preview without `SAKHI_BACKEND_ENABLED=true`:** `DemoAuthService` simulates the OTP screen only. Any six digits can preview navigation. No SMS, member account or authenticated session is created.
- **Debug local-backend mode:** build with `--dart-define=SAKHI_BACKEND_ENABLED=true` and a `SAKHI_API_BASE_URL` pointing to the local API. Example for Android USB reverse on port 3001: `http://127.0.0.1:3001/api/v1`. OTP codes are test codes returned by the local backend; no SMS is sent. At startup, a saved session is checked before displaying onboarding.
- **Release mode:** `UnconfiguredAuthService` fails clearly until a production identity/SMS provider and production API environment are separately approved and implemented.

No production OTP credentials, provider secrets or API keys are hardcoded. This development session does not establish real-world identity, eligibility or access to protected app functionality.
