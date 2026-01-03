alter table "public"."team_members" drop constraint "team_members_contractor_rate_type_check";


  create table "public"."cashback_accruals" (
    "id" uuid not null default gen_random_uuid(),
    "company_id" uuid not null,
    "team_member_id" uuid not null,
    "payment_id" uuid not null,
    "payroll_schedule_id" uuid not null,
    "employee_gross_salary" numeric not null,
    "cashback_rate" numeric not null,
    "cashback_amount" numeric not null,
    "accrual_month" integer not null,
    "accrual_year" integer not null,
    "accrual_period" date not null,
    "is_tech_employee" boolean not null,
    "created_at" timestamp with time zone not null default now()
      );



  create table "public"."cashback_config" (
    "id" uuid not null default gen_random_uuid(),
    "company_id" uuid,
    "tech_employee_rate" numeric not null default 0.10,
    "non_tech_employee_rate" numeric not null default 0.05,
    "effective_from" date not null default CURRENT_DATE,
    "effective_to" date,
    "is_active" boolean not null default true,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "created_by" uuid,
    "notes" text
      );



  create table "public"."cashback_payouts" (
    "id" uuid not null default gen_random_uuid(),
    "company_id" uuid not null,
    "payout_year" integer not null,
    "total_cashback_amount" numeric not null,
    "total_accruals_count" integer not null default 0,
    "status" text not null default 'pending'::text,
    "payout_date" timestamp with time zone,
    "payment_method" text,
    "payment_reference" text,
    "notes" text,
    "created_at" timestamp with time zone not null default now(),
    "updated_at" timestamp with time zone not null default now(),
    "processed_at" timestamp with time zone,
    "processed_by" uuid
      );


drop type "public"."contractor_rate_type_enum";

CREATE UNIQUE INDEX cashback_accruals_pkey ON public.cashback_accruals USING btree (id);

CREATE UNIQUE INDEX cashback_config_pkey ON public.cashback_config USING btree (id);

CREATE UNIQUE INDEX cashback_payouts_pkey ON public.cashback_payouts USING btree (id);

CREATE INDEX idx_cashback_accruals_company_period ON public.cashback_accruals USING btree (company_id, accrual_period);

CREATE INDEX idx_cashback_accruals_company_year ON public.cashback_accruals USING btree (company_id, accrual_year);

CREATE INDEX idx_cashback_accruals_payment ON public.cashback_accruals USING btree (payment_id);

CREATE INDEX idx_cashback_accruals_team_member ON public.cashback_accruals USING btree (team_member_id);

CREATE INDEX idx_cashback_config_active ON public.cashback_config USING btree (is_active, effective_from) WHERE (is_active = true);

CREATE INDEX idx_cashback_config_company ON public.cashback_config USING btree (company_id);

CREATE INDEX idx_cashback_config_dates ON public.cashback_config USING btree (effective_from, effective_to);

CREATE INDEX idx_cashback_payouts_company ON public.cashback_payouts USING btree (company_id);

CREATE INDEX idx_cashback_payouts_status ON public.cashback_payouts USING btree (status);

CREATE INDEX idx_cashback_payouts_year ON public.cashback_payouts USING btree (payout_year, status);

CREATE UNIQUE INDEX unique_company_year_payout ON public.cashback_payouts USING btree (company_id, payout_year);

CREATE UNIQUE INDEX unique_payment_cashback ON public.cashback_accruals USING btree (payment_id);

alter table "public"."cashback_accruals" add constraint "cashback_accruals_pkey" PRIMARY KEY using index "cashback_accruals_pkey";

alter table "public"."cashback_config" add constraint "cashback_config_pkey" PRIMARY KEY using index "cashback_config_pkey";

alter table "public"."cashback_payouts" add constraint "cashback_payouts_pkey" PRIMARY KEY using index "cashback_payouts_pkey";

alter table "public"."cashback_accruals" add constraint "cashback_accruals_accrual_month_check" CHECK (((accrual_month >= 1) AND (accrual_month <= 12))) not valid;

alter table "public"."cashback_accruals" validate constraint "cashback_accruals_accrual_month_check";

alter table "public"."cashback_accruals" add constraint "cashback_accruals_accrual_year_check" CHECK ((accrual_year >= 2024)) not valid;

alter table "public"."cashback_accruals" validate constraint "cashback_accruals_accrual_year_check";

