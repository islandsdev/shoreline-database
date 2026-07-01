-- Add the "Semi-Monthly" value to the payroll_schedule_type enum.
--
-- No seed rows are inserted here: the application's schedule generator
-- (generateScheduleByType in shoreline-nextjs) bootstraps and rolls forward
-- Semi-Monthly periods at runtime via the /api/payments/generate endpoint. This
-- migration only extends the enum.
ALTER TYPE "public"."payroll_schedule_type" ADD VALUE IF NOT EXISTS 'Semi-Monthly';
