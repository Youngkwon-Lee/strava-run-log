-- Seed P95 SCI functional/walking L2-L3 bridge.
--
-- Purpose:
-- - connect SCIM and WISCI summary cards that currently exist as Encounter
--   templates but do not yet feed the capability/exercise reasoning bridge
-- - add capability evidence for AI/RAG/reasoning without creating an SCI
--   if/then recommendation engine
-- - keep licensed-tool guardrails: no official item wording is embedded
--
-- Clinical safety note:
-- These are MVP spinal cord injury rehab-screen defaults for exercise matching.
-- They are not independent standing, gait, wheelchair, transfer, autonomic,
-- skin, bowel/bladder, return-to-driving, or community ambulation clearance
-- rules. Neurologic level/AIS, orthostatic tolerance, autonomic dysreflexia
-- symptoms, skin/pressure status, spasticity, pain, assist level, device or
-- orthosis fit, caregiver support, fatigue, and 24-hour response remain
-- clinician-reviewed context.

with taxonomy_seed (
  code,
  code_display,
  category,
  default_value_type,
  default_unit,
  reference_range_low,
  reference_range_high,
  reference_range_text,
  interpretation_guide,
  notes
) as (
  values
    (
      'SCIM_total_score',
      'SCIM total score',
      array['exam', 'spinal_cord_injury', 'function']::text[],
      'quantity',
      'score',
      0::numeric,
      100::numeric,
      'SCIM total score. MVP screen: >=60 ready, 40-59 caution/support review, <40 regress/support-first review. Use with neurological level, transfer/device context, skin/autonomic safety, and caregiver support.',
      jsonb_build_object(
        'seed_wave', 'p95_sci_functional_walking_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'sci_independence_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=60/100', 'caution: 40-59/100', 'regress/support-first: <40/100'),
        'safety_note', 'SCIM total is functional independence evidence, not stand-alone transfer, gait, skin, autonomic, or community clearance.'
      ),
      'SCIM-style total score anchor; official item wording not embedded.'
    ),
    (
      'SCIM_mobility_subscore',
      'SCIM mobility subscore',
      array['exam', 'spinal_cord_injury', 'mobility']::text[],
      'quantity',
      'score',
      0::numeric,
      40::numeric,
      'SCIM mobility subscore. MVP screen: >=25 ready, 15-24 caution/support review, <15 regress/support-first review. Use with wheelchair/walking context, assist level, device fit, skin, and autonomic status.',
      jsonb_build_object(
        'seed_wave', 'p95_sci_functional_walking_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'sci_mobility_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=25/40', 'caution: 15-24/40', 'regress/support-first: <15/40'),
        'safety_note', 'SCIM mobility supports transfer/mobility reasoning; pair with pressure relief, orthostatic/autonomic tolerance, assist level, and device setup.'
      ),
      'SCIM-style mobility subscore anchor; official item wording not embedded.'
    ),
    (
      'WISCI_level',
      'WISCI walking support level',
      array['exam', 'spinal_cord_injury', 'walking']::text[],
      'quantity',
      'score',
      0::numeric,
      20::numeric,
      'WISCI level. MVP screen: >=13 ready, 8-12 caution/device-support review, <8 regress/support-first review. Use with orthosis, assistive device, physical assistance, fatigue, skin, and autonomic safety.',
      jsonb_build_object(
        'seed_wave', 'p95_sci_functional_walking_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'sci_walking_support_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=13/20', 'caution: 8-12/20', 'regress/support-first: <8/20'),
        'safety_note', 'WISCI level is walking support evidence, not independent gait or community ambulation clearance.'
      ),
      'WISCI-style walking level anchor; official item wording not embedded.'
    )
),
taxonomy_upsert as (
  insert into public.observation_taxonomy (
    code,
    code_system,
    code_display,
    category,
    default_value_type,
    default_unit,
    reference_range_low,
    reference_range_high,
    reference_range_text,
    interpretation_guide,
    data_source,
    notes,
    is_active,
    updated_at
  )
  select
    code,
    'http://physiokorea.com/fhir/observation',
    code_display,
    category,
    default_value_type,
    default_unit,
    reference_range_low,
    reference_range_high,
    reference_range_text,
    interpretation_guide,
    'p95_sci_functional_walking_l2_l3_bridge',
    notes,
    true,
    now()
  from taxonomy_seed
  on conflict (code) do update
  set
    code_display = excluded.code_display,
    category = excluded.category,
    default_value_type = excluded.default_value_type,
    default_unit = excluded.default_unit,
    reference_range_low = excluded.reference_range_low,
    reference_range_high = excluded.reference_range_high,
    reference_range_text = excluded.reference_range_text,
    interpretation_guide = coalesce(public.observation_taxonomy.interpretation_guide, '{}'::jsonb) || excluded.interpretation_guide,
    data_source = excluded.data_source,
    notes = excluded.notes,
    is_active = true,
    updated_at = now()
  returning id, code
),
link_seed (
  form_code,
  score_key,
  binding_role,
  observation_code,
  display_override,
  category,
  default_value_type,
  default_unit,
  notes
) as (
  values
    ('SCIM_SUMMARY', 'total_score', 'aggregate', 'SCIM_total_score', 'SCIM total score', array['exam', 'spinal_cord_injury', 'function']::text[], 'quantity', 'score', 'SCIM-style total function score.'),
    ('SCIM_SUMMARY', 'mobility_subscore', 'aggregate', 'SCIM_mobility_subscore', 'SCIM mobility subscore', array['exam', 'spinal_cord_injury', 'mobility']::text[], 'quantity', 'score', 'SCIM-style mobility subscore.'),
    ('WISCI_SUMMARY', 'level_if_known', 'aggregate', 'WISCI_level', 'WISCI walking support level', array['exam', 'spinal_cord_injury', 'walking']::text[], 'quantity', 'score', 'WISCI-style walking support level.')
),
link_targets as (
  select
    t.id as form_template_id,
    t.form_code,
    ls.score_key,
    (
      select (item ->> 'question_number')::integer
      from jsonb_array_elements(t.items) item
      where item ->> 'score_key' = ls.score_key
      limit 1
    ) as question_number,
    ls.binding_role,
    ot.id as observation_taxonomy_id,
    cc.id as clinical_concept_id,
    ls.observation_code,
    'http://physiokorea.com/fhir/observation'::text as observation_code_system,
    ls.display_override,
    ls.category,
    ls.default_value_type,
    ls.default_unit,
    ls.notes
  from link_seed ls
  join public.assessment_form_templates t
    on t.form_code = ls.form_code
  join public.observation_taxonomy ot
    on ot.code = ls.observation_code
   and ot.code_system = 'http://physiokorea.com/fhir/observation'
  left join public.clinical_concepts cc
    on cc.concept_key = 'assessment_template:' || lower(ls.form_code)
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
  status,
  updated_at
)
select
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
  jsonb_build_object(
    'seed_wave', 'p95_sci_functional_walking_l2_l3_bridge',
    'form_code', form_code,
    'license_guardrail', 'official item wording not embedded'
  ),
  'active',
  now()
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
  metadata = public.assessment_template_item_semantic_links.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
