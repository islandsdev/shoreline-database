ALTER TABLE companies ADD COLUMN use_ach boolean NOT NULL DEFAULT true;

ALTER TABLE companies ADD COLUMN ach_stripe_customer_id text;