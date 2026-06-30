
-- =============================================================================
-- Drop 20 orphaned functions (reference dropped tables, no trigger/code refs)
-- KEPT: trigger_parse_assessment_to_observations (active trigger on assessment_form_responses)
-- =============================================================================

-- Churn ML functions (5)
DROP FUNCTION IF EXISTS archive_churn_prediction();
DROP FUNCTION IF EXISTS get_high_risk_customers(uuid, integer, integer);
DROP FUNCTION IF EXISTS get_latest_churn_prediction(uuid, uuid);
DROP FUNCTION IF EXISTS record_churn_intervention(uuid, text, text);
DROP FUNCTION IF EXISTS record_churn_outcome(uuid, uuid, text);

-- SMART on FHIR functions (3)
DROP FUNCTION IF EXISTS cleanup_expired_smart_auth_codes();
DROP FUNCTION IF EXISTS cleanup_expired_smart_tokens();
DROP FUNCTION IF EXISTS log_smart_audit_event(text, text, uuid, uuid, text[], text[], boolean, text, text, text, text);

-- FHIR/Posture functions (2)
DROP FUNCTION IF EXISTS insert_fhir_observation_from_soap(integer, uuid, uuid, text, text, text, text, uuid);
DROP FUNCTION IF EXISTS get_photo_comparison(uuid, timestamptz, timestamptz, text);

-- PK module (1)
DROP FUNCTION IF EXISTS get_task_def_id_for_tool_code(text);

-- HR/Scheduling (2)
DROP FUNCTION IF EXISTS check_shift_conflict(uuid, date, time, time, uuid);
DROP FUNCTION IF EXISTS get_available_staff(uuid, date, time, time);

-- Platform admin (1)
DROP FUNCTION IF EXISTS log_platform_admin_activity(text, text, uuid, jsonb);

-- Rate limiting (1)
DROP FUNCTION IF EXISTS record_rate_limit_alert(uuid, text, text, numeric, integer, text, boolean, text);

-- Red flag (2)
DROP FUNCTION IF EXISTS get_red_flag_stats(uuid, date, date);
DROP FUNCTION IF EXISTS get_unacknowledged_red_flag_alerts(uuid, uuid, integer);

-- Terminology (2)
DROP FUNCTION IF EXISTS search_concepts_by_category(text, text, text);
DROP FUNCTION IF EXISTS search_terminology(text, varchar[], integer);

-- Invoice (1)
DROP FUNCTION IF EXISTS generate_invoice_number(uuid);
;
