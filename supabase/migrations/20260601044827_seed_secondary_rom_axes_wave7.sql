-- Secondary ROM axes wave 7.
-- Purpose: connect the next shoulder/hip/ankle ROM axes to exercise reasoning
-- after the first primary ROM bridges are stable.
--
-- Scope:
-- - Refresh six existing ROM taxonomy rows with MVP reference metadata.
-- - Add six ROM capabilities for secondary axes across shoulder/hip/ankle.
-- - Map the observation codes to those capabilities.
-- - Seed a small target/required exercise set so the axes reach L2.
-- - Backfill patient_capability_observations from any existing live ROM rows.
--
-- This is intentionally L2. Strong prescribing still needs population-specific
-- cutoffs, symptom response handling, and laterality-aware regression logic.

with taxonomy_seed as (
  select * from (values
    (
      'ROM_shoulder_abduction',
      'Shoulder abduction ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      180::numeric,
      'MVP degree-based shoulder abduction ROM reference. Use for L2 exercise matching only.'
    ),
    (
      'ROM_shoulder_internal_rotation',
      'Shoulder internal rotation ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      70::numeric,
      'MVP degree-based shoulder internal rotation ROM reference. Use for L2 exercise matching only.'
    ),
    (
      'ROM_hip_abduction',
      'Hip abduction ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      45::numeric,
      'MVP degree-based hip abduction ROM reference. Use for L2 exercise matching only.'
    ),
    (
      'ROM_hip_internal_rotation',
      'Hip internal rotation ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      35::numeric,
      'MVP degree-based hip internal rotation ROM reference. Use for L2 exercise matching only.'
    ),
    (
      'ROM_ankle_plantarflexion',
      'Ankle plantarflexion ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      50::numeric,
      'MVP degree-based ankle plantarflexion ROM reference. Use for L2 exercise matching only.'
    ),
    (
      'ROM_ankle_inversion',
      'Ankle inversion ROM',
      array['rom']::text[],
      'quantity',
      'deg',
      35::numeric,
      'MVP degree-based ankle inversion ROM reference. Use for L2 exercise matching only.'
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
  'secondary_rom_axes_wave7',
  'Wave 7 seed for secondary shoulder/hip/ankle ROM ontology connection.',
  true,
  false,
  true,
  jsonb_build_object(
    'seed_wave', 'secondary_rom_axes_wave7',
    'plain_status', '운동 판단 연결',
    'granularity', 'joint_motion_axis',
    'unit_note', 'Degree-based L2 mapping. L3 needs laterality and symptom-response rules.'
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
    'shoulder_abduction_rom',
    'Shoulder abduction ROM',
    '어깨 외전 가동범위',
    'mobility',
    'shoulder',
    true,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_shoulder_abduction'),
      'l3_needed', jsonb_build_array('laterality', 'pain_arc_context', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'shoulder_internal_rotation_rom',
    'Shoulder internal rotation ROM',
    '어깨 내회전 가동범위',
    'mobility',
    'shoulder',
    true,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_shoulder_internal_rotation'),
      'l3_needed', jsonb_build_array('laterality', 'capsular_pattern_context', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'hip_abduction_rom',
    'Hip abduction ROM',
    '고관절 외전 가동범위',
    'mobility',
    'hip',
    true,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_hip_abduction'),
      'l3_needed', jsonb_build_array('laterality', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'hip_internal_rotation_rom',
    'Hip internal rotation ROM',
    '고관절 내회전 가동범위',
    'mobility',
    'hip',
    true,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_hip_internal_rotation'),
      'l3_needed', jsonb_build_array('laterality', 'impingement_context', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'ankle_plantarflexion_rom',
    'Ankle plantarflexion ROM',
    '발목 저측굴곡 가동범위',
    'mobility',
    'ankle',
    true,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_ankle_plantarflexion'),
      'l3_needed', jsonb_build_array('laterality', 'weight_bearing_context', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'ankle_inversion_rom',
    'Ankle inversion ROM',
    '발목 내번 가동범위',
    'mobility',
    'ankle',
    true,
    'quantity',
    'deg',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('ROM_ankle_inversion'),
      'l3_needed', jsonb_build_array('laterality', 'instability_context', 'severity_threshold', 'regression_rule')
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
    ('ROM_shoulder_abduction', 'shoulder_abduction_rom', 'Shoulder abduction ROM -> shoulder abduction ROM capability.'),
    ('ROM_shoulder_internal_rotation', 'shoulder_internal_rotation_rom', 'Shoulder internal rotation ROM -> shoulder internal rotation ROM capability.'),
    ('ROM_hip_abduction', 'hip_abduction_rom', 'Hip abduction ROM -> hip abduction ROM capability.'),
    ('ROM_hip_internal_rotation', 'hip_internal_rotation_rom', 'Hip internal rotation ROM -> hip internal rotation ROM capability.'),
    ('ROM_ankle_plantarflexion', 'ankle_plantarflexion_rom', 'Ankle plantarflexion ROM -> ankle plantarflexion ROM capability.'),
    ('ROM_ankle_inversion', 'ankle_inversion_rom', 'Ankle inversion ROM -> ankle inversion ROM capability.')
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
    'seed_wave', 'secondary_rom_axes_wave7',
    'completion_level', 'L2',
    'plain_status', '운동 판단 연결',
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
    (
      'EX_SHLD_FNC_005',
      'shoulder_abduction_rom',
      'required',
      110::numeric,
      null::numeric,
      'deg',
      2,
      'moderate',
      'Overhead reach needs usable shoulder abduction range for arm elevation.'
    ),
    (
      'EX_SHLD_STR_011',
      'shoulder_abduction_rom',
      'target',
      90::numeric,
      null::numeric,
      'deg',
      1,
      'low',
      'Standing shoulder stretch can be used to build shoulder abduction range.'
    ),
    (
      'edb_Cable_Internal_Rotation',
      'shoulder_internal_rotation_rom',
      'required',
      30::numeric,
      null::numeric,
      'deg',
      2,
      'moderate',
      'Cable internal rotation loading is easier when basic shoulder internal rotation range is available.'
    ),
    (
      'EX_SHLD_STR_005',
      'shoulder_internal_rotation_rom',
      'target',
      30::numeric,
      null::numeric,
      'deg',
      1,
      'low',
      'Cross-body shoulder stretch can support posterior shoulder mobility and internal rotation tolerance.'
    ),
    (
      'pk_lunge',
      'hip_abduction_rom',
      'required',
      15::numeric,
      null::numeric,
      'deg',
      2,
      'low',
      'Lunge setup benefits from enough frontal-plane hip opening to avoid a narrow, unstable base.'
    ),
    (
      'EX_HIP_STR_008',
      'hip_abduction_rom',
      'target',
      20::numeric,
      null::numeric,
      'deg',
      1,
      'low',
      'Side-lying hip stretch can be used to build hip abduction range.'
    ),
    (
      'EX_HIP_FNC_007',
      'hip_internal_rotation_rom',
      'required',
      15::numeric,
      null::numeric,
      'deg',
      2,
      'moderate',
      'Hip lunge with rotation needs enough hip internal rotation to tolerate turning and pivot demands.'
    ),
    (
      'EX_HIP_STR_010',
      'hip_internal_rotation_rom',
      'target',
      20::numeric,
      null::numeric,
      'deg',
      1,
      'low',
      'Seated hip stretch can be used to improve hip internal rotation mobility.'
    ),
    (
      'pk_calf_raise',
      'ankle_plantarflexion_rom',
      'required',
      20::numeric,
      null::numeric,
      'deg',
      2,
      'low',
      'Calf raise needs enough plantarflexion excursion to reach terminal heel rise comfortably.'
    ),
    (
      'EX_ANKL_STR_010',
      'ankle_plantarflexion_rom',
      'target',
      25::numeric,
      null::numeric,
      'deg',
      1,
      'low',
      'Seated ankle-foot stretch can support plantarflexion range restoration.'
    ),
    (
      'EX_ANKL_SGT_004',
      'ankle_inversion_rom',
      'required',
      10::numeric,
      null::numeric,
      'deg',
      2,
      'low',
      'Band resistance work is easier when a basic ankle inversion arc is available.'
    ),
    (
      'EX_ANKL_MOB_009',
      'ankle_inversion_rom',
      'target',
      10::numeric,
      null::numeric,
      'deg',
      1,
      'low',
      'Ankle circular AROM can be used to improve inversion mobility.'
    )
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
  e.id,
  mc.id,
  rs.requirement_role,
  rs.min_value,
  rs.max_value,
  rs.value_unit,
  null::boolean,
  rs.requirement_level,
  null::text,
  rs.severity,
  rs.rationale,
  'expert_seed_mvp',
  jsonb_build_object(
    'seed_wave', 'secondary_rom_axes_wave7',
    'plain_status', '운동 판단 연결',
    'source_family', 'ROM'
  ),
  'active'
from requirement_seed rs
join public.exercises e
  on e.exercise_code = rs.exercise_code
join public.movement_capabilities mc
  on mc.capability_code = rs.capability_code
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
    'ROM_shoulder_abduction',
    'ROM_shoulder_internal_rotation',
    'ROM_hip_abduction',
    'ROM_hip_internal_rotation',
    'ROM_ankle_plantarflexion',
    'ROM_ankle_inversion'
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
