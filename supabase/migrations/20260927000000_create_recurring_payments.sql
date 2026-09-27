-- ---------------------------------------------------------------------------------
-- Recurring Payments: a standing instruction to add the same amount to every
-- regular payroll for one Team Member (e.g. a benefits-replacement stipend).
--
-- MODEL
--   recurring_payments  — the instruction itself: amount, reason, first period,
--                         optional end date, and a lifecycle
--                         (pending_approval → active ⇄ paused → stopped, or
--                         pending_approval → rejected).
--   one_time_payments   — unchanged in meaning. Each regular payroll period the
--                         instruction applies to gets ONE ordinary row, linked
--                         back via recurring_payment_id. The invoice job, the
--                         QuickBooks entry queue, cashback, termination
--                         reconciliation and the payout webhooks therefore see a
--                         recurring stipend exactly as they see a one-time one.
--
-- WHAT THE DATABASE GUARANTEES
--   1. At most one row per (recurring payment, payroll period) — re-running the
--      sync, or the invoice job, can never bill a period twice.
--   2. An instruction cannot be active or paused without a tax treatment that
--      payroll confirmed. The client's REQUESTED treatment is a separate column
--      and never satisfies this on its own.
--   3. Once a one_time_payments row is on an invoice, its amount, period and
--      recurring link are frozen. Edits to an instruction only ever reach
--      periods that have not been billed. Deletes are deliberately NOT blocked:
--      the FKs to team_members and payroll_schedules cascade, and refusing those
--      for recurring rows only would be inconsistent with every other billed
--      one-time payment. The app never deletes an invoiced row.
--
-- SAFE TO APPLY AHEAD OF THE BACKEND DEPLOY: the new column is nullable and no
-- existing code writes to it. The freeze trigger only rejects changes the
-- backend already never makes (every existing one_time_payments update is
-- either `invoice_id IS NULL`-filtered or touches status/qb columns only).
--
-- After applying: regenerate shoreline-database/types.ts (never hand-edit it).
-- ---------------------------------------------------------------------------------

BEGIN;

-- ---------------------------------------------------------------------------------
-- 1. The instruction
-- ---------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.recurring_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  team_member_id uuid NOT NULL REFERENCES public.team_members(id) ON DELETE CASCADE,

  payment_type public.one_time_payment_type NOT NULL DEFAULT 'Stipend',
  -- Per regular pay period, not per month or per year.
  amount numeric(10,2) NOT NULL CHECK (amount > 0),
  -- Payroll runs in CAD only (see PAYROLL_CURRENCY in shoreline-nextjs). Stored
  -- rather than implied so the confirmation the client made is on record, and
  -- so widening this later is a constraint change, not a data backfill.
  currency text NOT NULL DEFAULT 'CAD' CHECK (currency = 'CAD'),
  -- The reason. Required: an ongoing payment with no stated purpose cannot be
  -- classified by payroll.
  description text NOT NULL CHECK (btrim(description) <> ''),
  memo text,

  -- The first regular pay period the payment applies to, and its start date
  -- snapshotted so eligibility can be computed without a join.
  start_payroll_schedule_id uuid NOT NULL REFERENCES public.payroll_schedules(id),
  start_date date NOT NULL,
  -- Optional. The last period included is the last one that STARTS on or before
  -- this date (same cut as termination: a period is either in or out, never
  -- prorated).
  end_date date,

  -- The pay frequency the amount was sized for (46.15 × 26 ≠ 46.15 × 24). If
  -- the Team Member's schedule later changes, the sync stops adding periods
  -- until payroll re-confirms, rather than silently changing the annual total.
  payroll_frequency public.payroll_schedule_type NOT NULL,

  status text NOT NULL DEFAULT 'pending_approval'
    CHECK (status IN ('pending_approval', 'active', 'paused', 'stopped', 'rejected')),

  -- What the client asked for. Informational only — see tax_treatment.
  requested_tax_treatment text
    CHECK (requested_tax_treatment IN ('taxable', 'non_taxable', 'unsure')),
  -- What payroll confirmed. The only treatment anything downstream may act on.
  tax_treatment text
    CHECK (tax_treatment IN ('taxable', 'non_taxable')),
  tax_treatment_notes text,

  approved_at timestamptz,
  approved_by uuid,
  approved_by_email text,
  rejected_at timestamptz,
  rejected_by_email text,
  rejection_reason text,
  paused_at timestamptz,
  stopped_at timestamptz,

  -- auth.users ids. Deliberately NOT FKs: these are payroll records that must
  -- outlive the account that made them.
  created_by uuid,
  created_by_email text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT recurring_payments_end_after_start
    CHECK (end_date IS NULL OR end_date >= start_date),
  -- Guarantee 2: nothing runs on the client's say-so alone. `stopped` is not
  -- listed: a client may withdraw a request that was never approved.
  CONSTRAINT recurring_payments_treatment_before_activation
    CHECK (status NOT IN ('active', 'paused')
           OR (tax_treatment IS NOT NULL AND approved_at IS NOT NULL))
);

