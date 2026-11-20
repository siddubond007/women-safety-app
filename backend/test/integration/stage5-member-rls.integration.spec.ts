import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { Client } from "pg";
import { randomUUID } from "node:crypto";
import { ConfigService } from "@nestjs/config";
import { createAuthenticatedMemberIdentity } from "../../src/auth/member-identity.js";
import { PrismaService } from "../../src/database/prisma.service.js";

const adminUrl = process.env.SAKHI_STAGE5_RLS_ADMIN_TEST_URL;
const appUrl = process.env.SAKHI_STAGE5_RLS_APP_TEST_URL;
const enabled = Boolean(adminUrl && appUrl);
const accountA = "11111111-1111-4111-8111-111111111111";
const accountB = "22222222-2222-4222-8222-222222222222";
const consentA = "33333333-3333-4333-8333-333333333331";
const consentB = "33333333-3333-4333-8333-333333333332";
const sessionA = "44444444-4444-4444-8444-444444444441";
const sessionB = "44444444-4444-4444-8444-444444444442";
const directoryA = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const directoryB = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const communityPostId = "55555555-5555-4555-8555-555555555551";
const communityMediaId = "66666666-6666-4666-8666-666666666661";
const draftMediaId = "77777777-7777-4777-8777-777777777771";

const cleanup = async (client: Client) => {
  await client.query("delete from public.media_assets where id = any($1::uuid[])", [[communityMediaId, draftMediaId]]);
  await client.query("delete from public.community_posts where id = $1", [communityPostId]);
  await client.query("delete from public.member_moderation_blocks where account_id = any($1::uuid[])", [[accountA, accountB]]);
  await client.query("delete from public.member_follows where account_id = any($1::uuid[])", [[accountA, accountB]]);
  await client.query("delete from public.eligibility_verification_sessions where id = any($1::uuid[])", [[sessionA, sessionB]]);
  await client.query("delete from public.eligibility_support_requests where account_id = any($1::uuid[])", [[accountA, accountB]]);
  await client.query("delete from public.eligibility_consents where id = any($1::uuid[])", [[consentA, consentB]]);
  await client.query("delete from public.community_directory_profiles where id = any($1::uuid[])", [[directoryA, directoryB]]);
  await client.query("delete from public.member_privacy_preferences where account_id = any($1::uuid[])", [[accountA, accountB]]);
  await client.query("delete from public.member_profiles where account_id = any($1::uuid[])", [[accountA, accountB]]);
  await client.query("delete from public.member_accounts where id = any($1::uuid[])", [[accountA, accountB]]);
};

