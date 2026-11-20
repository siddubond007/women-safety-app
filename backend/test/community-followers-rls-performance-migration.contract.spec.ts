import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

const migration = readFileSync(
  new URL(
    "../prisma/migrations/20261120130000_community_followers_rls_performance/migration.sql",
    import.meta.url,
  ),
  "utf8",
);

describe("community follower RLS performance migration", () => {
  it("targets only approved Sakhi runtime roles that actually exist in the environment", () => {
    expect(migration).toContain("FROM pg_catalog.pg_roles AS existing_role");
    expect(migration).toContain("'sakhi_dev_app'");
    expect(migration).toContain("'sakhi_test_app'");
    expect(migration).toContain("'sakhi_staging_app'");
    expect(migration).toContain("string_agg(format('%I', candidate.role_name)");
    expect(migration).toContain("TO %s");
    expect(migration).toContain("no approved Sakhi application role exists");
    expect(migration).not.toMatch(/TO\s+sakhi_dev_app\s*,\s*sakhi_test_app\s*,\s*sakhi_staging_app/i);
  });

  it("fails closed when no approved application role exists", () => {
    expect(migration).toContain("IF policy_roles IS NULL THEN");
    expect(migration).toContain("RAISE EXCEPTION");
    expect(migration).toContain("END IF;");
  });

  it("retains follower, publication, deletion, media-attachment and block predicates", () => {
    for (const predicate of [
      "visibility = 'FOLLOWERS_ONLY'",
      "status IN ('PUBLISHED', 'EDITED')",
      "deleted_at IS NULL",
      "member_follow.is_following = true",
      "viewer_block.blocked_account_id = community_posts.author_account_id",
      "purpose IN ('COMMUNITY_POST_IMAGE', 'COMMUNITY_POST_VIDEO')",
      "status = 'ATTACHED'",
      "community_post.author_account_id = media_assets.owner_account_id",
    ]) {
      expect(migration).toContain(predicate);
    }
  });

  it("uses scalar subqueries for request identity and adds the follower lookup index", () => {
    expect(migration.match(/\(SELECT NULLIF\(current_setting\('app\.account_id', true\), ''\)\)/g)?.length).toBeGreaterThanOrEqual(3);
    expect(migration).toContain(
      "CREATE INDEX IF NOT EXISTS member_follows_directory_profile_id_idx",
    );
    expect(migration).toContain("ON public.member_follows (directory_profile_id)");
  });
});
