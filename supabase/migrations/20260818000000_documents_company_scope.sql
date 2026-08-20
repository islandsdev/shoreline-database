-- Make public.documents owned by a COMPANY rather than by a user, and give
-- admin-uploaded client documents a private home.
--
-- See shoreline-database/docs/adr/0001-documents-owned-by-company.md and
-- shoreline-nextjs/docs/adr/0001-private-bucket-for-client-documents.md.
--
-- Until now a document's audience was whatever auth user id was passed at
-- insert time. Tenancy in this product is the Company, so "give this company a
-- document" was inexpressible: lib/cashback + lib/forex had to resolve
-- companies.user_id and, when it was null, log "stored but will not appear in
-- dashboard" and carry on -- writing a file nobody could ever see.
--
-- This migration is deliberately ONE file: splitting it would leave a deployed
-- state where company_id is NOT NULL but `anon` still holds GRANT ALL on a
-- table of payroll documents.
--
--   1. Add company_id + the columns the admin upload flow needs.
--   2. Backfill company_id from companies.user_id, then from the
--      <company_id>/... storage path for rows that user is no longer the owner
--      of, and ABORT if any row is still unmappable (better to fail the push
--      than to land half-done).
--   3. company_id NOT NULL + FK + indexes.
--   4. Drop the 7 legacy RLS policies and revoke the anon/authenticated grants
--      -- no browser code reads or writes this table any more.
--   5. Create the private `client-documents` storage bucket.
--
-- user_id is intentionally RETAINED (still written, no longer read) and is
-- deprecated for a later drop phase -- see RENAME_PLAN.md.

-- 1. New columns -------------------------------------------------------------

alter table public.documents
  add column if not exists company_id            uuid,
  add column if not exists team_member_id         uuid,
  add column if not exists content_type           text,
  add column if not exists size_bytes             bigint,
  add column if not exists uploaded_by_admin_id   uuid,
  add column if not exists uploaded_by_admin_email text,
  add column if not exists deleted_at             timestamptz;

comment on column public.documents.company_id is
  'The Company this document belongs to. THE visibility key: a Client sees a document because it belongs to their Company, not because their user id was stamped on it.';
comment on column public.documents.user_id is
  'DEPRECATED -- superseded by company_id, still written for continuity but never read. Scheduled for removal (see RENAME_PLAN.md). Do not add new reads.';
comment on column public.documents.team_member_id is
  'Optional: the Team Member this document is filed against (a placement letter, a paystub). Null = a company-level document. Team Members have no login, so this affects grouping only, never visibility.';
comment on column public.documents.content_type is
  'MIME type captured at upload. The download route previously read this column before it existed, so every download was served as application/octet-stream.';
comment on column public.documents.uploaded_by_admin_id is
  'auth.users id of the Shoreline Admin who uploaded this, matching the created_by convention on invoice_adjustments. Null for documents produced by the client or by a cron job.';
comment on column public.documents.uploaded_by_admin_email is
  'Snapshot of the uploading Admin''s email, so the audit trail survives an admin email change. Never exposed to the Client -- they only see that a document came "from Shoreline".';
comment on column public.documents.deleted_at is
  'Soft delete. Admin-only, and set instead of removing the row or the storage object: these are contracts and payroll documents the Client may already have downloaded.';

-- 2. Backfill ----------------------------------------------------------------
-- companies.user_id is 1:1 with a Company today (verified against production
-- before writing this: 67 documents, 0 with a null user_id, 10 companies, 0
-- with a null user_id, 0 users owning two companies), so this maps every row.

update public.documents d
   set company_id = c.id
  from public.companies c
 where c.user_id = d.user_id
   and d.company_id is null;

