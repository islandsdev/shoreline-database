ALTER TABLE public.companies ADD initialized boolean DEFAULT false NOT NULL;

UPDATE public.companies SET initialized = true WHERE customer_stripe_id IS NOT NULL;