-- Assessment capability bridge wave 1.
-- Purpose: move high-value PT assessment observations from taxonomy-only/template-only
-- coverage into the exercise reasoning graph.
--
-- Scope:
-- - Adds small generic capabilities needed by TUG, BBS, gait speed, 6MWT, and SLR/Slump.
-- - Maps existing observation_taxonomy codes to those capabilities.
-- - Adds a conservative set of exercise_requirements so these mappings reach L2.
-- - Leaves full L3 clinical validation/rule tuning to follow-up waves.

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
    'functional_transfer_balance',
    'Functional transfer balance',
    '기능적 이동/전이 균형',
    'functional',
    'global',
    false,
    'quantity',
    's',
    'lower_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'source_tools', jsonb_build_array('TUG', '5xSTS'),
      'l3_needed', jsonb_build_array('clinical_cutoff', 'severity_threshold', 'regression_rule'),
      'notes', 'Lower task-completion time generally indicates better functional transfer/mobility capacity.'
    ),
    'active'
  ),
  (
    'balance_function_score',
    'Balance function score',
    '균형 기능 점수',
    'balance',
    'global',
    false,
    'integer',
    'score',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'source_tools', jsonb_build_array('BBS'),
      'score_max', 56,
      'l3_needed', jsonb_build_array('clinical_cutoff', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'gait_speed_capacity',
    'Gait speed capacity',
    '보행 속도 능력',
    'functional',
    'global',
    false,
    'quantity',
    'm/s',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'source_tools', jsonb_build_array('gait_speed', '10m_walk_test'),
      'l3_needed', jsonb_build_array('clinical_cutoff', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'walking_endurance_capacity',
    'Walking endurance capacity',
    '보행 지구력',
    'endurance',
    'global',
    false,
    'quantity',
    'm',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'source_tools', jsonb_build_array('6MWT'),
      'l3_needed', jsonb_build_array('clinical_cutoff', 'severity_threshold', 'regression_rule')
    ),
    'active'
  ),
  (
    'neural_symptom_tolerance',
    'Neural symptom tolerance',
    '신경 증상 허용도',
    'load_tolerance',
    'global',
    true,
    'quantity',
    'level',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'source_tools', jsonb_build_array('SLR', 'Slump'),
      'examples', jsonb_build_array('straight_leg_raise', 'slump', 'radiating_pain_extent'),
      'l3_needed', jsonb_build_array('laterality', 'clinical_cutoff', 'severity_threshold', 'regression_rule'),
      'notes', 'Angle observations can compare numerically; positive/negative JSON/string observations need L3 interpretation rules.'
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
    ('TUG_seconds', 'functional_transfer_balance', 's', 'quantity', 'TUG elapsed time -> functional transfer balance'),
    ('five_times_sit_to_stand_seconds', 'functional_transfer_balance', 's', 'quantity', '5xSTS elapsed time -> functional transfer balance'),
    ('BBS_total', 'balance_function_score', 'score', 'integer', 'BBS total score -> balance function score'),
    ('gait_speed', 'gait_speed_capacity', 'm/s', 'quantity', 'Canonical gait speed observation -> gait speed capacity'),
    ('GAIT_speed', 'gait_speed_capacity', 'm/s', 'quantity', 'Legacy/canonicalized gait speed observation -> gait speed capacity'),
    ('PHYSIO-GAIT-SPEED', 'gait_speed_capacity', 'm/s', 'quantity', 'Physio gait speed source code -> gait speed capacity'),
    ('ten_meter_walk_speed', 'gait_speed_capacity', 'm/s', 'quantity', '10-meter walk speed -> gait speed capacity'),
    ('six_minute_walk_distance', 'walking_endurance_capacity', 'm', 'quantity', '6MWT distance -> walking endurance capacity'),
    ('special_test_slr_angle', 'neural_symptom_tolerance', 'deg', 'quantity', 'SLR angle -> neural symptom tolerance'),
    ('special_test_slr', 'neural_symptom_tolerance', null, 'json', 'SLR result -> neural symptom tolerance'),
    ('SLR', 'neural_symptom_tolerance', null, 'json', 'Legacy SLR result -> neural symptom tolerance'),
    ('special_test_slump', 'neural_symptom_tolerance', null, 'json', 'Slump result -> neural symptom tolerance'),
    ('SLUMP', 'neural_symptom_tolerance', null, 'json', 'Legacy Slump result -> neural symptom tolerance')
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
    'seed_wave', 'assessment_capability_bridge_wave1',
    'completion_level', 'L2',
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
    -- Functional transfer time: lower is better, so requirements use max_value.
    ('edb_Chair_Squat', 'functional_transfer_balance', 'required', null::numeric, 20::numeric, 's', null::boolean, 1, null::text, 'low', 'Chair squat is a supported transfer pattern; slower transfer time should trigger easier entry and cueing.'),
    ('edb_Bodyweight_Squat', 'functional_transfer_balance', 'required', null, 15, 's', null, 2, null, 'moderate', 'Bodyweight squat requires baseline sit-to-stand/transfer capacity.'),
    ('edb_Barbell_Step_Ups', 'functional_transfer_balance', 'required', null, 14, 's', null, 3, null, 'moderate', 'Step-up work requires functional transfer capacity.'),
    ('EX_ANKL_FNC_002', 'functional_transfer_balance', 'required', null, 15, 's', null, 2, null, 'moderate', 'Stair-climbing work requires baseline TUG/transfer performance.'),
    ('pk_lunge', 'functional_transfer_balance', 'required', null, 14, 's', null, 3, null, 'moderate', 'Lunge requires functional transfer and dynamic mobility capacity.'),

    -- BBS-style balance score: higher is better.
    ('pk_single_leg_stance', 'balance_function_score', 'target', 45, null, 'score', null, 2, null, 'moderate', 'Single-leg stance targets balance when global balance score is reduced but safe enough to train.'),
    ('edb_Balance_Board', 'balance_function_score', 'required', 45, null, 'score', null, 3, null, 'moderate', 'Balance board work requires sufficient global balance function.'),
    ('pk_lunge', 'balance_function_score', 'required', 48, null, 'score', null, 3, null, 'moderate', 'Lunge requires adequate balance function.'),
    ('edb_Bodyweight_Walking_Lunge', 'balance_function_score', 'required', 50, null, 'score', null, 3, null, 'high', 'Walking lunge requires higher global balance function.'),

    -- Gait speed: higher is better.
    ('EX_ANKL_FNC_008', 'gait_speed_capacity', 'required', 0.6, null, 'm/s', null, 2, null, 'moderate', 'Step-over work requires basic community-facing gait speed.'),
    ('EX_ANKL_FNC_002', 'gait_speed_capacity', 'required', 0.6, null, 'm/s', null, 2, null, 'moderate', 'Stair-climbing work requires baseline gait speed capacity.'),
    ('edb_Barbell_Step_Ups', 'gait_speed_capacity', 'required', 0.8, null, 'm/s', null, 3, null, 'moderate', 'Loaded step-up work benefits from stronger gait speed capacity.'),
    ('pk_lunge', 'gait_speed_capacity', 'required', 0.8, null, 'm/s', null, 3, null, 'moderate', 'Lunge progression requires dynamic gait/mobility capacity.'),

    -- Walking endurance: higher is better.
    ('EX_ANKL_FNC_008', 'walking_endurance_capacity', 'target', 150, null, 'm', null, 2, null, 'low', 'Step-over work can build functional walking endurance.'),
    ('EX_ANKL_FNC_002', 'walking_endurance_capacity', 'required', 200, null, 'm', null, 2, null, 'moderate', 'Stair-climbing work requires baseline walking endurance.'),
    ('edb_Bodyweight_Walking_Lunge', 'walking_endurance_capacity', 'required', 250, null, 'm', null, 3, null, 'moderate', 'Walking lunge requires more sustained lower-limb functional capacity.'),

    -- Neural symptom tolerance: angle observations can compare now; positive/negative JSON needs L3 interpretation rules.
    ('pk_straight_leg_raise', 'neural_symptom_tolerance', 'caution', 45, null, 'deg', null, 2, 'either', 'moderate', 'Straight-leg raise exercise should stay cautious when neural tension tolerance is limited.'),
    ('edb_90_90_Hamstring', 'neural_symptom_tolerance', 'caution', 45, null, 'deg', null, 2, 'either', 'moderate', 'Hamstring mobility work should be symptom-guided when SLR/slump findings suggest neural sensitivity.')
  ) as seed(
    exercise_code,
    capability_code,
    requirement_role,
    min_value,
    max_value,
    value_unit,
    required_boolean,
    requirement_level,
    laterality,
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
  requirement_seed.required_boolean,
  requirement_seed.requirement_level,
  requirement_seed.laterality,
  requirement_seed.severity,
  requirement_seed.rationale,
  'expert_seed_mvp',
  jsonb_build_object(
    'seed_wave', 'assessment_capability_bridge_wave1',
    'completion_level', 'L2',
    'l3_status', 'cutoffs are conservative MVP defaults; review before strong automated prescribing'
  ),
  'active'
from requirement_seed
join public.exercises
  on exercises.exercise_code = requirement_seed.exercise_code
join public.movement_capabilities
  on movement_capabilities.capability_code = requirement_seed.capability_code
on conflict (exercise_id, capability_id, requirement_role, coalesce(laterality, '')) where status = 'active'
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
    'TUG_seconds',
    'five_times_sit_to_stand_seconds',
    'BBS_total',
    'gait_speed',
    'GAIT_speed',
    'PHYSIO-GAIT-SPEED',
    'ten_meter_walk_speed',
    'six_minute_walk_distance',
    'special_test_slr_angle',
    'special_test_slr',
    'SLR',
    'special_test_slump',
    'SLUMP'
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
