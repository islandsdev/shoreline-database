-- Remove payment_id — accruals are now written once per employee per payroll
-- period, summing salary + eligible one-time payments into a single row.
ALTER TABLE cashback_accruals DROP CONSTRAINT IF EXISTS cashback_accruals_payment_id_fkey;
ALTER TABLE cashback_accruals DROP COLUMN IF EXISTS payment_id;

-- Add invoice_id so every accrual is traceable to its source invoice, and add
-- a unique constraint to make the accrual job idempotent on webhook retries.
ALTER TABLE cashback_accruals
  ADD COLUMN IF NOT EXISTS invoice_id uuid REFERENCES invoices(id);

CREATE UNIQUE INDEX IF NOT EXISTS cashback_accruals_invoice_member_period_key
  ON cashback_accruals (invoice_id, team_member_id, payroll_schedule_id);