alter table "public"."cashback_accruals" add constraint "cashback_accruals_cashback_amount_check" CHECK ((cashback_amount >= (0)::numeric)) not valid;

alter table "public"."cashback_accruals" validate constraint "cashback_accruals_cashback_amount_check";

alter table "public"."cashback_accruals" add constraint "cashback_accruals_cashback_rate_check" CHECK (((cashback_rate >= (0)::numeric) AND (cashback_rate <= (1)::numeric))) not valid;

alter table "public"."cashback_accruals" validate constraint "cashback_accruals_cashback_rate_check";

alter table "public"."cashback_accruals" add constraint "cashback_accruals_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE not valid;

alter table "public"."cashback_accruals" validate constraint "cashback_accruals_company_id_fkey";

alter table "public"."cashback_accruals" add constraint "cashback_accruals_payment_id_fkey" FOREIGN KEY (payment_id) REFERENCES public.payments(id) ON DELETE CASCADE not valid;

alter table "public"."cashback_accruals" validate constraint "cashback_accruals_payment_id_fkey";

alter table "public"."cashback_accruals" add constraint "cashback_accruals_payroll_schedule_id_fkey" FOREIGN KEY (payroll_schedule_id) REFERENCES public.payroll_schedules(id) ON DELETE CASCADE not valid;

alter table "public"."cashback_accruals" validate constraint "cashback_accruals_payroll_schedule_id_fkey";

alter table "public"."cashback_accruals" add constraint "cashback_accruals_team_member_id_fkey" FOREIGN KEY (team_member_id) REFERENCES public.team_members(team_member_id) ON DELETE CASCADE not valid;

alter table "public"."cashback_accruals" validate constraint "cashback_accruals_team_member_id_fkey";

alter table "public"."cashback_accruals" add constraint "unique_payment_cashback" UNIQUE using index "unique_payment_cashback";

alter table "public"."cashback_config" add constraint "cashback_config_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE not valid;

alter table "public"."cashback_config" validate constraint "cashback_config_company_id_fkey";

alter table "public"."cashback_config" add constraint "cashback_config_non_tech_employee_rate_check" CHECK (((non_tech_employee_rate >= (0)::numeric) AND (non_tech_employee_rate <= (1)::numeric))) not valid;

alter table "public"."cashback_config" validate constraint "cashback_config_non_tech_employee_rate_check";

alter table "public"."cashback_config" add constraint "cashback_config_tech_employee_rate_check" CHECK (((tech_employee_rate >= (0)::numeric) AND (tech_employee_rate <= (1)::numeric))) not valid;

alter table "public"."cashback_config" validate constraint "cashback_config_tech_employee_rate_check";

alter table "public"."cashback_config" add constraint "valid_date_range" CHECK (((effective_to IS NULL) OR (effective_to > effective_from))) not valid;

alter table "public"."cashback_config" validate constraint "valid_date_range";

alter table "public"."cashback_config" add constraint "valid_non_tech_rate" CHECK (((non_tech_employee_rate >= (0)::numeric) AND (non_tech_employee_rate <= (1)::numeric))) not valid;

alter table "public"."cashback_config" validate constraint "valid_non_tech_rate";

alter table "public"."cashback_config" add constraint "valid_tech_rate" CHECK (((tech_employee_rate >= (0)::numeric) AND (tech_employee_rate <= (1)::numeric))) not valid;

alter table "public"."cashback_config" validate constraint "valid_tech_rate";

alter table "public"."cashback_payouts" add constraint "cashback_payouts_company_id_fkey" FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE not valid;

alter table "public"."cashback_payouts" validate constraint "cashback_payouts_company_id_fkey";

alter table "public"."cashback_payouts" add constraint "cashback_payouts_payout_year_check" CHECK ((payout_year >= 2024)) not valid;

alter table "public"."cashback_payouts" validate constraint "cashback_payouts_payout_year_check";

alter table "public"."cashback_payouts" add constraint "cashback_payouts_status_check" CHECK ((status = ANY (ARRAY['pending'::text, 'processing'::text, 'completed'::text, 'failed'::text, 'cancelled'::text]))) not valid;

alter table "public"."cashback_payouts" validate constraint "cashback_payouts_status_check";

alter table "public"."cashback_payouts" add constraint "cashback_payouts_total_cashback_amount_check" CHECK ((total_cashback_amount >= (0)::numeric)) not valid;

