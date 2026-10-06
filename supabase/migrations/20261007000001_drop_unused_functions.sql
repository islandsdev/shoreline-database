-- ---------------------------------------------------------------------------------
-- Drop 13 public functions that nothing uses. 20261007000000 already pinned their
-- search_path and revoked EXECUTE; this removes them outright.
--
-- Evidence (staging, pg_stat_statements since 2025-12-22, plus a search of all four
-- repos' code and git history):
--   - No app code has ever called them; they only appeared in generated types.
--   - No other function body references them, and no pg_cron job calls them.
--   - The only real call on record is a single manual get_cashback_rate() test.
--
-- Unattached trigger functions (no trigger uses them, so they could never run):
--   autofill_company_name, autofill_payments_fields, autofill_one_time_payment_fields,
--   autofill_team_member_email, enforce_employee_company_match,
--   set_current_timestamp_updated_at
-- Callable functions with no callers:
--   approve_team_member  — SECURITY DEFINER; anon could approve any Team Member
--   has_role             — reads public.user_roles, which no longer exists
--   "generate-stripe-invoices" — hard-codes production's daily-invoice-job URL
--   get_cashback_rate, get_company_cashback_balance, create_annual_cashback_payout,
--   update_cashback_rates — cashback helpers; accrue_cashback computes its own rate
--
-- No CASCADE on purpose: if a trigger, policy or view still depends on one of these
-- in some environment, the DROP fails and the whole migration rolls back instead of
-- silently taking the dependent object with it. Functions missing from an
-- environment are skipped.
-- ---------------------------------------------------------------------------------

BEGIN;

DO $$
DECLARE
  fn record;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace
      AND p.proname IN (
        'autofill_company_name', 'autofill_payments_fields',
        'autofill_one_time_payment_fields', 'autofill_team_member_email',
        'enforce_employee_company_match', 'set_current_timestamp_updated_at',
        'approve_team_member', 'has_role', 'generate-stripe-invoices',
        'get_cashback_rate', 'get_company_cashback_balance',
        'create_annual_cashback_payout', 'update_cashback_rates'
      )
  LOOP
    EXECUTE format('DROP FUNCTION %s', fn.sig);
  END LOOP;
END $$;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK: recreate a function from its original migration
-- (20251227005554_remote_schema.sql, or 20260103105241_add_cashback_schema.sql for
-- the cashback helpers), then apply the search_path / EXECUTE hardening from
-- 20261007000000. Note the remote_schema version of generate-stripe-invoices targets
-- production's edge function.
-- ---------------------------------------------------------------------------------
