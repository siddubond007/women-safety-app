const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const migrationRoot = path.join(root, 'prisma', 'migrations');
const baseline = fs.readFileSync(path.join(root, 'prisma', 'staging', 'baseline.sql'), 'utf8');
const BASELINE_MIGRATIONS = [
  '20261015163000_stage1_foundation',
  '20261015170000_dev_auth_sessions',
  '20261016090000_audit_event_id_returning_privilege',
  '20261016120000_eligibility_status_domain',
  '20261016140000_eligibility_consent_sessions_support',
  '20261016150000_eligibility_provider_callback_events',
  '20261017121500_admin_manual_review_decisions',
  '20261017123000_eligibility_submissions',
  '20261018090000_module2_core_domain',
  '20261018090000_module2_profile_social_settings',
  '20261019120000_module3_social_wall_and_drive_media',
  '20261022103000_platform_registration_policy_settings',
  '20261023110000_module4_emergency_sos_and_safety',
  '20261026183000_module5_discreet_complaint_system',
  '20261027170000_module10_rbac_admin_roles_and_module5_fixes',
  '20261029190000_module6_business_pages',
  '20261101120000_direct_message_dedicated_storage',
  '20261101130000_direct_message_runtime_grants',
  '20261101140000_auth_session_device_metadata',
  '20261102140000_purge_seeded_demo_data',
  '20261103090000_module7_menstrual_cycle_tracker',
];
const files = fs.readdirSync(migrationRoot, { withFileTypes: true })
  .filter((item) => item.isDirectory())
  .filter((item) => BASELINE_MIGRATIONS.includes(item.name))
  .map((item) => path.join(migrationRoot, item.name, 'migration.sql'))
  .filter((file) => fs.existsSync(file));
const missingMigrationFiles = BASELINE_MIGRATIONS.filter((name) =>
  !fs.existsSync(path.join(migrationRoot, name, 'migration.sql')),
);
const missing = missingMigrationFiles.map((name) => `baseline migration file missing: ${name}`);
const quoted = (name) => name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const normalizeTable = (name) => {
  const match = baseline.match(new RegExp('CREATE TABLE "' + quoted(name) + '"\\s*\\(([\\s\\S]*?)\\n\\);', 'i'));
  return match?.[1] ?? '';
};

for (const file of files) {
  const sql = fs.readFileSync(file, 'utf8');
  const migration = path.basename(path.dirname(file));
  for (const match of sql.matchAll(/^CREATE TABLE\s+(?:IF NOT EXISTS\s+)?["']?([a-zA-Z_][\w]*)/gim)) {
    if (!normalizeTable(match[1])) missing.push(`${migration}: missing table ${match[1]}`);
  }
  for (const match of sql.matchAll(/^CREATE TYPE\s+["']?([a-zA-Z_][\w]*)/gim)) {
    if (!new RegExp('CREATE TYPE "' + quoted(match[1]) + '"', 'i').test(baseline)) missing.push(`${migration}: missing enum/type ${match[1]}`);
  }
  for (const match of sql.matchAll(/ALTER TABLE\s+["']?([a-zA-Z_][\w]*)["']?\s+ADD COLUMN(?: IF NOT EXISTS)?\s+["']?([a-zA-Z_][\w]*)/gim)) {
    const [, table, column] = match;
    const tableSql = normalizeTable(table);
    const inCreateTable = tableSql && new RegExp('(?:^|\\n)\\s*"' + quoted(column) + '"\\s', 'i').test(tableSql);
    const inAlterTable = new RegExp('ALTER TABLE "' + quoted(table) + '"[\\s\\S]*?ADD COLUMN(?: IF NOT EXISTS)? "' + quoted(column) + '"', 'i').test(baseline);
    if (!inCreateTable && !inAlterTable) {
      missing.push(`${migration}: missing column ${table}.${column}`);
    }
  }
  for (const match of sql.matchAll(/CREATE (?:UNIQUE )?INDEX(?: IF NOT EXISTS)?\s+["']?([a-zA-Z_][\w]*)/gim)) {
    if (!new RegExp('CREATE (?:UNIQUE )?INDEX "' + quoted(match[1]) + '"', 'i').test(baseline)) missing.push(`${migration}: missing index ${match[1]}`);
  }
  for (const match of sql.matchAll(/ADD CONSTRAINT\s+["']?([a-zA-Z_][\w]*)/gim)) {
    if (!new RegExp('CONSTRAINT "' + quoted(match[1]) + '"', 'i').test(baseline)) missing.push(`${migration}: missing constraint ${match[1]}`);
  }
}

if (missing.length) {
  [...new Set(missing)].forEach((item) => process.stdout.write(item + '\n'));
  process.exitCode = 1;
} else {
  process.stdout.write('Baseline audit passed: all Module 1–7 predecessor migration files and their tables, SQL-managed types, added columns, indexes, and constraints are represented. The separate Modules 8–12 migration is intentionally excluded from the fresh-schema baseline.\n');
}
