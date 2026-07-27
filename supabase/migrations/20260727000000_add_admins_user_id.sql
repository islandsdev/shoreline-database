-- Key admin identity on the stable auth user id instead of the login email.
-- This keeps a user's admin status intact even when their login email changes.
--
-- The `email` column is retained: it is still the notification target for the
-- late-fee digest (getAdminEmails) and remains the human-friendly way to seed a
-- new admin. Identity for all admin gating is now `user_id`.

ALTER TABLE public.admins
  ADD COLUMN user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- Backfill from existing emails (case-insensitive). Any row whose email has no
-- matching auth user is left NULL and will not be recognised as an admin until
-- resolved — verify none remain NULL after applying (see rollout notes).
UPDATE public.admins a
SET user_id = u.id
FROM auth.users u
WHERE a.user_id IS NULL
  AND lower(u.email) = lower(a.email);

-- At most one admin row per auth user. (A unique index permits multiple NULLs,
-- so un-backfilled rows do not conflict.)
CREATE UNIQUE INDEX admins_user_id_key ON public.admins (user_id);

-- Preserve the "add an admin by email" workflow: resolve user_id from
-- auth.users on insert/update whenever it is left NULL, so identity is always
-- stored as user_id even though rows are seeded by email.
CREATE OR REPLACE FUNCTION public.set_admin_user_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.user_id IS NULL AND NEW.email IS NOT NULL THEN
    SELECT id INTO NEW.user_id
    FROM auth.users
    WHERE lower(email) = lower(NEW.email);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER admins_set_user_id
  BEFORE INSERT OR UPDATE ON public.admins
  FOR EACH ROW
  EXECUTE FUNCTION public.set_admin_user_id();
