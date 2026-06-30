-- Phase 4 remaining: DROP organization_usage (empty, superseded by subscription_usage)
DROP TABLE IF EXISTS organization_usage CASCADE;

-- Phase 1 remaining: goals.patient_id → subject_person_id
ALTER TABLE goals RENAME COLUMN patient_id TO subject_person_id;

-- Rename index to match new column name
DROP INDEX IF EXISTS idx_goals_patient_id;
CREATE INDEX idx_goals_subject_person_id ON goals(subject_person_id);

-- Update RLS policy referencing patient_id
DROP POLICY IF EXISTS "Users can view their own goals" ON goals;
CREATE POLICY "Users can view their own goals" ON goals
  FOR SELECT USING (
    subject_person_id = (SELECT get_my_person_id())
  );

-- DROP broken function (references non-existent goals columns)
DROP FUNCTION IF EXISTS backfill_care_plan_goals();;
