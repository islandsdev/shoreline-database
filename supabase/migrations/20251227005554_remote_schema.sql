

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgsodium";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."Access" AS ENUM (
    'Employee',
    'Employer'
);


ALTER TYPE "public"."Access" OWNER TO "postgres";


COMMENT ON TYPE "public"."Access" IS 'employer document or employee document';



CREATE TYPE "public"."app_role" AS ENUM (
    'user',
    'team_member'
);


ALTER TYPE "public"."app_role" OWNER TO "postgres";


CREATE TYPE "public"."benefits_status" AS ENUM (
    'Yes',
    'No'
);


ALTER TYPE "public"."benefits_status" OWNER TO "postgres";


CREATE TYPE "public"."billing_term" AS ENUM (
    'Monthly',
    'Yearly'
);


ALTER TYPE "public"."billing_term" OWNER TO "postgres";


CREATE TYPE "public"."contractor_rate_type_enum" AS ENUM (
    'hourly',
    'daily',
    'project',
    'monthly'
);


ALTER TYPE "public"."contractor_rate_type_enum" OWNER TO "postgres";


CREATE TYPE "public"."contribution_type" AS ENUM (
    'percentage',
    'flat'
);


ALTER TYPE "public"."contribution_type" OWNER TO "postgres";


CREATE TYPE "public"."document_tag" AS ENUM (
    'Admin',
    'Contract',
    'Employee',
    'Employer',
    'Paystub',
    'Invoice',
    'Receipt',
    'Agreement'
);


ALTER TYPE "public"."document_tag" OWNER TO "postgres";


CREATE TYPE "public"."employment_term" AS ENUM (
    'Full Time',
    'Part Time'
);


ALTER TYPE "public"."employment_term" OWNER TO "postgres";


CREATE TYPE "public"."employment_type" AS ENUM (
    'Employee',
    'Contractor'
);


ALTER TYPE "public"."employment_type" OWNER TO "postgres";


CREATE TYPE "public"."one_time_payment_type" AS ENUM (
    'Bonus',
    'Stipend',
    'Reimbursement',
    'Severance',
    'Vacation',
    'Other',
    'Adjustment'
);


ALTER TYPE "public"."one_time_payment_type" OWNER TO "postgres";


CREATE TYPE "public"."payment_method" AS ENUM (
    'Stripe',
    'Wise'
);


ALTER TYPE "public"."payment_method" OWNER TO "postgres";


CREATE TYPE "public"."payment_status_enum" AS ENUM (
    'upcoming',
    'processing',
    'collected',
    'paid',
    'failed'
);


ALTER TYPE "public"."payment_status_enum" OWNER TO "postgres";


CREATE TYPE "public"."payment_type_enum" AS ENUM (
    'Debit',
    'Credit'
);


ALTER TYPE "public"."payment_type_enum" OWNER TO "postgres";


CREATE TYPE "public"."payroll_schedule_type" AS ENUM (
    'Monthly',
    'Bi-Weekly'
);


ALTER TYPE "public"."payroll_schedule_type" OWNER TO "postgres";


CREATE TYPE "public"."plan_name_enum" AS ENUM (
    'Essential',
    'Professional',
    'Enterprise'
);


ALTER TYPE "public"."plan_name_enum" OWNER TO "postgres";


CREATE TYPE "public"."plan_status" AS ENUM (
    'Processing',
    'Completed',
    'Cancelled'
);


ALTER TYPE "public"."plan_status" OWNER TO "postgres";


CREATE TYPE "public"."topup_type_enum" AS ENUM (
    'Group Investment Plan',
    'Benefits'
);


