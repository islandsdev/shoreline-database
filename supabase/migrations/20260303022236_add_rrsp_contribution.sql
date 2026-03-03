
  create table "public"."rrsp_contributions" (
    "id" uuid not null default gen_random_uuid(),
    "team_member_id" uuid not null,
    "company_id" uuid not null,
    "invoice_id" uuid,
    "created_at" timestamp with time zone default now(),
    "amount_cad" numeric(10,2) not null,
    "amount_usd" numeric(10,2),
    "rate" numeric(10,6),
    "details" json,
    "payroll_schedule_id" uuid
      );


alter table "public"."rrsp_plans" add column "annual_dollar_cap" numeric;

CREATE UNIQUE INDEX rrsp_contributions_pkey ON public.rrsp_contributions USING btree (id);

alter table "public"."rrsp_contributions" add constraint "rrsp_contributions_pkey" PRIMARY KEY using index "rrsp_contributions_pkey";

alter table "public"."rrsp_contributions" add constraint "rrsp_contributions_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE not valid;

alter table "public"."rrsp_contributions" validate constraint "rrsp_contributions_company_id_fkey";

alter table "public"."rrsp_contributions" add constraint "rrsp_contributions_invoice_id_fkey" FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE not valid;

alter table "public"."rrsp_contributions" validate constraint "rrsp_contributions_invoice_id_fkey";

alter table "public"."rrsp_contributions" add constraint "rrsp_contributions_payroll_schedules_fk" FOREIGN KEY (payroll_schedule_id) REFERENCES public.payroll_schedules(id) ON DELETE CASCADE not valid;

alter table "public"."rrsp_contributions" validate constraint "rrsp_contributions_payroll_schedules_fk";

alter table "public"."rrsp_contributions" add constraint "rrsp_contributions_team_member_id_fkey" FOREIGN KEY (team_member_id) REFERENCES public.team_members(team_member_id) ON DELETE CASCADE not valid;

alter table "public"."rrsp_contributions" validate constraint "rrsp_contributions_team_member_id_fkey";

grant delete on table "public"."rrsp_contributions" to "anon";

grant insert on table "public"."rrsp_contributions" to "anon";

grant references on table "public"."rrsp_contributions" to "anon";

grant select on table "public"."rrsp_contributions" to "anon";

grant trigger on table "public"."rrsp_contributions" to "anon";

grant truncate on table "public"."rrsp_contributions" to "anon";

grant update on table "public"."rrsp_contributions" to "anon";

grant delete on table "public"."rrsp_contributions" to "authenticated";

grant insert on table "public"."rrsp_contributions" to "authenticated";

grant references on table "public"."rrsp_contributions" to "authenticated";

grant select on table "public"."rrsp_contributions" to "authenticated";

grant trigger on table "public"."rrsp_contributions" to "authenticated";

grant truncate on table "public"."rrsp_contributions" to "authenticated";

grant update on table "public"."rrsp_contributions" to "authenticated";

grant delete on table "public"."rrsp_contributions" to "service_role";

grant insert on table "public"."rrsp_contributions" to "service_role";

grant references on table "public"."rrsp_contributions" to "service_role";

grant select on table "public"."rrsp_contributions" to "service_role";

grant trigger on table "public"."rrsp_contributions" to "service_role";

grant truncate on table "public"."rrsp_contributions" to "service_role";

grant update on table "public"."rrsp_contributions" to "service_role";