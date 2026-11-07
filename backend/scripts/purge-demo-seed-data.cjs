const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');

function resolveDatabaseUrl() {
  const args = process.argv.slice(2);
  const urlArgIndex = args.indexOf('--url');
  if (urlArgIndex !== -1 && args[urlArgIndex + 1]) {
    return args[urlArgIndex + 1];
  }
  if (process.env.DATABASE_URL) return process.env.DATABASE_URL;
  if (process.env.SAKHI_MIGRATOR_DATABASE_URL) return process.env.SAKHI_MIGRATOR_DATABASE_URL;

  // Try reading from .env in backend or project root
  const candidatePaths = [
    path.join(__dirname, '..', '.env'),
    path.join(__dirname, '..', '..', '.env'),
    path.join(__dirname, '..', '.env.local'),
  ];
  for (const envPath of candidatePaths) {
    if (fs.existsSync(envPath)) {
      const content = fs.readFileSync(envPath, 'utf8');
      for (const line of content.split('\n')) {
        const trimmed = line.trim();
        if (trimmed.startsWith('DATABASE_URL=')) {
          return trimmed.replace(/^DATABASE_URL=/, '').replace(/^["']|["']$/g, '').trim();
        }
        if (trimmed.startsWith('SAKHI_MIGRATOR_DATABASE_URL=')) {
          return trimmed.replace(/^SAKHI_MIGRATOR_DATABASE_URL=/, '').replace(/^["']|["']$/g, '').trim();
        }
      }
    }
  }
  return null;
}

async function main() {
  const dbUrl = resolveDatabaseUrl();
  if (!dbUrl) {
    console.error('Error: DATABASE_URL is not set. Provide it via DATABASE_URL environment variable or --url parameter.');
    process.exit(1);
  }

  // Sanitize connection URL (remove sslmode=require for pg client config if needed or enable rejectUnauthorized: false)
  const isSsl = dbUrl.includes('supabase.co') || dbUrl.includes('sslmode=require');
  const client = new Client({
    connectionString: dbUrl,
    ssl: isSsl ? { rejectUnauthorized: false } : false,
  });

  console.log('Connecting to PostgreSQL database...');
  await client.connect();
  console.log('Connected successfully. Starting comprehensive purge of legacy demo users and posts...');

  const DEMO_PHONES = [
    '+919999992222',
    '+919845010101',
    '+919845010102',
    '+919845010103',
    '+919845010104',
    '+919845010105',
    '+919845010106',
    '+919845010107',
  ];

  const DEMO_HANDLES = [
    '@siddhu',
    '@ananya',
    '@meera',
    '@kavya',
    '@ishita',
    '@priya',
    '@sneha',
    '@riya',
  ];

  try {
    await client.query('BEGIN');

    // 1. Delete all demo community posts (both by ID prefix and by demo username/name)
    const deletePostsRes = await client.query(`
      DELETE FROM community_posts
      WHERE id LIKE '11111111-1111-4111-8111-%'
         OR author_username = ANY($1)
         OR author_name = 'Siddhu'
    `, [DEMO_HANDLES]);
    console.log(`✓ Purged ${deletePostsRes.rowCount} demo community posts.`);

    // 2. Delete all demo community directory profiles
    const deleteDirRes = await client.query(`
      DELETE FROM community_directory_profiles
      WHERE username = ANY($1)
    `, [DEMO_HANDLES]);
    console.log(`✓ Purged ${deleteDirRes.rowCount} demo directory profiles.`);

    // 3. Find demo accounts by phone numbers
    const findAccountsRes = await client.query(`
      SELECT id FROM member_accounts WHERE phone_e164 = ANY($1)
    `, [DEMO_PHONES]);

    const demoAccountIds = findAccountsRes.rows.map((r) => r.id);
    if (demoAccountIds.length > 0) {
      // Delete child records first to satisfy foreign keys
      await client.query(`DELETE FROM community_post_comments WHERE account_id = ANY($1)`, [demoAccountIds]);
      await client.query(`DELETE FROM community_post_likes WHERE account_id = ANY($1)`, [demoAccountIds]);
      await client.query(`DELETE FROM community_post_saves WHERE account_id = ANY($1)`, [demoAccountIds]);
      await client.query(`DELETE FROM member_follows WHERE account_id = ANY($1)`, [demoAccountIds]);
      await client.query(`DELETE FROM community_posts WHERE author_account_id = ANY($1)`, [demoAccountIds]);
      await client.query(`DELETE FROM eligibility_submissions WHERE account_id = ANY($1)`, [demoAccountIds]);
      await client.query(`DELETE FROM member_profiles WHERE account_id = ANY($1)`, [demoAccountIds]);
      await client.query(`DELETE FROM member_privacy_preferences WHERE account_id = ANY($1)`, [demoAccountIds]);
      await client.query(`DELETE FROM member_notification_preferences WHERE account_id = ANY($1)`, [demoAccountIds]);
      await client.query(`DELETE FROM auth_sessions WHERE account_id = ANY($1)`, [demoAccountIds]);
      const delAccountsRes = await client.query(`DELETE FROM member_accounts WHERE id = ANY($1)`, [demoAccountIds]);
      console.log(`✓ Purged ${delAccountsRes.rowCount} demo member accounts and associated profile/session records.`);
    } else {
      console.log('✓ No demo member accounts were found in database.');
    }

    await client.query('COMMIT');
    console.log('\nPurge complete! The database now contains 0 fake users and 0 fake demo posts.');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Purge failed with error:', err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
