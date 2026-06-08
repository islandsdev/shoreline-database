# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Generate TypeScript types from the live database
npm run types:staging:generate      # writes types.ts from staging DB
npm run types:production:generate   # writes types.ts from production DB

# Apply pending migrations
npm run db:staging:push
npm run db:production:push

# Diff local migrations against remote (see what's unapplied)
npm run db:staging:diff
npm run db:production:diff
```

The Supabase CLI must be installed and authenticated (`supabase login`) before running any of these.

## Environments

| | Project ref |
|---|---|
| Production | `krzhosadvjdetijqvggz` |
| Staging | `oqbkhzrfguyyxktqxwxl` |

These are separate databases. Production and Staging do **not** share data. Always test migrations against staging first.

## Adding a Migration

Create a new file in `supabase/migrations/` with the naming convention:

```
YYYYMMDDHHMMSS_short_description.sql
```

Use `supabase migration new <name>` to generate the timestamped filename automatically, then write the SQL inside.

## Schema Overview

Core tables (defined in `20251227005554_remote_schema.sql`):

| Table | Purpose |
|---|---|
| `companies` | Top-level tenant; almost every other table scopes to this |
| `team_members` | Employees/contractors hired via a company. Has `company_id`, `is_tech_employee`, `employment_type`, termination fields |
| `payroll_schedules` | Pay periods (`start_date`, `end_date`, `type`: bi-weekly or monthly) |
| `payments` | One row per team member per pay period. Links to `team_members` and `payroll_schedules`. **No `company_id` column** — reach company via `team_members.company_id` |
| `invoices` | Company-level invoice per pay run. `payments` link to `invoices` via `invoice_id` |
| `plans` / `rrsp_plans` | Benefit plan enrollments per company |
| `new_documents` | HelloSign documents (EOR agreements, placement letters) |
| `wip_one_time_payments` / `topups` | Ad-hoc salary adjustments |
| `forex_rates` | CAD/USD exchange rate cache |

Cashback tables (added `20260103105241`, trigger removed `20260608132635`):

| Table | Purpose |
|---|---|
| `cashback_config` | Rate config per company (or global when `company_id IS NULL`) |
| `cashback_accruals` | One row per eligible payment. Populated by `processCashbackAccruals` in the Next.js cron (the DB trigger was dropped in `v2_cashback`) |
| `cashback_payouts` | Annual payout records per company |

Other tables added via later migrations: `addresses`, `audit_log`, `corrections`, `admins`, `team_member_leaves`.

## Edge Functions

`supabase/functions/` contains legacy Deno edge functions. Most are being migrated to `shoreline-nextjs` API routes. Do not add new logic here — add it to the Next.js backend instead.

The `functions:*:deploy` and `functions:*:download` scripts in `package.json` manage these if they still need to be updated.

## Key Constraints

- `payments` has a unique constraint on `(team_member_id, payroll_schedule_id)` — one payment per employee per pay period.
- `new_documents` has a unique constraint on `file_path`.
- `cashback_accruals` has a unique constraint on `payment_id` — one accrual per payment.
