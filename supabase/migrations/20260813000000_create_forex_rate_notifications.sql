-- Queue of forex-rate-change notifications to clients.
--
-- Mirrors cashback_rate_notifications (see 20260625000000). When the CAD -> USD
-- rate a client is billed at changes -- a per-company override, the global
-- default, a bulk change, or the removal of an override (reverting the company
-- to the global default) -- the API enqueues one row here per affected company
-- instead of emailing inline. A cron processor
-- (app/api/cron/forex-notifications) drains pending rows: it generates the
-- Forex Rate Notice PDF, stores it in the documents table (so it shows in the
-- client dashboard), emails it to the client, then marks the row sent/failed.
-- This keeps the side effect visible and retryable rather than fire-and-forget
-- after the committed forex_rates write, and lets a single global rate change
-- fan out to many companies safely.
--
-- rate, previous_rate and recipient_email are SNAPSHOTTED at enqueue time so a
-- later rate or company change cannot corrupt an unsent notification.

create table if not exists public.forex_rate_notifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  -- forex_rates.id is a bigint identity column, not a uuid.
  forex_rate_id bigint not null references public.forex_rates(id) on delete cascade,
  scope text not null check (scope in ('company', 'global', 'reset')),
  rate numeric not null,
  previous_rate numeric,
  effective_from timestamptz not null default now(),
  recipient_email text,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed')),
  document_id uuid references public.documents(id) on delete set null,
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_at timestamptz
);

comment on table public.forex_rate_notifications is
  'Queue of forex-rate-change client notifications; drained by the forex-notifications cron (generate PDF -> store -> email -> mark sent/failed).';
comment on column public.forex_rate_notifications.scope is
  'company = a per-company override was set; global = the global default changed and this row is one fanned-out recipient; reset = a per-company override was removed, so the company reverted to the global default.';
comment on column public.forex_rate_notifications.forex_rate_id is
  'The forex_rates row that now applies to this company. For scope=reset that is the active GLOBAL row, since the override was deactivated.';
comment on column public.forex_rate_notifications.rate is
  'Snapshot of the new effective rate (USD per CAD) for this company at enqueue time.';
comment on column public.forex_rate_notifications.previous_rate is
  'Snapshot of the effective rate this company was on before the change (its own override if it had one, otherwise the old global). Null when it could not be determined; the letter/email then omits the comparison.';
comment on column public.forex_rate_notifications.recipient_email is
  'Snapshot of the company billing_email (falling back to contact_email) at enqueue time.';

-- One notification per (rate row, company, scope). A new forex_rates row is
-- created on every rate change, so this makes a re-run of a fan-out idempotent.
-- scope is part of the key so a 'reset' notice is not swallowed by an earlier
-- 'global' notice that referenced the same global rate row.
create unique index if not exists forex_rate_notifications_rate_company_scope_uidx
  on public.forex_rate_notifications (forex_rate_id, company_id, scope);

-- Drain lookup: the cron fetches the oldest pending rows first.
create index if not exists forex_rate_notifications_status_created_idx
  on public.forex_rate_notifications (status, created_at);

create index if not exists forex_rate_notifications_company_idx
  on public.forex_rate_notifications (company_id);

-- Service-role only: this queue is never read by the client directly. Enabling
-- RLS with no policies denies anon/authenticated while supabaseAdmin (service
-- role) bypasses RLS.
alter table public.forex_rate_notifications enable row level security;
