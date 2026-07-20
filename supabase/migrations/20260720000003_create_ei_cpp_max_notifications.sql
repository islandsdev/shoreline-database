-- Queue of EI / CPP annual-maximum notifications to employers.
--
-- Canadian statutory employer contributions (EI, CPP) are capped per calendar
-- year (EEI $1,572.70, ECPP $4,230.45). The daily-invoice-job clamps a pay
-- period's deduction to the exact remaining cents when an employee reaches the
-- cap, and zeroes every period after. When that crossing happens, the job
-- enqueues one row here per (employee, contribution type, year) instead of
-- emailing inline. The cron processor (app/api/cron/ei-cpp-max-notifications)
-- drains pending rows: it builds the employer email and sends it, then marks
-- the row sent/failed. This keeps the side effect visible and retryable rather
-- than fire-and-forget after the committed invoice/contribution writes.
--
-- The deduction amounts and recipient_email are SNAPSHOTTED at enqueue time so a
-- later salary/rate/company change cannot corrupt an unsent notification.

create table if not exists public.ei_cpp_max_notifications (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  -- FK column keeps the <referenced>_id name (matches cpp_contributions et al.);
  -- team_members' PK was standardized to `id` (Phase 2, mirror dropped in
  -- 20260717000003), so it references team_members(id), not team_member_id.
  team_member_id uuid not null references public.team_members(id) on delete cascade,
  -- 'EI' = Employment Insurance (EEI), 'CPP' = Canada Pension Plan (ECPP).
  contribution_type text not null check (contribution_type in ('EI', 'CPP')),
  service_year integer not null,
  recipient_email text,
  employee_name text not null,
  company_name text not null,
  -- The regular full per-period employer deduction before the cap kicked in.
  previous_deduction_cad numeric not null,
  -- The (possibly reduced) deduction on the payroll that reached the maximum.
  current_deduction_cad numeric not null,
  -- What the next payroll's deduction will be now the cap is reached (0.00).
  next_deduction_cad numeric not null default 0,
  -- Year-to-date employer contribution after the capping period (== the max).
  ytd_total_cad numeric not null,
  annual_max_cad numeric not null,
  payroll_schedule_id uuid references public.payroll_schedules(id) on delete set null,
  period_end_date date,
  status text not null default 'pending' check (status in ('pending', 'processing', 'sent', 'failed')),
  attempts integer not null default 0,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  sent_at timestamptz
);

comment on table public.ei_cpp_max_notifications is
  'Queue of EI/CPP annual-maximum employer notifications; enqueued by the daily-invoice-job when an employee reaches the cap and drained by the ei-cpp-max-notifications cron (build email -> send -> mark sent/failed).';
comment on column public.ei_cpp_max_notifications.contribution_type is
  'EI = Employment Insurance (EEI), CPP = Canada Pension Plan (ECPP).';
comment on column public.ei_cpp_max_notifications.recipient_email is
  'Snapshot of the company billing_email at enqueue time.';
comment on column public.ei_cpp_max_notifications.previous_deduction_cad is
  'Regular full per-period employer deduction before the annual cap applied.';
comment on column public.ei_cpp_max_notifications.current_deduction_cad is
  'Employer deduction on the payroll that reached the maximum (may be reduced).';

-- One notification per (employee, contribution type, year): an employee crosses
-- each cap exactly once per calendar year. Makes enqueue idempotent so a
-- re-run of the invoice job for the same period does not duplicate the email.
create unique index if not exists ei_cpp_max_notifications_member_type_year_uidx
  on public.ei_cpp_max_notifications (team_member_id, contribution_type, service_year);

-- Drain lookup: the cron fetches the oldest pending rows first.
create index if not exists ei_cpp_max_notifications_status_created_idx
  on public.ei_cpp_max_notifications (status, created_at);

create index if not exists ei_cpp_max_notifications_company_idx
  on public.ei_cpp_max_notifications (company_id);

-- Service-role only: this queue is never read by the client directly. Enabling
-- RLS with no policies denies anon/authenticated while supabaseAdmin (service
-- role) bypasses RLS.
alter table public.ei_cpp_max_notifications enable row level security;
