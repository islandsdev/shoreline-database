-- Generic outbox for internal Slack notifications.
--
-- Business events (contract signed, client activated, employee added, ...) are
-- announced to internal Slack channels. The Slack call is NOT made inline in the
-- request: business logic writes one row here (a fast local INSERT) and the
-- delivery happens out of band — immediately via a post-response task, with the
-- slack-notifications cron as the retry/safety net.
--
-- Why an outbox rather than fire-and-forget: a notification that fails must stay
-- visible and retryable (last_error + attempts + next_attempt_at) instead of
-- disappearing into a swallowed .catch(). Mirrors ei_cpp_max_notifications and
-- off_cycle_payment_notifications, generalized to any event type:
--   * event_type + payload  — the event contract, snapshotted at emit time so a
--     later name/salary/rate change cannot corrupt an unsent notification.
--   * dedupe_key            — unique; makes emit idempotent. Redelivered
--     webhooks (HelloSign, Stripe) and client retries cannot double-post.
--   * channel_id            — resolved at emit time from per-event config, so
--     changing an env var never rewrites already-queued rows.
--   * next_attempt_at       — exponential-backoff gate for the drain.
--
-- This table is deliberately NOT event-specific: adding a notification type
-- needs no migration, only a new event definition in lib/notifications/events/.

CREATE TABLE IF NOT EXISTS public.slack_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- Registry key in lib/notifications/events (e.g. 'contract.signed'). Kept as
  -- free text, not an enum: a new event type must not require a migration.
  event_type text NOT NULL,
  -- Stable identity of the underlying business event, e.g.
  -- 'contract.signed:<signature_request_id>'. Unique (below) => exactly-once post.
  dedupe_key text NOT NULL,
  -- Nullable: an ops/system event need not belong to a tenant.
  company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE,
  -- Slack channel id resolved at emit time (per-event override, else default).
  channel_id text,
  -- The event payload, validated against the event's schema before insert.
  payload jsonb NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
  attempts integer NOT NULL DEFAULT 0,
  last_error text,
  -- Earliest time the next delivery attempt may run (exponential backoff).
  -- NULL = eligible immediately.
  next_attempt_at timestamptz,
  -- Slack message timestamp returned by chat.postMessage (proof of delivery).
  slack_ts text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz
);

COMMENT ON TABLE public.slack_notifications IS
  'Outbox of internal Slack notifications. Business logic enqueues a row (validated payload + resolved channel); the slack-notifications drain posts it via the Slack Web API and marks it sent/failed. Failures are retried with exponential backoff up to the app-level attempt cap.';
COMMENT ON COLUMN public.slack_notifications.event_type IS
  'Event registry key (lib/notifications/events), e.g. contract.signed. Free text so new event types need no migration.';
COMMENT ON COLUMN public.slack_notifications.dedupe_key IS
  'Stable identity of the business event. Unique — makes emit idempotent so redelivered webhooks cannot double-post.';
COMMENT ON COLUMN public.slack_notifications.payload IS
  'Event payload snapshotted at emit time, validated against the event schema. Never re-read from source tables at send time.';
COMMENT ON COLUMN public.slack_notifications.channel_id IS
  'Slack channel resolved at emit time from per-event config; NULL means fall back to the default channel at send time.';
COMMENT ON COLUMN public.slack_notifications.next_attempt_at IS
  'Exponential-backoff gate: the drain skips rows until now() >= next_attempt_at. NULL = eligible immediately.';
COMMENT ON COLUMN public.slack_notifications.status IS
  'pending -> processing -> sent | failed. A row exhausted its retries stays failed with attempts at the cap (no separate dead state).';

-- Exactly-once delivery per business event.
CREATE UNIQUE INDEX IF NOT EXISTS slack_notifications_dedupe_key_uidx
  ON public.slack_notifications (dedupe_key);

-- Drain lookup: oldest eligible pending/failed rows first.
CREATE INDEX IF NOT EXISTS slack_notifications_drain_idx
  ON public.slack_notifications (status, next_attempt_at, created_at);

-- Stuck-row recovery: reclaim rows left 'processing' by a crashed worker.
CREATE INDEX IF NOT EXISTS slack_notifications_processing_idx
  ON public.slack_notifications (status, updated_at);

CREATE INDEX IF NOT EXISTS slack_notifications_company_idx
  ON public.slack_notifications (company_id);

CREATE INDEX IF NOT EXISTS slack_notifications_event_type_idx
  ON public.slack_notifications (event_type, created_at);

-- Service-role only: this outbox is never read by the client directly. Enabling
-- RLS with no policies denies anon/authenticated while supabaseAdmin (service
-- role) bypasses RLS. Mirrors ei_cpp_max_notifications.
ALTER TABLE public.slack_notifications ENABLE ROW LEVEL SECURITY;

-- Refresh PostgREST's schema cache so the new table is picked up.
NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only):
--
--   DROP TABLE IF EXISTS public.slack_notifications;
--   NOTIFY pgrst, 'reload schema';
-- ---------------------------------------------------------------------------------
