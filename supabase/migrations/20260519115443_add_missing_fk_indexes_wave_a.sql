-- Add covering indexes for FK constraints flagged by Supabase Advisor (2026-05-19).
-- Scope: INFO-level `unindexed_foreign_keys` findings (16 constraints).

create index if not exists idx_activity_sessions_care_plan_id
  on public.activity_sessions (care_plan_id);
create index if not exists idx_activity_sessions_created_by
  on public.activity_sessions (created_by);
create index if not exists idx_atsl_terminology_registry_id
  on public.assessment_template_item_semantic_links (terminology_registry_id);
create index if not exists idx_clinical_extraction_reviews_ai_inference_id
  on public.clinical_extraction_reviews (ai_inference_id);
create index if not exists idx_clinical_extraction_reviews_organization_id
  on public.clinical_extraction_reviews (organization_id);
create index if not exists idx_clinical_extraction_reviews_resolved_link_id
  on public.clinical_extraction_reviews (resolved_link_id);
create index if not exists idx_clinical_extraction_reviews_resolved_observation_id
  on public.clinical_extraction_reviews (resolved_observation_id);
create index if not exists idx_clinical_extraction_reviews_reviewer_person_id
  on public.clinical_extraction_reviews (reviewer_person_id);
create index if not exists idx_observation_concept_links_ai_inference_id
  on public.observation_concept_links (ai_inference_id);
create index if not exists idx_observation_concept_links_created_by
  on public.observation_concept_links (created_by);
create index if not exists idx_observation_concept_links_matched_alias_id
  on public.observation_concept_links (matched_alias_id);
create index if not exists idx_observation_concept_links_organization_id
  on public.observation_concept_links (organization_id);
create index if not exists idx_observation_concept_links_reviewed_by
  on public.observation_concept_links (reviewed_by);
create index if not exists idx_patient_state_change_log_organization_id
  on public.patient_state_change_log (organization_id);
create index if not exists idx_patient_state_change_log_trigger_encounter_id
  on public.patient_state_change_log (trigger_encounter_id);
create index if not exists idx_person_lifecycle_events_actor_person_id
  on public.person_lifecycle_events (actor_person_id);
