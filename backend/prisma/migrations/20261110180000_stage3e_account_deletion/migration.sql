-- Stage 3E: durable account-deletion requests and confidential complaint unlinking.
CREATE TABLE IF NOT EXISTS "account_deletion_requests" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "account_id" UUID NOT NULL,
  "status" VARCHAR(24) NOT NULL DEFAULT 'REQUESTED',
  "request_reason" VARCHAR(500),
  "requested_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "processed_at" TIMESTAMPTZ(6),
  CONSTRAINT "account_deletion_requests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "account_deletion_requests_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "member_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX IF NOT EXISTS "account_deletion_requests_account_status_idx" ON "account_deletion_requests"("account_id", "status");

-- Complaint/evidence rows are preserved; only confidential identity linkage is removed.
