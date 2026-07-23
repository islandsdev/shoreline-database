-- Off-cycle (one-time) payment → QuickBooks Payroll entry tracking.
--
-- QuickBooks Online Payroll has no public API, so one-time payments (bonus,
-- stipend, reimbursement, severance, etc.) still have to be keyed into QB
-- Payroll by hand. This migration adds two things:
--
--   1. qb_entry_status on one_time_payments — the per-payment record of whether
--      a human has yet keyed it into QuickBooks ('pending' -> 'entered', or
--      'skipped' when it does not belong in payroll, e.g. a non-payroll
--      reimbursement or an accounting adjustment).
--
--   2. off_cycle_payment_notifications — a queue (mirrors ei_cpp_max_notifications)
--      drained by the off-cycle-payment-notifications cron, which posts each new
--      pending payment to the ops Slack channel and marks the row sent/failed.
--      This keeps the Slack side effect visible + retryable rather than
--      fire-and-forget after the committed one_time_payments write.
--
-- GOING-FORWARD ONLY: every one_time_payments row that already exists when this
-- migration runs is backfilled to 'entered' (assumed already handled in the old
-- manual process) so the first cron run does NOT blast Slack with historical
-- payments. Only rows created after this migration surface as tasks.

-- 1. Per-payment QB-entry state ---------------------------------------------------
-- Add with DEFAULT 'entered' so all existing rows are backfilled in place (fast,
-- metadata-only on PG 11+ since the default is a constant), then flip the default
-- to 'pending' so every row created from here on starts as a task to action.
ALTER TABLE public.one_time_payments
  ADD COLUMN IF NOT EXISTS qb_entry_status text NOT NULL DEFAULT 'entered'
    CHECK (qb_entry_status IN ('pending', 'entered', 'skipped')),
  ADD COLUMN IF NOT EXISTS qb_entered_at timestamptz,
  ADD COLUMN IF NOT EXISTS qb_entered_by text;

ALTER TABLE public.one_time_payments
  ALTER COLUMN qb_entry_status SET DEFAULT 'pending';

COMMENT ON COLUMN public.one_time_payments.qb_entry_status IS
  'Has this payment been keyed into QuickBooks Payroll by hand? pending = needs action, entered = done, skipped = not applicable (e.g. non-payroll reimbursement/adjustment). Rows predating the off-cycle tracking feature were backfilled to ''entered''.';
COMMENT ON COLUMN public.one_time_payments.qb_entered_at IS
  'When qb_entry_status was moved to entered/skipped.';
COMMENT ON COLUMN public.one_time_payments.qb_entered_by IS
  'Admin email that marked this entered/skipped (null for the historical backfill).';

-- Dashboard "outstanding" lookup: admins list the payments still needing entry.
CREATE INDEX IF NOT EXISTS one_time_payments_qb_entry_status_idx
  ON public.one_time_payments (qb_entry_status);

-- 2. Slack notification queue -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.off_cycle_payment_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- The payment this notification is for. Unique (below) => one Slack post per payment.
  one_time_payment_id uuid NOT NULL
    REFERENCES public.one_time_payments(id) ON DELETE CASCADE,
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  team_member_id uuid NOT NULL REFERENCES public.team_members(id) ON DELETE CASCADE,
  -- Snapshotted at enqueue time so a later name/salary change cannot corrupt an
  -- unsent notification.
  employee_name text NOT NULL,
  company_name text NOT NULL,
  payment_type text NOT NULL,
  amount numeric NOT NULL,
  description text,
  memo text,
  payroll_schedule_id uuid REFERENCES public.payroll_schedules(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
  attempts integer NOT NULL DEFAULT 0,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz
);

COMMENT ON TABLE public.off_cycle_payment_notifications IS
  'Queue of Slack notifications telling ops to key an off-cycle (one-time) payment into QuickBooks Payroll; enqueued by the off-cycle-payment-notifications cron (idempotent scan of pending one_time_payments) and drained by the same cron (build Slack message -> post -> mark sent/failed).';
COMMENT ON COLUMN public.off_cycle_payment_notifications.amount IS
  'Snapshot of one_time_payments.amount at enqueue time.';

-- One notification per payment: makes the enqueue upsert idempotent so the cron
-- posts to Slack exactly once even though the payment stays pending until a human
-- actions it.
CREATE UNIQUE INDEX IF NOT EXISTS off_cycle_payment_notifications_payment_uidx
  ON public.off_cycle_payment_notifications (one_time_payment_id);

-- Drain lookup: the cron fetches the oldest pending/failed rows first.
CREATE INDEX IF NOT EXISTS off_cycle_payment_notifications_status_created_idx
  ON public.off_cycle_payment_notifications (status, created_at);

CREATE INDEX IF NOT EXISTS off_cycle_payment_notifications_company_idx
  ON public.off_cycle_payment_notifications (company_id);

-- Service-role only: this queue is never read by the client directly. Enabling
-- RLS with no policies denies anon/authenticated while supabaseAdmin (service
-- role) bypasses RLS. Mirrors ei_cpp_max_notifications.
ALTER TABLE public.off_cycle_payment_notifications ENABLE ROW LEVEL SECURITY;

-- Refresh PostgREST's schema cache so the new column + table are picked up.
NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only):
--
--   DROP TABLE IF EXISTS public.off_cycle_payment_notifications;
--   ALTER TABLE public.one_time_payments
--     DROP COLUMN IF EXISTS qb_entry_status,
--     DROP COLUMN IF EXISTS qb_entered_at,
--     DROP COLUMN IF EXISTS qb_entered_by;
--   NOTIFY pgrst, 'reload schema';
-- ---------------------------------------------------------------------------------
