-- Record which Stripe account each payout settled from.
--
-- Shoreline runs TWO Stripe accounts — "cc" (subscriptions) and "ach" (salary
-- invoices / payouts) — and the payout backfill sweeps both. A Stripe payout id
-- (po_…) is unique to ONE account, so a dashboard deep link must be scoped to the
-- owning account (…/{acct_…}/…) or it 404s when viewed under the other account.
-- Persisting the account here lets the admin UI build a correctly-scoped link.
--
-- Nullable: rows predating this column (and any non-Stripe provider) may not have
-- it. Constrained to the two known accounts when present.

alter table public.payouts
  add column if not exists stripe_account text
    check (stripe_account is null or stripe_account in ('cc', 'ach'));

comment on column public.payouts.stripe_account is
  'Which Stripe account this payout settled from: cc (subscriptions) or ach '
  '(salary invoices / payouts). Scopes the admin dashboard deep link to the '
  'owning account. Null for rows predating this column or non-Stripe providers.';

-- Refresh PostgREST's schema cache so the new column is picked up.
notify pgrst, 'reload schema';
