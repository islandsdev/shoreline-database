-- ---------------------------------------------------------------------------------
-- Recurring Payments: no approval step, no tax treatment.
--
-- A Recurring Payment now takes effect as soon as the client creates it, like a
-- one-time payment does. There is no payroll approval and no tax treatment on
-- the instruction — neither the client's request nor a payroll decision.
--
--   lifecycle   active ⇄ paused → stopped   (was pending_approval → active …,
--                                            or pending_approval → rejected)
--   dropped     requested_tax_treatment, tax_treatment, tax_treatment_notes,
--               approved_at, approved_by, approved_by_email,
--               rejected_at, rejected_by_email, rejection_reason
--               (and the CHECK that required a treatment before activation)
--
-- EXISTING ROWS
--   pending_approval → active   the client already asked for it; the backend's
--                               next sync generates its periods.
--   rejected         → stopped  final either way.
--
-- DEPLOY ORDER: apply together with the backend that stops writing these
-- columns. The old backend inserts `status = 'pending_approval'` and
-- `requested_tax_treatment`, which this migration refuses.
--
-- After applying: regenerate shoreline-database/types.ts (never hand-edit it).
-- ---------------------------------------------------------------------------------

BEGIN;

ALTER TABLE public.recurring_payments
  DROP CONSTRAINT IF EXISTS recurring_payments_treatment_before_activation;

-- Moved before the new status CHECK goes on, or it would reject these rows.
ALTER TABLE public.recurring_payments
  DROP CONSTRAINT IF EXISTS recurring_payments_status_check;

UPDATE public.recurring_payments
SET status = 'active', updated_at = now()
WHERE status = 'pending_approval';

UPDATE public.recurring_payments
SET status = 'stopped', stopped_at = COALESCE(rejected_at, now()), updated_at = now()
WHERE status = 'rejected';

ALTER TABLE public.recurring_payments
  ALTER COLUMN status SET DEFAULT 'active',
  ADD CONSTRAINT recurring_payments_status_check
    CHECK (status IN ('active', 'paused', 'stopped'));

-- Their own CHECK constraints go with them.
ALTER TABLE public.recurring_payments
  DROP COLUMN IF EXISTS requested_tax_treatment,
  DROP COLUMN IF EXISTS tax_treatment,
  DROP COLUMN IF EXISTS tax_treatment_notes,
  DROP COLUMN IF EXISTS approved_at,
  DROP COLUMN IF EXISTS approved_by,
  DROP COLUMN IF EXISTS approved_by_email,
  DROP COLUMN IF EXISTS rejected_at,
  DROP COLUMN IF EXISTS rejected_by_email,
  DROP COLUMN IF EXISTS rejection_reason;

NOTIFY pgrst, 'reload schema';

COMMIT;
