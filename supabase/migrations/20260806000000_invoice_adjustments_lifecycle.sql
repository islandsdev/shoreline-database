-- ---------------------------------------------------------------------------------
-- invoice_adjustments: give the row a lifecycle and make it self-describing.
--
-- WHY: today the table stores only `amount_cad` — the *input*. The USD figure we
-- actually billed and the forex rate it was locked at are computed in memory by
-- the daily invoice job (utils.ts groupByCompany) and thrown away; only
-- `invoice_id` survives. Answering "how much did we charge the customer for this
-- adjustment?" means joining to the invoice and re-doing the multiplication, and
-- only works when the row attached to an invoice at all.
--
-- `invoice_id IS NULL` is also overloaded: it means "pending", "never attached",
-- and "was attached but the invoice was later deleted" (the FK is ON DELETE SET
-- NULL) all at once. There is no void path and no record of which admin created
-- the row.
--
-- WHAT THIS DOES
--   1. status         — explicit lifecycle: pending → billed, or pending → void
--   2. amount_usd     — snapshot of the USD actually put on the invoice
--   3. forex_rate_used— snapshot of the rate locked at billing time
--   4. billed_at      — when it attached
--   5. created_by / created_by_email — audit: which admin entered the charge
--   6. notes          — internal-only; `description` is customer-facing
--   7. drops admin_handled (never read by any code; a second "pending" concept)
--   8. enables RLS and revokes the anon/authenticated write grants
--   9. backfills already-billed rows from their invoice
--
-- SAFE TO APPLY AHEAD OF THE BACKEND DEPLOY: `status` defaults to 'pending', so
-- rows the job already picks up (`invoice_id IS NULL`) keep behaving exactly as
-- they do today. The reverse is NOT true — the deploy adds `.eq("status",
-- "pending")` to the pickup query, which 500s against the old schema. Migration
-- first, always.
--
-- After applying: regenerate shoreline-database/types.ts (never hand-edit it).
-- ---------------------------------------------------------------------------------

BEGIN;

-- ---------------------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------------------
ALTER TABLE public.invoice_adjustments
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'pending',
  -- USD actually billed. Stored, NOT generated: the value has to match the
  -- invoice job's arithmetic byte-for-byte (JS Math.round on the exact figure
  -- sent to Stripe). Postgres round() is half-away-from-zero and JS Math.round()
  -- is half-up, so a GENERATED column would drift by a cent on credits.
  ADD COLUMN IF NOT EXISTS amount_usd numeric,
  ADD COLUMN IF NOT EXISTS forex_rate_used numeric,
  ADD COLUMN IF NOT EXISTS billed_at timestamptz,
  -- auth.users id of the admin who created the row. Deliberately NOT a FK to
  -- auth.users: adjustments are financial records that must outlive the account.
  ADD COLUMN IF NOT EXISTS created_by uuid,
  ADD COLUMN IF NOT EXISTS created_by_email text,
  -- Internal only. `description` is what the customer reads on their invoice.
  ADD COLUMN IF NOT EXISTS notes text;

COMMENT ON COLUMN public.invoice_adjustments.status IS
  'pending → not yet on an invoice; billed → charged to the customer; void → cancelled before billing.';
COMMENT ON COLUMN public.invoice_adjustments.amount_usd IS
  'Snapshot of the USD amount actually billed. Written by the invoice job at billing time, never derived.';
COMMENT ON COLUMN public.invoice_adjustments.forex_rate_used IS
  'Snapshot of the CAD→USD rate locked when this adjustment was billed.';
COMMENT ON COLUMN public.invoice_adjustments.notes IS
  'Internal admin notes. Never leaves the portal — `description` is the customer-facing line.';

-- ---------------------------------------------------------------------------------
-- 2. Constraints
--
-- Added NOT VALID then validated separately so the table is not held under an
-- ACCESS EXCLUSIVE lock for the full scan. Any pre-existing row that violates
-- them surfaces here as a loud failure rather than silently sticking around.
-- ---------------------------------------------------------------------------------
ALTER TABLE public.invoice_adjustments
  ADD CONSTRAINT invoice_adjustments_status_check
    CHECK (status IN ('pending', 'billed', 'void')) NOT VALID;
ALTER TABLE public.invoice_adjustments
  VALIDATE CONSTRAINT invoice_adjustments_status_check;

-- A zero adjustment bills nothing and reads as a data-entry mistake.
-- Pre-check first so the failure names the offending rows: VALIDATE on its own
-- just reports the constraint name, which is no help mid-rollout.
DO $$
DECLARE
  offending text;
BEGIN
  SELECT string_agg(id::text, ', ')
    INTO offending
  FROM public.invoice_adjustments
  WHERE amount_cad = 0;

  IF offending IS NOT NULL THEN
    RAISE EXCEPTION
      'invoice_adjustments has zero-amount rows, which invoice_adjustments_amount_nonzero forbids. Delete or correct them, then re-run. Ids: %',
      offending;
  END IF;
END $$;

ALTER TABLE public.invoice_adjustments
  ADD CONSTRAINT invoice_adjustments_amount_nonzero
    CHECK (amount_cad <> 0) NOT VALID;
ALTER TABLE public.invoice_adjustments
  VALIDATE CONSTRAINT invoice_adjustments_amount_nonzero;

