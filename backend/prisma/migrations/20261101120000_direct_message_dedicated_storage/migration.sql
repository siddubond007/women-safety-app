-- Dedicated, participant-addressed direct-message storage.
-- Legacy audit rows are retained; only messages with two resolvable Sakhi accounts are copied.
CREATE TABLE IF NOT EXISTS "direct_messages" (
  "id" UUID NOT NULL,
  "sender_account_id" UUID NOT NULL,
  "recipient_account_id" UUID NOT NULL,
  "sender_directory_profile_id" UUID,
  "recipient_directory_profile_id" UUID,
  "sender_name" VARCHAR(100) NOT NULL,
  "sender_username" VARCHAR(50) NOT NULL,
  "sender_avatar" TEXT,
  "recipient_name" VARCHAR(100) NOT NULL,
  "recipient_handle" VARCHAR(50) NOT NULL,
  "body" TEXT NOT NULL,
  "source_audit_event_id" UUID,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "direct_messages_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "direct_messages_sender_account_fkey"
    FOREIGN KEY ("sender_account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "direct_messages_recipient_account_fkey"
    FOREIGN KEY ("recipient_account_id") REFERENCES "member_accounts"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "direct_messages_source_audit_event_fkey"
    FOREIGN KEY ("source_audit_event_id") REFERENCES "audit_events"("id")
    ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS "direct_messages_source_audit_event_key"
  ON "direct_messages"("source_audit_event_id");
CREATE INDEX IF NOT EXISTS "direct_messages_sender_recipient_created_idx"
  ON "direct_messages"("sender_account_id", "recipient_account_id", "created_at");
CREATE INDEX IF NOT EXISTS "direct_messages_recipient_sender_created_idx"
  ON "direct_messages"("recipient_account_id", "sender_account_id", "created_at");
CREATE INDEX IF NOT EXISTS "direct_messages_sender_created_idx"
  ON "direct_messages"("sender_account_id", "created_at");
CREATE INDEX IF NOT EXISTS "direct_messages_recipient_created_idx"
  ON "direct_messages"("recipient_account_id", "created_at");

-- Backfill from the original audit records without deleting or rewriting those records.
-- Recipient resolution supports account UUIDs, directory-profile UUIDs, and usernames.
WITH legacy_events AS (
  SELECT
    ae."id" AS audit_event_id,
    ae."actor_id" AS audit_actor_id,
    ae."created_at" AS audit_created_at,
    ae."redacted_metadata" AS metadata
  FROM "audit_events" ae
  WHERE ae."action" = 'module3.direct_message.sent'
    AND jsonb_typeof(ae."redacted_metadata") = 'object'
), normalized AS (
  SELECT
    le.*,
    CASE
      WHEN COALESCE(le.metadata ->> 'id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
      THEN (le.metadata ->> 'id')::uuid
      ELSE NULL
    END AS message_id
  FROM legacy_events le
), resolved AS (
  SELECT
    n.*,
    sender_account."id" AS sender_account_id,
    recipient_account."id" AS recipient_account_id,
    sender_profile."display_name" AS sender_profile_name,
    sender_profile."username" AS sender_profile_username,
    sender_profile."avatar_asset" AS sender_profile_avatar,
    sender_directory."id" AS sender_directory_profile_id,
    recipient_profile."display_name" AS recipient_profile_name,
    recipient_profile."username" AS recipient_profile_username,
    recipient_profile."directory_profile_id" AS recipient_directory_profile_id
  FROM normalized n
  LEFT JOIN LATERAL (
    SELECT ma."id"
    FROM "member_accounts" ma
    WHERE ma."id" = n.audit_actor_id
      AND (
        NULLIF(n.metadata ->> 'senderAccountId', '') IS NULL
        OR ma."id"::text = n.metadata ->> 'senderAccountId'
      )
    LIMIT 1
  ) sender_account ON TRUE
  LEFT JOIN "member_accounts" sender_account_row
    ON sender_account_row."id" = sender_account."id"
  LEFT JOIN "member_profiles" sender_profile
    ON sender_profile."account_id" = sender_account_row."id"
  LEFT JOIN "community_directory_profiles" sender_directory
    ON lower(trim(sender_directory."username")) = lower(trim(sender_profile."username"))
  LEFT JOIN LATERAL (
    SELECT ma."id"
    FROM "member_accounts" ma
    LEFT JOIN "member_profiles" mp ON mp."account_id" = ma."id"
    WHERE ma."id"::text = NULLIF(n.metadata ->> 'recipientAccountId', '')
       OR (
         ma."id"::text = NULLIF(n.metadata ->> 'recipientId', '')
         AND (
           NULLIF(n.metadata ->> 'recipientHandle', '') IS NULL
           OR lower(trim(mp."username")) = lower(trim(n.metadata ->> 'recipientHandle'))
           OR lower(trim(mp."username")) = lower(trim('@' || ltrim(n.metadata ->> 'recipientHandle', '@')))
         )
       )
    ORDER BY CASE
      WHEN ma."id"::text = NULLIF(n.metadata ->> 'recipientAccountId', '') THEN 0
      ELSE 1
    END
    LIMIT 1
  ) recipient_account_candidate ON TRUE
  LEFT JOIN LATERAL (
    SELECT ma."id"
    FROM "member_accounts" ma
    WHERE ma."id"::text = NULLIF(n.metadata ->> 'recipientId', '')
    LIMIT 1
  ) recipient_id_account ON TRUE
  LEFT JOIN LATERAL (
    SELECT cdp."id", cdp."username"
    FROM "community_directory_profiles" cdp
    WHERE cdp."id"::text = NULLIF(n.metadata ->> 'recipientId', '')
    LIMIT 1
  ) recipient_directory_by_id ON TRUE
  LEFT JOIN LATERAL (
    SELECT
      mp."account_id",
      mp."display_name",
      mp."username",
      cdp."id" AS directory_profile_id
    FROM "member_profiles" mp
    LEFT JOIN "community_directory_profiles" cdp
      ON lower(trim(cdp."username")) = lower(trim(mp."username"))
    WHERE (
      recipient_account_candidate."id" IS NOT NULL
      AND mp."account_id" = recipient_account_candidate."id"
    ) OR (
      recipient_account_candidate."id" IS NULL
      AND recipient_id_account."id" IS NULL
      AND NULLIF(n.metadata ->> 'recipientAccountId', '') IS NULL
      AND (
        (
          recipient_directory_by_id."id" IS NOT NULL
          AND cdp."id" = recipient_directory_by_id."id"
          AND (
            NULLIF(n.metadata ->> 'recipientHandle', '') IS NULL
            OR lower(trim(cdp."username")) = lower(trim(n.metadata ->> 'recipientHandle'))
            OR lower(trim(cdp."username")) = lower(trim('@' || ltrim(n.metadata ->> 'recipientHandle', '@')))
          )
        )
        OR (
          recipient_directory_by_id."id" IS NULL
          AND (
            NULLIF(n.metadata ->> 'recipientHandle', '') IS NULL
            OR NULLIF(n.metadata ->> 'recipientId', '') IS NULL
            OR lower(regexp_replace(trim(n.metadata ->> 'recipientHandle'), '^@+', '')) = lower(regexp_replace(trim(n.metadata ->> 'recipientId'), '^@+', ''))
          )
          AND (
            lower(trim(mp."username")) = lower(trim(COALESCE(
              NULLIF(n.metadata ->> 'recipientHandle', ''),
              NULLIF(n.metadata ->> 'recipientId', '')
            )))
            OR lower(trim(mp."username")) = lower(trim('@' || ltrim(COALESCE(
              NULLIF(n.metadata ->> 'recipientHandle', ''),
              NULLIF(n.metadata ->> 'recipientId', '')
            ), '@')))
          )
        )
      )
    )
    ORDER BY CASE
      WHEN recipient_account_candidate."id" IS NOT NULL
           AND mp."account_id" = recipient_account_candidate."id" THEN 0
      WHEN cdp."id"::text = NULLIF(n.metadata ->> 'recipientId', '') THEN 1
      ELSE 2
    END
    LIMIT 1
  ) recipient_profile ON TRUE
  LEFT JOIN "member_accounts" recipient_account
    ON recipient_account."id" = COALESCE(
      recipient_account_candidate."id",
      recipient_profile."account_id"
    )
)
INSERT INTO "direct_messages" (
  "id",
  "sender_account_id",
  "recipient_account_id",
  "sender_directory_profile_id",
  "recipient_directory_profile_id",
  "sender_name",
  "sender_username",
  "sender_avatar",
  "recipient_name",
  "recipient_handle",
  "body",
  "source_audit_event_id",
  "created_at"
)
SELECT
  r.message_id,
  r.sender_account_id,
  r.recipient_account_id,
  r.sender_directory_profile_id,
  r.recipient_directory_profile_id,
  LEFT(COALESCE(r.sender_profile_name, NULLIF(r.metadata ->> 'senderName', ''), 'Sakhi Member'), 100),
  LEFT(COALESCE(r.sender_profile_username, NULLIF(r.metadata ->> 'senderUsername', ''), '@member'), 50),
  COALESCE(NULLIF(r.sender_profile_avatar, ''), NULLIF(r.metadata ->> 'senderAvatar', '')),
  LEFT(COALESCE(r.recipient_profile_name, NULLIF(r.metadata ->> 'recipientName', ''), 'Sakhi Member'), 100),
  LEFT(COALESCE(r.recipient_profile_username, NULLIF(r.metadata ->> 'recipientHandle', ''), '@member'), 50),
  COALESCE(NULLIF(r.metadata ->> 'body', ''), NULLIF(r.metadata ->> 'message', '')),
  r.audit_event_id,
  r.audit_created_at
FROM resolved r
WHERE r.message_id IS NOT NULL
  AND r.sender_account_id IS NOT NULL
  AND r.recipient_account_id IS NOT NULL
  AND r.sender_account_id <> r.recipient_account_id
  AND COALESCE(NULLIF(r.metadata ->> 'body', ''), NULLIF(r.metadata ->> 'message', '')) IS NOT NULL
ON CONFLICT DO NOTHING;
