-- Rename `invoices` -> `salary_invoices` and leave a backward-compat view.
--
-- Context: we are introducing a second billing-invoice table, `subscription_invoices`
-- (plan + top-up Stripe subscription invoices). To make the two-table model explicit,
-- the existing `invoices` table — which stores salary and late-fee invoices — is
-- renamed to `salary_invoices`.
--
-- 1. Rename the table (metadata-only — no rewrite, no data movement).
-- 2. Rename the PK + company_id FK constraints to match the new name (best-effort).
--    Child-table FKs (payments.invoice_id, one_time_payments.invoice_id,
--    invoice_adjustments, cpp/eei/rrsp_contributions, stripe_invoices, wise_invoices,
--    invoice_late_fees) automatically keep pointing at the renamed table — FKs track
--    the table object, not its name — so they are left untouched.
-- 3. Leave a DEPRECATED, auto-updatable compatibility view at the old name so every
--    live .from("invoices") call site in shoreline-nextjs / shoreline-vite keeps
--    working (reads + inserts) until they are migrated. Mirrors the Phase-1
--    one_time_payments rename (20260622180000).

-- 1. Rename the table -------------------------------------------------------------
ALTER TABLE public.invoices RENAME TO salary_invoices;

-- 2. Rename constraints to match the new table name (idempotent + env-drift safe) --
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.salary_invoices'::regclass AND conname = 'invoices_pkey'
  ) THEN
    ALTER TABLE public.salary_invoices RENAME CONSTRAINT invoices_pkey TO salary_invoices_pkey;
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.salary_invoices'::regclass AND conname = 'invoices_company_id_fkey'
  ) THEN
    ALTER TABLE public.salary_invoices RENAME CONSTRAINT invoices_company_id_fkey TO salary_invoices_company_id_fkey;
  END IF;
END $$;

-- 3. Backward-compatibility shim --------------------------------------------------
-- Auto-updatable view (plain SELECT *), so the app's reads AND inserts pass through
-- to the base table. security_invoker = true makes the view respect the base table's
-- RLS for any non-service-role access (preserving the pre-rename behavior).
CREATE VIEW public.invoices
  WITH (security_invoker = true)
  AS SELECT * FROM public.salary_invoices;

COMMENT ON VIEW public.invoices IS
  'DEPRECATED compatibility shim for the renamed salary_invoices table. '
  'shoreline-nextjs / shoreline-vite still query this name. '
  'Drop this view once those call sites are migrated to salary_invoices.';

GRANT SELECT, INSERT, UPDATE, DELETE ON public.invoices
  TO anon, authenticated, service_role;

-- Refresh PostgREST's schema cache so the rename + view are picked up immediately.
NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only):
--
--   DROP VIEW IF EXISTS public.invoices;
--   ALTER TABLE public.salary_invoices RENAME TO invoices;
--   ALTER TABLE public.invoices RENAME CONSTRAINT salary_invoices_pkey TO invoices_pkey;
--   ALTER TABLE public.invoices RENAME CONSTRAINT salary_invoices_company_id_fkey TO invoices_company_id_fkey;
--   NOTIFY pgrst, 'reload schema';
-- ---------------------------------------------------------------------------------
