# Database Naming Improvement Plan

Plan to clean up table and column naming in the Shoreline Postgres/Supabase schema.
Derived from `shoreline-vite/src/integrations/supabase/types.ts` plus an impact analysis
across all four repos (`shoreline-vite`, `shoreline-nextjs`, `shoreline-database`, `shoreline-finance`).

> **Before running any migration**, verify each column against RLS policies, DB functions
> (`approve_team_member`, `get_cashback_rate`, etc.), triggers, and edge functions — these
> reference column names and are not captured by a simple grep of the app code.

> ⚠️ **SCHEMA DRIFT — this plan was derived from the Vite `types.ts`, which is STALE.** Phase 2
> investigation proved the live schema differs. **Re-validate every remaining phase against the
> authoritative `shoreline-database/types.ts` (regenerated from the live DB) before drafting its
> migration.** Confirmed drifts so far:
> - `cashback_config` rate columns are `tech_employee_rate` / `tech_contractor_rate` (NOT the
>   plan's `tech_employee_rate` / `non_tech_employee_rate`). §3 is wrong for this table.
> - `approve_team_member()` already references `id` (a column that didn't exist) — Phase 2 fixes it.
> - `team_members` has `is_active`, `hours_per_week`, `qb_employee_id`, `terminated_at`,
>   `termination_*` columns not in the original plan; `address` (free text) coexists with
>   `address_id` (FK). Re-check §3/§4 column lists against the live table.

---

## 1. Conventions to adopt first (the north star)

Lock these down so every migration moves toward one target.

| Rule | Convention |
|---|---|
| Tables | plural `snake_case` nouns |
| Primary key | always `id` (uuid) — never `<table>_id` |
| Foreign keys | `<referenced_singular>_id` |
| Booleans | `is_*` / `has_*` prefix, real `boolean` type |
| Timestamps | both `created_at` and `updated_at`, `not null default now()` |
| Money | explicit currency suffix (`_cad` / `_usd`) as the contributions tables already do |
| No redundant prefixes | `companies.address`, not `companies.company_address` |
| Enums | `snake_case` name, **no** `_enum` suffix, one consistent value casing |

---

## 2. Table renames

| Current | Proposed | Why |
|---|---|---|
| `new_documents` | `documents` (after retiring old) | `new_` is not a name |
| `documents` (legacy) | `legacy_documents` → drop | two doc tables is the worst ambiguity in the schema |
| `wip_one_time_payments` | `one_time_payments` | drop the `wip_` |
| `cashback_config` | `cashback_rate_configs` | it's versioned rows (effective_from/to, is_active), so plural |

Optional (bigger lift, see §6): merge `cpp_contributions` + `eei_contributions`.

---

## 3. Column renames

| Table | Current → Proposed |
|---|---|
| `addresses` | `address_id` → `id`; `address_1`/`address_2` → `line1`/`line2`; `state` → `region` |
| `companies` | `company_address` → `address`; `customer_stripe_id` → `stripe_customer_id` (matches `stripe_invoices`); `personal_email` → `contact_email` |
| `invoices` | `invoice_link` → `hosted_url`; `invoice_number` → `number` |
| `plans` | `plan_name` → `name` (or `tier`) |
| `cashback_config` | `tech_employee_rate` → `tech_rate`; `non_tech_employee_rate` → `non_tech_rate` (the DB functions already use `p_tech_rate` / `p_non_tech_rate`) |
| `team_members` | `team_member_id` → `id`; `role` → `job_title`; `manager_name` → `manager_id` (self-ref FK); `date_added` → drop (duplicates `created_at`) |
| `wip_one_time_payments` | `payment_type` → `type` |

---

## 4. Type / data fixes (need a data migration, not just a rename)

| Table.column | Problem | Fix |
|---|---|---|
| `team_members.is_employee` | `string \| null` — duplicates `employment_type` (Employee/Contractor) | drop; derive from `employment_type` |
| `team_members.benefits` | `Yes`/`No` enum | `has_benefits boolean` |
| `team_members.payroll_schedule` | enum column shadows the `payroll_schedules` table | rename → `payroll_frequency` |
| `plans.number_of_employees` | stored as string | `employee_count integer` |

---

## 5. Enum cleanup

- Drop `_enum` suffix: `payment_status_enum` → `payment_status`, `payment_type_enum` → `payment_type`,
  `plan_name_enum` → `plan_tier`, `topup_type_enum` → `topup_type`.
- `Access` (PascalCase, `Employee`/`Employer`) → `portal_access`, lowercase values. Distinct from
  `employment_type`, so keep the type — just rename.
- **Value casing**: standardize on lowercase (`payment_status` already is). This is the **riskiest**
  change — `ALTER TYPE ... RENAME VALUE` plus updating every comparison in code. Do it last and isolated.
- `payment_type_enum` (`Debit`/`Credit`) is not referenced by any table — confirm it's dead before renaming.

---

## 6. Optional structural improvements (bigger lift, real payoff)

- **Merge `cpp_contributions` + `eei_contributions`** → one `statutory_contributions` table with a
  `type` enum (`cpp`, `ei`). They are byte-for-byte identical schemas. Also clarify what `eei` means
  (looks like "employer EI").
- **Extract `team_members.contractor_*`** (13 columns) into a 1:1 `contractor_profiles` table.
  `team_members` is a very wide table where ~half the columns are null for any employee.

---

## 7. Impact analysis

Counts are `files / matches` per repo (excluding `node_modules`, build output, lockfiles).

| Rename target | vite | nextjs | database | Notes |
|---|---|---|---|---|
| `new_documents` | 1f/3m | 6f/8m | 5f/16m | |
| `wip_one_time_payments` | 1f/2m | 11f/16m | 6f/24m | |
| `cashback_config` | 1f/2m | 7f/26m | 4f/73m | |
| `cpp_contributions` | 1f/5m | 7f/11m | 4f/54m | |
| `eei_contributions` | 1f/5m | 7f/11m | 4f/54m | |
| `team_member_id` (PK) | 25f/118m | 38f/207m | 17f/87m | **heaviest by far — ~412 matches / ~80 files** |
| `address_id` | ~10m (10 plain, 5 are `shipping_address_id`) | 3f/13m | 3f/8m | disambiguate from `shipping_address_id` |
| `customer_stripe_id` | 11f/18m | 9f/23m | 5f/8m | |
| `company_address` | 8f/20m | 4f/5m | 1f/1m | |
| `invoice_link` | 10f/17m | 16f/32m | 6f/7m | |
| `invoice_number` | 11f/27m | 13f/34m | 3f/4m | |
| `plan_name` | 10m (after removing `plan_name_enum`) | 5f/9m | 4f/14m | overlaps `plan_name_enum` |
| `number_of_employees` | 4f/8m | 5f/8m | 3f/10m | |
| `date_added` | 4f/9m | 2f/4m | 1f/1m | |
| `manager_name` | 8f/26m | 4f/6m | 1f/1m | |
| `is_employee` | 10f/38m | 2f/3m | 3f/4m | **used in real frontend logic, not just types** |
| `social_insurance_number` | 8f/32m | 1f/2m | 1f/2m | sensitive — note encryption |
| `payment_status_enum` | 1f/8m | 0 | 2f/7m | backend doesn't reference Supabase enum types |
| `payment_type_enum` | 1f/2m | 0 | 1f/2m | |
| `plan_name_enum` | 1f/5m | 0 | 1f/3m | |
| `topup_type_enum` | 1f/5m | 0 | 1f/3m | |
| `one_time_payment_type` | 1f/5m | 0 | 1f/3m | |

### Three findings that change the strategy

1. **The Vite frontend is essentially off direct Supabase queries.** The only live `.from()` calls
   in `shoreline-vite/src` are `.from("companies")` (×2) and `.from("documents")` (×1). Everything
   else is **TypeScript type references** (`Tables<'…'>`, generated types) — those fail at **compile
   time**, which is safe: the build catches them. Runtime breakage in the frontend is near zero.

2. **The Next.js backend holds the runtime risk.** The live, server-side `.from()` queries
   (including `documents` ×4 and `new_documents` ×5 across the backend) are where a rename breaks
   things at runtime, not at build time. Prioritize backend coverage in testing.

3. **`shoreline-database` match counts are mostly immutable history.** Those are existing migration
   files — you do **not** edit them. The real work there is writing **one new migration** per change.
   So the high `database` numbers (e.g. `cashback_config` 73m) overstate effort dramatically.

### Effort tiers (from the data)

| Tier | Items |
|---|---|
| **XL** | `team_member_id` → `id` (PK; ~412 matches, touches `approve_team_member` + every FK) |
| **L** | `is_employee` drop (real frontend logic), enum value re-casing |
| **M** | `customer_stripe_id`, `invoice_link`, `invoice_number`, `manager_name` → `manager_id`, `social_insurance_number`, `benefits` → boolean |
| **S** | `new_documents`, `wip_one_time_payments`, `cashback_config`, `company_address`, `plan_name`, `number_of_employees`, `date_added`, `address_id`, stale FK constraint names |

---

## 8. Migration mechanics

The Next.js backend does direct Supabase/PostgREST queries, so a table/column rename breaks those
queries the instant it lands. Two strategies:

1. **Deprecation window (safest for hot tables)** — rename the real object, then create an updatable
   **view** with the old name pointing at it. PostgREST serves the view; migrate code at your own
   pace, then drop the view.
2. **Big-bang per rename** — rename + update all code refs + regenerate types in one coordinated PR,
   deploy frontend/backend together.

Each rename also requires:

- Update **RLS policies**, **DB functions** (`approve_team_member` returns the `team_members` shape;
  `get_cashback_rate` takes `p_is_tech_employee`; etc.), **triggers**, and **edge functions**.
- Regenerate types: `npm run supabase:generate` (per `shoreline-vite/CLAUDE.md`) **and**
  `shoreline-database/types.ts` (per root `CLAUDE.md` — do not hand-edit it).
- Grep both repos for `from('old_table')`, `.eq('old_col', …)`, and `Tables<'old_table'>` refs.
- Run on the **staging** Supabase DB first (separate database), then production.

`ALTER TABLE … RENAME` and `RENAME COLUMN` are metadata-only — cheap, no table rewrite. The
type/boolean conversions and enum value changes need real data migrations and care.

---

## 9. Suggested sequencing

- [ ] **Phase 0** — ratify the conventions in §1.
- [x] **Phase 1a (S, low risk)** — `wip_one_time_payments` → `one_time_payments` + stale FK
      constraint fixes (`paystubs_team_member_id_fkey` on `payments`, `one_time_payment_*` /
      `wip_one_time_payments_*` on the renamed table), behind a deprecated compat view.
      Drafted: `supabase/migrations/20260622180000_phase1_rename_one_time_payments.sql`.
      Call sites migrated: 13 `.from(...)` + 1 log label, branch
      `chore/db-rename-phase1-call-sites` in shoreline-nextjs. Remaining: deploy (see ordering
      below), then drop the compat view.
- [x] **Phase 1b — `new_documents` → `signature_requests`** (investigated; it's the HelloSign
      e-signature request lifecycle, **not** a file store — `documents` keeps its name). Same
      compat-view pattern as 1a. Drafted:
      `supabase/migrations/20260622180001_phase1_rename_signature_requests.sql`.
      Call sites migrated: 5 `.from("new_documents")` → `signature_requests`, same branch
      `chore/db-rename-phase1-call-sites`. Remaining: deploy (see ordering below), then drop the
      compat view.
      **Note: `types.ts` is stale for this table** — it's missing the `signature_request_id`
      column the code reads/writes; regenerate.
      Deferred column cleanups (later phases, not in the rename migration):
        - Phase 3: `file_id` is redundant with `signature_request_id` (both hold the HelloSign id) →
          consolidate to `signature_request_id`, updating the webhook's `.eq("file_id", …)` match.
        - Phase 3: `file_url` appears unused → verify + drop.
        - Phase 5: `status` (pending/awaiting_signature/signed) and `type` (EMPLOYMENT_AGREEMENT, …)
          are free strings → enum candidates.

  **Combined Phase 1–3 deploy ordering (must be in this sequence):**
  `supabase/migrations/` currently holds exactly the 4 safe-to-apply migrations (180000 Phase 1a,
  180001 Phase 1b, 190000 Phase 2a, 200000 Phase 3). Phase 2b is parked in `deferred-migrations/`.
  1. Push migrations to **staging** (`npm run db:staging:push`). Effect: Phase 1 tables renamed +
     compat views live; Phase 2 PKs renamed + mirror columns live (nothing breaks); Phase 3
     company/invoice columns renamed.
  2. Regenerate types (`shoreline-vite` `npm run supabase:generate`; `shoreline-database/types.ts`).
  3. Deploy the **shoreline-nextjs** branch to staging — it carries the Phase 1 + Phase 3 codemods
     (Phase 2 still rides the mirror columns; its codemod is deferred). The migration must land
     **before or with** this deploy — Phase 3 call sites need the renamed columns present.
  4. Deploy the **shoreline-vite** branch (carries Phase 3 frontend refs + the API JSON-key changes).
     FE + BE Phase 3 changes are coupled and must go together.
  5. Smoke-test staging (payroll/invoice/cashback flows, signup, company setup, invoices list).
  6. Repeat 1–5 for **production**.
  7. Later / paced: do the Phase 2 app codemod (`team_member_id`→`id`), then move
     `deferred-migrations/20260622190001` back into `migrations/` (re-timestamped) to drop the
     mirrors. Separately, drop the Phase 1 compat views (`wip_one_time_payments`, `new_documents`)
     once their call sites are confirmed migrated.

- [~] **Phase 2 (XL)** — PK standardization (`team_members.team_member_id` → `id`,
      `addresses.address_id` → `id`). **A deprecation VIEW is impossible** (the table keeps its
      name, so a view can't share it). Instead: rename the PK, then re-add the old name as a
      read-only `GENERATED ALWAYS AS (id) STORED` **mirror column** so all ~100 existing
      references keep working — same zero-runtime-risk property Phase 1's views had. Two steps:
      - Step A — `supabase/migrations/20260622190000_phase2_standardize_primary_keys.sql`
        (additive: rename + mirror columns; nothing breaks; `approve_team_member` self-fixes).
      - Step B — `deferred-migrations/20260622190001_phase2_drop_pk_shims.sql` (recreate the 5
        trigger fns with `id`, then drop the mirror columns). **Deliberately parked OUTSIDE
        `supabase/migrations/`** so `db:*:push` does NOT apply it yet — applying it before the
        Phase 2 app codemod would break the backend. Move it back (re-timestamped) only after the
        Phase 2 call sites are migrated to `id` and deployed.
      **Findings:** PK confirmed as `team_member_id` (live `types.ts`); `team_members` has NO `id`
      column, so `approve_team_member`'s `WHERE id = member_id` errored on every call — Phase 2
      fixes it. The CREATE TRIGGER DDL for the autofill/enforce triggers is NOT in migration
      history (dashboard-created), so functions are recreated via `CREATE OR REPLACE` (preserves
      bindings); confirm no out-of-band refs via `SELECT proname FROM pg_proc WHERE prosrc ILIKE
      '%team_member_id%'` before Step B.
      **Codemod is CONSERVATIVE & safe by construction:** only certain `team_members`-PK query
      refs change to `id`; a *miss* keeps working via the mirror (just blocks Step B), an
      *over-reach* (renaming a FK ref like `payments.team_member_id`) would be a silent bug —
      so when unsure, leave it. The string `team_member_id` is the correct FK column name on
      ~9 child tables and a pervasive app-layer domain field; those do NOT change.
- [~] **Phase 3 (S–M)** — column renames. **Cannot use the Phase-2 shim**: these columns are
      app-WRITTEN, so a GENERATED mirror breaks inserts/updates and a view can't share the table
      name. But the names are UNAMBIGUOUS, so this is a **coordinated rename + mechanical codemod**
      (migration deploys WITH the codemod; tested on staging before prod). Drafted:
      `supabase/migrations/20260622200000_phase3_rename_company_invoice_columns.sql`:
        - `companies.company_address` → `address`
        - `companies.customer_stripe_id` → `stripe_customer_id` (sibling of `ach_stripe_customer_id`)
        - `companies.personal_email` → `contact_email`
        - `invoices.invoice_link` → `hosted_url`
        - `invoices.invoice_number` → `number`
      Verified: none referenced by any DB function/trigger/RLS in migration history (no function
      recreation needed). Pre-deploy: confirm the `Invoice-status-sync` edge function doesn't write
      `invoice_link`/`invoice_number`. Frontend `types.ts` must be regenerated post-migration.
      **Deferred out of Phase 3:** `plans.plan_name` (→ Phase 5, BEFORE-trigger + enum),
      `plans.number_of_employees` (→ Phase 4, string→int), and `addresses.address_1/2/state` +
      `cashback_config` table rename (optional later batch — note `cashback_config`'s rate columns
      are already cleanly named `tech_employee_rate`/`tech_contractor_rate`; the plan's
      `non_tech_employee_rate` rename target does not exist).
- [ ] **Phase 4 (M–L)** — type/boolean fixes (`is_employee`, `benefits`, `number_of_employees`,
      `payroll_schedule` → `payroll_frequency`). Data migrations.
- [ ] **Phase 5 (L, riskiest)** — enum `_enum` suffix + value-casing cleanup, isolated.
- [ ] **Phase 6 (optional)** — merge `cpp`/`eei` → `statutory_contributions`; extract
      `contractor_profiles`; `manager_name` → `manager_id` FK.

### Stale FK constraint names to fix (cosmetic, but they mislead)

- `payments.paystubs_team_member_id_fkey` (table was renamed from `paystubs`)
- `wip_one_time_payments.one_time_payment_invoice_id_fkey`
- `wip_one_time_payments.one_time_payment_team_member_id_fkey`
