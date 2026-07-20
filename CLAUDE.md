# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

This is the **Supabase migrations repository** for the Shoreline project — a Canadian payroll and HR platform. It contains only SQL migrations and Supabase Edge Function deployment scripts. There is no application code here.

## Environments

| Environment | Project Ref |
|-------------|-------------|
| Production  | `krzhosadvjdetijqvggz` |
| Staging     | `oqbkhzrfguyyxktqxwxl` |

## Common Commands

```bash
# Diff schema changes against production
npm run db:production:diff

# Push pending migrations to production
npm run db:production:push

# Diff / push against staging
npm run db:staging:diff
npm run db:staging:push

# Deploy all Edge Functions to staging
npm run functions:staging:deploy

# Deploy all Edge Functions to production
npm run functions:production:deploy
```

Migrations are applied in filename order. Always run `diff` before `push` to verify what will be applied.

## Creating a New Migration

```bash
supabase migration new <description>
```

This creates `supabase/migrations/<timestamp>_<description>.sql`. Write the migration SQL, then push to the target environment.

## Schema Overview

The database is multi-tenant: every table (except global reference tables) has a `company_id` FK to `companies`.

### Core Tables

- **`companies`** — tenant root. Holds billing email, Stripe customer IDs (`customer_stripe_id`, `ach_stripe_customer_id`), `use_ach` flag, `reminders_enabled`, and `reminder_days_before_charge`.
- **`team_members`** — employees and contractors per company. Employment type (`Employee`/`Contractor`), payroll schedule, RRSP plan, contractor-specific fields, and termination fields (`termination_reason`, `termination_effective_date`, `terminated_at`). PK is `id` (renamed from `team_member_id` in migration `20260622190000`; the compat mirror column was dropped in `20260717000003`). Child tables still name their FK column `team_member_id`, but it references `team_members(id)` — a new FK to this table must target `id`.
- **`payroll_schedules`** — date ranges for payroll periods (`Monthly` or `Bi-Weekly`).
- **`payments`** — one row per employee per payroll schedule. Status lifecycle: `upcoming → processing → collected → paid / failed / cancelled`.
- **`plans`** — company subscription plans (`Essential` / `Professional` / `Enterprise`), billing term, Stripe subscription ID.
- **`invoices`** — synced from Stripe; linked to `companies`.

### Payroll & Deductions

- **`cpp_contributions`** / **`eei_contributions`** — Canadian statutory deductions (CPP, EI) per payroll schedule, with a `details` JSON column.
- **`rrsp_plans`** — RRSP contribution config per employee (`percentage` or `flat`, employer/employee amounts, optional tiers).
- **`wip_one_time_payments`** — bonuses, stipends, severance, reimbursements etc., tied to a payroll schedule.

### Cashback System

- **`cashback_config`** — rate configuration (tech vs. non-tech employees). `company_id = NULL` means a global default; a non-null `company_id` overrides the global for that company.
- **`cashback_accruals`** — one row per `payments` row that transitions to `paid`, recorded by the `accrue_cashback` trigger.
- **`cashback_payouts`** — annual rollup per company, unique on `(company_id, payout_year)`.

### Forex

- **`forex_rates`** — CAD/USD rates. `company_id = NULL` is the global rate; non-null is company-scoped. Resolution rule: `WHERE company_id = $id OR company_id IS NULL ORDER BY created_at DESC LIMIT 1`.

### Documents & Compliance

- **`documents`** / **`new_documents`** — file metadata linked to Supabase Storage.
- **`admins`** — internal admin users (separate from `user_roles`).
- **`user_roles`** — maps auth users to `app_role` (`user` / `team_member`).
- **`corrections`** — payroll correction records.
- **`addresses`** — normalised address table used by `team_members`.

### Reminders

- **`invoice_reminders`** — dedup log for email reminders; unique on `(company_id, payroll_schedule_id)` to prevent re-sends.
- **`team_member_leaves`** — leave records per employee.

## Key Triggers & Functions

| Trigger / Function | Table | Behaviour |
|--------------------|-------|-----------|
| `accrue_cashback` | `payments` | Fires on INSERT/UPDATE; inserts a `cashback_accruals` row when status becomes `paid`. |
| `autofill_payments_fields` | `payments` | Denormalises employee name/email and company name onto each payment row. |
| `autofill_one_time_payment_fields` | `wip_one_time_payments` | Same denormalisation for one-time payments. |
| `handle_new_plan` | `plans` | Cancels any other active plan for the company when a new plan is `Completed`. |
| `handle_plan_downgrade` | `plans` | Resets all team members to `processing` status on plan change. |
| `set_approved_date` | `team_members` | Stamps `approved_date` when status transitions to `approved`. |
| `auto_populate_plan_details` | `plans` | Sets description and employee limit based on `plan_name`. |

## Edge Functions

Managed via the `supabase functions` CLI. Defined in `supabase/config.toml`. Current functions:

`create-checkout-page`, `create-hellosign-document`, `daily-invoice-job`, `generate-payments`, `hellosign-webhook`, `impersonate`, `Invoice-status-sync`, `send-email`, `send-plan-request`, `subscription-status-sync`, `test-upload-document`, `upload-document`, `wise-webhook`

The `wise-webhook` function has `verify_jwt = false` and a custom `import_map`.
