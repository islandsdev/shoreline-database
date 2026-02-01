alter table "public"."team_members" add column "address_id" uuid;

alter table "public"."team_members" add constraint "team_members_address_fkey" FOREIGN KEY (address_id) REFERENCES public.addresses(address_id) ON DELETE SET NULL not valid;

alter table "public"."team_members" validate constraint "team_members_address_fkey";