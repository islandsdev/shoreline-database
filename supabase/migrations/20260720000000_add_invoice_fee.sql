-- Persist the payment-provider processing fee on invoices.
--
-- Stored value, NOT computed at read time. Written at the ingestion/reconciliation
-- layer; the admin billing page only reads and displays it. Added to both invoice
-- tables so the Salary tab (salary_invoices) and the Subscriptions / Top-ups tabs
-- (subscription_invoices) can show it.
--
-- `fee` is intentionally provider-agnostic (Stripe today, but Wise/other providers
-- issue invoices too) — it holds whatever processing fee applied.
--
-- Forex rates + the derived forex_gain_loss live in the next migration
-- (20260720000001), which must run after forex_rate_used/forex_rate_real exist.

alter table public.salary_invoices
  add column if not exists fee numeric;

comment on column public.salary_invoices.fee is
  'Payment-provider processing fee for this invoice (provider-agnostic). Persisted at ingestion; not computed at read time.';

alter table public.subscription_invoices
  add column if not exists fee numeric;

comment on column public.subscription_invoices.fee is
  'Payment-provider processing fee for this invoice (provider-agnostic). Persisted at ingestion; not computed at read time.';

-- Refresh PostgREST's schema cache so the new columns are picked up immediately.
notify pgrst, 'reload schema';
