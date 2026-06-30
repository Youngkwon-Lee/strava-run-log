-- Seed P93 CP mobility support L2-L3 bridge.
--
-- Purpose:
-- - connect CP/pediatric mobility anchors that were template-only or L1-only
-- - add capability evidence for AI/RAG/reasoning without creating a CP if/then
--   recommendation engine
-- - keep licensed-tool guardrails: no official item wording is embedded
--
-- Clinical safety note:
-- These are MVP pediatric rehab-screen defaults for exercise matching. They are
-- not independent mobility, school participation, orthotic, equipment, or home
-- safety clearance rules. Age, growth, GMFCS age band, tone/spasticity,
-- orthosis/device fit, seizure/respiratory/feeding safety, skin integrity,
-- caregiver handling, fatigue, participation goal, and 24-hour response remain
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
      'GMFCS_level',
      'GMFCS level',
      array['exam', 'pediatric', 'cerebral_palsy', 'gross_motor']::text[],
      'quantity',
      'level',
      1::numeric,
      5::numeric,
      'GMFCS level I-V; lower level generally indicates less mobility support need. MVP screen: I-II ready for basic guarded gross-motor progression, III caution/device-supervision context, IV-V regress/support-first review.',
      jsonb_build_object(
        'seed_wave', 'p93_cp_mobility_support_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'cp_mobility_support_level',
        'direction', 'lower_is_better',
        'decision_bands', jsonb_build_array('ready: level <=2', 'caution: level 3', 'regress/support-first: level >=4'),
        'safety_note', 'Use with age band, orthosis/device fit, caregiver handling, fatigue, fall risk, seizure/respiratory/feeding safety, skin integrity, and participation goal.'
      ),
      'GMFCS level as CP mobility support anchor; no official expanded age-band wording embedded.'
    ),
    (
      'PEDI_CAT_mobility_t_score',
      'PEDI-CAT mobility T-score',
      array['exam', 'pediatric', 'function', 'mobility']::text[],
      'quantity',
      'T-score',
      30::numeric,
      null::numeric,
      'PEDI-CAT mobility T-score. MVP screen: >=45 ready, 35-44 caution, <35 regress/support-first review. Use with GMFCS, device/caregiver context, fatigue, and participation goal.',
      jsonb_build_object(
        'seed_wave', 'p93_cp_mobility_support_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'pediatric_mobility_participation_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=45 T-score', 'caution: 35-44 T-score', 'regress/support-first: <35 T-score'),
        'safety_note', 'Mobility T-score is capability evidence, not a stand-alone device, school, or community mobility clearance rule.'
      ),
      'PEDI-CAT mobility domain T-score anchor; official item bank wording not embedded.'
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
    'p93_cp_mobility_support_l2_l3_bridge',
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
    ('GMFCS', 'gmfcs_level', 'aggregate', 'GMFCS_level', 'GMFCS level', array['exam', 'pediatric', 'cerebral_palsy', 'gross_motor']::text[], 'quantity', 'level', 'GMFCS level I-V mobility support anchor.'),
    ('PEDI_CAT_SUMMARY', 'mobility_t_score', 'aggregate', 'PEDI_CAT_mobility_t_score', 'PEDI-CAT mobility T-score', array['exam', 'pediatric', 'function', 'mobility']::text[], 'quantity', 'T-score', 'PEDI-CAT mobility domain T-score anchor.')
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
  join public.clinical_concepts cc
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
    'seed_wave', 'p93_cp_mobility_support_l2_l3_bridge',
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
      'cp_mobility_support_level',
      'CP mobility support level',
      '뇌성마비 이동 지원 수준',
      'functional',
      'global',
      false,
      'quantity',
      'level',
      'lower_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'gross_motor',
        'capability_v2_family_ko', '대동작 기능',
        'capability_v2_secondary_families', jsonb_build_array('walking', 'transfer', 'stairs', 'participation'),
        'source_observations', jsonb_build_array('GMFCS_level'),
        'source_tools', jsonb_build_array('GMFCS'),
        'source_refs', jsonb_build_array(
          'https://canchild.ca/en/resources/42-gross-motor-function-classification-system-expanded-revised-gmfcs-e-r',
          'https://canchild.ca/en/resources/46-gross-motor-function-classification-system-gmfcs'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_cp_mobility_support_screen_not_clearance',
          'direction', 'lower_is_better',
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '<=', 'value', 2, 'unit', 'level'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '=', 'value', 3, 'unit', 'level'),
            jsonb_build_object('label', 'regress', 'plain_ko', '지원/쉬운 버전 우선', 'operator', '>=', 'value', 4, 'unit', 'level')
          ),
          'default_regression', 'Use caregiver-assisted transitions, supported sitting/standing, device/orthosis setup, shorter bouts, and play-based lower-demand tasks before unsupported gait or dynamic balance progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If fatigue, tone, pain, skin pressure, respiratory/feeding concern, seizure-like event, or caregiver handling demand worsens, reduce intensity and reassess medical/device context.',
          'review_note', 'GMFCS level is a mobility support classification, not an exercise clearance rule. Pair with age band, GMFM/PEDI context, devices, orthoses, caregiver goals, and 24-hour response.'
        ),
        'seed_wave', 'p93_cp_mobility_support_l2_l3_bridge'
      )
    ),
    (
      'pediatric_mobility_participation_capacity',
      'Pediatric mobility participation capacity',
      '소아 이동/참여 기능',
      'functional',
      'global',
      false,
      'quantity',
      'T-score',
      'higher_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'participation',
        'capability_v2_family_ko', '참여',
        'capability_v2_secondary_families', jsonb_build_array('gross_motor', 'walking', 'transfer', 'stairs'),
        'source_observations', jsonb_build_array('PEDI_CAT_mobility_t_score'),
        'source_tools', jsonb_build_array('PEDI_CAT_SUMMARY'),
        'source_refs', jsonb_build_array(
          'https://www.pedicat.com/',
          'https://www.sralab.org/rehabilitation-measures/pediatric-evaluation-disability-inventory-computer-adaptive-test'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_pediatric_mobility_screen_not_clearance',
          'direction', 'higher_is_better',
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 45, 'unit', 'T-score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 35, 'and_operator', '<', 'and_value', 45, 'unit', 'T-score'),
            jsonb_build_object('label', 'regress', 'plain_ko', '지원/쉬운 버전 우선', 'operator', '<', 'value', 35, 'unit', 'T-score')
          ),
          'default_regression', 'Use shorter mobility bouts, supported transfer practice, home/school routine adaptation, caregiver cueing, and device/orthosis review before higher-volume gait, stairs, or community mobility progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If participation fatigue, pain, equipment tolerance, skin pressure, caregiver load, or next-day recovery worsens, reduce volume and revisit routine fit.',
          'review_note', 'PEDI-CAT mobility T-score is functional participation evidence; pair with GMFCS, age/development context, goals, devices, caregiver capacity, and medical safety.'
        ),
        'seed_wave', 'p93_cp_mobility_support_l2_l3_bridge'
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
    ('GMFCS_level', 'cp_mobility_support_level', 'level', 'L3', 'GMFCS level anchors CP mobility support and gross-motor exercise matching.'),
    ('PEDI_CAT_mobility_t_score', 'pediatric_mobility_participation_capacity', 'T-score', 'L3', 'PEDI-CAT mobility T-score anchors pediatric mobility and participation exercise matching.')
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
    'seed_wave', 'p93_cp_mobility_support_l2_l3_bridge',
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
      'cp_mobility_support_level',
      'target',
      null::numeric,
      5::numeric,
      'level',
      1,
      'low',
      'Supported neuromuscular patterning can target CP mobility support needs across GMFCS levels when caregiver/device context is reviewed.'
    ),
    (
      'EX_FBDY_FNC_001',
      'cp_mobility_support_level',
      'required',
      null::numeric,
      4::numeric,
      'level',
      2,
      'moderate',
      'Sit-to-stand practice should account for GMFCS mobility support level, guarding, tone, orthosis/device setup, and fatigue.'
    ),
    (
      'EX_FBDY_BAL_008',
      'cp_mobility_support_level',
      'progression_gate',
      null::numeric,
      3::numeric,
      'level',
      3,
      'high',
      'Dynamic weight-shift progression should be gated by mobility support level and close supervision/device safety.'
    ),
    (
      'EX_FBDY_FNC_015',
      'cp_mobility_support_level',
      'progression_gate',
      null::numeric,
      3::numeric,
      'level',
      4,
      'high',
      'Gait-training progression should consider GMFCS level, assistive device, orthosis, caregiver support, and medical safety context.'
    ),
    (
      'EX_FBDY_NMR_001',
      'pediatric_mobility_participation_capacity',
      'target',
      25::numeric,
      null::numeric,
      'T-score',
      1,
      'low',
      'Supported neuromuscular play can target low PEDI-CAT mobility participation capacity with caregiver cueing.'
    ),
    (
      'EX_FBDY_FNC_001',
      'pediatric_mobility_participation_capacity',
      'required',
      35::numeric,
      null::numeric,
      'T-score',
      2,
      'moderate',
      'Sit-to-stand practice requires enough mobility participation capacity for safe routine carryover and caregiver setup.'
    ),
    (
      'EX_FBDY_FNC_003',
      'pediatric_mobility_participation_capacity',
      'required',
      35::numeric,
      null::numeric,
      'T-score',
      2,
      'moderate',
      'Floor-transfer practice should consider mobility participation score, caregiver handling, and fatigue recovery.'
    ),
    (
      'EX_FBDY_BAL_008',
      'pediatric_mobility_participation_capacity',
      'progression_gate',
      45::numeric,
      null::numeric,
      'T-score',
      3,
      'high',
      'Dynamic weight-shift progression needs stronger mobility participation capacity and routine fit.'
    ),
    (
      'EX_FBDY_CRD_006',
      'pediatric_mobility_participation_capacity',
      'progression_gate',
      45::numeric,
      null::numeric,
      'T-score',
      3,
      'high',
      'Higher-volume step-machine participation should wait for adequate mobility capacity, fatigue recovery, and medical/device safety.'
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
    'seed_wave', 'p93_cp_mobility_support_l2_l3_bridge',
    'requirement_rule_family', 'cp_mobility_support_screen',
    'clinical_interpretation', 'Use as conservative exercise matching evidence only; pair with age, growth, tone, orthosis/device fit, caregiver handling, seizure/respiratory/feeding safety, skin integrity, fatigue, participation goal, and clinician judgment.'
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
