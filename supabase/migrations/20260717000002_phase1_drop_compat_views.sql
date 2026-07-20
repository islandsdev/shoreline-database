-- Phase 1 TEARDOWN of the DB naming cleanup (see RENAME_PLAN.md §9 step 7).
--
-- Drop the two DEPRECATED backward-compat views created by Phase 1a/1b:
--   public.wip_one_time_payments -> one_time_payments   (20260622180000)
--   public.new_documents         -> signature_requests  (20260622180001)
--
-- PRECONDITION — VERIFIED 2026-07-17: every call site has been migrated off the old
-- names, so nothing reads these views anymore:
--   * shoreline-nextjs (app/ + lib/): 0 refs to wip_one_time_payments / new_documents;
--     now uses one_time_payments (13 call sites) + signature_requests (5). The Phase 1
--     codemod is merged to `main` (production) and `staging`.
--   * shoreline-vite (src/): NO live .from() on either name. Remaining hits are only in
--     the generated supabase/types.ts (a build artifact — regenerate post-migration) and
--     one code comment. No source type-reference (Tables<'...'>) uses these names, so
--     regenerating types does not break the build.
--   * shoreline-finance (*.py): 0 refs.
--   * shoreline-database edge functions (supabase/functions/): 0 refs.
--
-- Plain DROP VIEW (NO CASCADE): if some out-of-band object still depends on a view, the
-- drop errors loudly instead of silently cascading. Run on STAGING first to catch it.
--
-- SCOPE NOTE: this does NOT touch the newer public.invoices -> salary_invoices compat
-- view (20260717000000). That one is still in use by ~11 .from("invoices") call sites in
-- shoreline-nextjs and must stay until those are migrated (a separate, later teardown).

BEGIN;

DROP VIEW IF EXISTS public.wip_one_time_payments;
DROP VIEW IF EXISTS public.new_documents;

-- Refresh PostgREST's schema cache so the dropped views disappear from the API immediately.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (forward-only DBs — run manually if needed): recreate the shims exactly as
-- Phase 1a/1b left them.
--
--   CREATE VIEW public.wip_one_time_payments WITH (security_invoker = true)
--     AS SELECT * FROM public.one_time_payments;
--   GRANT SELECT, INSERT, UPDATE, DELETE ON public.wip_one_time_payments
--     TO anon, authenticated, service_role;
--
--   CREATE VIEW public.new_documents WITH (security_invoker = true)
--     AS SELECT * FROM public.signature_requests;
--   GRANT SELECT, INSERT, UPDATE, DELETE ON public.new_documents
--     TO anon, authenticated, service_role;
--
--   NOTIFY pgrst, 'reload schema';
-- ---------------------------------------------------------------------------------
