
-- Phase A Step 2: Alter column default to SSOT naming
ALTER TABLE exercises ALTER COLUMN applicable_expert_types 
SET DEFAULT ARRAY['physiotherapist','athletic_trainer','pilates_instructor','crossfit_coach','wellness_coach'];

-- Phase A Step 3: Drop old CHECK and add new one for primary_expert_type
ALTER TABLE exercises DROP CONSTRAINT IF EXISTS exercises_primary_expert_type_check;
ALTER TABLE exercises ADD CONSTRAINT exercises_primary_expert_type_check 
CHECK (primary_expert_type = ANY(ARRAY['physiotherapist','athletic_trainer','pilates_instructor','crossfit_coach','wellness_coach','all']));
;
