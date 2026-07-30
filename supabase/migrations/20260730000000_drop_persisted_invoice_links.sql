-- ---------------------------------------------------------------------------------
-- Drop the persisted invoice-link columns.
--
--   salary_invoices.hosted_url
--   subscription_invoices.hosted_invoice_url
--
-- WHY: Stripe rotates the signed token embedded in a hosted-invoice URL, so a
-- value captured at invoice-creation / webhook time eventually renders Stripe's
-- "This link has expired" page. Every surface that linked to the stored column
-- inherited that bug (most recently the admin payout modal). Links are now
-- DERIVED on demand instead — see shoreline-nextjs/lib/invoice-link-resolver.ts:
--
--   Stripe invoices → retrieved live from the Stripe API (always current)
--   Wise invoices   → read from wise_invoices.raw_payload, where the link
--                     originally came from (Wise links are static)
--
-- APPLY ONLY AFTER the shoreline-nextjs + shoreline-vite changes are deployed to
-- the same environment; earlier code selects and writes these columns.
--
-- Regenerate types.ts (shoreline-database and shoreline-vite) after applying.
-- ---------------------------------------------------------------------------------

BEGIN;

-- ---------------------------------------------------------------------------------
-- Safety gate: a Stripe link is always recoverable from the API, but a Wise link
-- exists ONLY in what we stored. Refuse to drop the column if any Wise invoice's
-- link isn't recoverable from wise_invoices.raw_payload, rather than destroying
-- it — this DDL cannot be undone.
-- ---------------------------------------------------------------------------------
DO $$
DECLARE
  unrecoverable_wise integer;
  stripe_without_record integer;
BEGIN
  SELECT count(*) INTO unrecoverable_wise
  FROM public.salary_invoices si
  WHERE si.hosted_url IS NOT NULL
    AND si.provider = 'Wise'
    AND NOT EXISTS (
      SELECT 1
      FROM public.wise_invoices wi
      WHERE wi.invoice_id = si.id
        AND COALESCE(wi.raw_payload ->> 'link', wi.raw_payload ->> 'publicUrl') IS NOT NULL
    );

  IF unrecoverable_wise > 0 THEN
    RAISE EXCEPTION
      'Refusing to drop salary_invoices.hosted_url: % Wise invoice(s) have a stored link that is not recoverable from wise_invoices.raw_payload. Backfill raw_payload for those rows first.',
      unrecoverable_wise;
  END IF;

  -- Stripe rows with no stripe_invoices record can no longer be opened at all.
  -- Not a blocker (their stored URL had expired anyway, so nothing usable is
  -- lost) but worth surfacing in the migration output.
  SELECT count(*) INTO stripe_without_record
  FROM public.salary_invoices si
  WHERE si.hosted_url IS NOT NULL
    AND si.provider = 'Stripe'
    AND NOT EXISTS (
      SELECT 1 FROM public.stripe_invoices sti WHERE sti.invoice_id = si.id
    );

  IF stripe_without_record > 0 THEN
    RAISE NOTICE
      '% Stripe salary invoice(s) have no stripe_invoices row; they will show no invoice link (their stored URL had already expired).',
      stripe_without_record;
  END IF;
END $$;

-- ---------------------------------------------------------------------------------
-- The deprecated `invoices` compatibility view is SELECT * over salary_invoices,
-- so it pins the column and must be recreated. Definition kept identical to
-- 20260717000000_rename_invoices_to_salary_invoices.sql apart from the column
-- being gone.
-- ---------------------------------------------------------------------------------
DROP VIEW IF EXISTS public.invoices;

ALTER TABLE public.salary_invoices       DROP COLUMN IF EXISTS hosted_url;
ALTER TABLE public.subscription_invoices DROP COLUMN IF EXISTS hosted_invoice_url;

CREATE VIEW public.invoices
  WITH (security_invoker = true)
  AS SELECT * FROM public.salary_invoices;

COMMENT ON VIEW public.invoices IS
  'DEPRECATED compatibility shim for the renamed salary_invoices table. '
  'shoreline-nextjs / shoreline-vite still query this name. '
  'Drop this view once those call sites are migrated to salary_invoices.';

GRANT SELECT, INSERT, UPDATE, DELETE ON public.invoices
  TO anon, authenticated, service_role;

COMMENT ON TABLE public.salary_invoices IS
  'Salary and late-fee invoices. Payment links are NOT stored here: they are '
  'resolved on demand from stripe_invoices (live Stripe retrieve) or '
  'wise_invoices.raw_payload, because Stripe rotates hosted-invoice URL tokens.';

-- Refresh PostgREST's schema cache so the dropped columns disappear immediately.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only).
-- Restores the columns as empty; the old values are NOT recoverable, which is the
-- point: application code no longer reads or writes them.
--
--   BEGIN;
--   DROP VIEW IF EXISTS public.invoices;
--   ALTER TABLE public.salary_invoices       ADD COLUMN hosted_url text;
--   ALTER TABLE public.subscription_invoices ADD COLUMN hosted_invoice_url text;
--   CREATE VIEW public.invoices WITH (security_invoker = true)
--     AS SELECT * FROM public.salary_invoices;
--   GRANT SELECT, INSERT, UPDATE, DELETE ON public.invoices
--     TO anon, authenticated, service_role;
--   NOTIFY pgrst, 'reload schema';
--   COMMIT;
-- ---------------------------------------------------------------------------------