with capability_seed as (
  select * from (values
    (
      'sci_independence_capacity',
      'SCI independence capacity',
      '척수손상 독립성 기능',
      'functional',
      'global',
      false,
      'quantity',
      'score',
      'higher_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'participation',
        'capability_v2_family_ko', '참여',
        'capability_v2_secondary_families', jsonb_build_array('transfer', 'walking', 'endurance'),
        'source_observations', jsonb_build_array('SCIM_total_score'),
        'source_tools', jsonb_build_array('SCIM_SUMMARY'),
        'source_refs', jsonb_build_array(
          'https://www.sralab.org/rehabilitation-measures/spinal-cord-independence-measure',
          'https://www.scireproject.com/outcome-measures/'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_sci_independence_screen_not_clearance',
          'direction', 'higher_is_better',
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 60, 'unit', 'score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 40, 'and_operator', '<', 'and_value', 60, 'unit', 'score'),
            jsonb_build_object('label', 'regress', 'plain_ko', '지원/쉬운 버전 우선', 'operator', '<', 'value', 40, 'unit', 'score')
          ),
          'default_regression', 'Use supported transfers, shorter bouts, wheelchair-safe setup, caregiver/device review, and pressure-relief planning before higher-demand standing, gait, or conditioning progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If orthostatic symptoms, autonomic dysreflexia signs, skin pressure, spasticity, pain, fatigue, or caregiver/device safety worsens, stop or regress and reassess safety context.',
          'review_note', 'SCIM total is functional independence evidence; pair with neurologic level/AIS, SCIM domains, WISCI, skin/autonomic status, assist level, devices, and 24-hour response.'
        ),
        'seed_wave', 'p95_sci_functional_walking_l2_l3_bridge'
      )
    ),
    (
      'sci_mobility_capacity',
      'SCI transfer and mobility capacity',
      '척수손상 전이/이동 기능',
      'functional',
      'global',
      false,
      'quantity',
      'score',
      'higher_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'transfer',
        'capability_v2_family_ko', '전이',
        'capability_v2_secondary_families', jsonb_build_array('walking', 'balance', 'participation'),
        'source_observations', jsonb_build_array('SCIM_mobility_subscore'),
        'source_tools', jsonb_build_array('SCIM_SUMMARY'),
        'source_refs', jsonb_build_array(
          'https://www.sralab.org/rehabilitation-measures/spinal-cord-independence-measure',
          'https://www.scireproject.com/outcome-measures/'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_sci_mobility_screen_not_clearance',
          'direction', 'higher_is_better',
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 이동 진행 가능', 'operator', '>=', 'value', 25, 'unit', 'score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 15, 'and_operator', '<', 'and_value', 25, 'unit', 'score'),
            jsonb_build_object('label', 'regress', 'plain_ko', '지원/쉬운 버전 우선', 'operator', '<', 'value', 15, 'unit', 'score')
          ),
          'default_regression', 'Use bed-mobility, wheelchair setup, assisted transfer practice, pressure-relief scheduling, and supported standing before dynamic balance or gait progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If transfer safety, skin pressure, orthostatic/autonomic symptoms, spasticity, pain, fatigue, or assist level worsens, regress mobility demand and reassess equipment/safety.',
          'review_note', 'SCIM mobility subscore supports transfer/mobility reasoning; pair with wheelchair/walking context, assist level, skin, autonomic tolerance, device fit, and caregiver setup.'
        ),
        'seed_wave', 'p95_sci_functional_walking_l2_l3_bridge'
      )
    ),
    (
      'sci_walking_support_capacity',
      'SCI walking support capacity',
      '척수손상 보행 지원 기능',
      'functional',
      'global',
      false,
      'quantity',
      'score',
      'higher_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'walking',
        'capability_v2_family_ko', '보행',
        'capability_v2_secondary_families', jsonb_build_array('transfer', 'balance', 'stairs'),
        'source_observations', jsonb_build_array('WISCI_level'),
        'source_tools', jsonb_build_array('WISCI_SUMMARY'),
        'source_refs', jsonb_build_array(
          'https://www.sralab.org/rehabilitation-measures/walking-index-spinal-cord-injury',
          'https://www.scireproject.com/outcome-measures/'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_sci_walking_support_screen_not_clearance',
          'direction', 'higher_is_better',
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 보행 진행 가능', 'operator', '>=', 'value', 13, 'unit', 'score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '보조기/보행보조 주의', 'operator', '>=', 'value', 8, 'and_operator', '<', 'and_value', 13, 'unit', 'score'),
            jsonb_build_object('label', 'regress', 'plain_ko', '지원/쉬운 버전 우선', 'operator', '<', 'value', 8, 'unit', 'score')
          ),
          'default_regression', 'Use pre-gait, supported standing, orthosis/device setup, shorter gait bouts, wheelchair mobility backup, and close guarding before higher-volume gait or conditioning progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If orthostatic symptoms, autonomic dysreflexia signs, skin pressure, spasticity, pain, fatigue, falls, or device fit worsens, stop or regress and reassess safety context.',
          'review_note', 'WISCI level supports walking-support reasoning; pair with neurologic level/AIS, orthosis/device, physical assistance, skin/autonomic status, and community demand.'
        ),
        'seed_wave', 'p95_sci_functional_walking_l2_l3_bridge'
      )
    )
  ) as seed(
    capability_code,
    display,
    display_ko,
    capability_domain,
    body_region,
    laterality_applicable,
    default_value_type,
    default_unit,
    measurement_direction,
    properties
  )
)
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
  status,
  updated_at
)
select
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
  'active',
  now()
