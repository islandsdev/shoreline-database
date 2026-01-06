alter table "public"."cpp_contributions" drop column "amount";

alter table "public"."cpp_contributions" add column "amount_cad" numeric(10,2) not null;

alter table "public"."cpp_contributions" add column "amount_usd" numeric(10,2);

alter table "public"."cpp_contributions" add column "rate" numeric(10,6);

alter table "public"."eei_contributions" drop column "amount";

alter table "public"."eei_contributions" add column "amount_cad" numeric(10,2) not null;

alter table "public"."eei_contributions" add column "amount_usd" numeric(10,2);

alter table "public"."eei_contributions" add column "rate" numeric(10,6);