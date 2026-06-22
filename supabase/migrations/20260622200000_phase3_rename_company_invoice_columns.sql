-- Phase 3 of the DB naming cleanup (see RENAME_PLAN.md).
--
-- Coordinated rename + codemod (NO shim). These columns are app-WRITTEN, so a GENERATED
-- mirror would break inserts/updates, and a view can't share the table name. But unlike the
-- Phase 2 PK (which collides with FK columns and pervasive app-layer fields), these names are
-- UNAMBIGUOUS — every occurrence is the same column — so the call-site codemod is mechanical
-- and low-risk. This migration MUST deploy together with the shoreline-nextjs codemod
-- (and the regenerated frontend types). Tested on staging before production.
--
-- Renames (convention §1/§3 — drop redundant prefixes, match sibling names):
--   companies.company_address    -> address              (no redundant table prefix)
--   companies.customer_stripe_id -> stripe_customer_id   (matches ach_stripe_customer_id / stripe_invoices)
--   companies.personal_email     -> contact_email        (clearer intent)
--   invoices.invoice_link        -> hosted_url           (it's the Stripe hosted invoice URL)
--   invoices.invoice_number      -> number               (no redundant table prefix)
--
-- VERIFIED SAFE: none of these columns are referenced by any DB function/trigger body or RLS
-- policy in migration history (only CREATE TABLE + one data UPDATE). No function recreation
-- needed. PRE-DEPLOY CHECK: the Invoice-status-sync / subscription edge functions in
-- supabase/functions/ are NOT covered by this migration grep — confirm they don't write
-- invoice_link / invoice_number before promoting to production (those are being migrated to
-- shoreline-nextjs, whose stripe webhook routes ARE in the codemod).
--
-- NOT in this phase (coupled to functions/types/enums, handled later):
--   plans.plan_name         -> Phase 5 (BEFORE-trigger auto_populate_plan_details + plan_name_enum)
--   plans.number_of_employees -> Phase 4 (string -> integer; read by handle_plan_downgrade)
--   addresses.address_1/2/state, cashback_config table -> deferred batch.

BEGIN;

ALTER TABLE public.companies RENAME COLUMN company_address    TO address;
ALTER TABLE public.companies RENAME COLUMN customer_stripe_id TO stripe_customer_id;
ALTER TABLE public.companies RENAME COLUMN personal_email     TO contact_email;

ALTER TABLE public.invoices  RENAME COLUMN invoice_link   TO hosted_url;
ALTER TABLE public.invoices  RENAME COLUMN invoice_number TO number;

-- Refresh PostgREST's schema cache so the renamed columns are served immediately.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (forward-only DBs — run manually if needed):
--   ALTER TABLE public.companies RENAME COLUMN address            TO company_address;
--   ALTER TABLE public.companies RENAME COLUMN stripe_customer_id TO customer_stripe_id;
--   ALTER TABLE public.companies RENAME COLUMN contact_email      TO personal_email;
--   ALTER TABLE public.invoices  RENAME COLUMN hosted_url         TO invoice_link;
--   ALTER TABLE public.invoices  RENAME COLUMN number             TO invoice_number;
--   NOTIFY pgrst, 'reload schema';
-- ---------------------------------------------------------------------------------
