-- person_outcomes: drop duplicate constraint first
ALTER TABLE person_outcomes DROP CONSTRAINT IF EXISTS patient_outcomes_patient_unique;
ALTER INDEX IF EXISTS patient_outcomes_patient_id_unique RENAME TO person_outcomes_subject_person_unique;
ALTER INDEX IF EXISTS idx_patient_outcomes_category RENAME TO idx_person_outcomes_category;
ALTER INDEX IF EXISTS idx_patient_outcomes_condition RENAME TO idx_person_outcomes_condition;
ALTER INDEX IF EXISTS idx_patient_outcomes_org RENAME TO idx_person_outcomes_org;
ALTER INDEX IF EXISTS idx_patient_outcomes_responder RENAME TO idx_person_outcomes_responder;

-- clinical_events
ALTER INDEX IF EXISTS idx_clinical_events_patient RENAME TO idx_clinical_events_subject;

-- therapist_services
ALTER INDEX IF EXISTS idx_therapist_services_therapist RENAME TO idx_therapist_services_provider;

-- waitlist
ALTER INDEX IF EXISTS idx_waitlist_therapist_pending RENAME TO idx_waitlist_provider_pending;

-- encounters
DROP INDEX IF EXISTS idx_encounters_patient_migration;
ALTER INDEX IF EXISTS idx_encounters_org_therapist RENAME TO idx_encounters_org_provider;

-- user_device_tokens
ALTER INDEX IF EXISTS user_device_tokens_user_id_token_key RENAME TO user_device_tokens_person_id_token_key;;
