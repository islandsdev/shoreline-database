-- ---------------------------------------------------------------------------------
-- Give cashback_accruals.invoice_id an explicit ON DELETE SET NULL.
--
-- WHY: the column was added in 20260608140000 with a bare inline reference —
--
--   ALTER TABLE cashback_accruals
--     ADD COLUMN IF NOT EXISTS invoice_id uuid REFERENCES invoices(id);
--
-- With no ON DELETE clause Postgres defaults to NO ACTION, so deleting a
-- salary_invoices row fails outright while any accrual still points at it:
--
--   Key (id)=(…) is still referenced from table cashback_accruals
--
-- Every other child of that table declares its behaviour explicitly —
-- stripe_invoices, wise_invoices, cpp_contributions, eei_contributions,
-- rrsp_contributions and invoice_late_fees.original_invoice_id CASCADE;
-- invoice_adjustments and invoice_late_fees.fee_invoice_id SET NULL — so this
-- one was an oversight in that migration rather than a deliberate guard.
--
-- WHY SET NULL RATHER THAN CASCADE: an accrual is cashback owed to the client.
-- It is computed from the payroll period, not from the invoice document, and it
-- rolls up into cashback_payouts. Cascading would silently erase a liability
-- because an invoice got cleaned up. SET NULL keeps the amount, rate, period and
-- team member and drops only the provenance link. invoice_id is already nullable,
-- so no data change is required.
--
-- NOTE (accepted side effect): the unique index
-- cashback_accruals_invoice_member_period_key on
-- (invoice_id, team_member_id, payroll_schedule_id) exists to make the accrual
-- job idempotent on webhook retries. Postgres treats NULLs as distinct, so rows
-- orphaned by this rule are no longer covered by it. That is fine — orphaning
-- only happens on manual invoice deletion, never on the retry path the index
-- guards.
--
-- NOTE: deleting a salary_invoices row still CASCADE-deletes its
-- cpp_contributions and eei_contributions rows, and those are what
-- getAccumulatedCPP()/getAccumulatedEEI() sum for year-to-date totals. This
-- migration does not change that; it only stops the accrual FK from blocking.
--
-- No application code reads the delete rule, and generated types.ts does not
-- encode it, so this can be applied independently of any deploy.
-- ---------------------------------------------------------------------------------

BEGIN;

-- ---------------------------------------------------------------------------------
-- Safety gate: fail loudly if the constraint is not where we expect it, rather
-- than silently dropping nothing and leaving the delete still blocked.
-- confdeltype: a = NO ACTION, r = RESTRICT, c = CASCADE, n = SET NULL, d = SET DEFAULT
-- ---------------------------------------------------------------------------------
DO $$
DECLARE
  current_rule "char";
BEGIN
  SELECT confdeltype INTO current_rule
  FROM pg_constraint
  WHERE conname = 'cashback_accruals_invoice_id_fkey'
    AND conrelid = 'public.cashback_accruals'::regclass;

  IF current_rule IS NULL THEN
    RAISE EXCEPTION
      'cashback_accruals_invoice_id_fkey not found on public.cashback_accruals — confirm the constraint name before applying.';
  END IF;

  IF current_rule = 'n' THEN
    RAISE NOTICE
      'cashback_accruals_invoice_id_fkey is already ON DELETE SET NULL; this migration is a no-op.';
  ELSIF current_rule <> 'a' THEN
    RAISE NOTICE
      'cashback_accruals_invoice_id_fkey currently has delete rule "%", not the expected NO ACTION; replacing it with SET NULL.',
      current_rule;
  END IF;
END $$;

ALTER TABLE public.cashback_accruals
  DROP CONSTRAINT IF EXISTS cashback_accruals_invoice_id_fkey;

ALTER TABLE public.cashback_accruals
  ADD CONSTRAINT cashback_accruals_invoice_id_fkey
  FOREIGN KEY (invoice_id) REFERENCES public.salary_invoices(id)
  ON DELETE SET NULL;

COMMENT ON CONSTRAINT cashback_accruals_invoice_id_fkey ON public.cashback_accruals IS
  'SET NULL, not CASCADE: an accrual is cashback owed to the client and rolls up '
  'into cashback_payouts, so deleting the source invoice must orphan the accrual '
  'rather than erase the liability.';

-- Refresh PostgREST's schema cache so the changed relationship is picked up.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only).
-- Restores the implicit NO ACTION rule, which blocks salary_invoices deletes again.
-- Any invoice_id already nulled by a delete is NOT recoverable.
--
--   BEGIN;
--   ALTER TABLE public.cashback_accruals
--     DROP CONSTRAINT IF EXISTS cashback_accruals_invoice_id_fkey;
--   ALTER TABLE public.cashback_accruals
--     ADD CONSTRAINT cashback_accruals_invoice_id_fkey
--     FOREIGN KEY (invoice_id) REFERENCES public.salary_invoices(id);
--   NOTIFY pgrst, 'reload schema';
--   COMMIT;
-- ---------------------------------------------------------------------------------
