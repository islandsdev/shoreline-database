-- Phase 2 — STEP B (cleanup). Run ONLY after 20260622190000 is live AND the shoreline-nextjs
-- call sites have been migrated to `id` and deployed (see RENAME_PLAN.md Phase 2).
--
-- 1. Rewrite every function that named the team_members PK to use `id` instead of the (about to
--    be dropped) team_member_id mirror column. CREATE OR REPLACE preserves trigger bindings.
-- 2. Drop the deprecated mirror columns.
--
-- PRE-FLIGHT: confirm nothing else still references the old name before running:
--   SELECT proname FROM pg_proc WHERE prosrc ILIKE '%team_member_id%';   -- expect only FK uses
--   -- and grep shoreline-nextjs for team_members-PK refs (should be zero).

BEGIN;

-- 1. Function rewrites -------------------------------------------------------------
-- LEFT-hand `team_member_id` (the team_members lookup key) -> `id`. RIGHT-hand NEW.<col> stays
-- (those are FK columns on the trigger's own table).

-- Trigger on payments: denormalises employee/company names.
CREATE OR REPLACE FUNCTION public.autofill_payments_fields() RETURNS trigger
    LANGUAGE plpgsql AS $$
DECLARE
  fetched_first_name TEXT;
  fetched_last_name TEXT;
  fetched_email TEXT;
  fetched_company_name TEXT;
BEGIN
  SELECT first_name, last_name, email INTO fetched_first_name, fetched_last_name, fetched_email
  FROM team_members
  WHERE id = NEW.employee_id;

  SELECT legal_name INTO fetched_company_name
  FROM companies
  WHERE id = NEW.company_id;

  NEW.employee_name = fetched_first_name || ' ' || fetched_last_name;
  NEW.employee_email = fetched_email;
  NEW.company_legal_name = fetched_company_name;

  RETURN NEW;
END;
$$;

-- Trigger on one_time_payments: same denormalisation.
CREATE OR REPLACE FUNCTION public.autofill_one_time_payment_fields() RETURNS trigger
    LANGUAGE plpgsql AS $$
DECLARE
  fetched_first_name TEXT;
  fetched_last_name TEXT;
  fetched_email TEXT;
  fetched_company_name TEXT;
BEGIN
  SELECT first_name, last_name, email INTO fetched_first_name, fetched_last_name, fetched_email
  FROM team_members
  WHERE id = NEW.employee_id;

  SELECT legal_name INTO fetched_company_name
  FROM companies
  WHERE id = NEW.company_id;

  NEW.employee_name = fetched_first_name || ' ' || fetched_last_name;
  NEW.employee_email = fetched_email;
  NEW.company_legal_name = fetched_company_name;

  RETURN NEW;
END;
$$;

-- Denormalises team_member_email onto the trigger's own table. NEW.team_member_id is that
-- table's FK column (unchanged); the team_members lookup key becomes `id`.
CREATE OR REPLACE FUNCTION public.autofill_team_member_email() RETURNS trigger
    LANGUAGE plpgsql AS $$
DECLARE
  fetched_email TEXT;
BEGIN
  SELECT email INTO fetched_email
  FROM team_members
  WHERE id = NEW.team_member_id;

  RAISE NOTICE 'Fetched team_member_email: %', fetched_email;

  NEW.team_member_email = fetched_email;
  RETURN NEW;
END;
$$;

-- Guards that the chosen employee belongs to the chosen company.
CREATE OR REPLACE FUNCTION public.enforce_employee_company_match() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM team_members
        WHERE team_members.id = NEW.employee_id
        AND team_members.company_id = NEW.company_id
    ) THEN
        RAISE EXCEPTION 'Selected employee_id does not belong to the given company_id';
    END IF;
    RETURN NEW;
END;
$$;

-- accrue_cashback — full body from the latest def (20260311170330); only `tm.team_member_id`
-- -> `tm.id`. The cashback_accruals insert column and NEW.team_member_id are FK refs (unchanged).
CREATE OR REPLACE FUNCTION public.accrue_cashback() RETURNS trigger
    LANGUAGE plpgsql AS $function$
  DECLARE
    v_company_id uuid;
    v_is_tech boolean;
    v_employment_type text;  -- fixed: was boolean, stores 'Employee'/'contractor'/etc.
    v_cashback_rate numeric;
    v_cashback_amount numeric;
    v_accrual_month int;
    v_accrual_year int;
    v_accrual_period date;
  BEGIN
    IF NEW.status = 'paid' AND (OLD.status IS NULL OR OLD.status <> 'paid') THEN

      SELECT tm.company_id, tm.is_tech_employee, tm.employment_type
      INTO v_company_id, v_is_tech, v_employment_type
      FROM team_members tm
      WHERE tm.id = NEW.team_member_id;

      -- fixed: 3-tier rate logic
      SELECT
        CASE
          WHEN v_is_tech AND v_employment_type = 'Employee'   THEN tech_employee_rate
          WHEN v_is_tech AND v_employment_type = 'Contractor' THEN tech_contractor_rate
          ELSE 0
        END
      INTO v_cashback_rate
      FROM cashback_config
      WHERE (company_id = v_company_id OR company_id IS NULL)
        AND is_active = true
        AND CURRENT_DATE BETWEEN effective_from AND COALESCE(effective_to, '2099-12-31')
      ORDER BY company_id ASC
      LIMIT 1;

      v_cashback_amount := NEW.gross_salary * v_cashback_rate;

      SELECT
        EXTRACT(MONTH FROM start_date)::int,
        EXTRACT(YEAR FROM start_date)::int,
        start_date
      INTO v_accrual_month, v_accrual_year, v_accrual_period
      FROM payroll_schedules
      WHERE id = NEW.payroll_schedule_id;

      INSERT INTO cashback_accruals (
        company_id,
        team_member_id,
        payment_id,
        payroll_schedule_id,
        employee_gross_salary,
        cashback_rate,
        cashback_amount,
        accrual_month,
        accrual_year,
        accrual_period,
        is_tech_employee,
        is_employee
      ) VALUES (
        v_company_id,
        NEW.team_member_id,
        NEW.id,
        NEW.payroll_schedule_id,
        NEW.gross_salary,
        v_cashback_rate,
        v_cashback_amount,
        v_accrual_month,
        v_accrual_year,
        v_accrual_period,
        v_is_tech,
        (v_employment_type = 'Employee')  -- true if employee, false if contractor/other
      );

    END IF;

    RETURN NEW;
  END;
$function$;

-- 2. Drop the deprecated mirror columns -------------------------------------------
ALTER TABLE public.team_members DROP COLUMN team_member_id;
ALTER TABLE public.addresses    DROP COLUMN address_id;

-- 3. Refresh PostgREST's schema cache.
NOTIFY pgrst, 'reload schema';

COMMIT;
