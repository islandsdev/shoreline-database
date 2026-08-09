-- ---------------------------------------------------------------------------------
-- invoice_adjustments: contribution corrections and structured reasons.
--
-- WHY: the lifecycle migration (20260806000000) made an adjustment record what we
-- charged. This one makes it record *why*, and closes a hole that costs real money.
--
-- THE HOLE. When we over-charge a client for an employee's EEI or ECPP — a
-- miscalculation, a wrong payroll schedule, a salary corrected after the fact —
-- crediting the invoice is only half the repair. `eei_contributions` /
-- `cpp_contributions` still hold the inflated amount, and those rows are what
-- getAccumulatedEEI()/getAccumulatedCPP() sum to decide when an employee hits the
-- annual maximum ($1,572.70 EEI / $4,230.45 ECPP). Leave them alone and the
-- employee reads as closer to the cap than they are, so a later period is capped
-- early and we under-bill — silently, months later, in a different invoice.
--
-- THE FIX. A correction is one adjustment carrying:
--
--     amount_before_cad   what was actually charged for that employee+type+period
--     amount_after_cad    what it should have been
--     amount_cad          = amount_after_cad - amount_before_cad   (CHECKed)
--
-- Over-charge → negative → a credit on the next invoice. Under-charge → positive
-- → a charge. The money and the ledger cannot disagree because they are the same
-- subtraction, and the CHECK is what makes that structural rather than a
-- convention somebody has to remember.
--
-- The matching delta is written into eei_contributions / cpp_contributions
-- immediately, carrying the ORIGINAL period's payroll_schedule_id. That choice is
-- load-bearing in two ways:
--
--   1. Every existing consumer already sums those tables — the invoice job's
--      capping, the admin contributions pages, and the client-facing
--      /api/contributions/[team_member_id] history. They are all correct for free
--      and none can drift out of step with a parallel corrections table.
--   2. getAccumulated*() scopes by schedules whose end_date falls in the year, so
--      correcting December in January lands in December's year, where it belongs.
--
-- Written immediately (not at billing time) because the invoice job reads
-- accumulated totals BEFORE groupByCompany runs: defer the ledger write and the
-- very run that issues the credit would still cap off the stale balance.
--
-- Because that is two inserts and supabase-js has no transactions, creation goes
-- through create_contribution_correction() below. A compensating delete could
-- itself fail and leave an orphaned row quietly depressing an employee's balance;
-- for a ledger write against an annual statutory maximum that is not good enough.
--
-- After applying: regenerate shoreline-database/types.ts (never hand-edit it).
-- ---------------------------------------------------------------------------------

BEGIN;

-- ---------------------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------------------
ALTER TABLE public.invoice_adjustments
  ADD COLUMN IF NOT EXISTS kind text NOT NULL DEFAULT 'manual',
  -- Structured so "how much did we credit back for EI miscalculations this year"
  -- is a GROUP BY rather than a text search. Human labels live in application
  -- code (lib/invoice-adjustments/reasons.ts) so wording changes need no migration.
  ADD COLUMN IF NOT EXISTS reason_code text NOT NULL DEFAULT 'other',
  -- Correction targets. Null for a plain charge or credit.
  -- No FK CASCADE on team_member_id: an adjustment is a financial record and has
  -- to outlive the employee row it corrected.
  ADD COLUMN IF NOT EXISTS team_member_id uuid,
  ADD COLUMN IF NOT EXISTS contribution_type text,
  -- The period being corrected, NOT the period it bills on. This is what puts the
  -- ledger delta in the right calendar year.
  ADD COLUMN IF NOT EXISTS payroll_schedule_id uuid,
  ADD COLUMN IF NOT EXISTS amount_before_cad numeric,
  ADD COLUMN IF NOT EXISTS amount_after_cad numeric,
  -- The eei_contributions / cpp_contributions row this correction wrote. Not an
  -- FK because the target table depends on contribution_type. Nulled on void,
  -- when the row is removed.
  ADD COLUMN IF NOT EXISTS contribution_row_id uuid;

COMMENT ON COLUMN public.invoice_adjustments.kind IS
  'manual → a hand-entered charge or credit; contribution_correction → also rewrites an employee''s EEI/ECPP ledger.';
COMMENT ON COLUMN public.invoice_adjustments.reason_code IS
  'Structured reason. Human labels live in application code; the label is also snapshotted into the contribution row''s details so the client portal can render it.';
COMMENT ON COLUMN public.invoice_adjustments.payroll_schedule_id IS
  'The period being corrected, not the period this bills on — this is what lands the ledger delta in the correct calendar year.';
