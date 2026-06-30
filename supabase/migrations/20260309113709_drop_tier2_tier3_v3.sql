
-- =============================================================================
-- Tier 2 + Tier 3 DROP: 62 tables + dead views/functions
-- CASCADE on all to handle hidden view/function deps
-- pghd_code_mappings KEPT (v_unified_observations → risk engine)
-- =============================================================================

-- ── Tier 2: SMART on FHIR ──
DROP TABLE IF EXISTS smart_audit_log CASCADE;
DROP TABLE IF EXISTS smart_auth_codes CASCADE;
DROP TABLE IF EXISTS smart_tokens CASCADE;
DROP TABLE IF EXISTS fhir_resources CASCADE;

-- ── Tier 2: Telehealth ──
DROP TABLE IF EXISTS telehealth_org_config CASCADE;
DROP TABLE IF EXISTS telehealth_sessions CASCADE;

-- ── Tier 2: Marketplace v1 ──
DROP TABLE IF EXISTS marketplace_appointments CASCADE;
DROP TABLE IF EXISTS marketplace_proposals CASCADE;
DROP TABLE IF EXISTS marketplace_requests_private CASCADE;
DROP TABLE IF EXISTS match_candidates CASCADE;
DROP TABLE IF EXISTS expert_certifications CASCADE;
DROP TABLE IF EXISTS expert_reviews CASCADE;

-- ── Tier 2: Churn ML ──
DROP TABLE IF EXISTS churn_prediction_history CASCADE;
DROP TABLE IF EXISTS churn_predictions CASCADE;

-- ── Tier 2: PGHD (pghd_code_mappings KEPT) ──
DROP TABLE IF EXISTS pghd_daily_summaries CASCADE;
DROP TABLE IF EXISTS pghd_oauth_sessions CASCADE;

-- ── Tier 2: RTW ──
DROP TABLE IF EXISTS rtw_milestones CASCADE;
DROP TABLE IF EXISTS vla_pattern_types CASCADE;

-- ── Tier 2: Rate Limiting ──
DROP TABLE IF EXISTS rate_limit_alert_history CASCADE;
DROP TABLE IF EXISTS rate_limit_alert_settings CASCADE;

-- ── Tier 2: Workflow ──
DROP TABLE IF EXISTS workflow_steps CASCADE;
DROP TABLE IF EXISTS domain_registry CASCADE;
DROP TABLE IF EXISTS service_line_registry CASCADE;

-- ── Tier 2: PK Module ──
DROP TABLE IF EXISTS pk_features CASCADE;
DROP TABLE IF EXISTS pk_feedback CASCADE;
DROP TABLE IF EXISTS pk_task_defs CASCADE;

-- ── Tier 3: Legacy remnants ──
DROP TABLE IF EXISTS allergy_intolerances CASCADE;
DROP TABLE IF EXISTS clinical_aha_moments CASCADE;
DROP TABLE IF EXISTS condition_settings CASCADE;
DROP TABLE IF EXISTS diagnostic_reports CASCADE;
DROP TABLE IF EXISTS dunning_attempts CASCADE;
DROP TABLE IF EXISTS exercise_medication_interactions CASCADE;
DROP TABLE IF EXISTS exercise_promotion_logs CASCADE;
DROP TABLE IF EXISTS habit_completions CASCADE;
DROP TABLE IF EXISTS instrument_parser_mapping CASCADE;
DROP TABLE IF EXISTS intake_sessions CASCADE;
DROP TABLE IF EXISTS model_performance_logs CASCADE;
DROP TABLE IF EXISTS motion_analysis_results CASCADE;
DROP TABLE IF EXISTS onboarding_funnel CASCADE;
DROP TABLE IF EXISTS platform_admin_activity_logs CASCADE;
DROP TABLE IF EXISTS population_registry CASCADE;
DROP TABLE IF EXISTS posture_photos CASCADE;
DROP TABLE IF EXISTS practitioner_roles CASCADE;
DROP TABLE IF EXISTS protocol_effectiveness CASCADE;
DROP TABLE IF EXISTS protocol_exercises CASCADE;
DROP TABLE IF EXISTS recommendation_effectiveness CASCADE;
DROP TABLE IF EXISTS staff_availability_patterns CASCADE;
DROP TABLE IF EXISTS time_off_requests CASCADE;
DROP TABLE IF EXISTS work_shifts CASCADE;
DROP TABLE IF EXISTS subscription_usage CASCADE;
DROP TABLE IF EXISTS therapist_services CASCADE;
DROP TABLE IF EXISTS user_device_tokens CASCADE;
DROP TABLE IF EXISTS waitlist CASCADE;
DROP TABLE IF EXISTS webhook_idempotency CASCADE;

-- ── Borderline: Confirmed safe ──
DROP TABLE IF EXISTS encounter_note_approvals CASCADE;
DROP TABLE IF EXISTS encounter_note_contributors CASCADE;
DROP TABLE IF EXISTS invoice_payments CASCADE;
DROP TABLE IF EXISTS invoice_settings CASCADE;
DROP TABLE IF EXISTS report_share_tokens CASCADE;
DROP TABLE IF EXISTS observation_creation_queue CASCADE;
DROP TABLE IF EXISTS cron_execution_logs CASCADE;
DROP TABLE IF EXISTS mlops_events CASCADE;
;
