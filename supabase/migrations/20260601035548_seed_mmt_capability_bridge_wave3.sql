-- MMT capability bridge wave 3.
-- Purpose: connect the next MVP MMT fan-out observations to exercise reasoning.
--
-- Scope:
-- - Adds three strength capabilities for existing MMT observation codes.
-- - Maps MMT observations to those capabilities.
-- - Adds a small set of exercise requirements so these rows reach L2.
-- - Backfills patient_capability_observations from existing observations.
--
-- This is intentionally L2. MMT-specific L3 thresholds and side-specific dosage
-- rules should be reviewed in a later wave.

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
    'shoulder_abduction_strength',
    'Shoulder abduction strength',
    '어깨 외전 근력',
    'strength',
    'shoulder',
    true,
    'quantity',
    'grade',
    'higher_is_better',
    jsonb_build_object(
      'mmt', true,
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('MMT_shoulder_abduction'),
      'l3_needed', jsonb_build_array('laterality_dosage', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'ankle_dorsiflexion_strength',
    'Ankle dorsiflexion strength',
    '발목 배측굴곡 근력',
    'strength',
    'ankle',
    true,
    'quantity',
    'grade',
    'higher_is_better',
    jsonb_build_object(
      'mmt', true,
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('MMT_ankle_dorsiflexion'),
      'l3_needed', jsonb_build_array('laterality_dosage', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'trunk_flexion_strength',
    'Trunk flexion strength',
    '몸통 굴곡 근력',
    'strength',
    'trunk',
    false,
    'quantity',
    'grade',
    'higher_is_better',
    jsonb_build_object(
      'mmt', true,
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('MMT_trunk_flexion'),
      'l3_needed', jsonb_build_array('severity_threshold', 'regression_rule')
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
      'MMT_shoulder_abduction',
      'shoulder_abduction_strength',
      'grade',
      'json',
      'Shoulder abduction MMT -> shoulder abduction strength.'
    ),
    (
      'MMT_ankle_dorsiflexion',
      'ankle_dorsiflexion_strength',
      'grade',
      'json',
      'Ankle dorsiflexion MMT -> ankle dorsiflexion strength.'
    ),
    (
      'MMT_trunk_flexion',
      'trunk_flexion_strength',
      'grade',
      'quantity',
      'Trunk flexion MMT -> trunk flexion strength.'
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
    'seed_wave', 'mmt_capability_bridge_wave3',
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
      'pk_shoulder_abduction_seated',
      'shoulder_abduction_strength',
      'target',
      2::numeric,
      null::numeric,
      'grade',
      2,
      'low',
      'Seated shoulder abduction is an early strengthening option when abduction MMT is reduced.'
    ),
    (
      'edb_Lateral_Raise_-_With_Bands',
      'shoulder_abduction_strength',
      'required',
      3::numeric,
      null::numeric,
      'grade',
      3,
      'moderate',
      'Band lateral raise requires baseline shoulder abduction strength.'
    ),
    (
      'edb_Side_Lateral_Raise',
      'shoulder_abduction_strength',
      'required',
      3::numeric,
      null::numeric,
      'grade',
      3,
      'moderate',
      'Side lateral raise requires baseline shoulder abduction strength.'
    ),
    (
      'pk_ankle_dorsiflexion',
      'ankle_dorsiflexion_strength',
      'target',
      2::numeric,
      null::numeric,
      'grade',
      2,
      'low',
      'Ankle dorsiflexion exercise targets tibialis anterior/dorsiflexion strength.'
    ),
    (
      'edb_Crunches',
      'trunk_flexion_strength',
      'target',
      3::numeric,
      null::numeric,
      'grade',
      2,
      'moderate',
      'Crunches target trunk flexion strength.'
    ),
    (
      'edb_Reverse_Crunch',
      'trunk_flexion_strength',
      'target',
      3::numeric,
      null::numeric,
      'grade',
      2,
      'moderate',
      'Reverse crunch targets trunk flexion strength with different hip/pelvis demand.'
    ),
    (
      'edb_Ab_Crunch_Machine',
      'trunk_flexion_strength',
      'required',
      3::numeric,
      null::numeric,
      'grade',
      3,
      'moderate',
      'Machine crunch requires baseline trunk flexion strength before external load.'
    ),
    (
      'edb_Cable_Crunch',
      'trunk_flexion_strength',
      'required',
      3::numeric,
      null::numeric,
      'grade',
      3,
      'moderate',
      'Cable crunch requires baseline trunk flexion strength before loaded cable work.'
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
    'seed_wave', 'mmt_capability_bridge_wave3',
    'plain_status', '운동 판단 연결'
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
    'MMT_shoulder_abduction',
    'MMT_ankle_dorsiflexion',
    'MMT_trunk_flexion'
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