COMMENT ON TABLE public.recurring_payments IS
  'Standing instruction to add a fixed amount to every regular payroll for one team member. Materialised one period at a time into one_time_payments (recurring_payment_id) by the backend sync.';
COMMENT ON COLUMN public.recurring_payments.amount IS
  'CAD per regular pay period of payroll_frequency.';
COMMENT ON COLUMN public.recurring_payments.requested_tax_treatment IS
  'The client''s request. Informational only — never used to decide taxation or deductions.';
COMMENT ON COLUMN public.recurring_payments.tax_treatment IS
  'Payroll-confirmed treatment, set at approval. Required before the instruction can be active.';
COMMENT ON COLUMN public.recurring_payments.end_date IS
  'Optional. Periods starting after this date are not included.';

CREATE INDEX IF NOT EXISTS recurring_payments_company_idx
  ON public.recurring_payments (company_id);
CREATE INDEX IF NOT EXISTS recurring_payments_team_member_idx
  ON public.recurring_payments (team_member_id);
-- The daily sync and the admin approval queue both read by status.
CREATE INDEX IF NOT EXISTS recurring_payments_status_idx
  ON public.recurring_payments (status);

-- Service-role only, like invoice_adjustments: every read and write goes
-- through the Next.js API. Enabling RLS with no policies denies anon and
-- authenticated; supabaseAdmin bypasses RLS.
ALTER TABLE public.recurring_payments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.recurring_payments FROM anon, authenticated;

-- ---------------------------------------------------------------------------------
-- 2. Link each materialised period back to its instruction
-- ---------------------------------------------------------------------------------
ALTER TABLE public.one_time_payments
  ADD COLUMN IF NOT EXISTS recurring_payment_id uuid
    -- Default NO ACTION, not RESTRICT: a direct delete of an instruction that
    -- has generated rows is still refused, but the check runs at the end of the
    -- statement, so a cascade from team_members/companies (which removes both
    -- sides) completes. RESTRICT checks mid-cascade and can fail on row order.
    REFERENCES public.recurring_payments(id);

COMMENT ON COLUMN public.one_time_payments.recurring_payment_id IS
  'Set when this row was generated from a recurring_payments instruction for its payroll period. Null for one-time payments.';

-- Guarantee 1. Covers cancelled rows too: a period that was cancelled is
-- restored, never duplicated.
CREATE UNIQUE INDEX IF NOT EXISTS one_time_payments_recurring_period_uidx
  ON public.one_time_payments (recurring_payment_id, payroll_schedule_id)
  WHERE recurring_payment_id IS NOT NULL;

-- A recurring row always belongs to a period; an unattached one could never be
-- billed or de-duplicated.
ALTER TABLE public.one_time_payments
  ADD CONSTRAINT one_time_payments_recurring_has_period
    CHECK (recurring_payment_id IS NULL OR payroll_schedule_id IS NOT NULL);

-- ---------------------------------------------------------------------------------
-- 3. Guarantee 3: billed payments are history
--
-- Applies to every one_time_payments row, not only recurring ones — a one-time
-- bonus that has been invoiced is just as final. status and the QuickBooks
-- columns stay writable: payout webhooks and the ops queue move them after
-- billing, which is their job.
-- ---------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.one_time_payments_freeze_invoiced()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF OLD.invoice_id IS NOT NULL THEN
    IF NEW.amount IS DISTINCT FROM OLD.amount THEN
      RAISE EXCEPTION
        'one_time_payments %: amount cannot change once the payment is invoiced (% → %)',
        OLD.id, OLD.amount, NEW.amount
        USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.payroll_schedule_id IS DISTINCT FROM OLD.payroll_schedule_id THEN
      RAISE EXCEPTION
        'one_time_payments %: payroll period cannot change once the payment is invoiced',
        OLD.id
        USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.recurring_payment_id IS DISTINCT FROM OLD.recurring_payment_id THEN
      RAISE EXCEPTION
        'one_time_payments %: recurring link cannot change once the payment is invoiced',
        OLD.id
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS one_time_payments_freeze_invoiced_trg ON public.one_time_payments;
CREATE TRIGGER one_time_payments_freeze_invoiced_trg
  BEFORE UPDATE ON public.one_time_payments
  FOR EACH ROW
  EXECUTE FUNCTION public.one_time_payments_freeze_invoiced();

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only).
-- Materialised rows keep existing as plain one-time payments once the link is
-- dropped, so nothing already billed is lost.
--
--   BEGIN;
--   DROP TRIGGER IF EXISTS one_time_payments_freeze_invoiced_trg ON public.one_time_payments;
--   DROP FUNCTION IF EXISTS public.one_time_payments_freeze_invoiced();
--   ALTER TABLE public.one_time_payments
--     DROP CONSTRAINT IF EXISTS one_time_payments_recurring_has_period;
--   DROP INDEX IF EXISTS public.one_time_payments_recurring_period_uidx;
--   ALTER TABLE public.one_time_payments DROP COLUMN IF EXISTS recurring_payment_id;
--   DROP TABLE IF EXISTS public.recurring_payments;
--   NOTIFY pgrst, 'reload schema';
--   COMMIT;
-- ---------------------------------------------------------------------------------
