-- Payout tracking (Stripe today).
--
-- A payout is a payment-provider settlement: the provider (Stripe today) paying a
-- batch of collected funds out to Shoreline's bank, net of a payout fee. ONE payout
-- settles MANY invoices, which may span both invoice tables:
--   * salary_invoices       — salary + late-fee invoices
--   * subscription_invoices — plan + top-up invoices
--
-- The payout<->invoice link is stored ON each invoice (invoices.payout_id), not on
-- the payout — so "the invoices under a payout" is every row in either table with
-- that payout_id. `payouts.fee` is the payout's OWN fee, separate from the
-- per-invoice processing fee (salary_invoices.fee / subscription_invoices.fee).
--
-- Scope (per the July 13 wrap-up "Payout Tracking" item): this migration only
-- STORES the records + link. The admin page reads and displays them; a Stripe sync
-- and reconciliation actions (mark reconciled, link/unlink invoices) land in later
-- passes — neither is wired up here. `fee`/`provider` are provider-agnostic (Stripe
-- today, but the shape should survive other rails — e.g. Wise).

-- 1. payouts -----------------------------------------------------------------------
create table if not exists public.payouts (
  id                 uuid primary key default gen_random_uuid(),
  created_at         timestamptz not null default now(),
  company_id         uuid not null references public.companies(id) on delete cascade,
  amount             numeric,
  currency           text not null default 'USD',
  -- The payout's OWN fee (e.g. Stripe payout fee), NOT the per-invoice processing
  -- fee. Null until known.
  fee                numeric,
  -- CAD->USD rate (USD per CAD) that applied on the payout date, when a currency
  -- conversion was involved. Matches salary_invoices.forex_rate_used: USD = CAD * rate.
  forex_rate_used    numeric,
  payout_date        date,
  status             text not null default 'pending'
                       check (status in ('pending', 'reconciled', 'failed', 'cancelled')),
  provider           text not null default 'Stripe',
  -- External reference id (e.g. Stripe payout id, po_…) for reconciliation.
  provider_reference text
);

create index if not exists payouts_company_id_idx  on public.payouts (company_id);
create index if not exists payouts_status_idx      on public.payouts (status);
create index if not exists payouts_payout_date_idx on public.payouts (payout_date desc);

comment on table public.payouts is
  'Payment-provider payout settlements (Stripe today). One payout groups many '
  'invoices, linked via salary_invoices.payout_id / subscription_invoices.payout_id. '
  'Stores the payout amount, its own fee, and CAD->USD rate on the payout date. '
  'Read-only in the admin UI for now.';
comment on column public.payouts.fee is
  'The payout''s own provider fee (e.g. Stripe payout fee) — distinct from the '
  'per-invoice processing fee stored on the invoice tables.';

-- Access: service-role only (all reads/writes go through the Next.js backend via
-- supabaseAdmin). RLS on with no policies blocks anon/authenticated, matching
-- subscription_invoices.
alter table public.payouts enable row level security;
grant select, insert, update, delete on public.payouts to service_role;

-- 2. payout_id link on each invoice table ------------------------------------------
--    Nullable FK; ON DELETE SET NULL so removing a payout un-links its invoices
--    rather than deleting them.
alter table public.salary_invoices
  add column if not exists payout_id uuid references public.payouts(id) on delete set null;
create index if not exists salary_invoices_payout_id_idx on public.salary_invoices (payout_id);

alter table public.subscription_invoices
  add column if not exists payout_id uuid references public.payouts(id) on delete set null;
create index if not exists subscription_invoices_payout_id_idx on public.subscription_invoices (payout_id);

comment on column public.salary_invoices.payout_id is
  'The payout that settled this invoice (null until reconciled). FK -> payouts.';
comment on column public.subscription_invoices.payout_id is
  'The payout that settled this invoice (null until reconciled). FK -> payouts.';

-- 3. Recreate the `invoices` compat view so it exposes the new payout_id column -----
--    (a plain `select *` view binds its column list at creation time and does NOT
--    auto-pick-up new base-table columns — same reason the forex migration recreated it).
drop view if exists public.invoices;

create view public.invoices
  with (security_invoker = true)
  as select * from public.salary_invoices;

comment on view public.invoices is
  'DEPRECATED compatibility shim for the renamed salary_invoices table. '
  'shoreline-nextjs / shoreline-vite still query this name. '
  'Drop this view once those call sites are migrated to salary_invoices.';

grant select, insert, update, delete on public.invoices
  to anon, authenticated, service_role;

-- Refresh PostgREST's schema cache so the new table + columns are picked up.
notify pgrst, 'reload schema';
