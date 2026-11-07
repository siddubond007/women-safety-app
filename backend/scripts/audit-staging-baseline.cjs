const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const migrationRoot = path.join(root, 'prisma', 'migrations');
const baseline = fs.readFileSync(path.join(root, 'prisma', 'staging', 'baseline.sql'), 'utf8');
const files = fs.readdirSync(migrationRoot, { withFileTypes: true })
  .filter((item) => item.isDirectory())
  .map((item) => path.join(migrationRoot, item.name, 'migration.sql'))
  .filter((file) => fs.existsSync(file));
const missing = [];
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
  process.stdout.write('Baseline audit passed: tables, SQL-managed types, added columns, indexes, and constraints from existing migrations are represented.\n');
}
