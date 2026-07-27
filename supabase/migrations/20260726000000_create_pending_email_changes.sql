-- Login-email change with single-confirmation (admin-initiated OR client self-service).
--
-- Used by two flows that share this table:
--   * Admin (Shoreline staff) changes a client user's LOGIN email from the admin
--     panel (Admin -> Companies).
--   * A client changes their own login email from the portal settings page.
--
-- Both send ONE confirmation email to the NEW address via Resend (NOT Supabase
-- SMTP) so the change is verified before it takes effect (a typo can't lock a
-- user out) and so the flow doesn't depend on Supabase's email delivery. We use
-- our own single-use token:
--
--   1. The change is requested -> a row is inserted here (status 'pending')
--      with a sha256 hash of a random token and a 24h expiry.
--   2. ONE email is sent to the NEW address with a confirm link carrying the raw token.
--   3. The new address clicks the link -> the public confirm endpoint validates
--      the token, calls supabaseAdmin.auth.admin.updateUserById(..., { email }),
--      and marks the row 'confirmed'. The login email does not change until then.
--
-- Only the raw token (never stored) can be used to confirm; we store its hash so
-- a DB read cannot be replayed as a valid link. Service-role only — the client
-- never reads this table directly.

CREATE TABLE IF NOT EXISTS public.pending_email_changes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- The auth user whose login email is changing. FK to auth.users so the row is
  -- cleaned up if the user is deleted. (companies.user_id points at the same id.)
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- The company this change relates to (admin picks it; self-service derives it
  -- from the caller). Nullable audit/context only — the change targets user_id.
  company_id uuid REFERENCES public.companies(id) ON DELETE CASCADE,
  -- Snapshot of the login email at request time (for display/audit).
  current_email text NOT NULL,
  -- The requested new login email; applied to auth.users on confirmation.
  new_email text NOT NULL,
  -- sha256(raw token) hex. The raw token exists only in the emailed link.
  token_hash text NOT NULL,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'confirmed', 'failed', 'superseded', 'expired')),
  -- Admin email that initiated the change (audit trail).
  requested_by text,
  -- Populated when a send or finalize step fails (visible + retryable, not a
  -- silently-swallowed side effect).
  last_error text,
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.pending_email_changes IS
  'Single-use tokens for login-email changes (admin-initiated from the companies list, or client self-service from settings). A row is created when the change is requested; one confirmation email (Resend) goes to new_email; clicking the link finalizes the auth.users email change and marks the row confirmed. Service-role only.';
COMMENT ON COLUMN public.pending_email_changes.token_hash IS
  'sha256 hex of the random token. The raw token is never stored — only sent in the confirm link.';
COMMENT ON COLUMN public.pending_email_changes.status IS
  'pending = awaiting click; confirmed = applied; expired = past expires_at; superseded = a newer request for the same user replaced it; failed = send or finalize error (see last_error).';

-- Confirm lookup: the public confirm endpoint finds the row by token hash. Unique
-- so a token maps to exactly one request.
CREATE UNIQUE INDEX IF NOT EXISTS pending_email_changes_token_hash_uidx
  ON public.pending_email_changes (token_hash);

-- Supersede lookup: when a new request comes in we mark this user's prior pending
-- rows superseded so old links die.
CREATE INDEX IF NOT EXISTS pending_email_changes_user_status_idx
  ON public.pending_email_changes (user_id, status);

-- Service-role only: the client never reads this table directly. Enabling RLS
-- with no policies denies anon/authenticated while supabaseAdmin (service role)
-- bypasses RLS. Mirrors off_cycle_payment_notifications / ei_cpp_max_notifications.
ALTER TABLE public.pending_email_changes ENABLE ROW LEVEL SECURITY;

-- Refresh PostgREST's schema cache so the new table is picked up.
NOTIFY pgrst, 'reload schema';

-- ---------------------------------------------------------------------------------
-- ROLLBACK (run manually if needed — Supabase migrations are forward-only):
--
--   DROP TABLE IF EXISTS public.pending_email_changes;
--   NOTIFY pgrst, 'reload schema';
-- ---------------------------------------------------------------------------------
