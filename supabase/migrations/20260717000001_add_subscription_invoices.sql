-- New table: subscription_invoices.
--
-- Stores the Stripe *subscription* invoices that pay for company recurring billing:
--   - type='plan'  -> the SaaS plan subscription (Essential/Professional/Enterprise)
--   - type='topup' -> a top-up subscription (Benefits or Group Investment Plan)
-- differentiated by `type`, with a single `item_name` label (plan name for 'plan',
-- top-up kind for 'topup'). Salary/late-fee invoices live in the separate
-- salary_invoices table; these never mix.
--
-- Populated from Stripe by the invoice webhook (app/api/stripe/webhooks/invoice)
-- and a one-time backfill route; upserts are keyed on stripe_invoice_id.

create table if not exists public.subscription_invoices (
  id                      uuid primary key default gen_random_uuid(),
  company_id              uuid not null references public.companies(id) on delete cascade,

  -- Stripe identifiers
  stripe_invoice_id       text not null,
  stripe_subscription_id  text,
  stripe_customer_id      text,

  -- Classification
  type                    text not null check (type in ('plan', 'topup')),
  item_name               text,
  plan_id                 uuid references public.plans(id) on delete set null,
  topup_id                uuid references public.topups(id) on delete set null,

  -- Invoice figures (dollars — Stripe cents / 100), in the invoice's own currency
  number                  text,
  amount_due              numeric,
  amount_paid             numeric,
  amount_remaining        numeric,
  subtotal                numeric,
  tax                     numeric,
  total                   numeric,
  discount_total          numeric,
  currency                text,

  -- State
  status                  text,   -- Stripe status: draft/open/paid/void/uncollectible
  billing_reason          text,
  collection_method       text,

  -- Dates
  period_start            timestamptz,
  period_end              timestamptz,
  due_date                timestamptz,
  stripe_created_at       timestamptz,

  -- Links + raw payload
  hosted_invoice_url      text,
  invoice_pdf             text,
  raw_payload             jsonb,

  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

-- One row per Stripe invoice (upsert conflict target).
create unique index if not exists subscription_invoices_stripe_invoice_id_key
  on public.subscription_invoices (stripe_invoice_id);

create index if not exists subscription_invoices_company_id_idx
  on public.subscription_invoices (company_id);

create index if not exists subscription_invoices_type_idx
  on public.subscription_invoices (type);

create index if not exists subscription_invoices_stripe_created_at_idx
  on public.subscription_invoices (stripe_created_at desc);

comment on table public.subscription_invoices is
  'Stripe subscription invoices for company recurring billing: SaaS plan (type=plan) '
  'and top-ups (type=topup, item_name = Benefits | Group Investment Plan). Salary/late-fee '
  'invoices live in salary_invoices. Synced from Stripe via the invoice webhook + backfill; '
  'upserts keyed on stripe_invoice_id.';
comment on column public.subscription_invoices.type is 'plan (SaaS subscription) or topup (Benefits / Group Investment Plan)';
comment on column public.subscription_invoices.item_name is 'Plan name for type=plan; top-up kind (Benefits | Group Investment Plan) for type=topup';
comment on column public.subscription_invoices.total is 'Invoice total in `currency` (Stripe amount / 100)';

-- Access: service-role only. All reads/writes go through the Next.js backend
-- (supabaseAdmin, service role). RLS on with no policies blocks anon/authenticated.
alter table public.subscription_invoices enable row level security;

grant select, insert, update, delete on public.subscription_invoices to service_role;

-- Refresh PostgREST's schema cache so the new table is picked up immediately.
notify pgrst, 'reload schema';
