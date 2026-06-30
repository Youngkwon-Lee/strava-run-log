
-- P2-1: Add problem_type to conditions table
-- Rehab ontology requires 5-type classification (not just medical diagnosis)
ALTER TABLE conditions
  ADD COLUMN problem_type text DEFAULT 'medical_condition';

-- CHECK constraint for valid values
ALTER TABLE conditions
  ADD CONSTRAINT chk_conditions_problem_type
  CHECK (problem_type IN ('medical_condition', 'symptom', 'functional_problem', 'impairment', 'risk_state'));

-- Update existing rows based on code patterns (best-effort classification)
-- Most existing conditions are medical conditions (default), no need for bulk update

COMMENT ON COLUMN conditions.problem_type IS 'Rehab ontology: medical_condition|symptom|functional_problem|impairment|risk_state';

-- Index for filtering by problem_type
CREATE INDEX idx_conditions_problem_type ON conditions(problem_type) WHERE problem_type IS NOT NULL;
;