ALTER TYPE "public"."topup_type_enum" OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."team_members" (
    "team_member_id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "company_id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "role" "text" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "date_added" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "country" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "phone" "text",
    "address" "text",
    "department" "text" DEFAULT ''::"text",
    "is_employee" "text" DEFAULT ''::"text",
    "salary" numeric DEFAULT 0,
    "first_name" "text" NOT NULL,
    "last_name" "text" NOT NULL,
    "address_1" "text",
    "address_2" "text",
    "city" "text",
    "postal_code" "text",
    "action" character varying(50) DEFAULT NULL::character varying,
    "linkedin" "text",
    "resume_url" "text",
    "approved_date" timestamp with time zone,
    "payroll_schedule" "public"."payroll_schedule_type",
    "associated_contracts" "text"[],
    "state" "text",
    "benefits" "public"."benefits_status" DEFAULT 'No'::"public"."benefits_status",
    "commencement_date" "date",
    "gender" "text",
    "birth_date" "date",
    "social_insurance_number" "text",
    "manager_name" character varying,
    "rrsp_plan_id" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "benefits_start_date" "text",
    "employment_type" "public"."employment_type" DEFAULT 'Employee'::"public"."employment_type" NOT NULL,
    "employment_term" "public"."employment_term" DEFAULT 'Full Time'::"public"."employment_term" NOT NULL,
    "job_description" "text",
    "is_tech_employee" boolean DEFAULT false NOT NULL,
    "is_tech_employee_approved" boolean DEFAULT false NOT NULL,
    "contractor_wsib_wcb" boolean DEFAULT false,
    "contractor_professional_liability" boolean DEFAULT false,
    "contractor_background_check" boolean DEFAULT false,
    "contractor_other" "text",
    "contractor_has_gst_hst" boolean DEFAULT false,
    "contractor_gst_hst_number" "text",
    "contractor_role_title" "text",
    "contractor_scope_of_work" "text",
    "contractor_rate" numeric,
    "contractor_rate_type" "text",
    "contractor_estimated_duration" numeric,
    "contractor_payment_schedule" "text",
    CONSTRAINT "team_members_contractor_rate_type_check" CHECK (("contractor_rate_type" = ANY (ARRAY['hourly'::"text", 'daily'::"text", 'project'::"text", 'monthly'::"text"]))),
    CONSTRAINT "team_members_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'processing'::"text", 'approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."team_members" OWNER TO "postgres";


COMMENT ON COLUMN "public"."team_members"."commencement_date" IS 'Date when the team member starts their employment';



COMMENT ON COLUMN "public"."team_members"."gender" IS 'Gender of the team member';



COMMENT ON COLUMN "public"."team_members"."birth_date" IS 'Birth date of the team member';



COMMENT ON COLUMN "public"."team_members"."social_insurance_number" IS 'Social insurance number of the team member';



COMMENT ON COLUMN "public"."team_members"."contractor_wsib_wcb" IS 'WSIB/WCB Coverage status for contractors';



COMMENT ON COLUMN "public"."team_members"."contractor_professional_liability" IS 'Professional liability insurance status for contractors';



COMMENT ON COLUMN "public"."team_members"."contractor_background_check" IS 'Background check completion status for contractors';



COMMENT ON COLUMN "public"."team_members"."contractor_other" IS 'Other custom requirements for contractors';



CREATE OR REPLACE FUNCTION "public"."approve_team_member"("member_id" "uuid") RETURNS SETOF "public"."team_members"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  RETURN QUERY
  UPDATE team_members
  SET status = 'approved'
  WHERE id = member_id
  RETURNING *;
END;
$$;


ALTER FUNCTION "public"."approve_team_member"("member_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_populate_plan_details"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Set description based on plan name
  CASE NEW.plan_name
    WHEN 'Essential' THEN
      NEW.description := 'Basic compliance support, Standard payroll processing, Email support, Same day onboarding';
      -- Only set number_of_employees if it's not already set by the user
      IF NEW.number_of_employees IS NULL THEN
        NEW.number_of_employees := '1'; -- Changed from previous value to 1
      END IF;
    WHEN 'Professional' THEN
      NEW.description := 'Everything from Essential, plus..., Guaranteed 10% grant cashback on tech hires, Priority support with Slack, Benefits administration, Project, Budget and Time tracking with Timecapsule';
      NEW.number_of_employees := '5';
    WHEN 'Enterprise' THEN
      NEW.description := 'Everything from Professional, plus..., Dedicated Account Manager, Custom compliance consulting, Custom reporting suite, Up to 50% off Timecapsule';
      NEW.number_of_employees := 'unlimited';
  END CASE;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."auto_populate_plan_details"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."autofill_company_name"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Fetch the company_name based on the company_id
  SELECT legal_name INTO NEW.company_name
  FROM companies
  WHERE id = NEW.company_id;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."autofill_company_name"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."autofill_document_metadata"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
DECLARE
  file_name TEXT;
BEGIN
  -- Extract filename from file_path (get everything after the last /)
  file_name := SUBSTRING(NEW.file_path FROM '([^/]+)$');
  
  -- Set the name if not already set by the user
  IF NEW.name IS NULL OR NEW.name = '' THEN
    NEW.name := file_name;
  END IF;
  
  RETURN NEW;
END;
$_$;


ALTER FUNCTION "public"."autofill_document_metadata"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."autofill_one_time_payment_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  fetched_first_name TEXT;
  fetched_last_name TEXT;
  fetched_email TEXT;
  fetched_company_name TEXT;
BEGIN
  -- Fetch employee name and email
  SELECT first_name, last_name, email INTO fetched_first_name, fetched_last_name, fetched_email
  FROM team_members
  WHERE team_member_id = NEW.employee_id;

  -- Fetch company legal name
  SELECT legal_name INTO fetched_company_name
  FROM companies
  WHERE id = NEW.company_id;

  -- Assign the fetched values
  NEW.employee_name = fetched_first_name || ' ' || fetched_last_name;
  NEW.employee_email = fetched_email;
  NEW.company_legal_name = fetched_company_name;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."autofill_one_time_payment_fields"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."autofill_payments_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  fetched_first_name TEXT;
  fetched_last_name TEXT;
  fetched_email TEXT;
  fetched_company_name TEXT;
BEGIN
  -- Fetch employee name and email
  SELECT first_name, last_name, email INTO fetched_first_name, fetched_last_name, fetched_email
  FROM team_members
  WHERE team_member_id = NEW.employee_id;

  -- Fetch company legal name
  SELECT legal_name INTO fetched_company_name
  FROM companies
  WHERE id = NEW.company_id;

  -- Assign the fetched values
  NEW.employee_name = fetched_first_name || ' ' || fetched_last_name;
  NEW.employee_email = fetched_email;
  NEW.company_legal_name = fetched_company_name;

  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."autofill_payments_fields"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."autofill_team_member_email"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  fetched_email TEXT;
BEGIN
  -- Fetch the email based on the team_member_id
  SELECT email INTO fetched_email
  FROM team_members
  WHERE team_member_id = NEW.team_member_id;

  RAISE NOTICE 'Fetched team_member_email: %', fetched_email;

  -- Assign the fetched email to the NEW record
  NEW.team_member_email = fetched_email;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."autofill_team_member_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_employee_company_match"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Check if the selected employee_id belongs to the selected company_id
    IF NOT EXISTS (
        SELECT 1 FROM team_members 
        WHERE team_members.team_member_id = NEW.employee_id
        AND team_members.company_id = NEW.company_id
    ) THEN
        RAISE EXCEPTION 'Selected employee_id does not belong to the given company_id';
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."enforce_employee_company_match"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate-stripe-invoices"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$BEGIN
  PERFORM net.http_post(
    url := 'https://krzhosadvjdetijqvggz.supabase.co/functions/v1/daily-invoice-job',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imtyemhvc2FkdmpkZXRpanF2Z2d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk5NzkzNTEsImV4cCI6MjA1NTU1NTM1MX0.MYyCQtpg17BmmRIHoKhFPVclrUjLFUusKTz6JAuuLgk'
    )
  );
END;$$;


ALTER FUNCTION "public"."generate-stripe-invoices"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_plan"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Only update existing active plans to Cancelled when the new plan is marked as Completed
  IF NEW.status = 'Completed' THEN
    UPDATE plans 
    SET status = 'Cancelled', 
        updated_at = NOW()
    WHERE company_id = NEW.company_id 
      AND status = 'Completed'
      AND id != NEW.id;
  END IF;
    
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_new_plan"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_plan_downgrade"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  previous_plan_name TEXT;
  previous_max_employees TEXT;
  new_max_employees TEXT;
  is_downgrade BOOLEAN := FALSE;
BEGIN
  -- Only run when a plan is marked as completed
  IF NEW.status = 'Completed' THEN
    -- Get the previous active plan
    SELECT plan_name, number_of_employees INTO previous_plan_name, previous_max_employees
    FROM plans
    WHERE company_id = NEW.company_id 
      AND status = 'Completed'
      AND id != NEW.id
      AND updated_at < NEW.updated_at
    ORDER BY updated_at DESC
    LIMIT 1;
    
    -- Get new max employees
    new_max_employees := NEW.number_of_employees;
    
    RAISE NOTICE 'Previous plan: %, Previous max employees: %, New max employees: %', 
      previous_plan_name, previous_max_employees, new_max_employees;
    
    -- Check if it's a downgrade by comparing employee limits
    IF previous_max_employees = 'unlimited' AND new_max_employees != 'unlimited' THEN
      is_downgrade := TRUE;
    ELSIF previous_max_employees IS NOT NULL AND new_max_employees IS NOT NULL THEN
      BEGIN
        IF previous_max_employees::INTEGER > new_max_employees::INTEGER THEN
          is_downgrade := TRUE;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        -- Handle the case when conversion to integer fails
        is_downgrade := FALSE;
      END;
    END IF;
    
    RAISE NOTICE 'Is downgrade: %', is_downgrade;
    
    -- ALWAYS update ALL team members' status to 'processing' on plan change
    -- This ensures the UI will reflect the change and admins can review
    UPDATE team_members
    SET status = 'processing',
        action = NULL -- Reset any pending actions
    WHERE company_id = NEW.company_id;
    
    RAISE NOTICE 'Updated team members to processing for company ID: %', NEW.company_id;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_plan_downgrade"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_role"("_role" "public"."app_role") RETURNS boolean
    LANGUAGE "sql" SECURITY DEFINER
    AS $$
  select exists (
    select 1
    from public.user_roles
    where user_id = auth.uid()
      and role = _role
  );
$$;


ALTER FUNCTION "public"."has_role"("_role" "public"."app_role") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_approved_date"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF NEW.status = 'approved' AND (OLD.status != 'approved' OR OLD.status IS NULL) THEN
    NEW.approved_date = NOW();
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_approved_date"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_company_user_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  IF auth.uid() IS NOT NULL AND NEW.user_id IS NULL THEN
    NEW.user_id := auth.uid();
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_company_user_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_current_timestamp_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_current_timestamp_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."companies" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid",
    "legal_name" "text" NOT NULL,
    "hiring_country" "text" NOT NULL,
    "currency" "text" NOT NULL,
    "purpose" "text" NOT NULL,
    "hiring_timeline" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "company_size" "text" DEFAULT '1-10 employees'::"text" NOT NULL,
    "company_address" "text" DEFAULT ''::"text" NOT NULL,
    "billing_email" "text" DEFAULT ''::"text" NOT NULL,
    "personal_email" "text",
    "logo_path" "text",
    "customer_stripe_id" "text",
    "payment_method" "public"."payment_method" DEFAULT 'Stripe'::"public"."payment_method" NOT NULL
);


