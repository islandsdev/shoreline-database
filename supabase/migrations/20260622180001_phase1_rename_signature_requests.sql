-- Phase 1b of the DB naming cleanup (see RENAME_PLAN.md).
--
-- Rename new_documents -> signature_requests. Despite the name, this table is NOT a
-- documents store: it is the HelloSign e-signature request lifecycle (status
-- pending -> awaiting_signature -> signed). The resulting signed file is written to
-- the separate "documents" table, which keeps its name.
--
-- 1. Rename the table.
-- 2. Rename the two stale FK constraints + the PK constraint to match.
-- 3. Leave a DEPRECATED, auto-updatable compatibility view at the old name so the
--    5 live .from("new_documents") call sites in shoreline-nextjs keep working
--    (reads + inserts) until they are migrated. The backend Supabase client is
--    untyped (createClient without <Database>), so this does not break the build.
--
-- Pure rename — no data movement. Column-level cleanups identified during
-- investigation are intentionally DEFERRED to later phases:
--   * file_id is redundant with signature_request_id (both hold the HelloSign
--     signature_request_id) -> consolidate to signature_request_id in Phase 3,
--     and update the webhook's .eq("file_id", ...) match at the same time.
--   * file_url appears unused -> verify + drop in Phase 3.
--   * status / type are free strings -> enum candidates in Phase 5.
-- The compatibility view below exposes SELECT *, so all of these columns remain
-- visible to the old name until then.

-- 1. Rename the table -------------------------------------------------------------
ALTER TABLE public.new_documents RENAME TO signature_requests;

-- 2. Rename stale constraint names (idempotent + env-drift safe) -------------------
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('signature_requests', 'new_documents_company_id_fkey',  'signature_requests_company_id_fkey'),
      ('signature_requests', 'new_documents_employee_id_fkey', 'signature_requests_employee_id_fkey')
    ) AS t(tbl, old_name, new_name)
  LOOP
    IF EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conrelid = format('public.%I', r.tbl)::regclass
        AND conname  = r.old_name
    ) THEN
      EXECUTE format('ALTER TABLE public.%I RENAME CONSTRAINT %I TO %I',
                     r.tbl, r.old_name, r.new_name);
    END IF;
  END LOOP;
END $$;

-- Rename the primary-key constraint to match the new table name (best effort).
DO $$
DECLARE
  pk_name text;
BEGIN
  SELECT conname INTO pk_name
  FROM pg_constraint
  WHERE conrelid = 'public.signature_requests'::regclass
    AND contype  = 'p';

  IF pk_name IS NOT NULL AND pk_name <> 'signature_requests_pkey' THEN
    EXECUTE format('ALTER TABLE public.signature_requests RENAME CONSTRAINT %I TO signature_requests_pkey', pk_name);
  END IF;
END $$;

-- 3. Backward-compatibility shim --------------------------------------------------
-- Auto-updatable view (plain SELECT *), so the backend's reads AND inserts pass
-- through to the base table. security_invoker = true makes the view respect the
-- base table's RLS for any non-service-role access.
CREATE VIEW public.new_documents
  WITH (security_invoker = true)
  AS SELECT * FROM public.signature_requests;

COMMENT ON VIEW public.new_documents IS
  'DEPRECATED compatibility shim for the renamed signature_requests table '
  '(HelloSign e-signature requests). shoreline-nextjs still queries this name '
  '(5 call sites). Drop this view once those are migrated. See RENAME_PLAN.md Phase 1b.';

GRANT SELECT, INSERT, UPDATE, DELETE ON public.new_documents
  TO anon, authenticated, service_role;

-- Refresh PostgREST's schema cache so the rename + view are picked up immediately.
NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only):
--
--   DROP VIEW IF EXISTS public.new_documents;
--   ALTER TABLE public.signature_requests RENAME TO new_documents;
--   -- then rename the constraints back to their original names.
--   NOTIFY pgrst, 'reload schema';
-- ---------------------------------------------------------------------------------