COMMENT ON COLUMN public.invoice_adjustments.amount_before_cad IS
  'EEI/ECPP actually charged for this employee+type+period at correction time. With amount_after_cad it derives amount_cad.';
COMMENT ON COLUMN public.invoice_adjustments.contribution_row_id IS
  'The eei_contributions / cpp_contributions row written by this correction. Deleted and nulled when the adjustment is voided.';

ALTER TABLE public.invoice_adjustments
  ADD CONSTRAINT invoice_adjustments_kind_check
    CHECK (kind IN ('manual', 'contribution_correction')) NOT VALID;
ALTER TABLE public.invoice_adjustments
  VALIDATE CONSTRAINT invoice_adjustments_kind_check;

ALTER TABLE public.invoice_adjustments
  ADD CONSTRAINT invoice_adjustments_reason_code_check
    -- Direction-neutral on purpose: the sign of amount_cad already says whether
    -- we over- or under-charged, so one code covers both and the customer-facing
    -- label is derived from the sign (see lib/invoice-adjustments/reasons.ts).
    CHECK (reason_code IN (
      'ei_miscalculation',
      'cpp_miscalculation',
      'rrsp_miscalculation',
      'salary_correction',
      'billing_error',
      'service_credit',
      'goodwill',
      'other'
    )) NOT VALID;
ALTER TABLE public.invoice_adjustments
  VALIDATE CONSTRAINT invoice_adjustments_reason_code_check;

ALTER TABLE public.invoice_adjustments
  ADD CONSTRAINT invoice_adjustments_contribution_type_check
    CHECK (contribution_type IS NULL OR contribution_type IN ('eei', 'ecpp')) NOT VALID;
ALTER TABLE public.invoice_adjustments
  VALIDATE CONSTRAINT invoice_adjustments_contribution_type_check;

-- ---------------------------------------------------------------------------------
-- 2. The shape invariant
--
-- A correction is only a correction if it carries its whole derivation, and the
-- billed amount must BE the delta — not a number that happens to agree with it
-- today. This is the constraint that makes the money and the ledger impossible to
-- separate.
--
-- amount_after_cad >= 0: you cannot un-charge more EEI than exists.
-- ---------------------------------------------------------------------------------
ALTER TABLE public.invoice_adjustments
  ADD CONSTRAINT invoice_adjustments_correction_shape
    CHECK (
      CASE kind
        WHEN 'contribution_correction' THEN
          team_member_id IS NOT NULL
          AND contribution_type IS NOT NULL
          AND payroll_schedule_id IS NOT NULL
          AND amount_before_cad IS NOT NULL
          AND amount_after_cad IS NOT NULL
          AND amount_before_cad >= 0
          AND amount_after_cad >= 0
          AND amount_cad = amount_after_cad - amount_before_cad
        ELSE
          -- A plain charge/credit carries none of the correction machinery, so a
          -- half-populated row can never masquerade as one.
          contribution_type IS NULL
          AND amount_before_cad IS NULL
          AND amount_after_cad IS NULL
          AND contribution_row_id IS NULL
      END
    ) NOT VALID;
ALTER TABLE public.invoice_adjustments
  VALIDATE CONSTRAINT invoice_adjustments_correction_shape;

ALTER TABLE public.invoice_adjustments
  ADD CONSTRAINT invoice_adjustments_team_member_id_fkey
  FOREIGN KEY (team_member_id) REFERENCES public.team_members(id) ON DELETE SET NULL;

