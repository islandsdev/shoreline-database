-- Add columns to team_members
ALTER TABLE team_members
  ADD COLUMN termination_reason          TEXT,
  ADD COLUMN termination_effective_date  DATE,
  ADD COLUMN terminated_at               TIMESTAMPTZ;

-- Create team_member_leaves table
CREATE TABLE team_member_leaves (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  team_member_id   UUID        NOT NULL REFERENCES team_members(team_member_id),
  leave_type       TEXT        NOT NULL,
  start_date       DATE,
  end_date         DATE,
  description      TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);