-- Seed ODI lumbar function L3 bridge.
--
-- Purpose:
-- - move ODI from semantic-only into an executable lumbar function bridge
-- - keep ODI as a screening/default load-tolerance gate, not a diagnosis or
--   stand-alone exercise clearance rule
-- - add conservative exercise requirement gates for common low-back/core
--   starter exercises so high disability prompts easier versions and closer
--   symptom monitoring
--
-- Guardrails:
-- - no official ODI item wording is embedded
-- - thresholds are MVP screening defaults and require clinician review
-- - red flags and neurologic deterioration remain higher-priority gates

insert into public.observation_taxonomy (
  code,
  code_system,
  code_display,
  category,
  default_value_type,
  default_unit,
  data_source,
  notes,
  is_active
)
values (
  'ODI',
  'http://physiokorea.com/fhir/observation',
  'Oswestry Disability Index total score',
  array['exam','lumbar','function','disability']::text[],
  'quantity',
  'score',
  'odi_lumbar_function_l3_bridge',
  'ODI total score summary anchor. Licensed item wording is not embedded.',
  true
)
on conflict (code, code_system) do update
set
  code_display = excluded.code_display,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  data_source = excluded.data_source,
  notes = excluded.notes,
  is_active = true,
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
  observation_taxonomy_id,
  properties,
  status
)
select
  'lumbar_function_disability_tolerance',
  'Lumbar function disability tolerance',
  '요추 기능장애 허용도',
  'functional',
  'lumbar',
  false,
  'quantity',
  'score',
  'lower_is_better',
  ot.id,
  jsonb_build_object(
    'seed_wave', 'odi_lumbar_function_l3_bridge',
    'mvp_completion_level', 'L3',
    'plain_status', '처방 판단 가능',
    'source_tools', jsonb_build_array('ODI'),
    'license_guardrail', 'official item wording not embedded',
    'automation_boundary', 'screening default for dosing/regression; not stand-alone clearance',
    'l3_rules', jsonb_build_object(
      'basis', 'mvp_screening_default_not_diagnostic',
      'source_tools', jsonb_build_array('ODI'),
      'decision_bands', jsonb_build_array(
        jsonb_build_object(
          'label', 'ready',
          'operator', '<=',
          'value', 20,
          'unit', 'score',
          'plain_ko', '기본 운동 가능'
        ),
        jsonb_build_object(
          'label', 'caution',
          'operator', '<=',
          'value', 40,
          'unit', 'score',
          'plain_ko', '주의/보조 필요',
          'and_operator', '>',
          'and_value', 20
        ),
        jsonb_build_object(
          'label', 'regress',
          'operator', '>',
          'value', 40,
          'unit', 'score',
          'plain_ko', '쉬운 버전 우선'
        )
      ),
      'default_regression', 'Prefer low-load positions, shorter range, supported trunk control, lower volume, and symptom-guided pacing before loaded or high-endurance lumbar/core work.',
      'symptom_response_rule', 'Downgrade one band when pain, distal symptoms, or next-day function worsens even if ODI alone looks ready.',
      'laterality_required', false,
      'review_note', 'ODI score should be interpreted with pain irritability, neurologic screen, red flags, ROM, and patient-specific goals.'
    )
  ),
  'active'
from public.observation_taxonomy ot
where ot.code = 'ODI'
  and ot.code_system = 'http://physiokorea.com/fhir/observation'
on conflict (capability_code) do update
set
  display = excluded.display,
  display_ko = excluded.display_ko,
  capability_domain = excluded.capability_domain,
  body_region = excluded.body_region,
  laterality_applicable = excluded.laterality_applicable,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  measurement_direction = excluded.measurement_direction,
  observation_taxonomy_id = excluded.observation_taxonomy_id,
  properties = coalesce(public.movement_capabilities.properties, '{}'::jsonb) || excluded.properties,
  status = 'active',
  updated_at = now();
with mapping_seed (
  observation_code,
  capability_code,
  default_unit,
  value_type_hint,
  completion_level,
  rationale,
  clinical_interpretation
) as (
  values (
    'ODI',
    'lumbar_function_disability_tolerance',
    'score',
    'quantity',
    'L3',
    'ODI total score can drive lumbar/core exercise regression and pacing decisions when interpreted with safety screen, pain irritability, neurologic findings, ROM, and goals.',
    'Use ODI as a disability-burden gate. High scores should bias toward lower-load, supported, short-range, and monitored exercise rather than routine progression.'
  )
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
    'seed_wave', 'odi_lumbar_function_l3_bridge',
    'bridge_level', ms.completion_level,
    'mvp_completion_level', ms.completion_level,
    'rationale', ms.rationale,
    'capability_code', ms.capability_code,
    'clinical_interpretation', ms.clinical_interpretation,
    'license_guardrail', 'official item wording not embedded',
    'automation_boundary', 'screening default for dosing/regression; not stand-alone clearance'
  ),
  'active'
from mapping_seed ms
join public.movement_capabilities mc
  on mc.capability_code = ms.capability_code
 and mc.status = 'active'
on conflict (observation_code, observation_code_system, capability_id) do update
set
  default_unit = excluded.default_unit,
  value_type_hint = excluded.value_type_hint,
  metadata = coalesce(public.movement_capability_observation_mappings.metadata, '{}'::jsonb) || excluded.metadata,
  status = 'active',
  updated_at = now();
