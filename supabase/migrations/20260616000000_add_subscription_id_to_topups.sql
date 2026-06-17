ALTER TABLE "public"."topups"
  ADD COLUMN IF NOT EXISTS "stripe_subscription_id" text;