alter table "public"."cashback_payouts" validate constraint "cashback_payouts_total_cashback_amount_check";

alter table "public"."cashback_payouts" add constraint "unique_company_year_payout" UNIQUE using index "unique_company_year_payout";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.accrue_cashback()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  DECLARE
    v_company_id uuid;
    v_is_tech boolean;
    v_cashback_rate numeric;
    v_cashback_amount numeric;
    v_accrual_month int;
    v_accrual_year int;
    v_accrual_period date;
  BEGIN
    -- Only process when payment status changes to 'paid'
    IF NEW.status = 'paid' AND (OLD.status IS NULL OR OLD.status <> 'paid') THEN

      -- Get company_id and is_tech_employee from team_members
      SELECT tm.company_id, tm.is_tech_employee
      INTO v_company_id, v_is_tech
      FROM team_members tm
      WHERE tm.team_member_id = NEW.team_member_id;

      -- Get cashback rate from config (default to 10% for tech, 5% for non-tech)
      SELECT
        CASE WHEN v_is_tech THEN tech_employee_rate ELSE non_tech_employee_rate END
      INTO v_cashback_rate
      FROM cashback_config
      WHERE company_id = v_company_id
        AND is_active = true
        AND CURRENT_DATE BETWEEN effective_from AND COALESCE(effective_to, '2099-12-31')
      LIMIT 1;

      -- If no config found, use defaults
      IF v_cashback_rate IS NULL THEN
        v_cashback_rate := CASE WHEN v_is_tech THEN 0.10 ELSE 0.05 END;
      END IF;

      -- Calculate cashback amount
      v_cashback_amount := NEW.gross_salary * v_cashback_rate;

      -- Get accrual period from payroll schedule
      SELECT
        EXTRACT(MONTH FROM start_date)::int,
        EXTRACT(YEAR FROM start_date)::int,
        start_date
      INTO v_accrual_month, v_accrual_year, v_accrual_period
      FROM payroll_schedules
      WHERE id = NEW.payroll_schedule_id;

      -- Insert cashback accrual
      INSERT INTO cashback_accruals (
        company_id,
        team_member_id,
        payment_id,
        payroll_schedule_id,
        employee_gross_salary,
        cashback_rate,
        cashback_amount,
        accrual_month,
        accrual_year,
        accrual_period,
        is_tech_employee
      ) VALUES (
        v_company_id,
        NEW.team_member_id,
        NEW.id,
        NEW.payroll_schedule_id,
        NEW.gross_salary,
        v_cashback_rate,
        v_cashback_amount,
        v_accrual_month,
        v_accrual_year,
        v_accrual_period,
        v_is_tech
      );

    END IF;

    RETURN NEW;
  END;
  $function$
;

CREATE OR REPLACE FUNCTION public.create_annual_cashback_payout(p_company_id uuid, p_year integer)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_total_cashback numeric;
  v_accruals_count integer;
  v_payout_id uuid;
BEGIN
  -- Calculate total cashback and count for the year
  SELECT 
    COALESCE(SUM(cashback_amount), 0),
    COUNT(*)
  INTO 
    v_total_cashback,
    v_accruals_count
  FROM public.cashback_accruals
  WHERE company_id = p_company_id
    AND accrual_year = p_year;
  
  -- Only create payout if there's cashback to pay
  IF v_total_cashback > 0 THEN
    INSERT INTO public.cashback_payouts (
      company_id,
      payout_year,
      total_cashback_amount,
      total_accruals_count,
      status
    ) VALUES (
      p_company_id,
      p_year,
      v_total_cashback,
      v_accruals_count,
      'pending'
    )
    ON CONFLICT (company_id, payout_year) 
    DO UPDATE SET
      total_cashback_amount = v_total_cashback,
      total_accruals_count = v_accruals_count,
      updated_at = now()
    RETURNING id INTO v_payout_id;
    
    RETURN v_payout_id;
  ELSE
    RAISE EXCEPTION 'No cashback accruals found for company % in year %', p_company_id, p_year;
  END IF;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_cashback_rate(p_company_id uuid, p_date date, p_is_tech_employee boolean)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_rate numeric;