-- One-directional on purpose: a pending row must not already point at an
-- invoice, but a billed row IS allowed to have a null invoice_id — the FK is
-- ON DELETE SET NULL, so deleting the invoice orphans the link without
-- resurrecting the charge. Writing this as an equivalence would make the FK's
-- own side effect illegal.
ALTER TABLE public.invoice_adjustments
  ADD CONSTRAINT invoice_adjustments_pending_unlinked
    CHECK (status <> 'pending' OR invoice_id IS NULL) NOT VALID;
-- Deliberately validated AFTER the backfill below, which is what makes the
-- existing linked rows non-pending in the first place.

-- ---------------------------------------------------------------------------------
-- 3. Backfill rows that were already billed
--
-- amount_usd mirrors the job's JS arithmetic exactly:
--     Math.round(amount_cad * rate * 100) / 100
-- JS Math.round breaks ties toward +∞; Postgres round() breaks them away from
-- zero, which disagrees on negative halves (-2.5 → -2 vs -3). floor(x + 0.5)
-- reproduces the JS rule for both signs, so a backfilled credit matches what the
-- job would have written.
--
-- Where the invoice carries no rate, amount_usd and forex_rate_used stay null
-- and the UI renders "—". Better an honest gap than an invented number.
-- ---------------------------------------------------------------------------------
UPDATE public.invoice_adjustments AS adj
SET
  status          = 'billed',
  billed_at       = inv.created_at,
  forex_rate_used = inv.forex_rate_used,
  amount_usd      = CASE
                      WHEN inv.forex_rate_used IS NULL THEN NULL
                      ELSE floor(adj.amount_cad * inv.forex_rate_used * 100 + 0.5) / 100
                    END
FROM public.salary_invoices AS inv
WHERE adj.invoice_id = inv.id;

ALTER TABLE public.invoice_adjustments
  VALIDATE CONSTRAINT invoice_adjustments_pending_unlinked;

-- ---------------------------------------------------------------------------------
-- 4. Immutability of billed rows
--
-- It is money. The API layer refuses to edit a billed adjustment, but an
-- API-layer guard alone is not enough for a table that has, until now, been
-- edited by hand in Supabase Studio.
--
-- Only the customer-visible amount and description are frozen. `notes` stays
-- editable on purpose — annotating what happened after the fact is exactly what
-- an internal note is for.
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
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS invoice_adjustments_freeze_billed_trg ON public.invoice_adjustments;
CREATE TRIGGER invoice_adjustments_freeze_billed_trg
  BEFORE UPDATE ON public.invoice_adjustments
  FOR EACH ROW
  EXECUTE FUNCTION public.invoice_adjustments_freeze_billed();

-- ---------------------------------------------------------------------------------
-- 5. Drop admin_handled
--
-- Added in 20260308204756 and never read by any code — a second, competing
-- notion of "pending" that `status` now owns outright.
-- ---------------------------------------------------------------------------------
ALTER TABLE public.invoice_adjustments DROP COLUMN IF EXISTS admin_handled;

-- ---------------------------------------------------------------------------------
-- 6. Lock the table down
--
-- The original migration granted insert/update/delete to `anon`, and the
-- Supabase publishable key ships inside the browser bundle. Anyone could insert
-- a row against any company_id and the next invoice run would bill it to that
-- customer. This is a live hole independent of the admin-portal feature.
--
-- All legitimate access is through supabaseAdmin (service role) in the Next.js
-- API, which bypasses RLS. If clients should later see their own adjustments,
-- add a SELECT policy on company_id — do not re-grant writes.
-- ---------------------------------------------------------------------------------
ALTER TABLE public.invoice_adjustments ENABLE ROW LEVEL SECURITY;

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES
  ON public.invoice_adjustments FROM anon, authenticated;

-- Index the columns the admin list filters on. Cross-tenant, newest first.
CREATE INDEX IF NOT EXISTS invoice_adjustments_status_created_at_idx
  ON public.invoice_adjustments (status, created_at DESC);
CREATE INDEX IF NOT EXISTS invoice_adjustments_company_id_idx
  ON public.invoice_adjustments (company_id);

-- Refresh PostgREST's schema cache so the new columns are visible immediately.
NOTIFY pgrst, 'reload schema';

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only).
-- Restores the previous shape. The dropped admin_handled values are NOT
-- recoverable, and re-granting anon writes reopens the hole described above —
-- only do it if something genuinely depended on them.
--
--   BEGIN;
--   DROP TRIGGER IF EXISTS invoice_adjustments_freeze_billed_trg ON public.invoice_adjustments;
--   DROP FUNCTION IF EXISTS public.invoice_adjustments_freeze_billed();
--   ALTER TABLE public.invoice_adjustments
--     DROP CONSTRAINT IF EXISTS invoice_adjustments_pending_unlinked,
--     DROP CONSTRAINT IF EXISTS invoice_adjustments_amount_nonzero,
--     DROP CONSTRAINT IF EXISTS invoice_adjustments_status_check,
--     DROP COLUMN IF EXISTS notes,
--     DROP COLUMN IF EXISTS created_by_email,
--     DROP COLUMN IF EXISTS created_by,
--     DROP COLUMN IF EXISTS billed_at,
--     DROP COLUMN IF EXISTS forex_rate_used,
--     DROP COLUMN IF EXISTS amount_usd,
--     DROP COLUMN IF EXISTS status,
--     ADD COLUMN admin_handled boolean NOT NULL DEFAULT false;
--   ALTER TABLE public.invoice_adjustments DISABLE ROW LEVEL SECURITY;
--   NOTIFY pgrst, 'reload schema';
--   COMMIT;
-- ---------------------------------------------------------------------------------
