-- DROP FUNCTION public.accrue_cashback();

CREATE OR REPLACE FUNCTION public.accrue_cashback()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
  DECLARE
    v_company_id uuid;
    v_is_tech boolean;
    v_employment_type text;  -- fixed: was boolean, stores 'Employee'/'contractor'/etc.
    v_cashback_rate numeric;
    v_cashback_amount numeric;
    v_accrual_month int;
    v_accrual_year int;
    v_accrual_period date;
  BEGIN
    IF NEW.status = 'paid' AND (OLD.status IS NULL OR OLD.status <> 'paid') THEN

      SELECT tm.company_id, tm.is_tech_employee, tm.employment_type
      INTO v_company_id, v_is_tech, v_employment_type
      FROM team_members tm
      WHERE tm.team_member_id = NEW.team_member_id;

      -- fixed: 3-tier rate logic
      SELECT
        CASE
          WHEN v_is_tech AND v_employment_type = 'Employee'   THEN tech_employee_rate
          WHEN v_is_tech AND v_employment_type = 'Contractor' THEN tech_contractor_rate
          ELSE 0
        END
      INTO v_cashback_rate
      FROM cashback_config
      WHERE (company_id = v_company_id OR company_id IS NULL)
        AND is_active = true
        AND CURRENT_DATE BETWEEN effective_from AND COALESCE(effective_to, '2099-12-31')
      ORDER BY company_id ASC
      LIMIT 1;

      v_cashback_amount := NEW.gross_salary * v_cashback_rate;

      SELECT
        EXTRACT(MONTH FROM start_date)::int,
        EXTRACT(YEAR FROM start_date)::int,
        start_date
      INTO v_accrual_month, v_accrual_year, v_accrual_period
      FROM payroll_schedules
      WHERE id = NEW.payroll_schedule_id;

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
        is_tech_employee,
        is_employee  
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
        v_is_tech,
                (v_employment_type = 'Employee')  -- true if employee, false if contractor/other
      );

    END IF;

    RETURN NEW;
  END;
$function$
;