ALTER TABLE "public"."companies" OWNER TO "postgres";


COMMENT ON COLUMN "public"."companies"."customer_stripe_id" IS 'The ID of the company in Stripe';



CREATE TABLE IF NOT EXISTS "public"."documents" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "file_path" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "tag" "public"."document_tag" NOT NULL,
    "user_id" "uuid",
    "bucket" character varying DEFAULT 'documents'::character varying
);


ALTER TABLE "public"."documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."forex_rates" (
    "id" bigint NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "rate" numeric NOT NULL
);


ALTER TABLE "public"."forex_rates" OWNER TO "postgres";


COMMENT ON TABLE "public"."forex_rates" IS 'Forex exchange rate between CAD and USD';



ALTER TABLE "public"."forex_rates" ALTER COLUMN "id" ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME "public"."forex_rates_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."invoices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "stripe_invoice_id" "text" NOT NULL,
    "stripe_customer_id" "text" NOT NULL,
    "company_id" "uuid",
    "invoice_number" "text",
    "status" "text",
    "hosted_invoice_url" "text",
    "invoice_pdf" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "stripe_created_at" timestamp with time zone,
    "amount" numeric
);


ALTER TABLE "public"."invoices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."new_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "file_id" character varying NOT NULL,
    "template_id" character varying NOT NULL,
    "title" character varying NOT NULL,
    "type" character varying NOT NULL,
    "status" character varying NOT NULL,
    "file_url" "text",
    "company_id" "uuid" NOT NULL,
    "employee_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."new_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "team_member_id" "uuid" NOT NULL,
    "gross_salary" numeric(10,2) NOT NULL,
    "invoice_id" "uuid",
    "status" "public"."payment_status_enum" DEFAULT 'upcoming'::"public"."payment_status_enum" NOT NULL,
    "payroll_schedule_id" "uuid" NOT NULL,
    "payment_method" "public"."payment_method" DEFAULT 'Stripe'::"public"."payment_method"
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payroll_schedules" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "start_date" "date" NOT NULL,
    "end_date" "date" NOT NULL,
    "type" "public"."payroll_schedule_type" NOT NULL
);


