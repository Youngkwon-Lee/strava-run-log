-- verify_migration_integrity: references non-existent therapist_profiles, mvp_patients tables
DROP FUNCTION IF EXISTS verify_migration_integrity();

-- validate_expert_profile_specialties: references non-existent expert_profiles table and om.expert_type column
DROP FUNCTION IF EXISTS validate_expert_profile_specialties() CASCADE;

-- rollback_vla_migration: one-time rollback utility, no longer needed
DROP FUNCTION IF EXISTS rollback_vla_migration();

-- Also drop duplicate check_advanced_expertise_criteria (stub version)
-- Keep the real one that checks certifications
DO $$ BEGIN
  -- Check if there are multiple overloads
  IF (SELECT count(*) FROM pg_proc WHERE proname = 'check_advanced_expertise_criteria' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')) > 1 THEN
    RAISE NOTICE 'Multiple overloads found for check_advanced_expertise_criteria - manual review needed';
  END IF;
END $$;;
