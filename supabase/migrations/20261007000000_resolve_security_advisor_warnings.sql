-- ---------------------------------------------------------------------------------
-- Resolve the remaining Supabase security advisor warnings (2026-10-06), following
-- the RLS lockdown in 20261006000000.
--
-- 1. companies / team_members / payments: drop every policy and revoke the
--    anon/authenticated grants. The advisor flagged the always-true INSERT /
--    UPDATE / DELETE policies, but the SELECT policies are also `USING (true)`
--    for `public` (the advisor skips SELECT), so anyone holding the publishable
--    key could read every Team Member and payment row. Nothing legitimate uses
--    these: the SPA only queries `admins` directly, and the Next.js API and the
--    legacy edge functions all use the service role (bypasses RLS). Same
--    deny-all treatment as 20261006000000.
--
-- 2. Functions: pin search_path on every flagged function, and revoke EXECUTE
--    from PUBLIC/anon/authenticated. None of them is called over RPC by a client
--    (the backend calls RPCs as service role), no policy references has_role,
--    and trigger functions don't need EXECUTE at fire time — only when the
--    trigger is created. Worst of the lot: anon could call approve_team_member
--    (SECURITY DEFINER) to approve any Team Member, and "generate-stripe-invoices"
--    to fire the production daily-invoice-job edge function.
--
-- 3. Storage:
--    - team-documents: nothing references this bucket; its policies let anyone
--      list, upload and overwrite. Dropped. The bucket stays public, so existing
--      object URLs keep working.
--    - companies: the SPA uploads resumes here (ProfessionalInfo.tsx, upsert)
--      and reads their metadata (`storage.info()` in lib/utils.ts). Both need
--      SELECT on the object, so instead of dropping it, the policies are scoped
--      to signed-in users and to objects they uploaded. Public URLs don't go
--      through RLS, so getPublicUrl links are unaffected. If `info()` fails for
--      a resume someone else uploaded, getFileNameFromUrl already returns null.
--
-- Not covered here: "Leaked password protection" is an Auth setting in the
-- dashboard (Authentication → Sign In / Providers → Email), not a migration.
--
-- Everything is drift-tolerant (missing objects are skipped) so the same file
-- applies cleanly to staging and production.
-- ---------------------------------------------------------------------------------

BEGIN;

-- 1. Lock down companies / team_members / payments --------------------------------
DO $$
DECLARE
  t text;
  pol record;
BEGIN
  FOREACH t IN ARRAY ARRAY['companies', 'team_members', 'payments']
  LOOP
    IF to_regclass(format('public.%I', t)) IS NULL THEN
      RAISE NOTICE 'public.% does not exist; skipping', t;
      CONTINUE;
    END IF;

    FOR pol IN
      SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = t
    LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', pol.policyname, t);
    END LOOP;

    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon, authenticated', t);
  END LOOP;
END $$;

-- 2. Harden functions -------------------------------------------------------------
DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace
      AND p.proname IN (
        'approve_team_member', 'auto_populate_plan_details', 'autofill_company_name',
        'autofill_document_metadata', 'autofill_one_time_payment_fields',
        'autofill_payments_fields', 'autofill_team_member_email',
        'create_annual_cashback_payout', 'enforce_employee_company_match',
        'generate-stripe-invoices', 'get_cashback_rate', 'get_company_cashback_balance',
        'handle_new_plan', 'handle_plan_downgrade', 'has_role', 'set_admin_user_id',
        'set_approved_date', 'set_company_user_id', 'set_current_timestamp_updated_at',
        'update_cashback_rates', 'update_updated_at_column'
      )
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public', fn.sig);
    EXECUTE format('REVOKE EXECUTE ON FUNCTION %s FROM PUBLIC, anon, authenticated', fn.sig);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', fn.sig);
  END LOOP;
END $$;

-- 3. Storage policies -------------------------------------------------------------
DROP POLICY IF EXISTS "test team-documents 1t7ma14_0" ON storage.objects;
DROP POLICY IF EXISTS "test team-documents 1t7ma14_1" ON storage.objects;
DROP POLICY IF EXISTS "test team-documents 1t7ma14_2" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated users to upload documents 2 1t7ma14_0" ON storage.objects;

DROP POLICY IF EXISTS "ALL POLICY 1bny57f_0" ON storage.objects;
DROP POLICY IF EXISTS "ALL POLICY 1bny57f_1" ON storage.objects;
DROP POLICY IF EXISTS "ALL POLICY 1bny57f_2" ON storage.objects;

CREATE POLICY "companies: read own uploads" ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'companies' AND owner_id = (SELECT auth.uid())::text);

CREATE POLICY "companies: signed-in users upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'companies');

CREATE POLICY "companies: update own uploads" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'companies' AND owner_id = (SELECT auth.uid())::text);

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only).
-- The dropped table/storage policies are listed in the 2026-10-07 advisor export;
-- recreate only the specific one something turns out to depend on, scoped by
-- company_id / owner_id, rather than restoring the always-true versions.
--
--   GRANT EXECUTE ON FUNCTION public.<fn>(<args>) TO authenticated;
--   ALTER FUNCTION public.<fn>(<args>) RESET search_path;
-- ---------------------------------------------------------------------------------
