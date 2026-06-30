-- Phase 1-1: audit_logs - drop redundant user_id (actor_person_id exists)
ALTER TABLE audit_logs DROP COLUMN IF EXISTS user_id;

-- Phase 1-2: Feature flag tables
ALTER TABLE feature_flag_logs RENAME COLUMN user_id TO actor_person_id;
ALTER TABLE feature_flag_logs RENAME COLUMN therapist_id TO target_person_id;
ALTER TABLE feature_flag_overrides RENAME COLUMN user_id TO actor_person_id;
ALTER TABLE feature_flag_overrides RENAME COLUMN therapist_id TO target_person_id;

-- Phase 1-3: PGHD/Device tables
ALTER TABLE pghd_oauth_sessions RENAME COLUMN user_id TO person_id;
ALTER TABLE user_device_tokens RENAME COLUMN user_id TO person_id;

-- Phase 1-4: SMART on FHIR tables
ALTER TABLE smart_audit_log RENAME COLUMN user_id TO practitioner_person_id;
ALTER TABLE smart_audit_log RENAME COLUMN patient_id TO subject_person_id;
ALTER TABLE smart_auth_codes RENAME COLUMN user_id TO practitioner_person_id;
ALTER TABLE smart_auth_codes RENAME COLUMN patient_id TO subject_person_id;
ALTER TABLE smart_tokens RENAME COLUMN user_id TO practitioner_person_id;
ALTER TABLE smart_tokens RENAME COLUMN patient_id TO subject_person_id;

-- Phase 1-5: Clinical/Outcomes tables
ALTER TABLE clinical_events RENAME COLUMN patient_id TO subject_person_id;
ALTER TABLE patient_outcomes RENAME COLUMN patient_id TO subject_person_id;
ALTER TABLE mobile_exercise_sessions RENAME COLUMN patient_id TO subject_person_id;

-- Phase 1-6: Marketplace tables
ALTER TABLE therapist_services RENAME COLUMN therapist_id TO provider_person_id;
ALTER TABLE unified_therapist_proposals RENAME COLUMN therapist_id TO provider_person_id;
ALTER TABLE unified_appointments RENAME COLUMN patient_id TO subject_person_id;
ALTER TABLE unified_appointments RENAME COLUMN professional_id TO provider_person_id;
ALTER TABLE waitlist RENAME COLUMN patient_id TO subject_person_id;
ALTER TABLE waitlist RENAME COLUMN therapist_id TO provider_person_id;

-- Phase 1-7: Rename patient_outcomes table
ALTER TABLE patient_outcomes RENAME TO person_outcomes;;
