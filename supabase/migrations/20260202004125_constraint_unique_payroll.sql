alter table "public"."documents" drop constraint "documents_user_id_fkey";

alter table "public"."wip_one_time_payments" drop constraint "wip_one_time_payments_payroll_schedule_id_fkey";

CREATE UNIQUE INDEX payroll_schedules_unique ON public.payroll_schedules USING btree (start_date, end_date, type);

alter table "public"."payroll_schedules" add constraint "payroll_schedules_unique" UNIQUE using index "payroll_schedules_unique";

alter table "public"."documents" add constraint "documents_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE not valid;

alter table "public"."documents" validate constraint "documents_user_id_fkey";

alter table "public"."wip_one_time_payments" add constraint "wip_one_time_payments_payroll_schedule_id_fkey" FOREIGN KEY (payroll_schedule_id) REFERENCES public.payroll_schedules(id) ON DELETE CASCADE not valid;

alter table "public"."wip_one_time_payments" validate constraint "wip_one_time_payments_payroll_schedule_id_fkey";