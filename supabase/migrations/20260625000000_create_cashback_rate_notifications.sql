-- Queue of cashback-rate-change notifications to clients.
--
-- When a cashback rate is updated (per-company override or the global default),
-- the API enqueues one row here per affected company instead of sending inline.
-- A cron processor (app/api/cron/cashback-notifications) drains pending rows:
-- it generates the Cashback Commitment Letter PDF, stores it in the documents
-- table (so it shows in the client dashboard), emails it to the client, then
-- marks the row sent/failed. This keeps the side effect visible and retryable
-- rather than fire-and-forget after the committed cashback_config write, and
-- lets a single global rate change fan out to many companies safely.
--
-- Rates and recipient_email are SNAPSHOTTED at enqueue time so a later config
-- or company change cannot corrupt an unsent notification.

create table if not exists public.cashback_rate_notifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  cashback_config_id uuid not null references public.cashback_config(id) on delete cascade,
  scope text not null check (scope in ('company', 'global')),
  tech_employee_rate numeric not null,
  tech_contractor_rate numeric not null,
  recipient_email text,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed')),
  document_id uuid references public.documents(id) on delete set null,
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_at timestamptz
);

comment on table public.cashback_rate_notifications is
  'Queue of cashback-rate-change client notifications; drained by the cashback-notifications cron (generate PDF -> store -> email -> mark sent/failed).';
comment on column public.cashback_rate_notifications.scope is
  'company = a per-company override changed; global = the global default changed and this row is one fanned-out recipient.';
comment on column public.cashback_rate_notifications.recipient_email is
  'Snapshot of the company billing_email at enqueue time.';

-- One notification per (config change, company): a new cashback_config row is
-- created on every rate change, so this also makes enqueue idempotent if the
-- PATCH is retried.
create unique index if not exists cashback_rate_notifications_config_company_uidx
  on public.cashback_rate_notifications (cashback_config_id, company_id);

-- Drain lookup: the cron fetches the oldest pending rows first.
create index if not exists cashback_rate_notifications_status_created_idx
  on public.cashback_rate_notifications (status, created_at);

create index if not exists cashback_rate_notifications_company_idx
  on public.cashback_rate_notifications (company_id);

-- Service-role only: this queue is never read by the client directly. Enabling
-- RLS with no policies denies anon/authenticated while supabaseAdmin (service
-- role) bypasses RLS.
alter table public.cashback_rate_notifications enable row level security;