describe.skipIf(!enabled)("Stage 5 PostgreSQL member-data RLS contract", () => {
  let admin: Client;
  let app: Client;

  beforeAll(async () => {
    admin = new Client({ connectionString: adminUrl });
    app = new Client({ connectionString: appUrl });
    await admin.connect();
    await app.connect();
    const role = await app.query<{ current_user: string }>("select current_user");
    expect(role.rows[0]?.current_user).toBe("sakhi_test_app");
    await cleanup(admin);
    await admin.query(
      `insert into public.member_accounts(id,phone_e164,status,verification_status,eligibility_status,updated_at)
       values ($1,'+919000000001','ACTIVE','VERIFIED','VERIFIED',now()),
              ($2,'+919000000002','ACTIVE','VERIFIED','VERIFIED',now())`,
      [accountA, accountB],
    );
    await admin.query(
      `insert into public.member_profiles(account_id,display_name,date_of_birth,email,username,bio,location,location_city,updated_at)
       values ($1,'Synthetic Member A','2000-01-01','a.synthetic@example.invalid','@synthetica','Public test profile A','Test City','Test City',now()),
              ($2,'Synthetic Member B','2000-02-02','b.synthetic@example.invalid','@syntheticb','Public test profile B','Test City','Test City',now())`,
      [accountA, accountB],
    );
    await admin.query(
      `insert into public.member_privacy_preferences(account_id,search_results,view_profile)
       values ($1,'Yes','Verified members only'),($2,'Yes','Followers only')`,
      [accountA, accountB],
    );
    await admin.query(
      `insert into public.community_directory_profiles(id,account_id,name,username,avatar_asset,bio,searchable,profile_visibility)
       values ($1,$3,'Synthetic Directory A','@synthetica','avatar-a.webp','Safe projection A',true,'VERIFIED_MEMBERS'),
              ($2,$4,'Synthetic Directory B','@syntheticb','avatar-b.webp','Safe projection B',true,'FOLLOWERS_ONLY')`,
      [directoryA, directoryB, accountA, accountB],
    );
    await admin.query(
      `insert into public.community_posts(
         id,author_account_id,author_name,author_username,author_avatar,author_verified,
         content,image_asset,category_slug,visibility,status
       ) values (
         $1,$2,'Synthetic Member B','@syntheticb','avatar-b.webp',true,
         'Synthetic followers-only media fixture',$3,'community','FOLLOWERS_ONLY','PUBLISHED'
       )`,
      [communityPostId, accountB, `/api/v1/module2/media/object/${communityMediaId}`],
    );
    await admin.query(
      `insert into public.media_assets(
         id,owner_account_id,post_id,purpose,storage_provider,status,drive_folder_path,
         original_file_name,content_type,byte_size,sha256_checksum,visibility,drive_file_id
       ) values (
         $1,$2,$3,'COMMUNITY_POST_IMAGE','GOOGLE_DRIVE','ATTACHED',
         'Sakhi Staging Media/feeds/community/synthetic','synthetic.jpg','image/jpeg',
         4,repeat('a',64),'FOLLOWERS_ONLY','synthetic-drive-object'
       ),
       (
         $4,$2,null,'COMMUNITY_POST_IMAGE','GOOGLE_DRIVE','UPLOADED',
         'Sakhi Staging Media/feeds/community/synthetic','synthetic-draft.jpg','image/jpeg',
         4,repeat('b',64),'FOLLOWERS_ONLY','synthetic-draft-drive-object'
       )`,
      [communityMediaId, accountB, communityPostId, draftMediaId],
    );
    await admin.query(
      `insert into public.eligibility_consents(id,account_id,notice_version,accepted_at,biometric_processing_consented,source)
       values ($1,$3,'test-v1',now(),false,'SYNTHETIC_TEST'),($2,$4,'test-v1',now(),false,'SYNTHETIC_TEST')`,
      [consentA, consentB, accountA, accountB],
    );
    await admin.query(
      `insert into public.eligibility_support_requests(id,account_id,category,status,created_at,updated_at)
       values (gen_random_uuid(),$1,'VERIFICATION_HELP','OPEN',now(),now()),
              (gen_random_uuid(),$2,'VERIFICATION_HELP','OPEN',now(),now())`,
      [accountA, accountB],
    );
    await admin.query(
      `insert into public.eligibility_verification_sessions(id,account_id,consent_id,provider_key,status,created_at,updated_at)
       values ($1,$3,$5,'SYNTHETIC','CREATED',now(),now()),
              ($2,$4,$6,'SYNTHETIC','CREATED',now(),now())`,
      [sessionA, sessionB, accountA, accountB, consentA, consentB],
    );
  });

  afterAll(async () => {
    if (admin) {
      await cleanup(admin).catch(() => undefined);
      await admin.end();
    }
    if (app) await app.end();
  });

  it("isolates member roots and auxiliary eligibility records by transaction identity", async () => {
    await app.query("begin");
    await app.query("select set_config('app.account_id',$1,true)", [accountA]);
    for (const table of ["member_accounts", "member_profiles", "member_privacy_preferences", "eligibility_consents", "eligibility_support_requests", "eligibility_verification_sessions"]) {
      const column = table === "member_accounts" ? "id" : "account_id";
      const rows = await app.query(`select ${column} from public.${table}`);
      expect(rows.rows.map((row) => row[column])).toEqual([accountA]);
    }
    await app.query("rollback");

    const noIdentity = await app.query("select id from public.member_accounts");
    expect(noIdentity.rowCount).toBe(0);
  });

  it("enforces public, follower-only, hidden, and incoming-block directory visibility", async () => {
    await app.query("begin");
    await app.query("select set_config('app.account_id',$1,true)", [accountA]);
    const hiddenFollowerOnly = await app.query(
      "select account_id from public.community_directory_profiles where account_id=$1",
      [accountB],
    );
    expect(hiddenFollowerOnly.rowCount).toBe(0);
    expect((await app.query("select id from public.community_posts where id=$1", [communityPostId])).rowCount).toBe(0);
    expect((await app.query("select id from public.media_assets where id=$1", [communityMediaId])).rowCount).toBe(0);
    expect((await app.query("select id from public.media_assets where id=$1", [draftMediaId])).rowCount).toBe(0);
    await app.query("rollback");

    await admin.query(
      `insert into public.member_follows(id,account_id,directory_profile_id,is_following,updated_at)
       values ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',$1,$2,true,now())`,
      [accountA, directoryB],
    );
    await app.query("begin");
    await app.query("select set_config('app.account_id',$1,true)", [accountA]);
    const followed = await app.query(
      "select account_id from public.community_directory_profiles where account_id=$1",
      [accountB],
    );
    expect(followed.rows.map((row) => row.account_id)).toEqual([accountB]);
    expect((await app.query("select id from public.community_posts where id=$1", [communityPostId])).rowCount).toBe(1);
    expect((await app.query("select id from public.media_assets where id=$1", [communityMediaId])).rowCount).toBe(1);
    expect((await app.query("select id from public.media_assets where id=$1", [draftMediaId])).rowCount).toBe(0);
    await app.query("rollback");

    await admin.query(
      "update public.community_directory_profiles set searchable=false,profile_visibility='HIDDEN' where account_id=$1",
      [accountB],
    );
    await app.query("begin");
    await app.query("select set_config('app.account_id',$1,true)", [accountA]);
    const hidden = await app.query(
      "select account_id from public.community_directory_profiles where account_id=$1",
      [accountB],
    );
    expect(hidden.rowCount).toBe(0);
    expect((await app.query("select id from public.community_posts where id=$1", [communityPostId])).rowCount).toBe(0);
    expect((await app.query("select id from public.media_assets where id=$1", [communityMediaId])).rowCount).toBe(0);
    await app.query("rollback");

    await admin.query(
      "update public.community_directory_profiles set searchable=true,profile_visibility='VERIFIED_MEMBERS' where account_id=$1",
      [accountB],
    );
    await admin.query(
      `insert into public.member_moderation_blocks(id,account_id,blocked_username,blocked_account_id,blocked_display_name)
       values (gen_random_uuid(),$1,'@synthetica',$2,'Synthetic Member A')`,
      [accountB, accountA],
    );
    await app.query("begin");
    await app.query("select set_config('app.account_id',$1,true)", [accountA]);
    const blocked = await app.query(
      "select account_id from public.community_directory_profiles where account_id=$1",
      [accountB],
    );
    expect(blocked.rowCount).toBe(0);
    const incomingBlock = await app.query(
      "select account_id from public.member_moderation_blocks where blocked_account_id=$1",
      [accountA],
    );
    expect(incomingBlock.rows.map((row) => row.account_id)).toEqual([accountB]);
    expect((await app.query("select id from public.community_posts where id=$1", [communityPostId])).rowCount).toBe(0);
    expect((await app.query("select id from public.media_assets where id=$1", [communityMediaId])).rowCount).toBe(0);
    await app.query("rollback");

    await admin.query(
      "delete from public.member_moderation_blocks where account_id=$1 and blocked_account_id=$2",
      [accountB, accountA],
    );
    await admin.query(
      `insert into public.member_moderation_blocks(id,account_id,blocked_username,blocked_account_id,blocked_display_name)
       values (gen_random_uuid(),$1,'@syntheticb',$2,'Synthetic Member B')`,
      [accountA, accountB],
    );
    await app.query("begin");
    await app.query("select set_config('app.account_id',$1,true)", [accountA]);
    expect((await app.query("select id from public.community_posts where id=$1", [communityPostId])).rowCount).toBe(0);
    expect((await app.query("select id from public.media_assets where id=$1", [communityMediaId])).rowCount).toBe(0);
    await app.query("rollback");

    await admin.query(
      "delete from public.member_moderation_blocks where account_id=$1 and blocked_account_id=$2",
      [accountA, accountB],
    );
    await admin.query("update public.community_posts set status='MODERATED' where id=$1", [communityPostId]);
    await app.query("begin");
    await app.query("select set_config('app.account_id',$1,true)", [accountA]);
    expect((await app.query("select id from public.community_posts where id=$1", [communityPostId])).rowCount).toBe(0);
    expect((await app.query("select id from public.media_assets where id=$1", [communityMediaId])).rowCount).toBe(0);
    await app.query("rollback");
  });

  it("requires forced RLS on all Stage 3D/Stage 5 member and confidential tables", async () => {
    const expected = [
      "member_accounts", "auth_sessions", "otp_challenges", "account_deletion_requests",
      "member_profiles", "member_consents", "member_communication_preferences",
      "eligibility_submissions", "community_posts", "community_post_likes",
      "community_post_saves", "community_post_comments", "community_groups",
      "community_circle_memberships", "community_circle_posts", "member_follows",
      "member_privacy_preferences", "member_notification_preferences", "member_push_tokens",
      "member_wellness_preferences", "member_notifications", "safety_emergency_contacts",
      "safety_sos_events", "safety_location_shares", "member_moderation_blocks",
      "member_user_reports", "direct_messages", "media_assets", "community_post_reactions",
      "business_directory_listings", "business_enquiries", "business_reports",
      "menstrual_cycle_logs", "menstrual_daily_logs", "menstrual_tracker_preferences",
      "community_directory_profiles", "eligibility_consents", "eligibility_support_requests",
      "eligibility_verification_sessions", "audit_events", "moderation_decisions",
      "admin_staff_accounts", "admin_staff_sessions", "admin_staff_mfa",
      "admin_staff_backup_codes", "admin_staff_recovery_requests", "admin_auth_sessions",
      "discreet_complaints", "eligibility_provider_callback_events",
    ];
    const result = await admin.query<{ relname: string; relrowsecurity: boolean; relforcerowsecurity: boolean }>(
      `select c.relname,c.relrowsecurity,c.relforcerowsecurity
       from pg_class c join pg_namespace n on n.oid=c.relnamespace
       where n.nspname='public' and c.relkind='r' and c.relname=any($1::text[])`,
      [expected],
    );
    const byName = new Map(result.rows.map((row) => [row.relname, row]));
    expect([...byName.keys()].sort()).toEqual([...expected].sort());
    for (const table of expected) {
      expect(byName.get(table)?.relrowsecurity, `${table} RLS enabled`).toBe(true);
      expect(byName.get(table)?.relforcerowsecurity, `${table} RLS forced`).toBe(true);
    }

    const followerPolicies = await admin.query<{ tablename: string; roles: string[] }>(
      `select tablename, roles::text[] as roles
       from pg_policies
       where schemaname='public'
         and policyname in ('community_posts_followers_read','media_assets_followers_read')
       order by tablename`,
    );
    // PostgreSQL does not guarantee the order of role names in the
    // pg_policies.roles array. Normalize only that unordered dimension,
    // while retaining the exact policy count, table ordering, and role set.
    const normalizedFollowerPolicies = followerPolicies.rows.map((policy) => ({
      ...policy,
      roles: [...policy.roles].sort(),
    }));
    expect(normalizedFollowerPolicies).toEqual([
      {
        tablename: "community_posts",
        roles: ["sakhi_dev_app", "sakhi_staging_app", "sakhi_test_app"],
      },
      {
        tablename: "media_assets",
        roles: ["sakhi_dev_app", "sakhi_staging_app", "sakhi_test_app"],
      },
    ]);

    const followIndex = await admin.query<{ indexdef: string }>(
      `select indexdef from pg_indexes
       where schemaname='public'
         and tablename='member_follows'
         and indexname='member_follows_directory_profile_id_idx'`,
    );
    expect(followIndex.rows).toHaveLength(1);
    expect(followIndex.rows[0]?.indexdef).toContain("(directory_profile_id)");
  });

  it("allows member audit insertion but does not expose audit rows to member reads", async () => {
    await app.query("begin");
    await app.query("select set_config('app.account_id',$1,true)", [accountA]);
    await app.query(
      `insert into public.audit_events(id,actor_type,actor_id,action,outcome,request_id)
       values (gen_random_uuid(),'MEMBER',$1,'stage5.synthetic.test','success','stage5-rls-test-a')`,
      [accountA],
    );
    const memberRead = await app.query(
      "select id from public.audit_events where request_id='stage5-rls-test-a'",
    );
    expect(memberRead.rowCount).toBe(0);
    await app.query("rollback");
  });

  it("uses explicit transaction-local identity for member audit inserts without exposing audit reads", async () => {
    const prisma = new PrismaService(new ConfigService({
      SAKHI_ENV: "test",
      SAKHI_APP_DATABASE_URL: appUrl,
    }));
    const requestId = `stage5-community-media-${randomUUID()}`;
    const eventData = {
      actorType: "MEMBER",
      actorId: accountA,
      action: "module2.media.uploaded",
      targetType: "media_upload",
      targetId: communityMediaId,
      outcome: "stored",
      requestId,
      redactedMetadata: { synthetic: true },
    };
    await prisma.$connect();
    try {
      await expect(prisma.auditEvent.create({ data: eventData })).rejects.toThrow();
      const identity = createAuthenticatedMemberIdentity({
        accountId: accountA,
        sessionId: sessionA,
      });
      // Prisma create() uses INSERT ... RETURNING. Because members cannot read
      // audit rows, that response path is intentionally rejected by RLS.
      await expect(
        prisma.withMemberIdentity(identity, (tx) =>
          tx.auditEvent.create({ data: eventData }),
        ),
      ).rejects.toThrow();
      const inserted = await prisma.withMemberIdentity(identity, async (tx) => {
        const identityContext = await tx.$queryRaw<
          Array<{ role: string; account_id: string }>
        >`SELECT current_user::text AS role,
                 current_setting('app.account_id', true)::text AS account_id`;
        expect(identityContext[0]?.role).toBe("sakhi_test_app");
        expect(identityContext[0]?.account_id).toBe(accountA);
        return tx.auditEvent.createMany({ data: [eventData] });
      });
      expect(inserted.count).toBe(1);
      const adminRead = await admin.query(
        "select id from public.audit_events where request_id=$1",
        [requestId],
      );
      const memberRead = await app.query(
        "select id from public.audit_events where request_id=$1",
        [requestId],
      );
      expect(adminRead.rowCount).toBe(1);
      expect(memberRead.rowCount).toBe(0);
    } finally {
      await admin.query("delete from public.audit_events where request_id=$1", [requestId]);
      await prisma.$disconnect();
    }
  });

  it("revokes table and column grants from anon, authenticated and BYPASSRLS service_role", async () => {
    const protectedTables = [
      "member_accounts", "auth_sessions", "otp_challenges", "account_deletion_requests",
      "member_profiles", "member_consents", "member_communication_preferences",
      "eligibility_submissions", "community_posts", "community_post_likes",
      "community_post_saves", "community_post_comments", "community_groups",
      "community_circle_memberships", "community_circle_posts", "member_follows",
      "member_privacy_preferences", "member_notification_preferences", "member_push_tokens",
      "member_wellness_preferences", "member_notifications", "safety_emergency_contacts",
      "safety_sos_events", "safety_location_shares", "member_moderation_blocks",
      "member_user_reports", "direct_messages", "media_assets", "community_post_reactions",
      "business_directory_listings", "business_enquiries", "business_reports",
      "menstrual_cycle_logs", "menstrual_daily_logs", "menstrual_tracker_preferences",
      "community_directory_profiles", "eligibility_consents", "eligibility_support_requests",
      "eligibility_verification_sessions", "audit_events", "moderation_decisions",
      "admin_staff_accounts", "admin_staff_sessions", "admin_staff_mfa",
      "admin_staff_backup_codes", "admin_staff_recovery_requests", "admin_auth_sessions",
      "discreet_complaints", "eligibility_provider_callback_events", "admin_bootstrap_credentials",
    ];
    const roles = ["anon", "authenticated", "service_role"] as const;
    const bypass = await admin.query<{ rolbypassrls: boolean }>(
      "select rolbypassrls from pg_roles where rolname='service_role'",
    );
    expect(bypass.rows[0]?.rolbypassrls).toBe(true);

    const result = await admin.query<{
      table_name: string;
      role_name: string;
      select_grant: boolean;
      insert_grant: boolean;
      update_grant: boolean;
      delete_grant: boolean;
      references_grant: boolean;
      truncate_grant: boolean;
      trigger_grant: boolean;
    }>(
      `select t.table_name, r.role_name,
              has_table_privilege(r.role_name, format('public.%I',t.table_name), 'SELECT') as select_grant,
              has_table_privilege(r.role_name, format('public.%I',t.table_name), 'INSERT') as insert_grant,
              has_table_privilege(r.role_name, format('public.%I',t.table_name), 'UPDATE') as update_grant,
              has_table_privilege(r.role_name, format('public.%I',t.table_name), 'DELETE') as delete_grant,
              has_table_privilege(r.role_name, format('public.%I',t.table_name), 'REFERENCES') as references_grant,
              has_table_privilege(r.role_name, format('public.%I',t.table_name), 'TRUNCATE') as truncate_grant,
              has_table_privilege(r.role_name, format('public.%I',t.table_name), 'TRIGGER') as trigger_grant,
              has_any_column_privilege(r.role_name, format('public.%I',t.table_name), 'SELECT') as column_select,
              has_any_column_privilege(r.role_name, format('public.%I',t.table_name), 'INSERT') as column_insert,
              has_any_column_privilege(r.role_name, format('public.%I',t.table_name), 'UPDATE') as column_update,
              has_any_column_privilege(r.role_name, format('public.%I',t.table_name), 'REFERENCES') as column_references
       from unnest($1::text[]) as t(table_name)
       cross join unnest($2::text[]) as r(role_name)
       order by t.table_name, r.role_name`,
      [protectedTables, roles],
    );
    expect(result.rows).toHaveLength(protectedTables.length * roles.length);
    for (const row of result.rows) {
      expect(row.select_grant, `${row.role_name} SELECT on ${row.table_name}`).toBe(false);
      expect(row.insert_grant, `${row.role_name} INSERT on ${row.table_name}`).toBe(false);
      expect(row.update_grant, `${row.role_name} UPDATE on ${row.table_name}`).toBe(false);
      expect(row.delete_grant, `${row.role_name} DELETE on ${row.table_name}`).toBe(false);
      expect(row.references_grant, `${row.role_name} REFERENCES on ${row.table_name}`).toBe(false);
      expect(row.truncate_grant, `${row.role_name} TRUNCATE on ${row.table_name}`).toBe(false);
      expect(row.trigger_grant, `${row.role_name} TRIGGER on ${row.table_name}`).toBe(false);
    }
    const columnGrants = await admin.query<{
      role_name: string;
      table_name: string;
      has_column_grant: boolean;
    }>(
      `select r.role_name,t.table_name,
              has_any_column_privilege(r.role_name,format('public.%I',t.table_name),'SELECT')
              OR has_any_column_privilege(r.role_name,format('public.%I',t.table_name),'INSERT')
              OR has_any_column_privilege(r.role_name,format('public.%I',t.table_name),'UPDATE')
              OR has_any_column_privilege(r.role_name,format('public.%I',t.table_name),'REFERENCES')
                as has_column_grant
       from unnest($1::text[]) as t(table_name)
       cross join unnest($2::text[]) as r(role_name)`,
      [protectedTables, roles],
    );
    expect(columnGrants.rows.filter((row) => row.has_column_grant)).toEqual([]);
  });
});
