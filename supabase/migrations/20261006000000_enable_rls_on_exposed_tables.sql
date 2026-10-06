-- ---------------------------------------------------------------------------------
-- Close public access to every public-schema table that still has RLS disabled.
--
-- Flagged by the Supabase security advisor (rls_disabled_in_public, ERROR) on
-- 2026-10-06. These tables have never had RLS, and the default grants give ALL to
-- `anon` and `authenticated`. The Supabase publishable key ships in the browser
-- bundle, so anyone could read, edit or delete every row — including
-- oauth_tokens (third-party access/refresh tokens), addresses (Team Member home
-- addresses), and the payroll/contribution tables. Same hole one_time_payments
-- had (20260927000001) and invoice_adjustments had (20260806000000).
--
-- Nothing legitimate uses those grants: every read and write goes through the
-- Next.js API on supabaseAdmin (service role, bypasses RLS), and the legacy edge
-- functions also use the service role. The SPA queries none of these tables
-- directly, none are in a Realtime publication, and the plpgsql functions that
-- touch them (cashback, contribution corrections) are only called by the
-- backend as service role. RLS is enabled with no policies (deny-all for
-- anon/authenticated) and the grants are revoked as well, so a policy added by
-- mistake later can't silently reopen writes.
--
-- If Clients should ever read one of these directly, add a SELECT policy scoped
-- by company_id — do not re-grant writes.
-- ---------------------------------------------------------------------------------

BEGIN;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'addresses',
    'cashback_accruals',
    'cashback_config',
    'cashback_payouts',
    'cpp_contributions',
    'eei_contributions',
    'invoice_late_fees',
    'invoice_reminders',
    'oauth_tokens',
    'payroll_schedules',
    'rrsp_contributions',
    'rrsp_plans',
    'signature_requests',
    'stripe_invoices',
    'team_member_leaves',
    'topups',
    'wise_invoices'
  ]
  LOOP
    -- Skip rather than fail where a table doesn't exist, so staging and
    -- production can drift slightly without blocking the lockdown.
    IF to_regclass(format('public.%I', t)) IS NULL THEN
      RAISE NOTICE 'public.% does not exist; skipping', t;
      CONTINUE;
    END IF;

    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated', t);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only).
-- Re-granting reopens the hole described above; only do it for a specific table
-- if something turns out to depend on direct access.
--
--   BEGIN;
--   ALTER TABLE public.<table> DISABLE ROW LEVEL SECURITY;
--   GRANT ALL ON public.<table> TO anon, authenticated;
--   NOTIFY pgrst, 'reload schema';
--   COMMIT;
-- ---------------------------------------------------------------------------------