ALTER TABLE "public"."payroll_schedules" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."plans" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "company_id" "uuid" NOT NULL,
    "user_id" "uuid",
    "plan_name" "public"."plan_name_enum" NOT NULL,
    "status" "public"."plan_status" DEFAULT 'Processing'::"public"."plan_status" NOT NULL,
    "price" numeric,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "number_of_employees" "text",
    "description" "text",
    "term" "public"."billing_term" DEFAULT 'Monthly'::"public"."billing_term" NOT NULL,
    "stripe_subscription_id" "text"
);


ALTER TABLE "public"."plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."rrsp_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "amount" numeric(10,2) NOT NULL,
    "type" "public"."contribution_type" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "employee_amount" numeric(10,2),
    "team_member_id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL
);


ALTER TABLE "public"."rrsp_plans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."topups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "team_member_id" "uuid",
    "type" "public"."topup_type_enum" NOT NULL,
    "status" "public"."plan_status" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "company_id" "uuid"
);


ALTER TABLE "public"."topups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."wip_one_time_payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "team_member_id" "uuid" NOT NULL,
    "amount" numeric(10,2) NOT NULL,
    "invoice_id" "uuid",
    "description" "text",
    "memo" "text",
    "payment_type" "public"."one_time_payment_type" NOT NULL,
    "status" "public"."payment_status_enum" DEFAULT 'upcoming'::"public"."payment_status_enum" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "payroll_schedule_id" "uuid"
);


