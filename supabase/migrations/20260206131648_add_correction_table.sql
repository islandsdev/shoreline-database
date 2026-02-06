  create table "public"."invoice_adjustments" (
    "id" uuid not null default gen_random_uuid(),
    "created_at" timestamp with time zone not null default now(),
    "company_id" uuid not null,
    "amount_cad" numeric not null,
    "description" text not null,
    "invoice_id" uuid
      );


CREATE UNIQUE INDEX invoice_adjustments_pkey ON public.invoice_adjustments USING btree (id);

alter table "public"."invoice_adjustments" add constraint "invoice_adjustments_pkey" PRIMARY KEY using index "invoice_adjustments_pkey";

alter table "public"."invoice_adjustments" add constraint "invoice_adjustments_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE not valid;

alter table "public"."invoice_adjustments" validate constraint "invoice_adjustments_company_id_fkey";

alter table "public"."invoice_adjustments" add constraint "invoice_adjustments_invoice_id_fkey" FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE SET NULL not valid;

alter table "public"."invoice_adjustments" validate constraint "invoice_adjustments_invoice_id_fkey";

grant delete on table "public"."invoice_adjustments" to "anon";

grant insert on table "public"."invoice_adjustments" to "anon";

grant references on table "public"."invoice_adjustments" to "anon";

grant select on table "public"."invoice_adjustments" to "anon";

grant trigger on table "public"."invoice_adjustments" to "anon";

grant truncate on table "public"."invoice_adjustments" to "anon";

grant update on table "public"."invoice_adjustments" to "anon";

grant delete on table "public"."invoice_adjustments" to "authenticated";

grant insert on table "public"."invoice_adjustments" to "authenticated";

grant references on table "public"."invoice_adjustments" to "authenticated";

grant select on table "public"."invoice_adjustments" to "authenticated";

grant trigger on table "public"."invoice_adjustments" to "authenticated";

grant truncate on table "public"."invoice_adjustments" to "authenticated";

grant update on table "public"."invoice_adjustments" to "authenticated";

grant delete on table "public"."invoice_adjustments" to "service_role";

grant insert on table "public"."invoice_adjustments" to "service_role";

grant references on table "public"."invoice_adjustments" to "service_role";

grant select on table "public"."invoice_adjustments" to "service_role";

grant trigger on table "public"."invoice_adjustments" to "service_role";

grant truncate on table "public"."invoice_adjustments" to "service_role";

grant update on table "public"."invoice_adjustments" to "service_role";