-- Drop payouts.company_id — payouts are account-level, not company-scoped.
--
-- add_payouts (20260720000002) gave payouts a NOT NULL company_id, assuming every
-- payout is company-scoped. But a payment-provider payout (Stripe today) is an
-- ACCOUNT-level settlement that batches funds across ALL companies — it does not
-- belong to a single company. The payouts backfill stores those raw settlements
-- one row per Stripe payout, so a company_id column has no meaning here and is
-- removed entirely.
--
-- The payout<->invoice link is unaffected: it lives ON the invoice tables
-- (salary_invoices.payout_id / subscription_invoices.payout_id), each of which
-- still carries its own company_id. So "which companies did this payout settle"
-- is still answerable by joining through the linked invoices — it just isn't
-- denormalised onto the payout row.
--
-- Dropping the column also drops its dependent index (payouts_company_id_idx) and
-- the FK to companies automatically.

alter table public.payouts
  drop column if exists company_id;

comment on table public.payouts is
  'Payment-provider payout settlements (Stripe today), stored one row per raw '
  'account-level payout. Not company-scoped: the company/companies a payout '
  'settled are reachable via the linked invoices (salary_invoices.payout_id / '
  'subscription_invoices.payout_id). Read-only in the admin UI for now.';

-- Refresh PostgREST's schema cache so the dropped column is picked up.
notify pgrst, 'reload schema';
