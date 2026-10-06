-- ---------------------------------------------------------------------------------
-- Drop the pgjwt extension.
--
-- Supabase's Postgres 17 images don't ship pgjwt, and it blocks the 15 → 17
-- upgrade. Nothing uses it: no function, migration or backend code calls its
-- sign()/verify(); it was only ever installed by 20251227005554_remote_schema.sql.
-- Production had it disabled from the dashboard on 2026-10-07 before upgrading
-- to 17.11.0.003, so this is a no-op there; on staging it removes it ahead of
-- the same upgrade.
--
-- No CASCADE: if anything did depend on it, the migration fails instead of
-- dropping the dependent object.
-- ---------------------------------------------------------------------------------

DROP EXTENSION IF EXISTS pgjwt;
