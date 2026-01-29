drop view if exists "public"."v_active_cashback_rates";
drop view if exists "public"."v_monthly_cashback_summary";
alter table "public"."companies" drop column "payment_method";
alter table "public"."payments" drop column "payment_method"; 