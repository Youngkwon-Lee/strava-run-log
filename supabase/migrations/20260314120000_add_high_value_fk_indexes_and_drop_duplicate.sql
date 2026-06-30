-- P1 performance hardening
-- - Add high-value FK covering indexes
-- - Remove duplicate index on encounters(episode_id)
-- Date: 2026-03-14

create index if not exists idx_encounters_provider_person_id
  on public.encounters (provider_person_id);
create index if not exists idx_organization_subscriptions_plan_id
  on public.organization_subscriptions (plan_id);
create index if not exists idx_patient_clinical_state_trigger_encounter_id
  on public.patient_clinical_state (trigger_encounter_id);
create index if not exists idx_recommendations_episode_id
  on public.recommendations (episode_id);
create index if not exists idx_recommendations_observation_id
  on public.recommendations (observation_id);
create index if not exists idx_encounter_media_subject_person_id
  on public.encounter_media (subject_person_id);
create index if not exists idx_org_client_profile_person_id
  on public.org_client_profile (person_id);
create index if not exists idx_org_provider_profile_person_id
  on public.org_provider_profile (person_id);
drop index if exists public.idx_encounters_episode_id;
