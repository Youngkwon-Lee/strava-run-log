-- Observation concept review loop v1
-- Purpose:
--   Add extraction review workflow and accepted concept bridge tables
--   without modifying the core observations table yet.

create extension if not exists pgcrypto;
create table if not exists public.observation_concept_links (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  subject_person_id uuid not null references public.persons(id) on delete cascade,
  encounter_id uuid null references public.encounters(id) on delete set null,
  observation_id uuid not null references public.observations(id) on delete cascade,
  concept_id uuid not null references public.clinical_concepts(id) on delete restrict,
  matched_alias_id uuid null references public.concept_aliases(id) on delete set null,
  link_source_type text not null,
  ai_inference_id uuid null references public.ai_inference_log(id) on delete set null,
  confidence numeric null,
  link_status text not null default 'active',
  is_primary boolean not null default false,
  rationale text null,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid null references public.persons(id) on delete set null,
  reviewed_by uuid null references public.persons(id) on delete set null,
  reviewed_at timestamptz null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint observation_concept_links_source_type_check
    check (
      link_source_type in (
        'manual_mapping',
        'stt_extraction',
        'vision_extraction',
        'rule_engine',
        'ai_inference',
        'seed'
      )
    ),
  constraint observation_concept_links_status_check
    check (
      link_status in ('active', 'superseded', 'rejected')
    ),
  constraint observation_concept_links_confidence_range
    check (confidence is null or (confidence >= 0 and confidence <= 1)),
  constraint observation_concept_links_unique
    unique (observation_id, concept_id, link_source_type)
);
create index if not exists idx_observation_concept_links_observation
  on public.observation_concept_links (observation_id, link_status, is_primary);
create index if not exists idx_observation_concept_links_concept
  on public.observation_concept_links (concept_id, link_status);
create index if not exists idx_observation_concept_links_subject
  on public.observation_concept_links (subject_person_id, created_at desc);
create index if not exists idx_observation_concept_links_encounter
  on public.observation_concept_links (encounter_id, created_at desc);
comment on table public.observation_concept_links is
  'Accepted semantic mappings between observations and clinical concepts.';
create table if not exists public.clinical_extraction_reviews (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  subject_person_id uuid not null references public.persons(id) on delete cascade,
  encounter_id uuid null references public.encounters(id) on delete set null,
  source_table text not null,
  source_record_id uuid null,
  source_locator jsonb not null default '{}'::jsonb,
  source_modality text not null,
  ai_inference_id uuid null references public.ai_inference_log(id) on delete set null,
  proposed_payload jsonb not null,
  final_payload jsonb null,
  review_status text not null default 'auto_extracted',
  reviewer_person_id uuid null references public.persons(id) on delete set null,
  review_note text null,
  resolved_observation_id uuid null references public.observations(id) on delete set null,
  resolved_link_id uuid null references public.observation_concept_links(id) on delete set null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz null,

  constraint clinical_extraction_reviews_source_table_check
    check (
      source_table in (
        'voice_memos',
        'encounter_media',
        'encounter_notes',
        'client_media_summaries',
        'client_memory_chunks',
        'observations',
        'other'
      )
    ),
  constraint clinical_extraction_reviews_source_modality_check
    check (
      source_modality in (
        'transcript',
        'audio',
        'image',
        'video',
        'text',
        'mixed',
        'other'
      )
    ),
  constraint clinical_extraction_reviews_status_check
    check (
      review_status in (
        'auto_extracted',
        'clinician_accepted',
        'clinician_corrected',
        'validated',
        'rejected'
      )
    )
);
create index if not exists idx_clinical_extraction_reviews_status
  on public.clinical_extraction_reviews (review_status, created_at desc);
create index if not exists idx_clinical_extraction_reviews_subject
  on public.clinical_extraction_reviews (subject_person_id, created_at desc);
create index if not exists idx_clinical_extraction_reviews_encounter
  on public.clinical_extraction_reviews (encounter_id, created_at desc);
create index if not exists idx_clinical_extraction_reviews_source
  on public.clinical_extraction_reviews (source_table, source_record_id);
comment on table public.clinical_extraction_reviews is
  'Candidate extraction review workflow for STT, media, note, and AI-derived clinical meaning.';
alter table public.observation_concept_links enable row level security;
alter table public.clinical_extraction_reviews enable row level security;
drop policy if exists observation_concept_links_select_member on public.observation_concept_links;
create policy observation_concept_links_select_member
  on public.observation_concept_links
  for select
  to authenticated
  using (is_org_member(organization_id));
drop policy if exists observation_concept_links_service_write on public.observation_concept_links;
create policy observation_concept_links_service_write
  on public.observation_concept_links
  for all
  to service_role
  using (true)
  with check (true);
drop policy if exists clinical_extraction_reviews_select_member on public.clinical_extraction_reviews;
create policy clinical_extraction_reviews_select_member
  on public.clinical_extraction_reviews
  for select
  to authenticated
  using (is_org_member(organization_id));
drop policy if exists clinical_extraction_reviews_service_write on public.clinical_extraction_reviews;
create policy clinical_extraction_reviews_service_write
  on public.clinical_extraction_reviews
  for all
  to service_role
  using (true)
  with check (true);
drop trigger if exists observation_concept_links_set_updated_at on public.observation_concept_links;
create trigger observation_concept_links_set_updated_at
  before update on public.observation_concept_links
  for each row execute function public.set_updated_at();
