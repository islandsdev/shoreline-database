-- Phase 1 of the DB naming cleanup (see RENAME_PLAN.md).
--
-- 1. Rename wip_one_time_payments -> one_time_payments (drop the "wip_" prefix).
-- 2. Fix stale FK constraint names left over from earlier table renames:
--      - on one_time_payments: "one_time_payment_*" and "wip_one_time_payments_*"
--      - on payments:          "paystubs_team_member_id_fkey"
-- 3. Leave a DEPRECATED, auto-updatable compatibility view at the old name so the
--    13 live .from("wip_one_time_payments") call sites in shoreline-nextjs keep
--    working (reads + inserts) until they are migrated. The backend Supabase client
--    is untyped (createClient without <Database>), so this does not break the build.
--
-- All renames are metadata-only — no table rewrite, no data movement.

-- 1. Rename the table -------------------------------------------------------------
ALTER TABLE public.wip_one_time_payments RENAME TO one_time_payments;

-- 2. Rename stale constraint names (idempotent + env-drift safe) -------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('one_time_payments', 'one_time_payment_invoice_id_fkey',            'one_time_payments_invoice_id_fkey'),
      ('one_time_payments', 'one_time_payment_team_member_id_fkey',        'one_time_payments_team_member_id_fkey'),
      ('one_time_payments', 'wip_one_time_payments_payroll_schedule_id_fkey','one_time_payments_payroll_schedule_id_fkey'),
      ('payments',          'paystubs_team_member_id_fkey',                'payments_team_member_id_fkey')
    ) AS t(tbl, old_name, new_name)
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conrelid = format('public.%I', r.tbl)::regclass
        AND conname  = r.old_name
    ) THEN
      EXECUTE format('ALTER TABLE public.%I RENAME CONSTRAINT %I TO %I',
                     r.tbl, r.old_name, r.new_name);
    END IF;
  END LOOP;
END $$;

-- Rename the primary-key constraint to match the new table name (best effort).
DO $$
DECLARE
  pk_name text;
BEGIN
  SELECT conname INTO pk_name
  FROM pg_constraint
  WHERE conrelid = 'public.one_time_payments'::regclass
    AND contype  = 'p';

  IF pk_name IS NOT NULL AND pk_name <> 'one_time_payments_pkey' THEN
    EXECUTE format('ALTER TABLE public.one_time_payments RENAME CONSTRAINT %I TO one_time_payments_pkey', pk_name);
  END IF;
END $$;

-- 3. Backward-compatibility shim --------------------------------------------------
-- Auto-updatable view (plain SELECT *), so the backend's reads AND inserts pass
-- through to the base table. security_invoker = true makes the view respect the
-- base table's RLS for any non-service-role access.
CREATE VIEW public.wip_one_time_payments
  WITH (security_invoker = true)
  AS SELECT * FROM public.one_time_payments;

COMMENT ON VIEW public.wip_one_time_payments IS
  'DEPRECATED compatibility shim for the renamed one_time_payments table. '
  'shoreline-nextjs still queries this name (~13 call sites). '
  'Drop this view once those are migrated to one_time_payments. See RENAME_PLAN.md Phase 1.';

GRANT SELECT, INSERT, UPDATE, DELETE ON public.wip_one_time_payments
  TO anon, authenticated, service_role;

-- Refresh PostgREST's schema cache so the rename + view are picked up immediately.
NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only):
--
--   DROP VIEW IF EXISTS public.wip_one_time_payments;
--   ALTER TABLE public.one_time_payments RENAME TO wip_one_time_payments;
--   -- then rename the four constraints back to their original names.
--   NOTIFY pgrst, 'reload schema';
-- ---------------------------------------------------------------------------------
