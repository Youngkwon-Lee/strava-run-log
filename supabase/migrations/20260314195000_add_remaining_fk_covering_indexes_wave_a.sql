-- Wave A: add remaining covering indexes for unindexed foreign keys (2026-03-14).

create index if not exists idx_encounter_notes_classification_id
  on public.encounter_notes (classification_id);
create index if not exists idx_encounter_notes_reasoning_chain_id
  on public.encounter_notes (reasoning_chain_id);
create index if not exists idx_person_icf_assessments_assessed_by
  on public.person_icf_assessments (assessed_by);
create index if not exists idx_recommendations_classification_id
  on public.recommendations (classification_id);
create index if not exists idx_recommendations_created_by
  on public.recommendations (created_by);
create index if not exists idx_recommendations_organization_id
  on public.recommendations (organization_id);
create index if not exists idx_recommendations_reasoning_chain_id
  on public.recommendations (reasoning_chain_id);
create index if not exists idx_recommendations_reviewed_by
  on public.recommendations (reviewed_by);
