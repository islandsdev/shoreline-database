-- ---------------------------------------------------------------------------------
-- Fix create_contribution_correction(): every call failed with 42883
--
--   function jsonb_set(json, unknown, jsonb) does not exist
--
-- WHY. 20260806000001 finished the correction by writing the backlink with
--
--   UPDATE public.<table>
--      SET details = jsonb_set(details, '{correction,adjustment_id}', ...)
--
-- but eei_contributions.details / cpp_contributions.details are `json`, not
-- `jsonb` (added as json in 20260205161625_new_audit_tables.sql). Postgres will
-- apply a cast from jsonb to json when *assigning* to a column, which is why the
-- ledger INSERT above it was fine, but it will not cast a `json` argument to
-- `jsonb` when resolving a function call — so jsonb_set() never matched and the
-- statement failed at parse time.
--
-- Every path through the function ended at that UPDATE, so no correction has ever
-- committed: the whole RPC is one transaction, and the failure rolled back both
-- the contribution row and the invoice_adjustments row. Nothing to repair.
--
-- THE FIX. Generate both ids up front so `details` can be written complete on the
-- first insert. That drops the backlink UPDATE — and with it jsonb_set() and the
-- json/jsonb question — rather than casting around it. Both tables' id columns
-- default to gen_random_uuid(); supplying the value explicitly changes nothing
-- except that we know it before the insert.
--
-- jsonb_build_object() is kept uncast on purpose: assigning jsonb to a json
-- column works, and it would still work unchanged if these columns are ever
-- converted to jsonb.
--
-- Signature, semantics, SQLSTATEs and grants are unchanged — CREATE OR REPLACE
-- keeps the existing ACL; the REVOKE/GRANT below is re-asserted only so this file
-- states the intended posture on its own.
-- ---------------------------------------------------------------------------------

BEGIN;

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
  v_contribution_id  uuid := gen_random_uuid();
  v_adjustment_id    uuid := gen_random_uuid();
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
  --
  -- adjustment_id is in `details` from the start — the id is pre-generated above,
  -- so the ledger row points at the adjustment that justifies it without a second
  -- statement to patch the document.
  EXECUTE format(
    'INSERT INTO public.%I
       (id, team_member_id, company_id, payroll_schedule_id, amount_cad, details)
     VALUES ($1, $2, $3, $4, $5, $6)', v_table)
    USING v_contribution_id,
          p_team_member_id,
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
              'created_by_email',  p_created_by_email,
              'adjustment_id',     v_adjustment_id::text
            )
          );

  INSERT INTO public.invoice_adjustments (
    id, company_id, amount_cad, description, notes, status,
    kind, reason_code,
    team_member_id, contribution_type, payroll_schedule_id,
    amount_before_cad, amount_after_cad, contribution_row_id,
    created_by, created_by_email
  ) VALUES (
    v_adjustment_id, p_company_id, v_delta, p_description, p_notes, 'pending',
    'contribution_correction', p_reason_code,
    p_team_member_id, p_contribution_type, p_payroll_schedule_id,
    p_amount_before_cad, p_amount_after_cad, v_contribution_id,
    p_created_by, p_created_by_email
  );

  RETURN v_adjustment_id;
END;
$$;

COMMENT ON FUNCTION public.create_contribution_correction IS
  'Atomically writes an EEI/ECPP ledger delta and the invoice adjustment that credits or charges it. '
  'Re-verifies ownership, staleness and the annual maximum inside the transaction, under an advisory '
  'lock on (team_member, contribution_type).';

REVOKE ALL ON FUNCTION public.create_contribution_correction(
  uuid, uuid, text, uuid, numeric, numeric, text, text, text, text, numeric, uuid, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_contribution_correction(
  uuid, uuid, text, uuid, numeric, numeric, text, text, text, text, numeric, uuid, text
) TO service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
