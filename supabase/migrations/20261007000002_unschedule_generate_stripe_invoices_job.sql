-- ---------------------------------------------------------------------------------
-- Remove the generate_stripe_invoices_job pg_cron job (production only).
--
-- It ran `SELECT "generate-stripe-invoices"()` nightly at 00:00 UTC, which
-- net.http_post'ed the legacy daily-invoice-job edge function. That edge function
-- is no longer deployed (every call 404'd), and the job now lives in Next.js as the
-- Vercel cron /api/cron/daily-invoice-job on the same schedule. The function itself
-- was dropped in 20261007000001; without this, the job would fail every night.
--
-- Staging has no such job (and may not have pg_cron), so this is a no-op there.
-- ---------------------------------------------------------------------------------

DO $$
BEGIN
  IF to_regclass('cron.job') IS NULL THEN
    RAISE NOTICE 'pg_cron not installed; skipping';
    RETURN;
  END IF;

  EXECUTE $q$
    SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'generate_stripe_invoices_job'
  $q$;
END $$;

-- ---------------------------------------------------------------------------------
-- ROLLBACK: not needed — the job only called a now-dropped function that posted to
-- a now-deleted edge function. The real job is the Vercel cron.
-- ---------------------------------------------------------------------------------
