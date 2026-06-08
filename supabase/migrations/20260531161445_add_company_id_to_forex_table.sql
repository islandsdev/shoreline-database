-- Add per-company scope to forex_rates.
-- NULL company_id = global rate (applies to all companies by default).
-- Non-NULL company_id = company-specific rate (scoped to that company only).
--
-- Resolution rule: most recently created applicable rate wins, regardless of scope.
-- Query: WHERE company_id = $companyId OR company_id IS NULL ORDER BY created_at DESC LIMIT 1

ALTER TABLE forex_rates
  ADD COLUMN company_id uuid REFERENCES companies(id) ON DELETE CASCADE;

CREATE INDEX forex_rates_company_id_idx ON forex_rates (company_id);
