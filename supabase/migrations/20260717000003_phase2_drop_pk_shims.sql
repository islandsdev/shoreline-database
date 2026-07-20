-- Phase 2 — STEP B: drop the PK compatibility mirror columns (see RENAME_PLAN.md Phase 2).
--
-- Completes the team_members.team_member_id -> id / addresses.address_id -> id rename by
-- removing the GENERATED-ALWAYS mirror columns added (additively) in 20260622190000, and
-- repointing the team_members trigger functions to the renamed PK `id`.
--
-- PRECONDITION — MET: the shoreline-nextjs call sites are migrated to `id` and deployed to
-- `main` + `staging` (PR #89, commit 71b33d1). Nothing in the app reads team_member_id /
-- address_id as the PK anymore (residual `team_member_id` strings are child-table FK columns,
-- which are NOT touched here).
--
-- ⚠️ BEST-EFFORT PROMOTION (2026-07-17): the live bodies of the trigger functions could not be
--    introspected from this environment (Docker/psql unavailable, staging under a separate org).
--    The 4 CREATE OR REPLACE bodies below are the vetted checked-in baseline with ONLY the
--    team_members lookup key changed team_member_id -> id; FK columns and NEW.<col> refs are
--    left intact. If a function was edited via the Supabase dashboard after that baseline, this
--    would revert that edit. RECOMMENDED pre-deploy check (run on the target DB first):
--      SELECT proname, pg_get_functiondef(oid) FROM pg_proc
--      WHERE pronamespace = 'public'::regnamespace AND prosrc ILIKE '%team_member_id%'
--      ORDER BY proname;
--    Confirm (a) these 4 bodies match live apart from the lookup-key change, and (b) no OTHER
--    function reads team_members.team_member_id as a lookup (FK-column uses are fine).
--
-- SAFE-BY-CONSTRUCTION CHOICES:
--   * accrue_cashback is DROPPED, not recreated. Its trigger (trigger_accrue_cashback on
--     payments) was dropped by 20260608132635_v2_cashback.sql and never re-created; accrual moved
--     to app-level, per-invoice logic (20260608140000 dropped cashback_accruals.payment_id and
--     added invoice_id). The stale March body would have re-introduced the dropped payment_id
--     column. DROP FUNCTION without CASCADE: if a trigger unexpectedly still depends on it, this
--     ABORTS the whole migration rather than silently removing live accrual.
--   * The mirror-column drops use no CASCADE: if a view/object still depends on them the migration
--     aborts (transactional rollback) instead of cascading. Run on staging first where possible.

BEGIN;

-- 1. Drop the dead accrue_cashback trigger function ------------------------------------------
-- (No CASCADE — aborts if some object still depends on it. See header.)
DROP FUNCTION IF EXISTS public.accrue_cashback();

-- 2. Repoint the live team_members trigger functions to `id` ---------------------------------
-- LEFT-hand `team_member_id` (the team_members lookup key) -> `id`. RIGHT-hand NEW.<col> stays
-- (those are FK columns on the trigger's own table). companies PK is already `id`; unchanged.

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

-- 3. Drop the deprecated mirror columns (no CASCADE — see header) ------------------------------
ALTER TABLE public.team_members DROP COLUMN team_member_id;
ALTER TABLE public.addresses    DROP COLUMN address_id;

-- 4. Refresh PostgREST's schema cache.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (forward-only DBs — run manually if needed):
--   ALTER TABLE public.team_members
--     ADD COLUMN team_member_id uuid GENERATED ALWAYS AS (id) STORED;
--   ALTER TABLE public.addresses
--     ADD COLUMN address_id uuid GENERATED ALWAYS AS (id) STORED;
--   -- (The function bodies keep working against `id`; no need to revert them. accrue_cashback
--   --  stays dropped — recreate from a git history revision only if the trigger is restored.)
--   NOTIFY pgrst, 'reload schema';
-- ---------------------------------------------------------------------------------
