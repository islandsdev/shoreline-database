
  create table "public"."stripe_invoices" (
    "id" uuid not null default gen_random_uuid(),
    "invoice_id" uuid not null,
    "stripe_invoice_id" text not null,
    "stripe_customer_id" text not null,
    "stripe_created_at" timestamp with time zone,
    "raw_payload" jsonb,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."wise_invoices" (
    "id" uuid not null default gen_random_uuid(),
    "invoice_id" uuid not null,
    "wise_invoice_id" text not null,
    "profile_id" text,
    "payment_request_id" text,
    "raw_payload" jsonb,
    "created_at" timestamp with time zone not null default now()
      );


alter table "public"."invoices" add column "provider" public.payment_method not null default 'Stripe'::public.payment_method;

alter table "public"."invoices" alter column "stripe_customer_id" drop not null;

alter table "public"."invoices" alter column "stripe_invoice_id" drop not null;


CREATE UNIQUE INDEX one_stripe_invoice_per_invoice ON public.stripe_invoices USING btree (invoice_id);

CREATE UNIQUE INDEX one_wise_invoice_per_invoice ON public.wise_invoices USING btree (invoice_id);

CREATE UNIQUE INDEX stripe_invoice_unique ON public.stripe_invoices USING btree (stripe_invoice_id);

CREATE UNIQUE INDEX stripe_invoices_pkey ON public.stripe_invoices USING btree (id);

CREATE UNIQUE INDEX wise_invoice_unique ON public.wise_invoices USING btree (wise_invoice_id);

CREATE UNIQUE INDEX wise_invoices_pkey ON public.wise_invoices USING btree (id);

alter table "public"."stripe_invoices" add constraint "stripe_invoices_pkey" PRIMARY KEY using index "stripe_invoices_pkey";

alter table "public"."wise_invoices" add constraint "wise_invoices_pkey" PRIMARY KEY using index "wise_invoices_pkey";

alter table "public"."stripe_invoices" add constraint "stripe_invoice_unique" UNIQUE using index "stripe_invoice_unique";

alter table "public"."stripe_invoices" add constraint "stripe_invoices_invoice_id_fkey" FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE not valid;

alter table "public"."stripe_invoices" validate constraint "stripe_invoices_invoice_id_fkey";

alter table "public"."wise_invoices" add constraint "wise_invoice_unique" UNIQUE using index "wise_invoice_unique";

alter table "public"."wise_invoices" add constraint "wise_invoices_invoice_id_fkey" FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE not valid;

alter table "public"."wise_invoices" validate constraint "wise_invoices_invoice_id_fkey";

grant delete on table "public"."stripe_invoices" to "anon";

grant insert on table "public"."stripe_invoices" to "anon";

grant references on table "public"."stripe_invoices" to "anon";

grant select on table "public"."stripe_invoices" to "anon";

grant trigger on table "public"."stripe_invoices" to "anon";

grant truncate on table "public"."stripe_invoices" to "anon";

grant update on table "public"."stripe_invoices" to "anon";

grant delete on table "public"."stripe_invoices" to "authenticated";

grant insert on table "public"."stripe_invoices" to "authenticated";

grant references on table "public"."stripe_invoices" to "authenticated";

grant select on table "public"."stripe_invoices" to "authenticated";

grant trigger on table "public"."stripe_invoices" to "authenticated";

grant truncate on table "public"."stripe_invoices" to "authenticated";

grant update on table "public"."stripe_invoices" to "authenticated";

grant delete on table "public"."stripe_invoices" to "service_role";

grant insert on table "public"."stripe_invoices" to "service_role";

grant references on table "public"."stripe_invoices" to "service_role";

grant select on table "public"."stripe_invoices" to "service_role";

grant trigger on table "public"."stripe_invoices" to "service_role";

grant truncate on table "public"."stripe_invoices" to "service_role";

grant update on table "public"."stripe_invoices" to "service_role";

grant delete on table "public"."wise_invoices" to "anon";

grant insert on table "public"."wise_invoices" to "anon";

grant references on table "public"."wise_invoices" to "anon";

grant select on table "public"."wise_invoices" to "anon";

grant trigger on table "public"."wise_invoices" to "anon";

grant truncate on table "public"."wise_invoices" to "anon";

grant update on table "public"."wise_invoices" to "anon";

grant delete on table "public"."wise_invoices" to "authenticated";

grant insert on table "public"."wise_invoices" to "authenticated";

grant references on table "public"."wise_invoices" to "authenticated";

grant select on table "public"."wise_invoices" to "authenticated";

grant trigger on table "public"."wise_invoices" to "authenticated";

grant truncate on table "public"."wise_invoices" to "authenticated";

grant update on table "public"."wise_invoices" to "authenticated";

grant delete on table "public"."wise_invoices" to "service_role";

grant insert on table "public"."wise_invoices" to "service_role";

grant references on table "public"."wise_invoices" to "service_role";

grant select on table "public"."wise_invoices" to "service_role";

grant trigger on table "public"."wise_invoices" to "service_role";

grant truncate on table "public"."wise_invoices" to "service_role";

grant update on table "public"."wise_invoices" to "service_role";


