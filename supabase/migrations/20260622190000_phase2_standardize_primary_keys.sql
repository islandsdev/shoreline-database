-- Phase 2 of the DB naming cleanup (see RENAME_PLAN.md) — STEP A (additive, fully backward-compatible).
--
-- Standardize primary keys to `id` (convention §1 — PK is always `id`, never <table>_id):
--   public.team_members.team_member_id -> id
--   public.addresses.address_id        -> id
--
-- WHY A SHIM, AND WHY A GENERATED COLUMN (not a view like Phase 1):
--   Phase 1 renamed whole TABLES, so a compat VIEW could sit at the old table name. Here the
--   table KEEPS its name, so a view can't share it. Instead we rename the PK and re-add the old
--   name as a GENERATED-ALWAYS read-only mirror column. PostgREST then still serves the old
--   column name, so all ~100 existing references in shoreline-nextjs (the PK reads/filters AND
--   the cascading `.employee.team_member_id` property accesses) keep working with ZERO code
--   changes. We migrate the call sites to `id` at our own pace, then drop the shim in step B
--   (20260622190001). This preserves the same zero-runtime-risk property Phase 1 had.
--
-- WHY THIS IS SAFE WITH A GENERATED COLUMN (the usual gotcha doesn't apply):
--   A STORED generated column reads as NULL inside a BEFORE trigger on its OWN table. But there
--   is NO BEFORE trigger on team_members/addresses that reads NEW.<this column> — the autofill
--   triggers (autofill_payments_fields, autofill_one_time_payment_fields, autofill_team_member_
--   email, enforce_employee_company_match) and accrue_cashback all fire on OTHER tables and only
--   SELECT FROM team_members, where the mirror column resolves normally. They are left untouched
--   here and rewritten to use `id` in step B once the shim is removed.
--
-- WHAT IS *NOT* RENAMED: the FK COLUMNS named team_member_id / address_id / shipping_address_id
--   on child tables (payments, one_time_payments, cpp/eei/rrsp_contributions, rrsp_plans,
--   cashback_accruals, team_member_leaves, topups, team_members.address_id, ...). They are
--   correctly named (<referenced>_id); Postgres repoints their FK CONSTRAINTS to the renamed PK
--   automatically.
--
-- BONUS — fixes a latent bug for free: approve_team_member() already does `WHERE id = member_id`
--   but team_members had no `id` column, so the RPC errored on every call. After the rename below
--   the column exists and the function is correct. No recreate needed.
--
-- PK constraint names (team_members_pkey / addresses_pkey) already match the table name, so no
-- constraint rename is required.

BEGIN;

-- 1. Rename the PK columns (metadata-only) ----------------------------------------
ALTER TABLE public.team_members RENAME COLUMN team_member_id TO id;
ALTER TABLE public.addresses    RENAME COLUMN address_id     TO id;

-- 2. DEPRECATED backward-compat mirror columns ------------------------------------
-- Read-only generated mirrors of the new PK, exposed under the OLD column name so existing
-- PostgREST queries keep working. Dropped in 20260622190001 once call sites are migrated.
-- NOTE: ADD COLUMN ... GENERATED ALWAYS AS ... STORED rewrites the table once; both tables are
-- small (per-company employees / addresses) so this is cheap. The mirror is unindexed —
-- pre-codemod `.eq("team_member_id", ...)` does a seq scan on a small table (acceptable);
-- post-codemod every lookup uses the indexed PK `id`.
ALTER TABLE public.team_members
  ADD COLUMN team_member_id uuid GENERATED ALWAYS AS (id) STORED;
ALTER TABLE public.addresses
  ADD COLUMN address_id uuid GENERATED ALWAYS AS (id) STORED;

COMMENT ON COLUMN public.team_members.team_member_id IS
  'DEPRECATED compatibility mirror of team_members.id (renamed from team_member_id in Phase 2). '
  'Read-only. Drop once shoreline-nextjs call sites are migrated to `id`. See RENAME_PLAN.md Phase 2.';
COMMENT ON COLUMN public.addresses.address_id IS
  'DEPRECATED compatibility mirror of addresses.id (renamed from address_id in Phase 2). '
  'Read-only. Drop once shoreline-nextjs call sites are migrated to `id`. See RENAME_PLAN.md Phase 2.';

-- 3. Refresh PostgREST's schema cache so the renamed PK + mirrors are served immediately.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- PRE-DEPLOY CHECK (staging): some triggers in this project were created via the Supabase
-- dashboard and their CREATE TRIGGER DDL is NOT in migration history. The mirror column means
-- nothing breaks even if an out-of-band object still names team_member_id, but before running
-- step B (which drops the mirror) confirm what still references it:
--   SELECT proname FROM pg_proc WHERE prosrc ILIKE '%team_member_id%';
-- ---------------------------------------------------------------------------------
-- ROLLBACK (forward-only DBs — run manually if needed):
--   ALTER TABLE public.team_members DROP COLUMN team_member_id;
--   ALTER TABLE public.addresses    DROP COLUMN address_id;
--   ALTER TABLE public.team_members RENAME COLUMN id TO team_member_id;
--   ALTER TABLE public.addresses    RENAME COLUMN id TO address_id;
--   NOTIFY pgrst, 'reload schema';
--   -- (approve_team_member reverts to its original — still-broken — `WHERE id` form.)
-- ---------------------------------------------------------------------------------
