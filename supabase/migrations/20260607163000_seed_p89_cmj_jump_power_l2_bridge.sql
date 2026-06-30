-- Seed P89 CMJ jump-power L2 bridge.
-- Purpose:
-- - add a dedicated jump-power capability for CMJ height
-- - connect CMJ height into exercise-facing plyometric progression
-- - keep the wave at L2; asymmetry, landing quality, and sport phase remain L3 work

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
  'jump_power_capacity',
  'Jump power capacity',
  '점프 파워 능력',
  'functional',
  'lower_extremity',
  false,
  'quantity',
  'cm',
  'higher_is_better',
  jsonb_build_object(
    'mvp_completion_level', 'L2',
    'source_tools', jsonb_build_array('CMJ_SCREEN'),
    'l3_needed', jsonb_build_array('landing_quality', 'asymmetry', 'pain_irritability', 'return_to_sport_phase'),
    'notes', 'CMJ best jump height is a practical jump-power anchor for sports follow-up but should not automate return-to-sport decisions by itself.'
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
    'CMJ_best_jump_height'::text as observation_code,
    'jump_power_capacity'::text as capability_code,
    'cm'::text as default_unit,
    'quantity'::text as value_type_hint,
    'L2'::text as completion_level,
    'CMJ best jump height is a direct jump-power anchor for plyometric progression matching.'::text as rationale
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
    'seed_wave', 'p89_cmj_jump_power_l2_bridge',
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
      'edb_Standing_Long_Jump',
      'jump_power_capacity',
      'target',
      15::numeric,
      null::numeric,
      'cm',
      2,
      'low',
      'Standing long jump work can build baseline jump-power output for sports follow-up.'
    ),
    (
      'EX_KNEE_PLY_001',
      'jump_power_capacity',
      'required',
      20::numeric,
      null::numeric,
      'cm',
      3,
      'moderate',
      'Box-jump progression benefits from baseline jump-power output before higher landing demand.'
    ),
    (
      'edb_Hurdle_Hops',
      'jump_power_capacity',
      'required',
      25::numeric,
      null::numeric,
      'cm',
      4,
      'moderate',
      'Repeated hurdle hops benefit from stronger jump-power output before faster plyometric progression.'
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
    'seed_wave', 'p89_cmj_jump_power_l2_bridge',
    'scope', 'sports_jump_power_followup'
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
