# Documents are owned by a Company, not by a user

`public.documents` was keyed only by `user_id`, so a document's audience was
whichever auth user happened to be passed at insert time. That made
company-scoped documents impossible to express: the cashback and forex letter
jobs had to look up `companies.user_id` and, when it was null, log
"stored but will not appear in dashboard" and carry on — a document written to
storage that no one could ever see. Because tenancy in this product is the
Company (see `shoreline-nextjs/CONTEXT.md`), we added a `NOT NULL`
`company_id` and made it the sole visibility key. Documents now belong to the
Company; the Client sees them because they belong to that Company, not because
a user id was recorded against them.

## Considered options

- **Resolve `companies.user_id` at write time and keep `user_id` as the key.**
  Cheaper — no migration, no writer changes. Rejected: it reproduces the
  invisible-document bug for any Company without a user, and it re-orphans
  every existing document if a Client's login is ever recreated, which the
  admin portal's "change login email" flow makes a live possibility.
- **Nullable `company_id`.** Rejected: a nullable ownership key means the
  invisible-document state stays representable, which is the whole defect.

## Consequences

- `user_id` is retained but no longer read, and is deprecated for a later drop
  phase (see `RENAME_PLAN.md`). The seven RLS policies that keyed on it were
  dropped, along with the `anon` and `authenticated` grants on the table, since
  no browser code reads or writes the table any more.
- Every writer must now supply a `company_id`. That forced
  `shoreline-vite`'s direct browser insert of résumé documents to move behind
  the API, which it should have been anyway.
- The backfill was total — at migration time all 67 rows mapped to exactly one
  Company, no Company lacked a user, and no user owned two Companies — so no
  legacy rows needed an escape hatch.
