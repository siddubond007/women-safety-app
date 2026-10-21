# Sakhi Super Admin

Standalone React + TypeScript + Vite administration frontend. This UI is intended for authorized local or staging-test operators and is not production identity/access management.

## Current behavior

- The overview dashboard fetches member and eligibility counts, audit events, report records, community counts, and media audit entries from the configured backend API. Empty or failed responses are shown as empty/error states; the frontend does not substitute mock dashboard figures.
- Members & accounts uses the backend member directory, search, filters, pagination, masked phone numbers, and a member-detail drawer.
- Local development mode retains the development-only account-state troubleshooting actions.
- Staging-test mode makes the member directory read-only and directs account eligibility outcomes through the explicit Eligibility & verification review workflow. It does not expose general account-state overrides or member-creation controls.
- Eligibility review uses explicit persisted manual-review submissions and requires the separately approved procedure to be attested before a decision can be recorded. This page does not collect or display identity documents.
- The existing review and operations endpoints supply dashboard/report data and moderation actions where implemented. Other menu entries that do not yet have complete end-to-end screens remain explicitly marked as planned instead of displaying invented operational data.
- The previous fuller dashboard structure and visual system (metric cards, activity panel, priority queue, indicator grid, operations table and integration panel) is retained, now populated by backend responses where implemented.

## Security and data handling

The reviewer token is a shared operator token, not an individual administrator identity and not a production authentication system. Configure a unique random \`SAKHI_ADMIN_REVIEW_TOKEN\` of at least 32 characters only in the backend host's protected environment. Never place it in source control, a \`VITE_*\` variable, the Flutter app, APKs or a message to friend testers.

The staging reviewer mode requires all server-side staging test gates, including \`SAKHI_ENV=staging\`, \`NODE_ENV=production\`, \`SAKHI_OTP_MODE=staging_test\`, \`SAKHI_STAGING_ADMIN_REVIEW_ENABLED=true\`, and the long random token. The staging frontend can read persisted member rows and eligibility submissions; general account-state overrides, member creation and demo-data seeding are blocked in staging. Final eligibility decisions must use the dedicated review endpoint, not a shortcut from the member directory.

Never use this shared-token workflow as production authentication. Individual admin accounts, RBAC/MFA, evidence handling, approval and retention policies, privacy/security review and real provider integrations require separate implementation and approval.

## Configure the API URL

The frontend reads \`VITE_API_BASE_URL\` at build time.

For local development, the default is:

\`\`\`text
http://127.0.0.1:3001/api/v1
\`\`\`

For hosted staging, set it to the deployed Render API URL ending in \`/api/v1\`, for example:

\`\`\`text
https://sakhi-staging-api.onrender.com/api/v1
\`\`\`

Vite embeds this value in the compiled JavaScript. Changing an environment variable after a static-site build is not enough; rebuild/redeploy the static site. This variable is public URL configuration, not a secret.

## Run locally

From the repository root:

\`\`\`powershell
cd super-admin
npm ci
npm run dev
\`\`\`

Open the loopback URL printed by Vite (normally \`http://127.0.0.1:5173\`). The backend must be running and \`SAKHI_ADMIN_CORS_ORIGIN\` must include the exact local origin.

## Checks

\`\`\`powershell
npm run typecheck
npm run lint
npm run build
\`\`\`

## Render staging deployment

The root \`render.yaml\` declares both:
- \`sakhi-staging-api\`: NestJS backend connected to the existing dedicated Supabase staging project.
- \`sakhi-super-admin\`: static Vite frontend with SPA route rewrite and a build-time API base URL.

Before syncing the Blueprint, supply the required protected database URL, invited-tester phone allowlist and six-digit shared OTP code. For the admin service, also configure a separate random \`SAKHI_ADMIN_REVIEW_TOKEN\` in the backend environment. Never reuse the OTP code as the admin token.

After Render assigns both service URLs, verify that:
- \`SAKHI_ADMIN_CORS_ORIGIN\` on the API is the exact HTTPS origin of the static admin site.
- \`VITE_API_BASE_URL\` on the static site is the exact HTTPS API URL ending in \`/api/v1\`.
- the backend health endpoint responds successfully and the portal can validate the reviewer token.

If Render gives either service a different hostname, update the exact values above in its environment and redeploy. No database migrations or seed operations are required for a UI update. The admin demo seed endpoint is intentionally blocked against the shared staging database.

## Explicit limitations

Staging test OTPs do not send SMS or verify ownership of a phone number. The default staging age is a temporary 18+ test restriction, not an approved product/legal policy. Eligibility remains a manual test workflow; this frontend does not collect identity evidence or constitute a production eligibility system.
