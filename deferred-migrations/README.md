# Deferred migrations

These SQL files are intentionally OUTSIDE `supabase/migrations/` so they are NOT applied by
`db:staging:push` / `db:production:push` yet. Move a file back into `supabase/migrations/` (and
**re-timestamp it to its actual application date**) only when its precondition is met.

_(Currently empty — no migrations are parked.)_

## History

- `20260622190001_phase2_drop_pk_shims.sql` — **PROMOTED 2026-07-17** to
  `supabase/migrations/20260717000003_phase2_drop_pk_shims.sql`. Drops the Phase 2
  `team_member_id` / `address_id` mirror columns and repoints the team_members trigger functions
  to `id`. On promotion, `accrue_cashback` was DROPPED instead of recreated (its trigger was
  dropped by `20260608132635_v2_cashback.sql`; the old body wrote the since-removed
  `cashback_accruals.payment_id`). Promoted as best-effort — see that migration's header for the
  live-`pg_proc` verification query to run before pushing.
