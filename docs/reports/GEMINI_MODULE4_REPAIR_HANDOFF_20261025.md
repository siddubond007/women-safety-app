# Sakhi Module 4 Repair Handoff — 2026-10-25

## Checkpoint baseline
- Repository: D:\Development\Projects\women_safety_app
- Base commit: 830ac3f45ef30307222872befd33e7d5a97ec0c4
- Checkpoint branch: checkpoint/gemini-module4-repair-handoff-20261025
- The starting tracked worktree had no modifications. .sakhi_module3_agent_state.txt was untracked and intentionally preserved; it must not be deleted or included in a third-party handoff archive.
- This checkpoint captures the handoff instructions and issue inventory, not completed fixes for the user's newly reported bugs.

## Reported problem groups
1. Safety page actions incorrectly navigate to the same helplines/tips destination.
2. Individual safety tip cards do nothing.
3. SOS activation history, safety checklist/discreet trigger, and settings shortcut navigate to the same generic screen.
4. Emergency contacts entered by a user disappear on restart while three hardcoded contacts reappear; phone numbers should have a show/hide control.
5. Nearby police stations and map views appear fake/static; must use a configured, real source and truthful unavailable states.
6. SOS home map does not show a real location/map even when GPS is enabled.
7. SOS red button/halo/shadow has visual defects.
8. Power-button and shake shortcuts do not work reliably; must implement only platform-supported behavior and clearly disclose restrictions.
9. Live location sharing cannot be confirmed by the server.
10. “Call now” copies the number rather than opening the native dialer.
11. Admin UI appears broken and backend data/control integration is uncertain; verify every screen and all actions against real API data with role-based authorization and audit logs.

## Scope
The Gemini prompt in GEMINI_MODULE4_REPAIR_PROMPT_20261025.txt requires a full source audit, reproduction and root-cause analysis, regression tests, repair of the listed issues, review of the entire requirements document (especially Modules 11/12 and sections 15–20), and explicit reporting of external-provider setup and remaining launch blockers.

## Safety constraints
- Do not expose/commit secrets or personal data.
- Preserve untracked user work.
- Do not run database migrations, change database permissions, touch the marketplace database, merge to main, or deploy to production.
- Do not hardcode credentials, create bypasses, or misrepresent mock data as live.
- Any unsupported emergency shortcut must be labeled honestly with a supported alternative.
- Never place a real emergency call as part of testing.
- Real-device, map provider, staging API, and admin integration checks must be evidenced rather than assumed.
