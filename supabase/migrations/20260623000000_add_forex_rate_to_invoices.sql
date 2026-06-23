-- Persist the CAD→USD forex rate used at the moment each invoice was generated.
-- Invoice amounts are billed and stored in USD; storing the rate lets the user
-- portal convert an invoice back to CAD using the historical rate locked in at
-- creation (USD = CAD * forex_rate, so CAD = USD / forex_rate) instead of the
-- current rate. Null for invoices created before this column existed — the UI
-- falls back to the current forex rate for those.
alter table public.invoices
  add column if not exists forex_rate numeric;

comment on column public.invoices.forex_rate is
  'CAD→USD forex rate (USD per CAD) applied when this invoice was generated. USD = CAD * forex_rate. Null for legacy invoices.';