BEGIN
  -- Try company-specific rate first, then fall back to global default
  SELECT 
    CASE 
      WHEN p_is_tech_employee THEN tech_employee_rate 
      ELSE non_tech_employee_rate 
    END
  INTO v_rate
  FROM public.cashback_config
  WHERE (company_id = p_company_id OR company_id IS NULL)
    AND effective_from <= p_date
    AND (effective_to IS NULL OR effective_to > p_date)
    AND is_active = true
  ORDER BY 
    company_id NULLS LAST, -- Prefer company-specific over global
    effective_from DESC
  LIMIT 1;
  
  -- Fallback to default if no config found
  RETURN COALESCE(v_rate, CASE WHEN p_is_tech_employee THEN 0.10 ELSE 0.05 END);
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_company_cashback_balance(p_company_id uuid, p_year integer DEFAULT NULL::integer)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_year integer;
BEGIN
  v_year := COALESCE(p_year, EXTRACT(YEAR FROM CURRENT_DATE)::integer);
  
  RETURN (
    SELECT COALESCE(SUM(cashback_amount), 0)
    FROM public.cashback_accruals
    WHERE company_id = p_company_id
      AND accrual_year = v_year
  );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_cashback_rates(p_company_id uuid, p_tech_rate numeric, p_non_tech_rate numeric, p_effective_from date, p_notes text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_new_config_id uuid;
BEGIN
  -- Validate rates
  IF p_tech_rate < 0 OR p_tech_rate > 1 THEN
    RAISE EXCEPTION 'Tech rate must be between 0 and 1';
  END IF;
  
  IF p_non_tech_rate < 0 OR p_non_tech_rate > 1 THEN
    RAISE EXCEPTION 'Non-tech rate must be between 0 and 1';
  END IF;
  
  -- Deactivate current active config
  UPDATE public.cashback_config
  SET 
    is_active = false,
    effective_to = p_effective_from - INTERVAL '1 day',
    updated_at = now()
  WHERE (company_id = p_company_id OR (company_id IS NULL AND p_company_id IS NULL))
    AND is_active = true
    AND effective_from < p_effective_from;
  
  -- Insert new config
  INSERT INTO public.cashback_config (
    company_id,
    tech_employee_rate,
    non_tech_employee_rate,
    effective_from,
    is_active,
    notes,
    created_by
  ) VALUES (
    p_company_id,
    p_tech_rate,
    p_non_tech_rate,
    p_effective_from,
    true,
    p_notes,
    p_created_by
  )
  RETURNING id INTO v_new_config_id;
  
  RETURN v_new_config_id;
END;
$function$
;

create or replace view "public"."v_active_cashback_rates" as  SELECT cc.id,
    cc.company_id,
    c.legal_name AS company_name,
        CASE
            WHEN (cc.company_id IS NULL) THEN '🌍 Global Default'::text
            ELSE c.legal_name
        END AS scope,
    cc.tech_employee_rate,
    cc.non_tech_employee_rate,
    cc.effective_from,
    cc.notes,
    cc.created_at
   FROM (public.cashback_config cc
     LEFT JOIN public.companies c ON ((cc.company_id = c.id)))
  WHERE (cc.is_active = true)
  ORDER BY cc.company_id NULLS FIRST, cc.effective_from DESC;


create or replace view "public"."v_monthly_cashback_summary" as  SELECT ca.company_id,
    c.legal_name AS company_name,
    ca.accrual_year,
    ca.accrual_month,
    ca.accrual_period,
    to_char((ca.accrual_period)::timestamp with time zone, 'Month YYYY'::text) AS month_name,
    to_char((ca.accrual_period)::timestamp with time zone, 'YYYY-MM'::text) AS month_key,
    count(*) AS total_payments,
    count(DISTINCT ca.team_member_id) AS unique_employees,
    sum(ca.cashback_amount) AS total_cashback,
    sum(
        CASE
            WHEN ca.is_tech_employee THEN ca.cashback_amount
            ELSE (0)::numeric
        END) AS tech_cashback,
    sum(
        CASE
            WHEN (NOT ca.is_tech_employee) THEN ca.cashback_amount
            ELSE (0)::numeric
        END) AS non_tech_cashback,
    sum(
        CASE
            WHEN ca.is_tech_employee THEN 1
            ELSE 0
        END) AS tech_employee_count,
    sum(
        CASE
            WHEN (NOT ca.is_tech_employee) THEN 1
            ELSE 0
        END) AS non_tech_employee_count,
    sum(ca.employee_gross_salary) AS total_salaries_paid,
    avg(ca.cashback_rate) AS avg_cashback_rate
   FROM (public.cashback_accruals ca
     JOIN public.companies c ON ((ca.company_id = c.id)))
  GROUP BY ca.company_id, c.legal_name, ca.accrual_year, ca.accrual_month, ca.accrual_period;


grant delete on table "public"."cashback_accruals" to "anon";

grant insert on table "public"."cashback_accruals" to "anon";

grant references on table "public"."cashback_accruals" to "anon";

grant select on table "public"."cashback_accruals" to "anon";

grant trigger on table "public"."cashback_accruals" to "anon";

grant truncate on table "public"."cashback_accruals" to "anon";

grant update on table "public"."cashback_accruals" to "anon";

grant delete on table "public"."cashback_accruals" to "authenticated";

grant insert on table "public"."cashback_accruals" to "authenticated";

grant references on table "public"."cashback_accruals" to "authenticated";

grant select on table "public"."cashback_accruals" to "authenticated";

grant trigger on table "public"."cashback_accruals" to "authenticated";

grant truncate on table "public"."cashback_accruals" to "authenticated";

grant update on table "public"."cashback_accruals" to "authenticated";

grant delete on table "public"."cashback_accruals" to "service_role";

grant insert on table "public"."cashback_accruals" to "service_role";

grant references on table "public"."cashback_accruals" to "service_role";

grant select on table "public"."cashback_accruals" to "service_role";

grant trigger on table "public"."cashback_accruals" to "service_role";

grant truncate on table "public"."cashback_accruals" to "service_role";

grant update on table "public"."cashback_accruals" to "service_role";

grant delete on table "public"."cashback_config" to "anon";

grant insert on table "public"."cashback_config" to "anon";

grant references on table "public"."cashback_config" to "anon";

grant select on table "public"."cashback_config" to "anon";

grant trigger on table "public"."cashback_config" to "anon";

grant truncate on table "public"."cashback_config" to "anon";

grant update on table "public"."cashback_config" to "anon";

grant delete on table "public"."cashback_config" to "authenticated";

grant insert on table "public"."cashback_config" to "authenticated";

grant references on table "public"."cashback_config" to "authenticated";

grant select on table "public"."cashback_config" to "authenticated";

grant trigger on table "public"."cashback_config" to "authenticated";

grant truncate on table "public"."cashback_config" to "authenticated";

grant update on table "public"."cashback_config" to "authenticated";

grant delete on table "public"."cashback_config" to "service_role";

grant insert on table "public"."cashback_config" to "service_role";

grant references on table "public"."cashback_config" to "service_role";

grant select on table "public"."cashback_config" to "service_role";

grant trigger on table "public"."cashback_config" to "service_role";

grant truncate on table "public"."cashback_config" to "service_role";

grant update on table "public"."cashback_config" to "service_role";

grant delete on table "public"."cashback_payouts" to "anon";

grant insert on table "public"."cashback_payouts" to "anon";

grant references on table "public"."cashback_payouts" to "anon";

grant select on table "public"."cashback_payouts" to "anon";

grant trigger on table "public"."cashback_payouts" to "anon";

grant truncate on table "public"."cashback_payouts" to "anon";

grant update on table "public"."cashback_payouts" to "anon";

grant delete on table "public"."cashback_payouts" to "authenticated";

grant insert on table "public"."cashback_payouts" to "authenticated";

grant references on table "public"."cashback_payouts" to "authenticated";

grant select on table "public"."cashback_payouts" to "authenticated";

grant trigger on table "public"."cashback_payouts" to "authenticated";

grant truncate on table "public"."cashback_payouts" to "authenticated";

grant update on table "public"."cashback_payouts" to "authenticated";

grant delete on table "public"."cashback_payouts" to "service_role";

grant insert on table "public"."cashback_payouts" to "service_role";

grant references on table "public"."cashback_payouts" to "service_role";

grant select on table "public"."cashback_payouts" to "service_role";

grant trigger on table "public"."cashback_payouts" to "service_role";

grant truncate on table "public"."cashback_payouts" to "service_role";

grant update on table "public"."cashback_payouts" to "service_role";

CREATE TRIGGER trigger_accrue_cashback AFTER INSERT OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.accrue_cashback();


