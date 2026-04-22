ALTER TYPE public."payment_status_enum" ADD VALUE 'cancelled';

ALTER TABLE companies ADD COLUMN reminder_days_before_charge INT NOT NULL DEFAULT 7;                                                                                                        