ALTER TABLE "public"."wip_one_time_payments" OWNER TO "postgres";


ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_customer_stirpe_id_key" UNIQUE ("customer_stripe_id");



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."forex_rates"
    ADD CONSTRAINT "forex_rates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."new_documents"
    ADD CONSTRAINT "new_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."wip_one_time_payments"
    ADD CONSTRAINT "one_time_payment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_team_member_payroll_schedule_unique" UNIQUE ("team_member_id", "payroll_schedule_id");



ALTER TABLE ONLY "public"."payroll_schedules"
    ADD CONSTRAINT "payroll-schedule_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "paystubs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."rrsp_plans"
    ADD CONSTRAINT "rrsp_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_pkey" PRIMARY KEY ("team_member_id");



ALTER TABLE ONLY "public"."topups"
    ADD CONSTRAINT "topups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "unique_legal_name" UNIQUE ("legal_name");



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "unique_team_member_email" UNIQUE ("email");



CREATE UNIQUE INDEX "unique_active_plan" ON "public"."plans" USING "btree" ("company_id") WHERE ("status" = 'Completed'::"public"."plan_status");



CREATE OR REPLACE TRIGGER "One Time Payments Notification" AFTER INSERT ON "public"."wip_one_time_payments" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://hook.eu2.make.com/dc3s4j1f0yonpq8gvscblmdgjhi866aj', 'POST', '{"Content-type":"application/json"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "RRSP Configuration Changes" AFTER INSERT ON "public"."rrsp_plans" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://hook.eu2.make.com/dc3s4j1f0yonpq8gvscblmdgjhi866aj', 'POST', '{"Content-type":"application/json"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "Team Members Updates" AFTER INSERT OR UPDATE ON "public"."team_members" FOR EACH ROW EXECUTE FUNCTION "supabase_functions"."http_request"('https://hook.eu2.make.com/dc3s4j1f0yonpq8gvscblmdgjhi866aj', 'POST', '{"Content-type":"application/json"}', '{}', '5000');



