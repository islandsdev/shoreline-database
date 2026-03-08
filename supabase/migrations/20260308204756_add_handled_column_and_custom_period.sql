alter table "public"."invoice_adjustments" add column "admin_handled" boolean not null default false;

alter table "public"."payments" add column "custom_invoice_period_text" character varying;