with link_targets as (
  select
    aft.id as form_template_id,
    nullif(item.value ->> 'question_number', '')::integer as question_number,
    ot.id as observation_taxonomy_id,
    cc.id as clinical_concept_id
  from public.assessment_form_templates aft
  join lateral jsonb_array_elements(coalesce(aft.items, '[]'::jsonb)) as item(value)
    on item.value ->> 'score_key' = 'total_score'
  join public.observation_taxonomy ot
    on ot.code = 'ODI'
   and ot.code_system = 'http://physiokorea.com/fhir/observation'
  left join public.clinical_concepts cc
    on cc.concept_key = 'assessment_template:odi'
  where aft.form_code = 'ODI'
)
insert into public.assessment_template_item_semantic_links (
  form_template_id,
  score_key,
  question_number,
  binding_role,
  observation_taxonomy_id,
  clinical_concept_id,
  observation_code,
  observation_code_system,
  display_override,
  category,
  default_value_type,
  default_unit,
  notes,
  metadata,
  status
)
select
  form_template_id,
  'total_score',
  question_number,
  'aggregate',
  observation_taxonomy_id,
  clinical_concept_id,
  'ODI',
  'http://physiokorea.com/fhir/observation',
  'ODI total score',
  array['exam','lumbar','function','disability']::text[],
  'quantity',
  'score',
  'ODI total score summary anchor. Licensed item wording is not embedded.',
  jsonb_build_object(
    'seed_wave', 'odi_lumbar_function_l3_bridge',
    'form_code', 'ODI',
    'capability_bridge', 'lumbar_function_disability_tolerance',
    'bridge_level', 'L3',
    'license_guardrail', 'official item wording not embedded'
  ),
  'active'
from link_targets
on conflict (form_template_id, score_key, binding_role) do update
set
  question_number = excluded.question_number,
  observation_taxonomy_id = excluded.observation_taxonomy_id,
  clinical_concept_id = excluded.clinical_concept_id,
  observation_code = excluded.observation_code,
  observation_code_system = excluded.observation_code_system,
  display_override = excluded.display_override,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  notes = excluded.notes,
  metadata = coalesce(public.assessment_template_item_semantic_links.metadata, '{}'::jsonb) || excluded.metadata,
  status = 'active',
  updated_at = now();
with requirement_seed (
  exercise_name,
  requirement_role,
  max_value,
  severity,
  rationale,
  default_regression
) as (
  values
    (
      'Pelvic Tilt',
      'required',
      60::numeric,
      'low',
      'Pelvic tilt can be used with higher ODI burden but should remain low-load and symptom-guided.',
      'Use hook-lying pelvic clock, smaller range, fewer reps, or breathing reset first.'
    ),
    (
      'Dead Bug',
      'required',
      40::numeric,
      'moderate',
      'Dead bug requires enough lumbar function tolerance to maintain trunk control without symptom escalation.',
      'Regress to heel taps, arms-only, shorter lever, or supported breathing reset.'
    ),
    (
      'Bird Dog',
      'required',
      40::numeric,
      'moderate',
      'Bird dog requires moderate lumbar function tolerance and trunk control.',
      'Regress to quadruped weight shift, arm-only bird dog, leg slide, or tabletop support.'
    ),
    (
      'Side Plank',
      'required',
      30::numeric,
      'moderate',
      'Side plank should be scaled when ODI disability burden suggests limited trunk endurance or participation tolerance.',
      'Regress to side plank from knees, short holds, side-lying brace, or anti-rotation isometric.'
    ),
    (
      'Prone Press Up (McKenzie)',
      'required',
      40::numeric,
      'moderate',
      'Prone press-up should be symptom-guided when ODI burden is moderate or high.',
      'Regress to prone lying, prone on elbows, smaller range, or hold if distal symptoms worsen.'
    )
),
target_exercises as (
  select
    e.id as exercise_id,
    rs.requirement_role,
    rs.max_value,
    rs.severity,
    rs.rationale,
    rs.default_regression
  from requirement_seed rs
  join public.exercises e
    on e.exercise_name = rs.exercise_name
   and e.is_active = true
),
capability as (
  select id
  from public.movement_capabilities
  where capability_code = 'lumbar_function_disability_tolerance'
    and status = 'active'
)
insert into public.exercise_requirements (
  exercise_id,
  capability_id,
  requirement_role,
  max_value,
  value_unit,
  requirement_level,
  severity,
  rationale,
  evidence_level,
  metadata,
  status
)
select
  te.exercise_id,
  c.id,
  te.requirement_role,
  te.max_value,
  'score',
  2,
  te.severity,
  te.rationale,
  'MVP screening default',
  jsonb_build_object(
    'seed_wave', 'odi_lumbar_function_l3_bridge',
    'completion_level', 'L3',
    'capability_code', 'lumbar_function_disability_tolerance',
    'measurement_direction', 'lower_is_better',
    'default_regression', te.default_regression,
    'symptom_response_rule', 'Downgrade or stop when pain, distal symptoms, or next-day function worsens.',
    'automation_boundary', 'screening default; clinician remains final decision-maker'
  ),
  'active'
from target_exercises te
cross join capability c
on conflict (exercise_id, capability_id, requirement_role, coalesce(laterality, '')) where status = 'active'
do update
set
  max_value = excluded.max_value,
  value_unit = excluded.value_unit,
  requirement_level = excluded.requirement_level,
  severity = excluded.severity,
  rationale = excluded.rationale,
  evidence_level = excluded.evidence_level,
  metadata = coalesce(public.exercise_requirements.metadata, '{}'::jsonb) || excluded.metadata,
  updated_at = now();
