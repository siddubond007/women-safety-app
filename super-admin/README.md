# Sakhi Super Admin

Standalone React + TypeScript + Vite administration UI for the Sakhi mobile platform. This application lives in its own directory and does not replace or embed the Flutter app.

## Stage 1 scope

- Responsive admin shell and grouped navigation.
- Browser-tab-only **demo session** entry screen.
- Overview dashboard powered by fictional sample data isolated in \`src/services/mock/dashboard.ts\`.
- Planned-module page states to avoid dead navigation links.
- Central theme styles, reusable status pills and metric cards.
- Type checking, ESLint and Vite production-build scripts.

## Important status

**This is a frontend-only prototype.** The backend is not implemented or connected. Dashboard values and queue entries are fictional, every integration is marked not connected, and the demo entry screen is not production authentication or authorization. Actions shown in this stage do not change production records.

Do not enter real member data, credentials, complaint evidence, identity documents, health data or live locations. Do not deploy this demo sign-in as an access-control mechanism.

## Requirements

Use a supported Node.js release for the installed Vite version and npm.

## Run locally

From the repository root, run:

\`\`\`powershell
cd super-admin
npm install
npm run dev
\`\`\`

Open the loopback URL printed by Vite (normally http://127.0.0.1:5173). Choose **Enter demo environment** on the sign-in screen. No real credential is required or collected.

## Checks

\`\`\`powershell
npm run typecheck
npm run lint
npm run build
\`\`\`

## Architecture notes

- Replace the mock repository behind a stable typed data-access interface when backend API contracts are approved.
- No backend API routes are assumed to exist.
- Values from frontend environment variables are public browser configuration, not secret storage.
- Production authentication, backend-enforced role/record authorization, server audit logs, security review and privacy workflows remain future work.
- Keep the Stage 1 scope isolated to this directory. The root README, \`app/\` and \`backend/\` are not required to change for this UI foundation.
