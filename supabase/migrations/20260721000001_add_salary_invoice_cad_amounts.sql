-- Derived CAD amounts on salary invoices (persisted, display-only).
--
-- salary_invoices.amount is the USD figure Shoreline billed. The rates are stored
-- USD-per-CAD (USD = CAD * rate), so:
--
--   amount_cad             = amount / forex_rate_used
--       The CAD amount we were *supposed* to charge — the USD bill converted back
--       to CAD at the rate we actually billed at.
--
--   amount_should_charged  = amount_cad * forex_rate_real  (= amount * real / used)
--       The USD amount we *should* have charged: that CAD value re-converted at the
--       real market rate. The gap vs `amount` is the forex gain/loss (already stored
--       separately as forex_gain_loss, in CAD).
--
-- Both are GENERATED STORED — the DB derives them from amount + the two rates; the
-- app only displays them (same pattern as forex_gain_loss). Null whenever a rate is
-- missing/zero (nullif guards division), e.g. late-fee invoices with no billed rate.

alter table public.salary_invoices
  add column if not exists amount_cad numeric
    generated always as (
      round(amount / nullif(forex_rate_used, 0), 2)
    ) stored;

alter table public.salary_invoices
  add column if not exists amount_should_charged numeric
    generated always as (
      round(amount * forex_rate_real / nullif(forex_rate_used, 0), 2)
    ) stored;

comment on column public.salary_invoices.amount_cad is
  'GENERATED (CAD): amount / forex_rate_used — the CAD amount we were supposed to charge. Null when the billed rate is missing.';
comment on column public.salary_invoices.amount_should_charged is
  'GENERATED (USD): amount * forex_rate_real / forex_rate_used — what we should have charged at the real market rate. Null when a rate is missing.';

-- Recreate the `invoices` compat view so its SELECT * exposes the new columns
-- (a view''s * is frozen at creation; new base-table columns don''t appear until
-- the view is rebuilt). Mirrors 20260720000001.
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

-- Refresh PostgREST's schema cache so the new columns are picked up immediately.
notify pgrst, 'reload schema';
