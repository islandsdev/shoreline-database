
-- Create admins table to store admin email addresses
CREATE TABLE public.admins (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read (to check if they're admin)
CREATE POLICY "Authenticated users can check admin status"
  ON public.admins
  FOR SELECT
  USING (auth.role() = 'authenticated');

-- Only service_role can insert/update/delete admins
-- (no user-facing policies for write operations)
