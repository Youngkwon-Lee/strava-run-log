-- Seed P91 stroke motor/postural L2-L3 bridge.
--
-- Purpose:
-- - move stroke-specific summary observations beyond template-only/L1 status
-- - keep recommendation generation AI-native by adding capability/requirement evidence,
--   not diagnosis-specific if/then recommendation logic
-- - preserve licensed-tool guardrails: no official item wording is embedded
--
-- Clinical safety note:
-- These are MVP rehab-screen defaults for exercise matching. They are not
-- discharge, ambulation, or return-to-community clearance rules. Clinician
-- review, medical stability, tone, neglect/sensation, assist level, device use,
-- vitals, fatigue, and 24-hour response still gate progression.

with capability_seed as (
  select * from (values
    (
      'stroke_lower_limb_motor_control',
      'Stroke lower-limb motor control',
      '뇌졸중 하지 운동조절',
      'motor_control',
      'lower_extremity',
      true,
      'quantity',
      'score',
      'higher_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'neurologic_motor',
        'capability_v2_family_ko', '신경계 운동 조절',
        'capability_v2_secondary_families', jsonb_build_array('walking', 'transfer', 'balance'),
        'source_observations', jsonb_build_array('FMA_LE_total_score'),
        'source_tools', jsonb_build_array('FMA_LE'),
        'source_refs', jsonb_build_array(
          'https://www.gu.se/en/neuroscience-physiology/fugl-meyer-assessment',
          'https://www.sralab.org/rehabilitation-measures/fugl-meyer-assessment-motor-recovery-after-stroke'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_stroke_rehab_screen_not_clearance',
          'score_max', 34,
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 22, 'unit', 'score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 12, 'and_operator', '<', 'and_value', 22, 'unit', 'score'),
            jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 12, 'unit', 'score')
          ),
          'default_regression', 'Use supported weight shift, guided PNF or task-specific assisted stepping before independent gait, lunge, or dynamic balance progression.',
          'laterality_required', true,
          'symptom_response_rule', 'If tone, fatigue, pain, knee control, foot clearance, neglect, or compensatory synergy worsens, reduce task complexity and reassess assist level.',
          'review_note', 'FMA-LE is an impairment/motor-control anchor after stroke; pair with gait speed, balance, assistive-device status, cognition/neglect, vitals, and transfer safety.'
        ),
        'seed_wave', 'p91_stroke_motor_postural_l2_l3_bridge'
      )
    ),
    (
      'stroke_postural_control_capacity',
      'Stroke postural control capacity',
      '뇌졸중 자세조절 능력',
      'balance',
      'global',
      false,
      'quantity',
      'score',
      'higher_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'balance',
        'capability_v2_family_ko', '균형',
        'capability_v2_secondary_families', jsonb_build_array('transfer', 'walking', 'fall_risk'),
        'source_observations', jsonb_build_array('PASS_total_score'),
        'source_tools', jsonb_build_array('PASS_SUMMARY'),
        'source_refs', jsonb_build_array(
          'https://www.sralab.org/rehabilitation-measures/postural-assessment-scale-stroke'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_stroke_rehab_screen_not_clearance',
          'score_max', 36,
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 28, 'unit', 'score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 18, 'and_operator', '<', 'and_value', 28, 'unit', 'score'),
            jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 18, 'unit', 'score')
          ),
          'default_regression', 'Use guarded sitting/standing balance, supported transfers, reduced reach/turn amplitude, and caregiver/device setup review before higher-demand gait or dynamic balance tasks.',
          'laterality_required', false,
          'symptom_response_rule', 'If loss of balance, unsafe transfer strategy, orthostatic symptoms, fear, neglect, or caregiver guarding demand increases, regress to supported postural-control work.',
          'review_note', 'PASS total score supports stroke postural-control reasoning but should be paired with BBS/TUG/gait speed, assist level, device fit, and home fall-risk context.'
        ),
        'seed_wave', 'p91_stroke_motor_postural_l2_l3_bridge'
      )
    ),
    (
      'sitting_trunk_control_capacity',
      'Sitting trunk control capacity',
      '앉은 자세 몸통조절 능력',
      'stability',
      'trunk',
      false,
      'quantity',
      'score',
      'higher_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'transfer',
        'capability_v2_family_ko', '전이',
        'capability_v2_secondary_families', jsonb_build_array('balance', 'caregiver_safety', 'upper_limb_reach'),
        'source_observations', jsonb_build_array('FIST_total_score'),
        'source_tools', jsonb_build_array('FIST_SUMMARY'),
        'source_refs', jsonb_build_array(
          'https://www.sralab.org/rehabilitation-measures/function-sitting-test',
          'https://pmc.ncbi.nlm.nih.gov/articles/PMC3976801/'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_sitting_balance_screen_not_clearance',
          'score_max', 56,
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 45, 'unit', 'score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 30, 'and_operator', '<', 'and_value', 45, 'unit', 'score'),
            jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 30, 'unit', 'score')
          ),
          'default_regression', 'Use supported sitting balance, edge-of-bed reach within base of support, manual guarding, or transfer setup practice before unsupported reach, floor transfer, or dynamic standing tasks.',
          'laterality_required', false,
          'symptom_response_rule', 'If trunk collapse, unsafe reach strategy, dizziness, fatigue, pushing, neglect, or caregiver load increases, reduce reach distance and support the sitting base.',
          'review_note', 'FIST is a sitting-balance and trunk-control screen; interpret alongside transfer assistance, upper-limb support, cognition/neglect, and caregiver safety.'
        ),
        'seed_wave', 'p91_stroke_motor_postural_l2_l3_bridge'
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
with guide_seed as (
  select * from (values
    (
      'FMA_LE_total_score',
      12::numeric,
      34::numeric,
      'MVP stroke screen: FMA-LE max 34; >=22 ready, 12-21 caution, <12 regress/easy-version review. Use with assist level, tone, gait/balance context.',
      jsonb_build_object(
        'seed_wave', 'p91_stroke_motor_postural_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'stroke_lower_limb_motor_control',
        'direction', 'higher_is_better',
        'score_max', 34,
        'decision_bands', jsonb_build_array('ready: >=22/34', 'caution: 12-21/34', 'regress: <12/34'),
        'safety_note', 'Not a gait or discharge clearance rule; pair with gait speed, BBS/TUG, assistive device, tone, neglect, vitals, fatigue, and clinician judgment.'
      )
    ),
    (
      'PASS_total_score',
      18::numeric,
      36::numeric,
      'MVP stroke postural screen: PASS max 36; >=28 ready, 18-27 caution, <18 regress/easy-version review. Use with fall risk and transfer safety.',
      jsonb_build_object(
        'seed_wave', 'p91_stroke_motor_postural_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'stroke_postural_control_capacity',
        'direction', 'higher_is_better',
        'score_max', 36,
        'decision_bands', jsonb_build_array('ready: >=28/36', 'caution: 18-27/36', 'regress: <18/36'),
        'safety_note', 'Not a stand-alone ambulation clearance rule; pair with transfer assistance, device fit, BBS/TUG/FGA context, vitals, cognition, and caregiver safety.'
      )
    ),
    (
      'FIST_total_score',
      30::numeric,
      56::numeric,
      'MVP sitting-balance screen: FIST max 56; >=45 ready, 30-44 caution, <30 regress/easy-version review. Use with transfer assistance and caregiver safety.',
      jsonb_build_object(
        'seed_wave', 'p91_stroke_motor_postural_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'sitting_trunk_control_capacity',
        'direction', 'higher_is_better',
        'score_max', 56,
        'decision_bands', jsonb_build_array('ready: >=45/56', 'caution: 30-44/56', 'regress: <30/56'),
        'safety_note', 'Use with transfer assistance, sitting reach quality, neglect, dizziness, fatigue, and caregiver load; not an independent transfer clearance by itself.'
      )
    )
  ) as seed(code, reference_range_low, reference_range_high, reference_range_text, interpretation_guide)
)
update public.observation_taxonomy ot
set
  default_value_type = 'quantity',
  default_unit = 'score',
  reference_range_low = guide_seed.reference_range_low,
  reference_range_high = guide_seed.reference_range_high,
  reference_range_text = guide_seed.reference_range_text,
  interpretation_guide = coalesce(ot.interpretation_guide, '{}'::jsonb) || guide_seed.interpretation_guide,
  updated_at = now()
