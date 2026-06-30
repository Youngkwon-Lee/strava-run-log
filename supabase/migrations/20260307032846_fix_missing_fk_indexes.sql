-- ============================================================
-- Fix: FK 인덱스 누락 — schema-foreign-key-indexes
-- Postgres는 FK를 자동 인덱싱하지 않음 → 수동 추가 필수
-- ============================================================

-- [신규 테이블] clinical_tasks
CREATE INDEX IF NOT EXISTS idx_clinical_tasks_completed_by
  ON public.clinical_tasks(completed_by) WHERE completed_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_clinical_tasks_requested_by
  ON public.clinical_tasks(requested_by) WHERE requested_by IS NOT NULL;

-- [신규 테이블] ai_feedback
CREATE INDEX IF NOT EXISTS idx_ai_feedback_encounter_id
  ON public.ai_feedback(encounter_id) WHERE encounter_id IS NOT NULL;

-- [기존] ai_inference_log
CREATE INDEX IF NOT EXISTS idx_ai_inference_log_reviewed_by
  ON public.ai_inference_log(reviewed_by) WHERE reviewed_by IS NOT NULL;

-- [기존] patient_consent_records
CREATE INDEX IF NOT EXISTS idx_patient_consent_records_created_by
  ON public.patient_consent_records(created_by);

CREATE INDEX IF NOT EXISTS idx_patient_consent_records_encounter_id
  ON public.patient_consent_records(encounter_id) WHERE encounter_id IS NOT NULL;

-- [기존] patient_education_deliveries
CREATE INDEX IF NOT EXISTS idx_patient_ed_deliveries_encounter_id
  ON public.patient_education_deliveries(encounter_id) WHERE encounter_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_patient_ed_deliveries_delivered_by
  ON public.patient_education_deliveries(delivered_by_person_id) WHERE delivered_by_person_id IS NOT NULL;

-- [기존] exercise_prescriptions
CREATE INDEX IF NOT EXISTS idx_exercise_prescriptions_exercise_id
  ON public.exercise_prescriptions(exercise_id);

CREATE INDEX IF NOT EXISTS idx_exercise_prescriptions_created_by
  ON public.exercise_prescriptions(created_by) WHERE created_by IS NOT NULL;

-- [기존] notification_logs
CREATE INDEX IF NOT EXISTS idx_notification_logs_automation_rule_id
  ON public.notification_logs(automation_rule_id) WHERE automation_rule_id IS NOT NULL;

-- [기존] scheduled_reminders
CREATE INDEX IF NOT EXISTS idx_scheduled_reminders_automation_rule_id
  ON public.scheduled_reminders(automation_rule_id) WHERE automation_rule_id IS NOT NULL;

-- [기존] care_relationship
CREATE INDEX IF NOT EXISTS idx_care_relationship_referral_link_id
  ON public.care_relationship(referral_link_id) WHERE referral_link_id IS NOT NULL;

-- [기존] assessment_schedules
CREATE INDEX IF NOT EXISTS idx_assessment_schedules_created_by
  ON public.assessment_schedules(created_by) WHERE created_by IS NOT NULL;

-- [기존] marketing_content_drafts
CREATE INDEX IF NOT EXISTS idx_marketing_content_drafts_approved_by
  ON public.marketing_content_drafts(approved_by) WHERE approved_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_marketing_content_drafts_provider_person_id
  ON public.marketing_content_drafts(provider_person_id);;
