-- Invoice forex rates (used vs real) + persisted forex gain/loss.
--
-- Each invoice now carries TWO CAD->USD rates (both USD-per-CAD, so USD = CAD * rate):
--   * forex_rate_used  — the rate Shoreline billed at (renamed from the existing
--                        `forex_rate`; salary invoices only — subs bill flat in USD)
--   * forex_rate_real  — the actual market rate on the invoice date (fetched from
--                        Wise, or Bank of Canada as a fallback, at write time)
--
-- forex_gain_loss is a GENERATED STORED column: the DB derives it from the two
-- rates + the invoice amount whenever the rates are written. Nothing computes it
-- in application code — it is persisted at the DB level and the app only displays
-- it. Positive => gain to Shoreline (used rate > real rate): the invoiced USD,
-- converted back to CAD at the real rate, is worth more CAD than at the billed rate.
--
-- Runs after 20260717000000 (invoices -> salary_invoices + `invoices` view) and
-- 20260717000001 (subscription_invoices), so both base tables + the view exist.

-- 1. salary_invoices: rename forex_rate -> forex_rate_used (guarded / drift-safe) --
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'salary_invoices'
      AND column_name = 'forex_rate'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'salary_invoices'
      AND column_name = 'forex_rate_used'
  ) THEN
    ALTER TABLE public.salary_invoices RENAME COLUMN forex_rate TO forex_rate_used;
  END IF;
END $$;

-- 2. Add the real-rate columns -----------------------------------------------------
alter table public.salary_invoices
  add column if not exists forex_rate_real numeric;

-- subs are billed flat in USD, so forex_rate_used stays null there; the column
-- exists for a uniform shape across the billing UI.
alter table public.subscription_invoices
  add column if not exists forex_rate_used numeric,
  add column if not exists forex_rate_real numeric;

-- 3. Generated forex gain/loss (CAD), derived + persisted by the DB ----------------
--    amount (salary) / total (subs) is the invoice's USD figure.
--    gain/loss = usd/real - usd/used  (null if either rate is null/zero).
alter table public.salary_invoices
  add column if not exists forex_gain_loss numeric
    generated always as (
      round(amount * (1.0 / nullif(forex_rate_real, 0) - 1.0 / nullif(forex_rate_used, 0)), 2)
    ) stored;

alter table public.subscription_invoices
  add column if not exists forex_gain_loss numeric
    generated always as (
      round(total * (1.0 / nullif(forex_rate_real, 0) - 1.0 / nullif(forex_rate_used, 0)), 2)
    ) stored;

comment on column public.salary_invoices.forex_rate_used is
  'CAD->USD rate (USD per CAD) Shoreline billed this invoice at. USD = CAD * rate. Renamed from forex_rate.';
comment on column public.salary_invoices.forex_rate_real is
  'Actual market CAD->USD rate on the invoice date (Wise, or Bank of Canada fallback). Null for legacy invoices / when the fetch was unavailable.';
comment on column public.salary_invoices.forex_gain_loss is
  'GENERATED (CAD): amount*(1/forex_rate_real - 1/forex_rate_used). Positive = gain to Shoreline. Null when a rate is missing.';
comment on column public.subscription_invoices.forex_rate_real is
  'Actual market CAD->USD rate on the invoice date (Wise, or Bank of Canada fallback). Null when the fetch was unavailable.';
comment on column public.subscription_invoices.forex_gain_loss is
  'GENERATED (CAD): total*(1/forex_rate_real - 1/forex_rate_used). Null for subs (no billed used rate).';

-- 4. Recreate the `invoices` compat view so it exposes the renamed + new columns ---
--    (explicit drop/create rather than relying on rename auto-propagation).
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

-- Refresh PostgREST's schema cache so the rename + new columns are picked up.
notify pgrst, 'reload schema';