from capability_seed
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
  properties = public.movement_capabilities.properties || excluded.properties,
  status = 'active',
  updated_at = now();
with mapping_seed as (
  select * from (values
    ('SCIM_total_score', 'sci_independence_capacity', 'score', 'L3', 'SCIM total score anchors SCI functional independence exercise matching.'),
    ('SCIM_mobility_subscore', 'sci_mobility_capacity', 'score', 'L3', 'SCIM mobility subscore anchors SCI transfer and mobility exercise matching.'),
    ('WISCI_level', 'sci_walking_support_capacity', 'score', 'L3', 'WISCI level anchors SCI walking-support exercise matching.')
  ) as seed(observation_code, capability_code, default_unit, completion_level, rationale)
)
insert into public.movement_capability_observation_mappings (
  observation_code,
  observation_code_system,
  capability_id,
  value_type_hint,
  default_unit,
  metadata,
  status,
  updated_at
)
select
  mapping_seed.observation_code,
  'http://physiokorea.com/fhir/observation',
  mc.id,
  'quantity',
  mapping_seed.default_unit,
  jsonb_build_object(
    'seed_wave', 'p95_sci_functional_walking_l2_l3_bridge',
    'completion_level', mapping_seed.completion_level,
    'plain_status', '처방 판단 가능',
    'capability_code', mapping_seed.capability_code,
    'normalization', jsonb_build_object('canonical_unit', mapping_seed.default_unit, 'laterality_required', false),
    'rationale', mapping_seed.rationale
  ),
  'active',
  now()
from mapping_seed
join public.movement_capabilities mc
  on mc.capability_code = mapping_seed.capability_code
