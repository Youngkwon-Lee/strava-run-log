-- Seed P88 Copenhagen adduction endurance L2 bridge.
-- Purpose:
-- - add a semantically correct groin/adductor endurance capability
-- - connect Copenhagen hold time into an exercise-facing sports path
-- - keep the wave at L2 and do not overclaim return-to-sport automation

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
values (
  'hip_adduction_endurance',
  'Hip adduction endurance',
  '고관절 내전 지구력',
  'endurance',
  'hip',
  true,
  'quantity',
  'seconds',
  'higher_is_better',
  jsonb_build_object(
    'mvp_completion_level', 'L2',
    'source_tools', jsonb_build_array('COPENHAGEN_ADDUCTION_TEST'),
    'l3_needed', jsonb_build_array('laterality', 'pain_irritability', 'return_to_sport_phase', 'clinical_cutoff'),
    'capability_v2_family', 'endurance',
    'capability_v2_family_ko', '지구력',
    'capability_v2_secondary_families', jsonb_build_array('gross_motor'),
    'capability_v2_bridge_sources', jsonb_build_array('Copenhagen adduction', 'groin endurance'),
    'capability_v2_explanation_cue', 'Groin/adductor endurance helps explain hop, cutting, and lateral-load progression readiness but still needs symptom and phase context.'
  ),
  'active'
)
on conflict (capability_code) do update
set display = excluded.display,
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
  select
    'COPENHAGEN_hold_time_seconds'::text as observation_code,
    'hip_adduction_endurance'::text as capability_code,
    'seconds'::text as default_unit,
    'quantity'::text as value_type_hint,
    'L2'::text as completion_level,
    'Copenhagen hold time is a direct groin/adductor endurance anchor that can feed sports loading decisions.'::text as rationale
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
  ms.observation_code,
  'http://physiokorea.com/fhir/observation',
  mc.id,
  ms.default_unit,
  ms.value_type_hint,
  jsonb_build_object(
    'seed_wave', 'p88_copenhagen_endurance_l2_bridge',
    'completion_level', ms.completion_level,
    'rationale', ms.rationale
  ),
  'active'
from mapping_seed ms
join public.movement_capabilities mc
  on mc.capability_code = ms.capability_code
 and mc.status = 'active'
on conflict (observation_code, observation_code_system, capability_id) do update
set default_unit = excluded.default_unit,
    value_type_hint = excluded.value_type_hint,
    metadata = public.movement_capability_observation_mappings.metadata || excluded.metadata,
    status = 'active',
    updated_at = now();
with requirement_seed (
  exercise_code,
  capability_code,
  requirement_role,
  min_value,
  max_value,
  value_unit,
  requirement_level,
  severity,
  rationale
) as (
  values
    (
      'edb_Thigh_Adductor',
      'hip_adduction_endurance',
      'target',
      10::numeric,
      null::numeric,
      'seconds',
      2,
      'low',
      'Thigh adductor work can begin building baseline groin/adductor endurance.'
    ),
    (
      'EX_HIP_PLY_004',
      'hip_adduction_endurance',
      'required',
      20::numeric,
      null::numeric,
      'seconds',
      3,
      'moderate',
      'Single-leg hop progression benefits from baseline adductor endurance for frontal-plane hip control.'
    ),
    (
      'edb_Hurdle_Hops',
      'hip_adduction_endurance',
      'required',
      25::numeric,
      null::numeric,
      'seconds',
      4,
      'moderate',
      'Repeated hurdle hops benefit from stronger groin/adductor endurance before higher-speed cutting and landing work.'
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
  null,
  rs.requirement_level,
  null,
  rs.severity,
  rs.rationale,
  'expert_consensus',
  jsonb_build_object(
    'seed_wave', 'p88_copenhagen_endurance_l2_bridge',
    'scope', 'sports_groin_followup'
  ),
  'active'
from requirement_seed rs
join public.exercises e
  on e.exercise_code = rs.exercise_code
 and e.is_active = true
join public.movement_capabilities mc
  on mc.capability_code = rs.capability_code
 and mc.status = 'active'
on conflict (
  exercise_id,
  capability_id,
  requirement_role,
  coalesce(laterality, ''::text)
) where status = 'active' do update
set min_value = excluded.min_value,
    max_value = excluded.max_value,
    value_unit = excluded.value_unit,
    requirement_level = excluded.requirement_level,
    severity = excluded.severity,
    rationale = excluded.rationale,
    evidence_level = excluded.evidence_level,
    metadata = public.exercise_requirements.metadata || excluded.metadata,
    status = 'active',
    updated_at = now();
