begin;
-- 1) observation_taxonomy alignment
-- Keep legacy rows available for historical observations while also adding
-- future-facing canonical rows for PT exam capture.

insert into public.observation_taxonomy (
  code,
  code_display,
  category,
  code_system,
  default_value_type,
  default_unit,
  unit_system,
  body_site_applicable,
  laterality_applicable,
  is_required_typed,
  is_active,
  notes
)
values
  (
    'gait_speed',
    'Gait speed',
    array['gait','function'],
    'http://physiokorea.com/fhir/observation',
    'quantity',
    'm/s',
    'http://unitsofmeasure.org',
    false,
    false,
    true,
    true,
    'PT exam Wave 1B canonical gait speed code. Legacy extractor code GAIT_speed remains supported.'
  ),
  (
    'GAIT_speed',
    'Gait speed',
    array['gait','function'],
    'http://physiokorea.com/fhir/observation',
    'quantity',
    'm/s',
    'http://unitsofmeasure.org',
    false,
    false,
    true,
    true,
    'Legacy compatibility row for historical observation.code values.'
  ),
  (
    'SLR',
    'Straight Leg Raise',
    array['special_test','msk','neuro'],
    'http://physiokorea.com/fhir/observation',
    'json',
    null,
    null,
    true,
    true,
    true,
    true,
    'Legacy compatibility row. Historical data mixes boolean and quantity-style SLR capture; prefer special_test_slr for future structured writes.'
  ),
  (
    'SLUMP',
    'Slump test',
    array['special_test','msk','neuro'],
    'http://physiokorea.com/fhir/observation',
    'json',
    null,
    null,
    true,
    true,
    true,
    true,
    'Legacy compatibility row. Prefer special_test_slump for future structured writes.'
  )
on conflict (code, code_system) do update
set
  code_display = excluded.code_display,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  unit_system = excluded.unit_system,
  body_site_applicable = excluded.body_site_applicable,
  laterality_applicable = excluded.laterality_applicable,
  is_required_typed = excluded.is_required_typed,
  is_active = excluded.is_active,
  notes = excluded.notes;
update public.observation_taxonomy
set notes = 'Legacy Wave A2 quantity-based MMT row retained for backwards compatibility. Future PT capture that needs ordinal nuance may prefer json-based codes in later waves.'
where code in ('MMT_hip_abduction', 'MMT_hip_extension', 'MMT_trunk_flexion')
  and code_system = 'http://physiokorea.com/fhir/observation';
-- 2) clinical_concepts alignment
-- Add test concepts distinct from positive findings.

with concept_seed(
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  source_table,
  source_code,
  definition,
  status,
  properties
) as (
  values
  (
    'straight_leg_raise_test',
    'Straight Leg Raise test',
    '하지직거상 검사',
    'special_test',
    array['core', 'msk', 'neuro']::text[],
    'observation_taxonomy',
    'special_test_slr',
    'seed:pt-wave1b-alignment',
    'active',
    jsonb_build_object(
      'seed_version', 'pt-wave1b',
      'semantic_role', 'test_observation',
      'preferred_observation_code', 'special_test_slr'
    )
  ),
  (
    'slump_test',
    'Slump test',
    '슬럼프 테스트',
    'special_test',
    array['core', 'msk', 'neuro']::text[],
    'observation_taxonomy',
    'special_test_slump',
    'seed:pt-wave1b-alignment',
    'active',
    jsonb_build_object(
      'seed_version', 'pt-wave1b',
      'semantic_role', 'test_observation',
      'preferred_observation_code', 'special_test_slump'
    )
  )
)
insert into public.clinical_concepts (
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  source_table,
  source_code,
  definition,
  status,
  properties
)
select
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  source_table,
  source_code,
  definition,
  status,
  properties
from concept_seed
on conflict (concept_key) do update
set
  display = excluded.display,
  display_ko = excluded.display_ko,
  concept_domain = excluded.concept_domain,
  specialty_scope = excluded.specialty_scope,
  source_table = excluded.source_table,
  source_code = excluded.source_code,
  definition = excluded.definition,
  status = excluded.status,
  properties = excluded.properties;
-- 3) alias alignment

with alias_seed(
  concept_key,
  alias_text,
  normalized_alias,
  language_code,
  alias_type,
  source,
  is_preferred
) as (
  values
  ('gait_speed', 'GAIT_speed', 'gait_speed', 'en', 'legacy_code', 'seed:pt-wave1b-alignment', false),
  ('gait_speed', 'Gait speed', 'gait speed', 'en', 'surface_form', 'seed:pt-wave1b-alignment', false),

  ('straight_leg_raise_test', 'SLR', 'slr', 'en', 'abbreviation', 'seed:pt-wave1b-alignment', false),
  ('straight_leg_raise_test', 'special_test_slr', 'special_test_slr', 'en', 'legacy_code', 'seed:pt-wave1b-alignment', false),
  ('straight_leg_raise_test', 'Straight Leg Raise', 'straight leg raise', 'en', 'surface_form', 'seed:pt-wave1b-alignment', true),
  ('straight_leg_raise_test', '하지직거상', '하지직거상', 'ko', 'synonym', 'seed:pt-wave1b-alignment', false),

  ('slump_test', 'SLUMP', 'slump', 'en', 'abbreviation', 'seed:pt-wave1b-alignment', false),
  ('slump_test', 'special_test_slump', 'special_test_slump', 'en', 'legacy_code', 'seed:pt-wave1b-alignment', false),
  ('slump_test', 'Slump test', 'slump test', 'en', 'surface_form', 'seed:pt-wave1b-alignment', true),
  ('slump_test', '슬럼프 테스트', '슬럼프 테스트', 'ko', 'synonym', 'seed:pt-wave1b-alignment', false)
)
insert into public.concept_aliases (
  concept_id,
  alias_text,
  normalized_alias,
  language_code,
  alias_type,
  source,
  is_preferred
)
select
  cc.id,
  a.alias_text,
  a.normalized_alias,
  a.language_code,
  a.alias_type,
  a.source,
  a.is_preferred
from alias_seed a
join public.clinical_concepts cc
  on cc.concept_key = a.concept_key
on conflict (concept_id, normalized_alias, language_code, alias_type) do update
set
  alias_text = excluded.alias_text,
  source = excluded.source,
  is_preferred = excluded.is_preferred;
commit;
