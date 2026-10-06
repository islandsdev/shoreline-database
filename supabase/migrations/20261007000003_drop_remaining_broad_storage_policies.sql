-- ---------------------------------------------------------------------------------
-- Drop the broad storage policies that 20261007000000 missed on production.
--
-- 20261007000000 dropped the staging policy names; production created the same
-- dashboard policies under different names ("test company policy 1bny57f_*",
-- "Allow authenticated users to upload documents 1t7ma14_*", ...), so the advisor
-- still flags public_bucket_allows_listing there. This matches on the bucket a
-- policy targets instead of its name, so it works in both environments.
--
--   - companies: drop every policy except the three scoped ones 20261007000000
--     created. The SPA's resume upload is covered by those; the backend logo
--     upload (signup) uses the service role.
--   - team-documents: drop every policy. Nothing references this bucket.
--   - company_logos: drop the broad SELECT policy only. Nothing in the code uses
--     this bucket (logos go to `companies`), and public object URLs don't need it.
--
-- All three buckets stay public, so existing public URLs keep working.
-- ---------------------------------------------------------------------------------

BEGIN;

DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND (
        (
          coalesce(qual, '') || ' ' || coalesce(with_check, '') ~ '''companies'''
          AND policyname NOT IN (
            'companies: read own uploads',
            'companies: signed-in users upload',
            'companies: update own uploads'
          )
        )
        OR coalesce(qual, '') || ' ' || coalesce(with_check, '') ~ '''team-documents'''
        OR (cmd = 'SELECT' AND coalesce(qual, '') ~ '''company_logos''')
      )
  LOOP
    RAISE NOTICE 'dropping storage policy %', pol.policyname;
    EXECUTE format('DROP POLICY %I ON storage.objects', pol.policyname);
  END LOOP;
END $$;

COMMIT;

-- ---------------------------------------------------------------------------------
-- ROLLBACK: the dropped names are printed as NOTICEs when this runs. Recreate only
-- what something turns out to need, scoped to owner_id or a company folder — not
-- `USING (bucket_id = '...')` for everyone.
-- ---------------------------------------------------------------------------------