from guide_seed
where ot.code = guide_seed.code
  and ot.code_system = 'http://physiokorea.com/fhir/observation';
with mapping_seed as (
  select * from (values
    ('FMA_LE_total_score', 'stroke_lower_limb_motor_control', true, 'FMA-LE total score anchors stroke lower-limb motor-control exercise reasoning.'),
    ('PASS_total_score', 'stroke_postural_control_capacity', false, 'PASS total score anchors stroke postural-control transfer, balance, and fall-risk reasoning.'),
    ('FIST_total_score', 'sitting_trunk_control_capacity', false, 'FIST total score anchors sitting balance, trunk control, and transfer setup reasoning.')
  ) as seed(observation_code, capability_code, laterality_required, rationale)
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
  'score',
  jsonb_build_object(
    'seed_wave', 'p91_stroke_motor_postural_l2_l3_bridge',
    'completion_level', 'L3',
    'plain_status', '처방 판단 가능',
    'capability_code', mapping_seed.capability_code,
    'normalization', jsonb_build_object(
      'canonical_unit', 'score',
      'laterality_required', mapping_seed.laterality_required
    ),
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
-- Promote the older broad FMA-LE -> neurologic_motor_control mapping metadata to
-- show the new dedicated L3 bridge without deleting the broader L1 anchor.
update public.movement_capability_observation_mappings map
set
  metadata = coalesce(map.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'seed_wave_followup', 'p91_stroke_motor_postural_l2_l3_bridge',
      'dedicated_l3_capability_code', 'stroke_lower_limb_motor_control',
      'note', 'Broad neurologic_motor_control anchor retained; dedicated stroke_lower_limb_motor_control now carries score-specific L3 exercise reasoning.'
    ),
  updated_at = now()
from public.movement_capabilities mc
where map.capability_id = mc.id
  and mc.capability_code = 'neurologic_motor_control'
  and map.observation_code = 'FMA_LE_total_score'
  and map.status = 'active';
with requirement_seed as (
  select * from (values
    (
      'EX_FBDY_NMR_001',
      'stroke_lower_limb_motor_control',
      'target',
      10::numeric,
      null::numeric,
      'score',
      1,
      'either',
      'low',
      'Guided full-body PNF patterning can target early stroke lower-limb motor-control recovery when FMA-LE is low enough to need assisted task specificity.'
    ),
    (
      'EX_FBDY_FNC_001',
      'stroke_lower_limb_motor_control',
      'required',
      15::numeric,
      null::numeric,
      'score',
      2,
      'either',
      'moderate',
      'Sit-to-stand work requires enough selective lower-limb motor control for safe weight shift and knee/foot placement.'
    ),
    (
      'EX_FBDY_FNC_015',
      'stroke_lower_limb_motor_control',
      'progression_gate',
      22::numeric,
      null::numeric,
      'score',
      4,
      'either',
      'high',
      'Gait-training progression should consider better lower-limb motor-control carryover plus assistive-device and fall-risk context.'
    ),
    (
      'EX_FBDY_BAL_001',
      'stroke_postural_control_capacity',
      'target',
      12::numeric,
      null::numeric,
      'score',
      1,
      null::text,
      'low',
      'Guarded static balance can target early postural-control limitations after stroke.'
    ),
    (
      'EX_FBDY_FNC_003',
      'stroke_postural_control_capacity',
      'required',
      20::numeric,
      null::numeric,
      'score',
      2,
      null::text,
      'moderate',
      'Floor-transfer work requires enough postural-control capacity for safe transition setup and guarding.'
    ),
    (
      'EX_FBDY_BAL_008',
      'stroke_postural_control_capacity',
      'progression_gate',
      28::numeric,
      null::numeric,
      'score',
      3,
      null::text,
      'high',
      'Dynamic weight-shift progression should be gated by stronger postural-control capacity and fall-risk review.'
    ),
    (
      'EX_FBDY_BAL_001',
      'sitting_trunk_control_capacity',
      'target',
      20::numeric,
      null::numeric,
      'score',
      1,
      null::text,
      'low',
      'Supported static balance can target low sitting/trunk-control capacity before standing tasks.'
    ),
    (
      'EX_FBDY_FNC_001',
      'sitting_trunk_control_capacity',
      'required',
      30::numeric,
      null::numeric,
      'score',
      2,
      null::text,
      'moderate',
      'Sit-to-stand practice requires enough sitting trunk control for safe forward lean and transfer setup.'
    ),
    (
      'EX_FBDY_BAL_008',
      'sitting_trunk_control_capacity',
      'progression_gate',
      45::numeric,
      null::numeric,
      'score',
      3,
      null::text,
      'high',
      'Dynamic weight shift should wait until sitting trunk control is strong enough for unsupported reach and recovery strategies.'
    )
  ) as seed(
    exercise_code,
    capability_code,
    requirement_role,
    min_value,
    max_value,
    value_unit,
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
  requirement_seed.laterality,
  requirement_seed.severity,
  requirement_seed.rationale,
  jsonb_build_object(
    'seed_wave', 'p91_stroke_motor_postural_l2_l3_bridge',
    'requirement_rule_family', 'stroke_motor_postural_screen_score',
    'clinical_interpretation', 'Use as conservative exercise matching evidence only; pair with red flags, vitals, assist level, tone, neglect/sensation, fall risk, and clinician judgment.'
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
