# Decentro DigiLocker staging integration

## Runtime configuration

The backend reads Decentro settings from its private runtime environment. Use backend/.env for local development and the hosting provider secret store for staging. Do not commit real credentials, copy them into the Flutter app, or expose them in the Super-Admin browser bundle.

Required runtime settings:
- DECENTRO_BASE_URL=https://in.staging.decentro.tech
- DECENTRO_CLIENT_ID — supplied through the private runtime environment
- DECENTRO_CLIENT_SECRET — supplied through the private runtime environment
- APP_VERIFICATION_CALLBACK_URL — HTTPS URL ending in /api/v1/eligibility/decentro/callback
- SAKHI_DECENTRO_POLICY_APPROVED=true only after verification consent, privacy, data-handling, retention, and provider flow have been approved

DECENTRO_KYC_MODULE_SECRET is optional for the documented standard endpoint headers; if the Decentro account specifically requires it, set it in the private runtime environment. DECENTRO_WEBHOOK_SECRET is only for a separately confirmed HMAC adapter, not a claim that the standard redirect uses HMAC.

## Flow and trust boundary

1. The authenticated mobile client explicitly consents and calls POST /api/v1/eligibility/decentro/initiate.
2. The backend starts a session with POST /v2/kyc/digilocker/initiate_session, saves the random Sakhi reference and provider transaction ID as minimal audit metadata, and returns the HTTPS provider authorization URL.
3. The provider redirects to the configured callback URL with the Sakhi reference. The callback ignores demographic query parameters.
4. The backend uses the recorded initial transaction ID to call POST /v2/kyc/digilocker/eaadhaar. It requires a successful provider response and the expected e-Aadhaar response key before using provider-returned gender and date of birth for the eligibility decision.
5. The raw provider response is only read in memory. The application must not retain or return Aadhaar UID, full DOB, name, address, XML, PDF, image, or raw identity documents. Audit records retain the decision outcome and minimal transaction/reference metadata.

Provider reference pages:
- https://docs.decentro.tech/reference/kyc_api-digilocker-initiate-session
- https://docs.decentro.tech/reference/kyc_api-digilocker-get-e-aadhaar

## Local simulator

SAKHI_ENABLE_LOCAL_ELIGIBILITY_SIMULATOR=true is honored only when NODE_ENV=development, SAKHI_ENV=dev, and HOST=127.0.0.1. It returns a simulation result without persisting an account status or marking the member verified. Keep it disabled for staging and production.

## Staging demo session (synthetic only)

SAKHI_ENABLE_STAGING_ELIGIBILITY_DEMO=true is a separate synthetic test path for the dedicated Sakhi staging API. It is accepted only when NODE_ENV=production, SAKHI_ENV=staging, and APP_VERIFICATION_CALLBACK_URL exactly matches the HTTPS Sakhi staging callback. This demo flag does not require or imply SAKHI_DECENTRO_POLICY_APPROVED=true; keep the real identity-provider policy gate false until its separate policy review is approved.

1. The authenticated staging app calls POST /api/v1/eligibility/decentro/staging-demo/start to obtain a synthetic session reference.
2. After the session starts, the app can call POST /api/v1/eligibility/decentro/staging-demo/result with that reference and synthetic gender/date-of-birth values to exercise the pass/fail UI.
3. Results are marked SIMULATION_ONLY with isDemo=true, persisted=false, identityVerified=false, and verificationStatusChanged=false. These endpoints do not call Decentro or write account, eligibility-submission, or audit records.
4. Keep SAKHI_ENABLE_LOCAL_ELIGIBILITY_SIMULATOR=false in staging; it remains loopback-only. The staging demo flag must never be copied to production.

## Validation boundary

Automated validation includes backend typecheck and focused API/unit tests, Flutter analysis/full tests, live staging health/configuration checks, and a staging APK build. The synthetic staging demo does not prove that Decentro credentials work or that a real provider transaction can complete. Verify those separately after the API reports providerConfigured=true. Database migrations, seeds, and permissions remain unchanged.