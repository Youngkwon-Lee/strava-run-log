-- Lumbar ROM capability bridge wave 4.
-- Purpose: connect lumbar ROM observations to exercise reasoning without
-- going segment-by-segment.
--
-- Scope:
-- - Keeps MVP granularity at lumbar region + motion axis.
-- - Adds/updates the missing lateral-flexion taxonomy row.
-- - Adds four lumbar mobility capabilities.
-- - Maps existing lumbar ROM observations to those capabilities.
-- - Adds a small set of exercise requirements so the four axes reach L2.
-- - Backfills patient_capability_observations from existing degree-based observations.
--
-- Note: low-back sidecar fields may emit pct_limit-style values in some paths.
-- This wave is degree-based L2 only. Percent-limitation normalization belongs in
-- a later L3/normalization wave before strong automated prescribing.

with taxonomy_seed as (
  select * from (values
    (
      'ROM_lumbar_flexion',
      'Lumbar flexion ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      55::numeric,
      'MVP degree-based lumbar flexion ROM reference. Use for L2 exercise matching only.'
    ),
    (
      'ROM_lumbar_extension',
      'Lumbar extension ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      25::numeric,
      'MVP degree-based lumbar extension ROM reference. Use for L2 exercise matching only.'
    ),
    (
      'ROM_lumbar_rotation',
      'Lumbar rotation ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      30::numeric,
      'MVP degree-based lumbar rotation ROM reference. Use for L2 exercise matching only.'
    ),
    (
      'ROM_lumbar_lateral_flexion',
      'Lumbar lateral flexion ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      25::numeric,
      'MVP degree-based lumbar lateral flexion ROM reference. Use for L2 exercise matching only.'
    )
  ) as seed(code, code_display, category, default_value_type, default_unit, reference_range_high, reference_range_text)
)
insert into public.observation_taxonomy (
  code,
  code_system,
  code_display,
  category,
  default_value_type,
  default_unit,
  reference_range_high,
  reference_range_text,
  data_source,
  notes,
  is_active,
  body_site_applicable,
  laterality_applicable,
  interpretation_guide
)
select
  taxonomy_seed.code,
  'http://physiokorea.com/fhir/observation',
  taxonomy_seed.code_display,
  taxonomy_seed.category,
  taxonomy_seed.default_value_type,
  taxonomy_seed.default_unit,
  taxonomy_seed.reference_range_high,
  taxonomy_seed.reference_range_text,
  'lumbar_rom_capability_bridge_wave4',
  'Wave 4 seed for lumbar ROM ontology connection at region + motion-axis granularity.',
  true,
  false,
  taxonomy_seed.code = 'ROM_lumbar_lateral_flexion',
  jsonb_build_object(
    'seed_wave', 'lumbar_rom_capability_bridge_wave4',
    'plain_status', '운동 판단 연결',
    'granularity', 'lumbar_region_motion_axis',
    'unit_note', 'Degree-based L2 mapping. pct_limit values need normalization before L3 use.'
  )
from taxonomy_seed
on conflict (code, code_system) do update set
  code_display = excluded.code_display,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  reference_range_high = excluded.reference_range_high,
  reference_range_text = excluded.reference_range_text,
  data_source = excluded.data_source,
  notes = excluded.notes,
  is_active = excluded.is_active,
  body_site_applicable = excluded.body_site_applicable,
  laterality_applicable = excluded.laterality_applicable,
  interpretation_guide = coalesce(public.observation_taxonomy.interpretation_guide, '{}'::jsonb)
    || excluded.interpretation_guide,
  updated_at = now();
