-- 1. Add the reminders_enabled flag on companies (default off so existing                                                                                                                                                   
  --    companies don't start receiving preview emails without opting in).                                                                                                                                                     
  ALTER TABLE companies                                                                                                                                                                                                        
    ADD COLUMN IF NOT EXISTS reminders_enabled BOOLEAN NOT NULL DEFAULT TRUE;                                                                                                                                                 
                                                                                                                                                                                                                               
  -- 2. Tracking table for reminders already sent. The (company_id, payroll_schedule_id)                                                                                                                                       
  --    pair is the dedupe key the cron uses to avoid re-sending on daily re-fires.                                                                                                                                            
  CREATE TABLE IF NOT EXISTS invoice_reminders (                                                                                                                                                                               
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id          UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,                                                                                                                                              
    payroll_schedule_id UUID NOT NULL REFERENCES payroll_schedules(id) ON DELETE CASCADE,                                                                                                                                      
    billing_email       TEXT NOT NULL,                                                                                                                                                                                         
    total_cad           NUMERIC(12, 2) NOT NULL,                                                                                                                                                                               
    total_usd           NUMERIC(12, 2) NOT NULL,
    line_item_count     INTEGER NOT NULL,                                                                                                                                                                                      
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT invoice_reminders_company_schedule_unique                                                                                                                                                                       
      UNIQUE (company_id, payroll_schedule_id)
  );                                                                                                                                                                                                                           
                  
  CREATE INDEX IF NOT EXISTS invoice_reminders_company_id_idx                                                                                                                                                                  
    ON invoice_reminders (company_id);
                                                                                                                                                                                                                               
  CREATE INDEX IF NOT EXISTS invoice_reminders_created_at_idx
    ON invoice_reminders (created_at DESC);                              