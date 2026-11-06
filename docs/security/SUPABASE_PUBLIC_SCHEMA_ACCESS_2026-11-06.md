# Supabase public-schema API access hardening — 2026-11-06

## Scope

Project: `sakhi-friend-testing`  
Project ref: `wmlpokholjfadyohdlgo`  
Database: PostgreSQL 17, database `postgres`

This is an operational security record. It contains no passwords, connection strings, API keys, or member data.

## Verified connection roles

The project contains the PostgreSQL roles `sakhi_staging_app` and `sakhi_staging_migrator`. Both can connect to the database and use the `public` schema. The app role has table-level access needed by the API; the migrator role has schema CREATE and migration privileges. Neither role has `BYPASSRLS`.

The pooler connection username includes the project reference suffix (for example, `sakhi_staging_app.<project-ref>`); the database catalog stores the underlying role name without that suffix.

## Live controls applied

The following changes were executed directly against the staging database and verified with privilege queries:

- Revoked `anon` and `authenticated` table privileges on the three menstrual-tracker tables.
- Revoked `anon` and `authenticated` privileges on public sequences and function execution.
- Revoked `USAGE` on schema `public` from `PUBLIC`. This removes inherited schema access from `anon` and `authenticated` while preserving explicit access for the Sakhi app and migrator roles.
- Revoked default table, sequence, and function privileges for `anon` and `authenticated` from objects created by the current `postgres` role in `public`.

Post-change verification returned:
- `anon`: no `USAGE` on `public`, no SELECT privilege on public tables, no EXECUTE privilege on public functions.
- `authenticated`: no `USAGE` on `public`, no SELECT privilege on public tables, no EXECUTE privilege on public functions.
- `sakhi_staging_app`: retains `USAGE` on `public`.
- `sakhi_staging_migrator`: retains `USAGE` and `CREATE` on `public`.

## Remaining review items

- Supabase's security advisor continues to report tables with RLS disabled. Those tables are currently reachable through the Sakhi server-side database role, not through `anon` or `authenticated` Data API roles. RLS must not be enabled indiscriminately: the app role does not bypass RLS, and enabling RLS without correct per-table policies would break legitimate server queries.
- Default ACL entries owned by `supabase_admin` were not changed because the connected database role does not have permission to alter that role's defaults. Public-schema `USAGE` is revoked from `PUBLIC`, which blocks the Data API roles from resolving those objects. Review this again if future infrastructure work grants schema usage to client roles.
- Perform a table-by-table ownership and row-authorization design before production use, especially for profiles, sessions, SOS data, complaints, menstrual records, messages, audit events, and media metadata.
- This staging-hardening work does not certify the Render service deployment or production launch readiness.

## SQL operations applied

```sql
REVOKE ALL PRIVILEGES ON TABLE
  public.menstrual_cycle_logs,
  public.menstrual_daily_logs,
  public.menstrual_tracker_preferences
FROM anon, authenticated;

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE ALL ON SEQUENCES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated;
```

The default-privilege statements apply to the executing role (`postgres` in this operation); they are not a blanket change to objects created by `supabase_admin`.
