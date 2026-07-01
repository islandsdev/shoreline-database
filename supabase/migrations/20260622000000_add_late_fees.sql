-- Late-fee / past-due interest feature.
--
-- Terms of service: "Interest will be charged at a rate of 18% per annum
-- (1.5% per month) on any amounts that remain unpaid for more than ten (10)
-- days."
--
-- Design decisions (confirmed with product):
--   * Applies to SALARY invoices only (Stripe + Wise), not subscription invoices.
--   * The 10-day grace is measured from the invoice issue/finalize date. We use
--     invoices.created_at as that reference: the invoice record is written
--     immediately after the Stripe/Wise invoice is finalized in the daily
--     invoice job, so created_at is a faithful proxy for the issue date and
--     needs no backfill.
--   * Flat 1.5% of the outstanding principal per STARTED month past the grace
--     (a partial month is charged in full), simple interest (non-compounding).
--   * Each accrual period is charged via a SEPARATE late-fee invoice, linked
--     back to the original via invoice_late_fees.fee_invoice_id.
--   * Fees are computed nightly (status 'pending_review') and only charged
--     after an admin batch-confirms them.

-- 1. Distinguish late-fee invoices from salary invoices so they are excluded
--    from re-accrual (a late-fee invoice must never grow its own late fee) and
--    can be labelled in the UI.
create type "public"."invoice_type_enum" as enum ('salary', 'late_fee');

alter table "public"."invoices"
  add column "invoice_type" invoice_type_enum not null default 'salary';

-- 2. Audit table: one row per (invoice, month-of-delinquency). Snapshots the
--    principal, rate, fee and days-overdue at accrual time so the charge stays
--    reproducible even if the invoice amount or forex rate later changes.
create table "public"."invoice_late_fees" (
    "id" uuid not null default gen_random_uuid(),
    "created_at" timestamp with time zone not null default now(),
    "company_id" uuid not null,
    "original_invoice_id" uuid not null,
    "period_index" integer not null,
    "principal_amount" numeric not null,
    "rate" numeric not null default 0.015,
    "fee_amount" numeric not null,
    "currency" text not null,
    "days_overdue" integer not null,
    "status" text not null default 'pending_review',
    "fee_invoice_id" uuid,
    "accrued_at" timestamp with time zone not null default now(),
    "approved_by" uuid,
    "approved_at" timestamp with time zone,
    "error_message" text
      );


CREATE UNIQUE INDEX invoice_late_fees_pkey ON public.invoice_late_fees USING btree (id);

-- Idempotency: the nightly cron can never insert the same month's fee twice.
CREATE UNIQUE INDEX invoice_late_fees_invoice_period_key ON public.invoice_late_fees USING btree (original_invoice_id, period_index);

CREATE INDEX invoice_late_fees_status_idx ON public.invoice_late_fees USING btree (status);

CREATE INDEX invoice_late_fees_company_id_idx ON public.invoice_late_fees USING btree (company_id);

CREATE INDEX invoice_late_fees_original_invoice_id_idx ON public.invoice_late_fees USING btree (original_invoice_id);

CREATE INDEX invoice_late_fees_fee_invoice_id_idx ON public.invoice_late_fees USING btree (fee_invoice_id);

alter table "public"."invoice_late_fees" add constraint "invoice_late_fees_pkey" PRIMARY KEY using index "invoice_late_fees_pkey";

alter table "public"."invoice_late_fees" add constraint "invoice_late_fees_invoice_period_key" UNIQUE using index "invoice_late_fees_invoice_period_key";

alter table "public"."invoice_late_fees" add constraint "invoice_late_fees_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE not valid;

alter table "public"."invoice_late_fees" validate constraint "invoice_late_fees_company_id_fkey";

alter table "public"."invoice_late_fees" add constraint "invoice_late_fees_original_invoice_id_fkey" FOREIGN KEY (original_invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE not valid;

alter table "public"."invoice_late_fees" validate constraint "invoice_late_fees_original_invoice_id_fkey";

alter table "public"."invoice_late_fees" add constraint "invoice_late_fees_fee_invoice_id_fkey" FOREIGN KEY (fee_invoice_id) REFERENCES public.invoices(id) ON DELETE SET NULL not valid;

alter table "public"."invoice_late_fees" validate constraint "invoice_late_fees_fee_invoice_id_fkey";

alter table "public"."invoice_late_fees" add constraint "invoice_late_fees_period_index_check" CHECK ((period_index >= 1)) not valid;

alter table "public"."invoice_late_fees" validate constraint "invoice_late_fees_period_index_check";

alter table "public"."invoice_late_fees" add constraint "invoice_late_fees_status_check" CHECK ((status = ANY (ARRAY['pending_review'::text, 'approved'::text, 'invoiced'::text, 'paid'::text, 'cancelled'::text, 'failed'::text]))) not valid;

alter table "public"."invoice_late_fees" validate constraint "invoice_late_fees_status_check";

grant delete on table "public"."invoice_late_fees" to "anon";

grant insert on table "public"."invoice_late_fees" to "anon";

grant references on table "public"."invoice_late_fees" to "anon";

grant select on table "public"."invoice_late_fees" to "anon";

grant trigger on table "public"."invoice_late_fees" to "anon";

grant truncate on table "public"."invoice_late_fees" to "anon";

grant update on table "public"."invoice_late_fees" to "anon";

grant delete on table "public"."invoice_late_fees" to "authenticated";

grant insert on table "public"."invoice_late_fees" to "authenticated";

grant references on table "public"."invoice_late_fees" to "authenticated";

grant select on table "public"."invoice_late_fees" to "authenticated";

grant trigger on table "public"."invoice_late_fees" to "authenticated";

grant truncate on table "public"."invoice_late_fees" to "authenticated";

grant update on table "public"."invoice_late_fees" to "authenticated";

grant delete on table "public"."invoice_late_fees" to "service_role";

grant insert on table "public"."invoice_late_fees" to "service_role";

grant references on table "public"."invoice_late_fees" to "service_role";

grant select on table "public"."invoice_late_fees" to "service_role";

grant trigger on table "public"."invoice_late_fees" to "service_role";

grant truncate on table "public"."invoice_late_fees" to "service_role";

grant update on table "public"."invoice_late_fees" to "service_role";
