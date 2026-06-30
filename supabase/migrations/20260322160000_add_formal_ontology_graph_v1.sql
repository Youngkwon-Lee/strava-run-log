-- Formal ontology graph v1
-- Purpose:
--   Add a thin generic concept graph layer above the current ontology/reference assets.
-- Scope:
--   - clinical_concepts
--   - concept_aliases
--   - concept_relationships
-- Notes:
--   Existing ontology tables remain the source-oriented truth.

create extension if not exists pgcrypto;
create table if not exists public.clinical_concepts (
  id uuid primary key default gen_random_uuid(),
  concept_key text not null unique,
  display text not null,
  display_ko text null,
  concept_domain text not null,
  specialty_scope text[] not null default array['core']::text[],
  source_table text null,
  source_record_id_text text null,
  source_code text null,
  source_code_system text null,
  parent_concept_id uuid null
    references public.clinical_concepts(id) on delete set null,
  definition text null,
  properties jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint clinical_concepts_nonempty_key
    check (length(trim(concept_key)) > 0),
  constraint clinical_concepts_nonempty_display
    check (length(trim(display)) > 0),
  constraint clinical_concepts_domain_check
    check (
      concept_domain in (
        'observation',
        'impairment',
        'movement_pattern',
        'special_test',
        'assessment_template',
        'reasoning_framework',
        'terminology',
        'intervention',
        'risk',
        'condition',
        'body_region',
        'care',
        'other'
      )
    ),
  constraint clinical_concepts_status_check
    check (status in ('draft', 'active', 'deprecated')),
  constraint clinical_concepts_specialty_scope_check
    check (
      cardinality(specialty_scope) >= 1
      and specialty_scope <@ array[
        'core',
        'pediatric',
        'msk',
        'neuro',
        'trainer',
        'wellness'
      ]::text[]
    )
);
create index if not exists idx_clinical_concepts_domain
  on public.clinical_concepts (concept_domain);
create index if not exists idx_clinical_concepts_source
  on public.clinical_concepts (source_table, source_record_id_text);
create index if not exists idx_clinical_concepts_parent
  on public.clinical_concepts (parent_concept_id);
create table if not exists public.concept_aliases (
  id uuid primary key default gen_random_uuid(),
  concept_id uuid not null
    references public.clinical_concepts(id) on delete cascade,
  alias_text text not null,
  normalized_alias text not null,
  language_code text not null default 'en',
  alias_type text not null default 'synonym',
  source text null,
  confidence numeric null,
  is_preferred boolean not null default false,
  created_at timestamptz not null default now(),

  constraint concept_aliases_nonempty_alias
    check (length(trim(alias_text)) > 0),
  constraint concept_aliases_nonempty_normalized
    check (length(trim(normalized_alias)) > 0),
  constraint concept_aliases_alias_type_check
    check (
      alias_type in (
        'synonym',
        'abbreviation',
        'legacy_code',
        'surface_form',
        'stt_normalized'
      )
    ),
  constraint concept_aliases_confidence_range
    check (confidence is null or (confidence >= 0 and confidence <= 1))
);
create unique index if not exists uq_concept_aliases_unique_alias
  on public.concept_aliases (concept_id, normalized_alias, language_code, alias_type);
create index if not exists idx_concept_aliases_normalized
  on public.concept_aliases (normalized_alias);
create index if not exists idx_concept_aliases_concept_id
  on public.concept_aliases (concept_id);
create table if not exists public.concept_relationships (
  id uuid primary key default gen_random_uuid(),
  source_concept_id uuid not null
    references public.clinical_concepts(id) on delete cascade,
  relationship_type text not null,
  target_concept_id uuid not null
    references public.clinical_concepts(id) on delete cascade,
  weight numeric not null default 1.0,
  specialty_scope text[] not null default array['core']::text[],
  evidence_source text null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint concept_relationships_no_self_edge
    check (source_concept_id <> target_concept_id),
  constraint concept_relationships_weight_positive
    check (weight > 0),
  constraint concept_relationships_type_check
    check (
      relationship_type in (
        'is_a',
        'part_of',
        'maps_to',
        'indicates',
        'related_to',
        'increases_risk_of',
        'suggests_assessment',
        'suggests_intervention'
      )
    ),
  constraint concept_relationships_specialty_scope_check
    check (
      cardinality(specialty_scope) >= 1
      and specialty_scope <@ array[
        'core',
        'pediatric',
        'msk',
        'neuro',
        'trainer',
        'wellness'
      ]::text[]
    )
);
create unique index if not exists uq_concept_relationships_edge
  on public.concept_relationships (source_concept_id, relationship_type, target_concept_id);
create index if not exists idx_concept_relationships_source
  on public.concept_relationships (source_concept_id);
create index if not exists idx_concept_relationships_target
  on public.concept_relationships (target_concept_id);
create index if not exists idx_concept_relationships_type
  on public.concept_relationships (relationship_type);
comment on table public.clinical_concepts is
  'Generic semantic concept registry layered above existing ontology/reference tables.';
comment on table public.concept_aliases is
  'Multilingual and workflow-specific aliases for clinical concepts.';
comment on table public.concept_relationships is
  'Generic semantic edges between clinical concepts.';
alter table public.clinical_concepts enable row level security;
alter table public.concept_aliases enable row level security;
alter table public.concept_relationships enable row level security;
drop policy if exists clinical_concepts_read_all on public.clinical_concepts;
create policy clinical_concepts_read_all
  on public.clinical_concepts
  for select
  to authenticated
  using (true);
drop policy if exists clinical_concepts_service_write on public.clinical_concepts;
create policy clinical_concepts_service_write
  on public.clinical_concepts
  for all
  to service_role
  using (true)
  with check (true);
drop policy if exists concept_aliases_read_all on public.concept_aliases;
create policy concept_aliases_read_all
  on public.concept_aliases
  for select
  to authenticated
  using (true);
drop policy if exists concept_aliases_service_write on public.concept_aliases;
create policy concept_aliases_service_write
  on public.concept_aliases
  for all
  to service_role
  using (true)
  with check (true);
drop policy if exists concept_relationships_read_all on public.concept_relationships;
create policy concept_relationships_read_all
  on public.concept_relationships
  for select
  to authenticated
  using (true);
drop policy if exists concept_relationships_service_write on public.concept_relationships;
create policy concept_relationships_service_write
  on public.concept_relationships
  for all
  to service_role
  using (true)
  with check (true);
drop trigger if exists clinical_concepts_set_updated_at on public.clinical_concepts;
create trigger clinical_concepts_set_updated_at
  before update on public.clinical_concepts
  for each row execute function public.set_updated_at();