insert into public.movement_capabilities (
  capability_code,
  display,
  display_ko,
  capability_domain,
  body_region,
  laterality_applicable,
  default_value_type,
  default_unit,
  measurement_direction,
  properties,
  status
)
values
  (
    'lumbar_flexion_mobility',
    'Lumbar flexion mobility',
    '요추 굴곡 가동성',
    'mobility',
    'lumbar',
    false,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_lumbar_flexion'),
      'l3_needed', jsonb_build_array('pct_limit_normalization', 'directional_preference', 'symptom_response', 'regression_rule')
    ),
    'active'
  ),
  (
    'lumbar_extension_mobility',
    'Lumbar extension mobility',
    '요추 신전 가동성',
    'mobility',
    'lumbar',
    false,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_lumbar_extension'),
      'l3_needed', jsonb_build_array('pct_limit_normalization', 'directional_preference', 'symptom_response', 'regression_rule')
    ),
    'active'
  ),
  (
    'lumbar_rotation_mobility',
    'Lumbar rotation mobility',
    '요추 회전 가동성',
    'mobility',
    'lumbar',
    false,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_lumbar_rotation'),
      'l3_needed', jsonb_build_array('pct_limit_normalization', 'symptom_response', 'regression_rule')
    ),
    'active'
  ),
  (
    'lumbar_lateral_flexion_mobility',
    'Lumbar lateral flexion mobility',
    '요추 측굴 가동성',
    'mobility',
    'lumbar',
    true,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_lumbar_lateral_flexion'),
      'l3_needed', jsonb_build_array('pct_limit_normalization', 'laterality', 'symptom_response', 'regression_rule')
    ),
    'active'
  )
on conflict (capability_code) do update set
  display = excluded.display,
  display_ko = excluded.display_ko,
  capability_domain = excluded.capability_domain,
  body_region = excluded.body_region,
  laterality_applicable = excluded.laterality_applicable,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  measurement_direction = excluded.measurement_direction,
  properties = public.movement_capabilities.properties || excluded.properties,
  status = 'active',
  updated_at = now();
with mapping_seed as (
  select * from (values
    ('ROM_lumbar_flexion', 'lumbar_flexion_mobility', 'Lumbar flexion ROM -> lumbar flexion mobility.'),
    ('ROM_lumbar_extension', 'lumbar_extension_mobility', 'Lumbar extension ROM -> lumbar extension mobility.'),
    ('ROM_lumbar_rotation', 'lumbar_rotation_mobility', 'Lumbar rotation ROM -> lumbar rotation mobility.'),
    ('ROM_lumbar_lateral_flexion', 'lumbar_lateral_flexion_mobility', 'Lumbar lateral flexion ROM -> lumbar lateral flexion mobility.')
  ) as seed(observation_code, capability_code, rationale)
)
insert into public.movement_capability_observation_mappings (
  observation_code,
  observation_code_system,
  capability_id,
  default_unit,
  value_type_hint,
  metadata,
  status
)
select
  mapping_seed.observation_code,
  '',
  movement_capabilities.id,
  'deg',
  'quantity',
  jsonb_build_object(
    'seed_wave', 'lumbar_rom_capability_bridge_wave4',
    'completion_level', 'L2',
    'plain_status', '운동 판단 연결',
    'unit_scope', 'degree_based',
    'normalization_gap', 'pct_limit values need conversion before L3.',
    'rationale', mapping_seed.rationale
  ),
  'active'
from mapping_seed
join public.movement_capabilities
  on movement_capabilities.capability_code = mapping_seed.capability_code
on conflict (observation_code, observation_code_system, capability_id) do update set
  default_unit = excluded.default_unit,
  value_type_hint = excluded.value_type_hint,
  metadata = public.movement_capability_observation_mappings.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
