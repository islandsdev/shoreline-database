
  create table "public"."cpp_contributions" (
    "id" uuid not null default gen_random_uuid(),
    "team_member_id" uuid not null,
    "company_id" uuid not null,
    "contribution_year" integer not null,
    "amount" numeric(10,2) not null,
    "invoice_id" uuid,
    "created_at" timestamp with time zone default now()
      );



  create table "public"."eei_contributions" (
    "id" uuid not null default gen_random_uuid(),
    "team_member_id" uuid not null,
    "company_id" uuid not null,
    "contribution_year" integer not null,
    "amount" numeric(10,2) not null,
    "invoice_id" uuid,
    "created_at" timestamp with time zone default now()
      );


CREATE UNIQUE INDEX cpp_contributions_pkey ON public.cpp_contributions USING btree (id);

CREATE UNIQUE INDEX eei_contributions_pkey ON public.eei_contributions USING btree (id);

CREATE INDEX idx_cpp_contributions_team_member_year ON public.cpp_contributions USING btree (team_member_id, contribution_year);

CREATE INDEX idx_eei_contributions_team_member_year ON public.eei_contributions USING btree (team_member_id, contribution_year);

alter table "public"."cpp_contributions" add constraint "cpp_contributions_pkey" PRIMARY KEY using index "cpp_contributions_pkey";

alter table "public"."eei_contributions" add constraint "eei_contributions_pkey" PRIMARY KEY using index "eei_contributions_pkey";

alter table "public"."cpp_contributions" add constraint "cpp_contributions_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE not valid;

alter table "public"."cpp_contributions" validate constraint "cpp_contributions_company_id_fkey";

alter table "public"."cpp_contributions" add constraint "cpp_contributions_invoice_id_fkey" FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE not valid;

alter table "public"."cpp_contributions" validate constraint "cpp_contributions_invoice_id_fkey";

alter table "public"."cpp_contributions" add constraint "cpp_contributions_team_member_id_fkey" FOREIGN KEY (team_member_id) REFERENCES public.team_members(team_member_id) ON DELETE CASCADE not valid;

alter table "public"."cpp_contributions" validate constraint "cpp_contributions_team_member_id_fkey";

alter table "public"."eei_contributions" add constraint "eei_contributions_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE not valid;

alter table "public"."eei_contributions" validate constraint "eei_contributions_company_id_fkey";

alter table "public"."eei_contributions" add constraint "eei_contributions_invoice_id_fkey" FOREIGN KEY (invoice_id) REFERENCES public.invoices(id) ON DELETE CASCADE not valid;

alter table "public"."eei_contributions" validate constraint "eei_contributions_invoice_id_fkey";

alter table "public"."eei_contributions" add constraint "eei_contributions_team_member_id_fkey" FOREIGN KEY (team_member_id) REFERENCES public.team_members(team_member_id) ON DELETE CASCADE not valid;

alter table "public"."eei_contributions" validate constraint "eei_contributions_team_member_id_fkey";

grant delete on table "public"."cpp_contributions" to "anon";

grant insert on table "public"."cpp_contributions" to "anon";

grant references on table "public"."cpp_contributions" to "anon";

grant select on table "public"."cpp_contributions" to "anon";

grant trigger on table "public"."cpp_contributions" to "anon";

grant truncate on table "public"."cpp_contributions" to "anon";

grant update on table "public"."cpp_contributions" to "anon";

grant delete on table "public"."cpp_contributions" to "authenticated";

grant insert on table "public"."cpp_contributions" to "authenticated";

grant references on table "public"."cpp_contributions" to "authenticated";

grant select on table "public"."cpp_contributions" to "authenticated";

grant trigger on table "public"."cpp_contributions" to "authenticated";

grant truncate on table "public"."cpp_contributions" to "authenticated";

grant update on table "public"."cpp_contributions" to "authenticated";

grant delete on table "public"."cpp_contributions" to "service_role";

grant insert on table "public"."cpp_contributions" to "service_role";

grant references on table "public"."cpp_contributions" to "service_role";

grant select on table "public"."cpp_contributions" to "service_role";

grant trigger on table "public"."cpp_contributions" to "service_role";

grant truncate on table "public"."cpp_contributions" to "service_role";

grant update on table "public"."cpp_contributions" to "service_role";

grant delete on table "public"."eei_contributions" to "anon";

grant insert on table "public"."eei_contributions" to "anon";

grant references on table "public"."eei_contributions" to "anon";

grant select on table "public"."eei_contributions" to "anon";

grant trigger on table "public"."eei_contributions" to "anon";

grant truncate on table "public"."eei_contributions" to "anon";

grant update on table "public"."eei_contributions" to "anon";

grant delete on table "public"."eei_contributions" to "authenticated";

grant insert on table "public"."eei_contributions" to "authenticated";

grant references on table "public"."eei_contributions" to "authenticated";

grant select on table "public"."eei_contributions" to "authenticated";

grant trigger on table "public"."eei_contributions" to "authenticated";

grant truncate on table "public"."eei_contributions" to "authenticated";

grant update on table "public"."eei_contributions" to "authenticated";

grant delete on table "public"."eei_contributions" to "service_role";

grant insert on table "public"."eei_contributions" to "service_role";

grant references on table "public"."eei_contributions" to "service_role";

grant select on table "public"."eei_contributions" to "service_role";

grant trigger on table "public"."eei_contributions" to "service_role";

grant truncate on table "public"."eei_contributions" to "service_role";

grant update on table "public"."eei_contributions" to "service_role";