-- Remaining MMT fan-out wave 6.
-- Purpose: complete the current canonical MMT observation set for MVP L2
-- exercise reasoning without going deep into specialty hand/foot protocols yet.
--
-- Scope:
-- - Reuse existing elbow flexion strength capability and mark it as L2-ready.
-- - Add wrist extension and great toe extension strength capabilities.
-- - Map the remaining canonical MMT observation codes to those capabilities.
-- - Seed a small set of exercise requirements so these rows reach L2.
-- - Backfill patient_capability_observations from any existing canonical rows.
--
-- This is intentionally L2. MMT-specific L3 thresholds, laterality dosing, and
-- regression rules still need a later review.

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
    'elbow_flexion_strength',
    'Elbow flexion strength',
    '팔꿈치 굴곡 근력',
    'strength',
    'elbow',
    true,
    'quantity',
    'grade',
    'higher_is_better',
    jsonb_build_object(
      'mmt', true,
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('MMT_elbow_flexion'),
      'l3_needed', jsonb_build_array('laterality_dosage', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'wrist_extension_strength',
    'Wrist extension strength',
    '손목 신전 근력',
    'strength',
    'wrist_hand',
    true,
    'quantity',
    'grade',
    'higher_is_better',
    jsonb_build_object(
      'mmt', true,
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('MMT_wrist_extension'),
      'l3_needed', jsonb_build_array('laterality_dosage', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'great_toe_extension_strength',
    'Great toe extension strength',
    '엄지발가락 신전 근력',
    'strength',
    'foot',
    true,
    'quantity',
    'grade',
    'higher_is_better',
    jsonb_build_object(
      'mmt', true,
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('MMT_great_toe_extension'),
      'l3_needed', jsonb_build_array('laterality_dosage', 'severity_threshold', 'regression_rule')
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
    (
      'MMT_elbow_flexion',
      'elbow_flexion_strength',
      'grade',
      'json',
      'Elbow flexion MMT -> elbow flexion strength.'
    ),
    (
      'MMT_wrist_extension',
      'wrist_extension_strength',
      'grade',
      'json',
      'Wrist extension MMT -> wrist extension strength.'
    ),
    (
      'MMT_great_toe_extension',
      'great_toe_extension_strength',
      'grade',
      'json',
      'Great toe extension MMT -> great toe extension strength.'
    )
  ) as seed(observation_code, capability_code, default_unit, value_type_hint, rationale)
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
  mapping_seed.default_unit,
  mapping_seed.value_type_hint,
  jsonb_build_object(
    'seed_wave', 'remaining_mmt_fanout_wave6',
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
      'edb_Hammer_Curls',
      'elbow_flexion_strength',
      'target',
      3::numeric,
      null::numeric,
      'grade',
      3,
      'moderate',
      'Hammer curls target elbow flexion strength in a simple open-chain pattern.'
    ),
    (
      'edb_Dumbbell_Bicep_Curl',
      'elbow_flexion_strength',
      'required',
      3::numeric,
      null::numeric,
      'grade',
      3,
      'moderate',
      'Dumbbell bicep curl requires baseline elbow flexion strength before repeated loaded reps.'
    ),
    (
      'edb_Preacher_Curl',
      'elbow_flexion_strength',
      'required',
      3::numeric,
      null::numeric,
      'grade',
      3,
      'moderate',
      'Preacher curl requires baseline elbow flexion strength and control.'
    ),
    (
      'edb_Palms-Down_Wrist_Curl_Over_A_Bench',
      'wrist_extension_strength',
      'target',
      2::numeric,
      null::numeric,
      'grade',
      2,
      'low',
      'Palms-down wrist curl targets wrist extensor strength with a simple supported setup.'
    ),
    (
      'edb_Seated_Palms-Down_Barbell_Wrist_Curl',
      'wrist_extension_strength',
      'required',
      3::numeric,
      null::numeric,
      'grade',
      3,
      'moderate',
      'Seated barbell wrist extension loading requires baseline wrist extensor strength.'
    ),
    (
      'edb_Wrist_Roller',
      'wrist_extension_strength',
      'required',
      3::numeric,
      null::numeric,
      'grade',
      3,
      'moderate',
      'Wrist roller requires enough wrist extensor strength to sustain loaded forearm work.'
    ),
    (
      'EX_ANKL_SGT_001',
      'great_toe_extension_strength',
      'target',
      1::numeric,
      null::numeric,
      'grade',
      1,
      'low',
      'Early ankle-foot isometric work can start when great toe extension strength is limited.'
    ),
    (
      'EX_ANKL_SGT_004',
      'great_toe_extension_strength',
      'target',
      2::numeric,
      null::numeric,
      'grade',
      2,
      'low',
      'Band-based ankle-foot strengthening can be used to build toe extension contribution.'
    ),
    (
      'EX_ANKL_FNC_015',
      'great_toe_extension_strength',
      'required',
      2::numeric,
      null::numeric,
      'grade',
      2,
      'moderate',
      'Gait training needs enough great toe extension strength for toe clearance and terminal stance mechanics.'
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
    'seed_wave', 'remaining_mmt_fanout_wave6',
    'plain_status', '운동 판단 연결',
    'source_family', 'MMT'
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
    'MMT_elbow_flexion',
    'MMT_wrist_extension',
    'MMT_great_toe_extension'
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
