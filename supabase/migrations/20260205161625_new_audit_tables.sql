drop index if exists "public"."idx_cpp_contributions_team_member_year";

drop index if exists "public"."idx_eei_contributions_team_member_year";

alter table "public"."cpp_contributions" drop column "contribution_year";

alter table "public"."cpp_contributions" add column "details" json;

alter table "public"."cpp_contributions" add column "payroll_schedule_id" uuid;

alter table "public"."eei_contributions" drop column "contribution_year";

alter table "public"."eei_contributions" add column "details" json;

alter table "public"."eei_contributions" add column "payroll_schedule_id" uuid;

alter table "public"."cpp_contributions" add constraint "cpp_contributions_payroll_schedules_fk" FOREIGN KEY (payroll_schedule_id) REFERENCES public.payroll_schedules(id) ON DELETE CASCADE not valid;

alter table "public"."cpp_contributions" validate constraint "cpp_contributions_payroll_schedules_fk";

alter table "public"."eei_contributions" add constraint "eei_contributions_payroll_schedules_fk" FOREIGN KEY (payroll_schedule_id) REFERENCES public.payroll_schedules(id) ON DELETE CASCADE not valid;

alter table "public"."eei_contributions" validate constraint "eei_contributions_payroll_schedules_fk";