with requirement_seed as (
  select * from (values
    ('edb_Cat_Stretch', 'lumbar_flexion_mobility', 'target', 30::numeric, null::numeric, 'deg', 2, 'low', 'Cat stretch targets lumbar flexion mobility in a low-load position.'),
    ('pk_cat_cow', 'lumbar_flexion_mobility', 'target', 30::numeric, null::numeric, 'deg', 2, 'low', 'Cat-cow uses gentle lumbar flexion mobility.'),
    ('edb_Cat_Stretch', 'lumbar_extension_mobility', 'target', 10::numeric, null::numeric, 'deg', 2, 'low', 'Cat stretch/cat-cow pattern includes gentle extension return.'),
    ('pk_cat_cow', 'lumbar_extension_mobility', 'target', 10::numeric, null::numeric, 'deg', 2, 'low', 'Cat-cow uses gentle lumbar extension mobility.'),
    ('edb_Hyperextensions_Back_Extensions', 'lumbar_extension_mobility', 'required', 15::numeric, null::numeric, 'deg', 3, 'moderate', 'Back extension requires baseline lumbar extension mobility and symptom tolerance.'),
    ('edb_Torso_Rotation', 'lumbar_rotation_mobility', 'target', 15::numeric, null::numeric, 'deg', 2, 'low', 'Torso rotation targets controlled trunk/lumbar rotation mobility.'),
    ('edb_Pallof_Press_With_Rotation', 'lumbar_rotation_mobility', 'required', 15::numeric, null::numeric, 'deg', 3, 'moderate', 'Pallof press with rotation requires baseline trunk/lumbar rotation mobility.'),
    ('EX_LSPN_STB_011', 'lumbar_rotation_mobility', 'target', 15::numeric, null::numeric, 'deg', 3, 'moderate', 'Lumbar spine trunk-rotation-resist work targets controlled rotation capacity.'),
    ('edb_Dumbbell_Side_Bend', 'lumbar_lateral_flexion_mobility', 'target', 15::numeric, null::numeric, 'deg', 2, 'moderate', 'Dumbbell side bend targets lateral flexion mobility and lateral trunk loading.'),
    ('edb_Barbell_Side_Bend', 'lumbar_lateral_flexion_mobility', 'required', 15::numeric, null::numeric, 'deg', 3, 'moderate', 'Barbell side bend requires baseline lateral flexion mobility before loading.')
  ) as seed(
    exercise_code,
    capability_code,
    requirement_role,
    min_value,
    max_value,
    value_unit,
    requirement_level,
    severity,
    rationale
  )
)
insert into public.exercise_requirements (
  exercise_id,
  capability_id,
  requirement_role,
  min_value,
  max_value,
  value_unit,
  required_boolean,
  requirement_level,
  laterality,
  severity,
  rationale,
  evidence_level,
  metadata,
  status
)
select
  exercises.id,
  movement_capabilities.id,
  requirement_seed.requirement_role,
  requirement_seed.min_value,
  requirement_seed.max_value,
  requirement_seed.value_unit,
  null::boolean,
  requirement_seed.requirement_level,
  null::text,
  requirement_seed.severity,
  requirement_seed.rationale,
  'expert_seed_mvp',
  jsonb_build_object(
    'seed_wave', 'lumbar_rom_capability_bridge_wave4',
    'plain_status', '운동 판단 연결',
    'unit_scope', 'degree_based'
  ),
  'active'
from requirement_seed
join public.exercises
  on exercises.exercise_code = requirement_seed.exercise_code
join public.movement_capabilities
  on movement_capabilities.capability_code = requirement_seed.capability_code
on conflict (exercise_id, capability_id, requirement_role, coalesce(laterality, ''))
  where status = 'active'
do update set
  min_value = excluded.min_value,
  max_value = excluded.max_value,
  value_unit = excluded.value_unit,
  required_boolean = excluded.required_boolean,
  requirement_level = excluded.requirement_level,
  severity = excluded.severity,
  rationale = excluded.rationale,
  evidence_level = excluded.evidence_level,
  metadata = public.exercise_requirements.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
select coalesce(sum(private.project_observation_to_patient_capability(observations.id)), 0)
from public.observations
where observations.status <> all (array['entered-in-error'::text, 'cancelled'::text])
  and observations.code in (
    'ROM_lumbar_flexion',
    'ROM_lumbar_extension',
    'ROM_lumbar_rotation',
    'ROM_lumbar_lateral_flexion'
  )
  and (
    observations.value_unit is null
    or lower(observations.value_unit) in ('deg', 'degree', 'degrees')
  )
  and exists (
    select 1
    from public.movement_capability_observation_mappings mapping
    where mapping.observation_code = observations.code
      and mapping.status = 'active'
      and (
        mapping.observation_code_system = ''
        or mapping.observation_code_system = coalesce(observations.code_system, '')
      )
  );
