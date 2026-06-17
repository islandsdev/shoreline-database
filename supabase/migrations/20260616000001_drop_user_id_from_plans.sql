-- Drop RLS policies that reference plans.user_id (legacy — all access now goes through the Next.js backend via service role)
DROP POLICY IF EXISTS "Users can manage their plans" ON "public"."plans";
DROP POLICY IF EXISTS "insert_plans_policy" ON "public"."plans";
DROP POLICY IF EXISTS "read_plans_policy" ON "public"."plans";
DROP POLICY IF EXISTS "update_plans_policy" ON "public"."plans";

ALTER TABLE "public"."plans"
  DROP COLUMN IF EXISTS "user_id";