CREATE OR REPLACE TRIGGER "auto_populate_plan_details_trigger" BEFORE INSERT OR UPDATE ON "public"."plans" FOR EACH ROW EXECUTE FUNCTION "public"."auto_populate_plan_details"();



CREATE OR REPLACE TRIGGER "autofill_document_metadata_trigger" BEFORE INSERT OR UPDATE ON "public"."documents" FOR EACH ROW EXECUTE FUNCTION "public"."autofill_document_metadata"();



CREATE OR REPLACE TRIGGER "before_plan_insert" BEFORE INSERT ON "public"."plans" FOR EACH ROW EXECUTE FUNCTION "public"."handle_new_plan"();



CREATE OR REPLACE TRIGGER "handle_plan_downgrade_trigger" AFTER UPDATE ON "public"."plans" FOR EACH ROW EXECUTE FUNCTION "public"."handle_plan_downgrade"();



CREATE OR REPLACE TRIGGER "set_team_member_approved_date" BEFORE INSERT OR UPDATE ON "public"."team_members" FOR EACH ROW EXECUTE FUNCTION "public"."set_approved_date"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."team_members" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trg_companies_set_user_id" BEFORE INSERT ON "public"."companies" FOR EACH ROW EXECUTE FUNCTION "public"."set_company_user_id"();



