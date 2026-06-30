-- 1. Drop duplicate indexes (keep UNIQUE constraint indexes, drop manual idx_*)
DROP INDEX IF EXISTS idx_clinical_guidelines_code;
DROP INDEX IF EXISTS idx_encounter_intake_snapshots_encounter;
DROP INDEX IF EXISTS idx_intake_sessions_token;
DROP INDEX IF EXISTS idx_loinc_codes_code;
DROP INDEX IF EXISTS idx_org_patients_org_person;
DROP INDEX IF EXISTS idx_org_members_rls_reverse;
DROP INDEX IF EXISTS idx_org_usage_period;
DROP INDEX IF EXISTS idx_person_outcomes_subject_person;
DROP INDEX IF EXISTS idx_persons_auth_user;
DROP INDEX IF EXISTS idx_persons_auth_user_id;
DROP INDEX IF EXISTS idx_pk_feature_defs_code;
DROP INDEX IF EXISTS idx_pk_feature_defs_loinc;
DROP INDEX IF EXISTS idx_pk_task_defs_code;
DROP INDEX IF EXISTS idx_platform_admins_person;
DROP INDEX IF EXISTS idx_prognosis_guides_condition_code;
DROP INDEX IF EXISTS idx_rate_limit_alert_settings_org;
DROP INDEX IF EXISTS idx_report_share_tokens_token;
DROP INDEX IF EXISTS idx_icd10_cm_code;
DROP INDEX IF EXISTS idx_icd10_cm_display;
DROP INDEX IF EXISTS idx_term_map_source;
DROP INDEX IF EXISTS idx_term_map_target;
DROP INDEX IF EXISTS idx_term_reg_code;
DROP INDEX IF EXISTS idx_terminology_registry_system_code;
DROP INDEX IF EXISTS idx_ta_code;
DROP INDEX IF EXISTS idx_treatment_code;
DROP INDEX IF EXISTS idx_data_sharing_active;

-- 2. Audit triggers for encounter_notes and encounter_media
CREATE TRIGGER trg_encounter_notes_audit AFTER INSERT OR UPDATE OR DELETE ON encounter_notes FOR EACH ROW EXECUTE FUNCTION log_clinical_event();
CREATE TRIGGER trg_encounter_media_audit AFTER INSERT OR UPDATE OR DELETE ON encounter_media FOR EACH ROW EXECUTE FUNCTION log_clinical_event();

-- 3. prevent_org_id_change for encounter_media and medication_statements
CREATE TRIGGER trg_encounter_media_immutable_org BEFORE UPDATE ON encounter_media FOR EACH ROW EXECUTE FUNCTION prevent_org_id_change();
CREATE TRIGGER trg_medication_statements_immutable_org BEFORE UPDATE ON medication_statements FOR EACH ROW EXECUTE FUNCTION prevent_org_id_change();;
