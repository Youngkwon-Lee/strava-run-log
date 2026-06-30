-- ============================================
-- Migration: cleanup_legacy_patterns
-- Purpose: Remove all remaining legacy patterns
-- ============================================

-- 1. Replace is_admin_user() policy with is_platform_admin()
DROP POLICY IF EXISTS admin_write_exercises ON exercises;
CREATE POLICY admin_write_exercises ON exercises
  FOR ALL
  USING (is_platform_admin())
  WITH CHECK (is_platform_admin());

-- 2. Drop legacy column indexes
DROP INDEX IF EXISTS idx_persons_legacy_client;
DROP INDEX IF EXISTS idx_persons_legacy_patient;

-- 3. Drop legacy columns from persons
ALTER TABLE persons DROP COLUMN IF EXISTS legacy_client_id;
ALTER TABLE persons DROP COLUMN IF EXISTS legacy_patient_id;

-- 4. Drop deprecated functions
DROP FUNCTION IF EXISTS is_admin_user();
DROP FUNCTION IF EXISTS handle_new_therapist_user() CASCADE;
DROP FUNCTION IF EXISTS is_assigned_therapist(TEXT);
DROP FUNCTION IF EXISTS user_belongs_to_clinic(TEXT);;
