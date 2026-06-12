-- Add QuickBooks employee ID to team_members for idempotency
ALTER TABLE "public"."team_members"
  ADD COLUMN IF NOT EXISTS "qb_employee_id" "text";

-- Store rotating OAuth tokens for centralized integrations (e.g. QuickBooks)
-- QB refresh tokens rotate on every use and expire after ~100 days, so env vars won't work.
CREATE TABLE IF NOT EXISTS "public"."oauth_tokens" (
  "id" "text" PRIMARY KEY,              -- e.g. 'quickbooks'
  "access_token" "text",
  "refresh_token" "text" NOT NULL,
  "expires_at" timestamp with time zone,
  "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);

ALTER TABLE "public"."oauth_tokens"
  ADD COLUMN IF NOT EXISTS "realm_id" "text",
  ADD COLUMN IF NOT EXISTS "pending_state" "text";

ALTER TABLE "public"."oauth_tokens" OWNER TO "postgres";