-- Second pass, for rows whose stamped user no longer owns any Company. Every
-- bucket lays documents out as `<company_id>/...` -- shoreline-vite writes
-- `${companyId}/resumes/...` (ProfessionalInfo.tsx, Team.tsx) and the admin
-- upload route builds the same shape via buildStoragePath(companyId, ...) -- so
-- the path still names the owner after companies.user_id has moved on. Staging
-- has exactly one such row: a resume uploaded during signup, whose user was
-- later replaced as the Company's owner.
--
-- Cross-checked against staging before relying on it: for all 14 rows the first
-- pass DID map, the path prefix names the same Company the user_id join chose.
-- `split_part` keeps this text-only, so a non-uuid prefix simply matches nothing
-- rather than raising a cast error.
update public.documents d
   set company_id = c.id
  from public.companies c
 where d.company_id is null
   and split_part(d.file_path, '/', 1) = c.id::text;

do $$
declare
  orphans bigint;
begin
  select count(*) into orphans from public.documents where company_id is null;
  if orphans > 0 then
    raise exception
      'documents_company_scope: % document row(s) could not be mapped to a company -- neither via companies.user_id nor from the <company_id>/... storage path. Resolve these rows before pushing -- do NOT relax company_id to nullable, which would re-create the invisible-document bug this migration exists to fix.',
      orphans;
  end if;
end $$;

-- 3. Constraints + indexes ---------------------------------------------------

alter table public.documents
  alter column company_id set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.documents'::regclass
       and conname  = 'documents_company_id_fkey'
  ) then
    alter table public.documents
      add constraint documents_company_id_fkey
      foreign key (company_id) references public.companies(id) on delete cascade;
  end if;

  if not exists (
    select 1 from pg_constraint
     where conrelid = 'public.documents'::regclass
       and conname  = 'documents_team_member_id_fkey'
  ) then
    -- set null, not cascade: losing a Team Member row must not destroy the
    -- company's copy of their contract.
    alter table public.documents
      add constraint documents_team_member_id_fkey
      foreign key (team_member_id) references public.team_members(id) on delete set null;
  end if;
end $$;

-- The list query for both portals: one company's live documents, newest first.
create index if not exists documents_company_created_idx
  on public.documents (company_id, created_at desc)
  where deleted_at is null;

create index if not exists documents_team_member_idx
  on public.documents (team_member_id)
  where team_member_id is not null;

-- 4. Lock the table down -----------------------------------------------------
-- Every read and write goes through supabaseAdmin (service role, bypasses RLS).
-- The last browser-side writer (shoreline-vite's resume insert) moves behind the
-- API in this same change, so nothing outside the service role needs access.
--
-- No replacement policy: a company-scoped policy would have to derive the
-- company from companies.user_id -- exactly the lookup being deprecated above --
-- and would encode the model we are leaving.

drop policy if exists "Allow authenticated users to insert documents" on public.documents;
drop policy if exists "Allow users to view documents"                 on public.documents;
drop policy if exists "Users can delete their own documents"          on public.documents;
drop policy if exists "Users can insert their own documents"          on public.documents;
drop policy if exists "Users can see only their documents"            on public.documents;
drop policy if exists "Users can update their own documents"          on public.documents;
drop policy if exists "Users can view their own documents"            on public.documents;

-- Already enabled in production; asserted here so a fresh environment cannot
-- come up with a policy-less table that is readable by everyone.
alter table public.documents enable row level security;

revoke all on table public.documents from anon;
revoke all on table public.documents from authenticated;

-- 5. Private bucket for admin-uploaded client documents ----------------------
-- The four pre-existing buckets (companies, documents, company_logos,
-- team-documents) are all public: true with no MIME restrictions, and none of
-- them appears in any migration -- they were created by hand, which is why
-- staging and production drifted with no record of it. This one is tracked in
-- SQL on purpose.
--
-- 25 MB, and the allowlist the admin upload route enforces as well. Enforcing
-- it here too means the other storage endpoints cannot be used to smuggle a
-- different content type into this bucket.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'client-documents',
  'client-documents',
  false,
  26214400,
  array[
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'text/csv',
    'image/png',
    'image/jpeg'
  ]
)
on conflict (id) do nothing;