ALTER TABLE public.invoice_adjustments
  ADD CONSTRAINT invoice_adjustments_payroll_schedule_id_fkey
  FOREIGN KEY (payroll_schedule_id) REFERENCES public.payroll_schedules(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS invoice_adjustments_correction_target_idx
  ON public.invoice_adjustments (team_member_id, contribution_type, payroll_schedule_id)
  WHERE kind = 'contribution_correction';

CREATE INDEX IF NOT EXISTS invoice_adjustments_reason_code_idx
  ON public.invoice_adjustments (reason_code);

-- ---------------------------------------------------------------------------------
-- 3. Freeze the derivation on billed rows too
--
-- The lifecycle migration froze amount_cad and description once billed. The
-- correction columns are part of the same story: once the customer has been
-- credited, what we said we were correcting is a matter of record.
-- ---------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.invoice_adjustments_freeze_billed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  IF OLD.status = 'billed' THEN
    IF NEW.amount_cad IS DISTINCT FROM OLD.amount_cad THEN
      RAISE EXCEPTION
        'invoice_adjustments %: amount_cad cannot change once the adjustment is billed (% → %)',
        OLD.id, OLD.amount_cad, NEW.amount_cad
        USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.description IS DISTINCT FROM OLD.description THEN
      RAISE EXCEPTION
        'invoice_adjustments %: description cannot change once the adjustment is billed',
        OLD.id
        USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.status <> 'billed' THEN
      RAISE EXCEPTION
        'invoice_adjustments %: a billed adjustment cannot be moved back to "%"',
        OLD.id, NEW.status
        USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.kind IS DISTINCT FROM OLD.kind
       OR NEW.team_member_id IS DISTINCT FROM OLD.team_member_id
       OR NEW.contribution_type IS DISTINCT FROM OLD.contribution_type
       OR NEW.payroll_schedule_id IS DISTINCT FROM OLD.payroll_schedule_id
       OR NEW.amount_before_cad IS DISTINCT FROM OLD.amount_before_cad
       OR NEW.amount_after_cad IS DISTINCT FROM OLD.amount_after_cad THEN
      RAISE EXCEPTION
        'invoice_adjustments %: the correction derivation cannot change once the adjustment is billed',
        OLD.id
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------------
-- 4. create_contribution_correction()
--
-- Writes the ledger delta and the adjustment in one transaction, re-verifying
-- every precondition inside it. The API validates first for readable errors; this
-- function is what makes those checks true rather than merely likely.
--
-- SQLSTATEs (mapped to HTTP status in the API — see lib/invoice-adjustments/errors.ts):
--   SLA01  employee or payroll schedule not found
--   SLA02  employee does not belong to the given company
--   SLA03  amount_before_cad no longer matches the ledger (someone corrected it first)
--   SLA04  the resulting year-to-date total would be negative or over the annual max
--   SLA05  the correction is a no-op (before = after)
-- ---------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_contribution_correction(
  p_company_id uuid,
  p_team_member_id uuid,
  p_contribution_type text,
  p_payroll_schedule_id uuid,
  p_amount_before_cad numeric,
  p_amount_after_cad numeric,
  p_description text,
  p_reason_code text,
  p_reason_label text,
  p_notes text,
  -- Passed in rather than duplicated here so lib/contribution-constants.ts stays
  -- the single home for the statutory maximums.
  p_annual_max numeric,
  p_created_by uuid,
  p_created_by_email text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_table            text;
  v_member_company   uuid;
  v_year             int;
  v_period_total     numeric;
  v_year_total       numeric;
  v_delta            numeric;
  v_new_year_total   numeric;
  v_contribution_id  uuid;
  v_adjustment_id    uuid;
BEGIN
  IF p_contribution_type = 'eei' THEN
    v_table := 'eei_contributions';
  ELSIF p_contribution_type = 'ecpp' THEN
    v_table := 'cpp_contributions';
  ELSE
    RAISE EXCEPTION 'contribution_type must be eei or ecpp, got %', p_contribution_type
      USING ERRCODE = 'SLA01';
  END IF;

  v_delta := p_amount_after_cad - p_amount_before_cad;
  IF v_delta = 0 THEN
    RAISE EXCEPTION 'correction is a no-op: amount_before_cad equals amount_after_cad (%)', p_amount_before_cad
      USING ERRCODE = 'SLA05';
  END IF;

  -- Serialize concurrent corrections of the same employee+type. Without this two
  -- admins can both read the same amount_before, both pass the staleness check,
  -- and both write a delta — double-correcting the balance. The lock is held to
  -- the end of the transaction.
  PERFORM pg_advisory_xact_lock(
    hashtext(p_team_member_id::text || ':' || p_contribution_type)
  );

  SELECT company_id INTO v_member_company
  FROM team_members WHERE id = p_team_member_id;

  IF v_member_company IS NULL THEN
    RAISE EXCEPTION 'team member % not found', p_team_member_id USING ERRCODE = 'SLA01';
  END IF;
  IF v_member_company <> p_company_id THEN
    RAISE EXCEPTION 'team member % does not belong to company %', p_team_member_id, p_company_id
      USING ERRCODE = 'SLA02';
  END IF;

  -- The correction is dated by the period it corrects, and getAccumulated*()
  -- buckets by the schedule's end_date year, so that is the year to guard.
  SELECT EXTRACT(YEAR FROM end_date)::int INTO v_year
  FROM payroll_schedules WHERE id = p_payroll_schedule_id;

  IF v_year IS NULL THEN
    RAISE EXCEPTION 'payroll schedule % not found', p_payroll_schedule_id USING ERRCODE = 'SLA01';
  END IF;

  -- What this employee+type+period currently sums to, including any earlier
  -- correction. Correcting against the live total (not one original row) is what
  -- makes a second correction of the same period behave.
  EXECUTE format(
    'SELECT COALESCE(SUM(amount_cad), 0) FROM public.%I
      WHERE team_member_id = $1 AND payroll_schedule_id = $2', v_table)
    INTO v_period_total
    USING p_team_member_id, p_payroll_schedule_id;

  IF v_period_total <> p_amount_before_cad THEN
    RAISE EXCEPTION
      'ledger moved: % currently totals % for this period, not the % this correction was derived from',
      p_contribution_type, v_period_total, p_amount_before_cad
      USING ERRCODE = 'SLA03';
  END IF;

  EXECUTE format(
    'SELECT COALESCE(SUM(c.amount_cad), 0) FROM public.%I c
       JOIN public.payroll_schedules ps ON ps.id = c.payroll_schedule_id
      WHERE c.team_member_id = $1
        AND ps.end_date >= $2 AND ps.end_date < $3', v_table)
    INTO v_year_total
    USING p_team_member_id,
          make_date(v_year, 1, 1),
          make_date(v_year + 1, 1, 1);

  v_new_year_total := v_year_total + v_delta;

  IF v_new_year_total < 0 THEN
    RAISE EXCEPTION
      'correction would take %''s % year-to-date total for % to % — it cannot go below zero',
      p_team_member_id, p_contribution_type, v_year, v_new_year_total
      USING ERRCODE = 'SLA04';
  END IF;

  IF p_annual_max IS NOT NULL AND v_new_year_total > p_annual_max THEN
    RAISE EXCEPTION
      'correction would take %''s % year-to-date total for % to %, over the annual maximum of %',
      p_team_member_id, p_contribution_type, v_year, v_new_year_total, p_annual_max
      USING ERRCODE = 'SLA04';
  END IF;

  -- amount_usd / rate / invoice_id stay null until the credit actually bills;
  -- the invoice job stamps them then. amount_cad is what drives the balance and
  -- it is correct from this moment.
  EXECUTE format(
    'INSERT INTO public.%I
       (team_member_id, company_id, payroll_schedule_id, amount_cad, details)
     VALUES ($1, $2, $3, $4, $5) RETURNING id', v_table)
    INTO v_contribution_id
    USING p_team_member_id,
          p_company_id,
          p_payroll_schedule_id,
          v_delta,
          jsonb_build_object(
            'correction', jsonb_build_object(
              'reason_code',  p_reason_code,
              -- Snapshotted so the client portal can label the row without
              -- knowing our reason taxonomy.
              'reason_label', p_reason_label,
              'amount_before_cad', p_amount_before_cad,
              'amount_after_cad',  p_amount_after_cad,
              'delta_cad',         v_delta,
              'created_by_email',  p_created_by_email
            )
          );

  INSERT INTO public.invoice_adjustments (
    company_id, amount_cad, description, notes, status,
    kind, reason_code,
    team_member_id, contribution_type, payroll_schedule_id,
    amount_before_cad, amount_after_cad, contribution_row_id,
    created_by, created_by_email
  ) VALUES (
    p_company_id, v_delta, p_description, p_notes, 'pending',
    'contribution_correction', p_reason_code,
    p_team_member_id, p_contribution_type, p_payroll_schedule_id,
    p_amount_before_cad, p_amount_after_cad, v_contribution_id,
    p_created_by, p_created_by_email
  ) RETURNING id INTO v_adjustment_id;

  -- Backlink, so the ledger row points at the adjustment that justifies it and
  -- the client portal can show which credit it belongs to.
  EXECUTE format(
    'UPDATE public.%I
        SET details = jsonb_set(details, ''{correction,adjustment_id}'', to_jsonb($1::text))
      WHERE id = $2', v_table)
    USING v_adjustment_id, v_contribution_id;

  RETURN v_adjustment_id;
END;
$$;

COMMENT ON FUNCTION public.create_contribution_correction IS
  'Atomically writes an EEI/ECPP ledger delta and the invoice adjustment that credits or charges it. '
  'Re-verifies ownership, staleness and the annual maximum inside the transaction, under an advisory '
  'lock on (team_member, contribution_type).';

-- ---------------------------------------------------------------------------------
-- 5. void_invoice_adjustment()
--
-- Voiding a correction has to remove the ledger delta as well, or the employee's
-- balance keeps a reduction the customer was never credited for. Same transaction,
-- same reason.
--
-- The ledger row is deleted rather than reversed with an opposite row: it never
-- billed, and the audit trail is the invoice_adjustments row, which survives with
-- status='void' and its full derivation intact. A ±pair in the client-facing
-- contributions history would be noise standing in for a record we already keep.
--
-- SQLSTATEs (deliberately a different range from create_contribution_correction's,
-- so one code never means two things):
--   SLA11  adjustment not found
--   SLA12  adjustment is not pending (already billed or already void)
-- ---------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.void_invoice_adjustment(p_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_status            text;
  v_contribution_type text;
  v_contribution_id   uuid;
  v_table             text;
BEGIN
  SELECT status, contribution_type, contribution_row_id
    INTO v_status, v_contribution_type, v_contribution_id
  FROM invoice_adjustments WHERE id = p_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'invoice adjustment % not found', p_id USING ERRCODE = 'SLA11';
  END IF;

  IF v_status <> 'pending' THEN
    RAISE EXCEPTION 'invoice adjustment % is %, not pending', p_id, v_status
      USING ERRCODE = 'SLA12';
  END IF;

  IF v_contribution_id IS NOT NULL AND v_contribution_type IS NOT NULL THEN
    v_table := CASE v_contribution_type
                 WHEN 'eei' THEN 'eei_contributions'
                 WHEN 'ecpp' THEN 'cpp_contributions'
               END;
    IF v_table IS NULL THEN
      RAISE EXCEPTION 'unknown contribution_type % on adjustment %', v_contribution_type, p_id
        USING ERRCODE = 'SLA11';
    END IF;
    EXECUTE format('DELETE FROM public.%I WHERE id = $1', v_table) USING v_contribution_id;
  END IF;

  UPDATE invoice_adjustments
     SET status = 'void',
         contribution_row_id = NULL
   WHERE id = p_id;

  RETURN p_id;
END;
$$;

COMMENT ON FUNCTION public.void_invoice_adjustment IS
  'Atomically voids a pending adjustment and removes the EEI/ECPP ledger delta it wrote, if any. '
  'Used for every adjustment kind so there is one void path.';

-- ---------------------------------------------------------------------------------
-- 6. Both functions are service-role only
--
-- They bypass the API's validation layer by design, so the browser must never be
-- able to reach them. Matches the RLS posture set in 20260806000000.
-- ---------------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.create_contribution_correction(
  uuid, uuid, text, uuid, numeric, numeric, text, text, text, text, numeric, uuid, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_contribution_correction(
  uuid, uuid, text, uuid, numeric, numeric, text, text, text, text, numeric, uuid, text
) TO service_role;

REVOKE ALL ON FUNCTION public.void_invoice_adjustment(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.void_invoice_adjustment(uuid) TO service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only).
-- Ledger rows already written by corrections are NOT removed by this; find them
-- with `details -> 'correction' IS NOT NULL` on eei_contributions /
-- cpp_contributions and decide deliberately, because deleting them changes
-- employees' year-to-date totals.
--
--   BEGIN;
--   DROP FUNCTION IF EXISTS public.void_invoice_adjustment(uuid);
--   DROP FUNCTION IF EXISTS public.create_contribution_correction(
--     uuid, uuid, text, uuid, numeric, numeric, text, text, text, text, numeric, uuid, text);
--   ALTER TABLE public.invoice_adjustments
--     DROP CONSTRAINT IF EXISTS invoice_adjustments_payroll_schedule_id_fkey,
--     DROP CONSTRAINT IF EXISTS invoice_adjustments_team_member_id_fkey,
--     DROP CONSTRAINT IF EXISTS invoice_adjustments_correction_shape,
--     DROP CONSTRAINT IF EXISTS invoice_adjustments_contribution_type_check,
--     DROP CONSTRAINT IF EXISTS invoice_adjustments_reason_code_check,
--     DROP CONSTRAINT IF EXISTS invoice_adjustments_kind_check,
--     DROP COLUMN IF EXISTS contribution_row_id,
--     DROP COLUMN IF EXISTS amount_after_cad,
--     DROP COLUMN IF EXISTS amount_before_cad,
--     DROP COLUMN IF EXISTS payroll_schedule_id,
--     DROP COLUMN IF EXISTS contribution_type,
--     DROP COLUMN IF EXISTS team_member_id,
--     DROP COLUMN IF EXISTS reason_code,
--     DROP COLUMN IF EXISTS kind;
--   NOTIFY pgrst, 'reload schema';
--   COMMIT;
-- ---------------------------------------------------------------------------------
