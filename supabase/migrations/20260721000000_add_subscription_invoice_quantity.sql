-- Persist the billed quantity (seat / unit count) on subscription invoices.
--
-- A subscription invoice's line item carries how many units were billed — e.g.
-- an Essential plan billed for 5 seats has quantity 5. It's sourced from the
-- recurring Stripe line item at write time (the invoice webhook / backfill) and
-- only read by the admin billing page — same persist-then-display pattern as
-- fee / forex_rate_*.
--
-- Nullable: legacy rows (and the odd invoice with no resolvable line) stay null
-- until re-synced by the subscription-invoices backfill, which re-maps from
-- Stripe and fills it in.

alter table public.subscription_invoices
  add column if not exists quantity integer;

comment on column public.subscription_invoices.quantity is
  'Billed quantity (units/seats) from the recurring Stripe line item. Persisted at ingestion; not computed at read time.';

-- Refresh PostgREST's schema cache so the new column is picked up immediately.
notify pgrst, 'reload schema';
