# Deferred migrations

These SQL files are intentionally OUTSIDE `supabase/migrations/` so they are NOT applied by
`db:staging:push` / `db:production:push` yet. Move a file back into `supabase/migrations/` (and
**re-timestamp it to its actual application date**) only when its precondition is met.

- `20260622190001_phase2_drop_pk_shims.sql` — drops the Phase 2 `team_member_id` / `address_id`
  GENERATED mirror columns and rewrites the 5 trigger functions to use `id`.
  **Precondition:** the shoreline-nextjs `team_members`-PK call sites have been migrated to `id`
  and deployed (the Phase 2 app codemod — see RENAME_PLAN.md Phase 2). Until then the mirror
  columns must stay so the backend keeps working.