ALTER TABLE ONLY "public"."companies"
    ADD CONSTRAINT "companies_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documents"
    ADD CONSTRAINT "documents_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."new_documents"
    ADD CONSTRAINT "new_documents_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."new_documents"
    ADD CONSTRAINT "new_documents_employee_id_fkey" FOREIGN KEY ("employee_id") REFERENCES "public"."team_members"("team_member_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."wip_one_time_payments"
    ADD CONSTRAINT "one_time_payment_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."invoices"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."wip_one_time_payments"
    ADD CONSTRAINT "one_time_payment_team_member_id_fkey" FOREIGN KEY ("team_member_id") REFERENCES "public"."team_members"("team_member_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."invoices"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_payroll_schedule_id_fkey" FOREIGN KEY ("payroll_schedule_id") REFERENCES "public"."payroll_schedules"("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "paystubs_team_member_id_fkey" FOREIGN KEY ("team_member_id") REFERENCES "public"."team_members"("team_member_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."plans"
    ADD CONSTRAINT "plans_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."rrsp_plans"
    ADD CONSTRAINT "rrsp_plans_team_member_id_fkey" FOREIGN KEY ("team_member_id") REFERENCES "public"."team_members"("team_member_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."team_members"
    ADD CONSTRAINT "team_members_rrsp_plan_id_fkey" FOREIGN KEY ("rrsp_plan_id") REFERENCES "public"."rrsp_plans"("id") ON UPDATE CASCADE ON DELETE SET NULL;



ALTER TABLE ONLY "public"."topups"
    ADD CONSTRAINT "topups_company_id_fkey" FOREIGN KEY ("company_id") REFERENCES "public"."companies"("id");



ALTER TABLE ONLY "public"."topups"
    ADD CONSTRAINT "topups_team_member_id_fkey" FOREIGN KEY ("team_member_id") REFERENCES "public"."team_members"("team_member_id");



ALTER TABLE ONLY "public"."wip_one_time_payments"
    ADD CONSTRAINT "wip_one_time_payments_payroll_schedule_id_fkey" FOREIGN KEY ("payroll_schedule_id") REFERENCES "public"."payroll_schedules"("id");



CREATE POLICY "All users can delete payments" ON "public"."payments" FOR DELETE USING (true);



CREATE POLICY "Allow authenticated users to insert documents" ON "public"."documents" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow users to view documents" ON "public"."documents" FOR SELECT USING (true);



CREATE POLICY "Anyone can create company" ON "public"."companies" FOR INSERT TO "authenticated", "anon" WITH CHECK (true);



CREATE POLICY "Enable insert access for authenticated users" ON "public"."team_members" FOR INSERT WITH CHECK (true);



CREATE POLICY "Enable read access for all users" ON "public"."invoices" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."payments" FOR SELECT USING (true);



CREATE POLICY "Enable read access for all users" ON "public"."team_members" FOR SELECT USING (true);



CREATE POLICY "Enable update access for authenticated users" ON "public"."team_members" FOR UPDATE USING (true);



CREATE POLICY "Users can create plans for their company" ON "public"."plans" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."companies"
  WHERE (("companies"."id" = "plans"."company_id") AND ("companies"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can delete their own documents" ON "public"."documents" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert their own documents" ON "public"."documents" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can manage their plans" ON "public"."plans" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can see only their documents" ON "public"."documents" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can update own company" ON "public"."companies" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own company data" ON "public"."companies" FOR UPDATE TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update their own documents" ON "public"."documents" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view and update their own company data" ON "public"."companies" TO "authenticated" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own company" ON "public"."companies" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own company data" ON "public"."companies" FOR SELECT TO "authenticated" USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view their company plans" ON "public"."plans" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."companies"
  WHERE (("companies"."id" = "plans"."company_id") AND ("companies"."user_id" = "auth"."uid"())))));



CREATE POLICY "Users can view their company team members" ON "public"."team_members" USING (("company_id" IN ( SELECT "c"."id"
   FROM "public"."companies" "c"
  WHERE ("c"."user_id" = "auth"."uid"()))));



CREATE POLICY "Users can view their own documents" ON "public"."documents" FOR SELECT USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."companies" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."forex_rates" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "insert_plans_policy" ON "public"."plans" FOR INSERT WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."invoices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."plans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "read_plans_policy" ON "public"."plans" FOR SELECT USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."team_members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "update_plans_policy" ON "public"."plans" FOR UPDATE USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";












GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";









































































































































































































GRANT ALL ON TABLE "public"."team_members" TO "anon";
GRANT ALL ON TABLE "public"."team_members" TO "authenticated";
GRANT ALL ON TABLE "public"."team_members" TO "service_role";



GRANT ALL ON FUNCTION "public"."approve_team_member"("member_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."approve_team_member"("member_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."approve_team_member"("member_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."auto_populate_plan_details"() TO "anon";
GRANT ALL ON FUNCTION "public"."auto_populate_plan_details"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."auto_populate_plan_details"() TO "service_role";



GRANT ALL ON FUNCTION "public"."autofill_company_name"() TO "anon";
GRANT ALL ON FUNCTION "public"."autofill_company_name"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."autofill_company_name"() TO "service_role";



GRANT ALL ON FUNCTION "public"."autofill_document_metadata"() TO "anon";
GRANT ALL ON FUNCTION "public"."autofill_document_metadata"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."autofill_document_metadata"() TO "service_role";



GRANT ALL ON FUNCTION "public"."autofill_one_time_payment_fields"() TO "anon";
GRANT ALL ON FUNCTION "public"."autofill_one_time_payment_fields"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."autofill_one_time_payment_fields"() TO "service_role";



GRANT ALL ON FUNCTION "public"."autofill_payments_fields"() TO "anon";
GRANT ALL ON FUNCTION "public"."autofill_payments_fields"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."autofill_payments_fields"() TO "service_role";



GRANT ALL ON FUNCTION "public"."autofill_team_member_email"() TO "anon";
GRANT ALL ON FUNCTION "public"."autofill_team_member_email"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."autofill_team_member_email"() TO "service_role";



GRANT ALL ON FUNCTION "public"."enforce_employee_company_match"() TO "anon";
GRANT ALL ON FUNCTION "public"."enforce_employee_company_match"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."enforce_employee_company_match"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate-stripe-invoices"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate-stripe-invoices"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate-stripe-invoices"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_plan"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_plan"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_plan"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_plan_downgrade"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_plan_downgrade"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_plan_downgrade"() TO "service_role";



GRANT ALL ON FUNCTION "public"."has_role"("_role" "public"."app_role") TO "anon";
GRANT ALL ON FUNCTION "public"."has_role"("_role" "public"."app_role") TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_role"("_role" "public"."app_role") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_approved_date"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_approved_date"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_approved_date"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_company_user_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_company_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_company_user_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_current_timestamp_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_current_timestamp_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_current_timestamp_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";
























GRANT ALL ON TABLE "public"."companies" TO "anon";
GRANT ALL ON TABLE "public"."companies" TO "authenticated";
GRANT ALL ON TABLE "public"."companies" TO "service_role";



GRANT ALL ON TABLE "public"."documents" TO "anon";
GRANT ALL ON TABLE "public"."documents" TO "authenticated";
GRANT ALL ON TABLE "public"."documents" TO "service_role";



GRANT ALL ON TABLE "public"."forex_rates" TO "anon";
GRANT ALL ON TABLE "public"."forex_rates" TO "authenticated";
GRANT ALL ON TABLE "public"."forex_rates" TO "service_role";



GRANT ALL ON SEQUENCE "public"."forex_rates_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."forex_rates_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."forex_rates_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."invoices" TO "anon";
GRANT ALL ON TABLE "public"."invoices" TO "authenticated";
GRANT ALL ON TABLE "public"."invoices" TO "service_role";



GRANT ALL ON TABLE "public"."new_documents" TO "anon";
GRANT ALL ON TABLE "public"."new_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."new_documents" TO "service_role";



GRANT ALL ON TABLE "public"."payments" TO "anon";
GRANT ALL ON TABLE "public"."payments" TO "authenticated";
GRANT ALL ON TABLE "public"."payments" TO "service_role";



GRANT ALL ON TABLE "public"."payroll_schedules" TO "anon";
GRANT ALL ON TABLE "public"."payroll_schedules" TO "authenticated";
GRANT ALL ON TABLE "public"."payroll_schedules" TO "service_role";



GRANT ALL ON TABLE "public"."plans" TO "anon";
GRANT ALL ON TABLE "public"."plans" TO "authenticated";
GRANT ALL ON TABLE "public"."plans" TO "service_role";



GRANT ALL ON TABLE "public"."rrsp_plans" TO "anon";
GRANT ALL ON TABLE "public"."rrsp_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."rrsp_plans" TO "service_role";



GRANT ALL ON TABLE "public"."topups" TO "anon";
GRANT ALL ON TABLE "public"."topups" TO "authenticated";
GRANT ALL ON TABLE "public"."topups" TO "service_role";



GRANT ALL ON TABLE "public"."wip_one_time_payments" TO "anon";
GRANT ALL ON TABLE "public"."wip_one_time_payments" TO "authenticated";
GRANT ALL ON TABLE "public"."wip_one_time_payments" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