on conflict (observation_code, observation_code_system, capability_id) do update
set
  value_type_hint = excluded.value_type_hint,
  default_unit = excluded.default_unit,
  metadata = public.movement_capability_observation_mappings.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
with requirement_seed as (
  select * from (values
    (
      'EX_FBDY_NMR_001',
      'sci_independence_capacity',
      'target',
      25::numeric,
      null::numeric,
      'score',
      1,
      'low',
      'Supported neuromuscular patterning can target SCI independence goals when skin/autonomic/device safety is reviewed.'
    ),
    (
      'EX_FBDY_FNC_001',
      'sci_independence_capacity',
      'required',
      40::numeric,
      null::numeric,
      'score',
      2,
      'moderate',
      'Sit-to-stand practice should account for SCI independence, assist level, pressure relief, and orthostatic/autonomic tolerance.'
    ),
    (
      'EX_FBDY_BAL_008',
      'sci_independence_capacity',
      'progression_gate',
      50::numeric,
      null::numeric,
      'score',
      3,
      'high',
      'Dynamic weight-shift progression needs stronger independence capacity and close safety review.'
    ),
    (
      'EX_FBDY_FNC_001',
      'sci_mobility_capacity',
      'required',
      8::numeric,
      null::numeric,
      'score',
      2,
      'moderate',
      'Sit-to-stand or transfer practice needs enough SCI mobility capacity for safe setup and guarding.'
    ),
    (
      'EX_FBDY_BAL_008',
      'sci_mobility_capacity',
      'progression_gate',
      15::numeric,
      null::numeric,
      'score',
      3,
      'high',
      'Dynamic balance should be gated by SCI mobility capacity, pressure relief, assist level, and autonomic tolerance.'
    ),
    (
      'EX_FBDY_FNC_015',
      'sci_mobility_capacity',
      'progression_gate',
      20::numeric,
      null::numeric,
      'score',
      4,
      'high',
      'Gait training should account for SCI mobility capacity, orthosis/device context, skin safety, and fatigue.'
    ),
    (
      'EX_FBDY_CRD_006',
      'sci_mobility_capacity',
      'progression_gate',
      25::numeric,
      null::numeric,
      'score',
      4,
      'high',
      'Higher-volume stepping should wait for stronger SCI mobility capacity, autonomic tolerance, and pressure-relief plan.'
    ),
    (
      'EX_FBDY_BAL_008',
      'sci_walking_support_capacity',
      'progression_gate',
      8::numeric,
      null::numeric,
      'score',
      3,
      'high',
      'Dynamic balance progression should consider WISCI walking support level, device/orthosis setup, and fall risk.'
    ),
    (
      'EX_FBDY_FNC_015',
      'sci_walking_support_capacity',
      'required',
      8::numeric,
      null::numeric,
      'score',
      3,
      'high',
      'Gait training requires walking-support context, physical assistance, orthosis/device fit, and skin/autonomic safety review.'
    ),
    (
      'EX_FBDY_CRD_006',
      'sci_walking_support_capacity',
      'progression_gate',
      13::numeric,
      null::numeric,
      'score',
      4,
      'high',
      'Higher-volume stepping should wait for stronger WISCI walking support capacity and medical/equipment safety.'
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
  metadata,
  status,
  updated_at
)
select
  ex.id,
  mc.id,
  requirement_seed.requirement_role,
  requirement_seed.min_value,
  requirement_seed.max_value,
  requirement_seed.value_unit,
  null::boolean,
  requirement_seed.requirement_level,
  null::text,
  requirement_seed.severity,
  requirement_seed.rationale,
  jsonb_build_object(
    'seed_wave', 'p95_sci_functional_walking_l2_l3_bridge',
    'requirement_rule_family', 'sci_functional_walking_screen',
    'clinical_interpretation', 'Use as conservative exercise matching evidence only; pair with neurologic level/AIS, orthostatic/autonomic tolerance, skin/pressure status, spasticity, pain, device/orthosis fit, assist level, caregiver support, fatigue, and clinician judgment.'
  ),
  'active',
  now()
from requirement_seed
join public.exercises ex
  on ex.exercise_code = requirement_seed.exercise_code
 and ex.is_active = true
join public.movement_capabilities mc
  on mc.capability_code = requirement_seed.capability_code
on conflict (exercise_id, capability_id, requirement_role, (coalesce(laterality, ''::text))) where (status = 'active')
do update
set
  min_value = excluded.min_value,
  max_value = excluded.max_value,
  value_unit = excluded.value_unit,
  required_boolean = excluded.required_boolean,
  requirement_level = excluded.requirement_level,
  severity = excluded.severity,
  rationale = excluded.rationale,
  metadata = public.exercise_requirements.metadata || excluded.metadata,
  updated_at = now();
