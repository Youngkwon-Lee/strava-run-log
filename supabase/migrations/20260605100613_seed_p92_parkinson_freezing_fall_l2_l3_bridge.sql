-- Seed P92 Parkinson freezing/fall L2-L3 bridge.
--
-- Purpose:
-- - move Parkinson/freezing/fall-risk summary observations beyond template-only status
-- - add capability evidence for AI/RAG/reasoning without creating a Parkinson if/then
--   recommendation engine
-- - keep licensed-tool guardrails: no official item wording is embedded
--
-- Clinical safety note:
-- These are MVP screening defaults for exercise matching, not diagnosis, medication,
-- fall-risk clearance, or community ambulation clearance rules. Medication on/off
-- timing, orthostatic symptoms, dyskinesia, cognition, assist level, device fit,
-- supervision, home hazards, freezing context, and clinician judgment remain required.

with capability_seed as (
  select * from (values
    (
      'parkinson_freezing_turning_burden',
      'Parkinson freezing and turning burden',
      '파킨슨 동결/회전 부담',
      'functional',
      'global',
      false,
      'quantity',
      'score',
      'lower_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'walking',
        'capability_v2_family_ko', '보행',
        'capability_v2_secondary_families', jsonb_build_array('balance', 'fall_risk', 'transfer'),
        'source_observations', jsonb_build_array('FOGQ_total_score'),
        'source_tools', jsonb_build_array('FOGQ_SUMMARY'),
        'source_refs', jsonb_build_array(
          'https://www.sralab.org/rehabilitation-measures/freezing-gait-questionnaire',
          'https://pmc.ncbi.nlm.nih.gov/articles/PMC2891299/'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_parkinson_screen_not_clearance',
          'direction', 'lower_is_better',
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '<=', 'value', 5, 'unit', 'score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>', 'value', 5, 'and_operator', '<=', 'and_value', 12, 'unit', 'score'),
            jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '>', 'value', 12, 'unit', 'score')
          ),
          'default_regression', 'Use external cueing, rhythmic initiation, wide-turn practice, lower walking speed, close guarding, and obstacle-free paths before dual-task gait or dynamic balance progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If freezing, start hesitation, turning blocks, near falls, orthostatic symptoms, or cue carryover worsens, reduce task complexity and document medication on/off timing.',
          'review_note', 'FOG-Q burden should gate turning, dual-task, and dynamic gait challenge with assist level, supervision, home hazards, and medication timing.'
        ),
        'seed_wave', 'p92_parkinson_freezing_fall_l2_l3_bridge'
      )
    ),
    (
      'parkinson_balance_confidence_capacity',
      'Parkinson balance confidence capacity',
      '파킨슨 균형 자신감',
      'balance',
      'global',
      false,
      'quantity',
      'percent',
      'higher_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'balance',
        'capability_v2_family_ko', '균형',
        'capability_v2_secondary_families', jsonb_build_array('fall_risk', 'walking', 'participation'),
        'source_observations', jsonb_build_array('ABC_balance_confidence_percent'),
        'source_tools', jsonb_build_array('ABC_SCALE'),
        'source_refs', jsonb_build_array(
          'https://www.sralab.org/rehabilitation-measures/activities-specific-balance-confidence-scale'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_balance_confidence_screen_not_clearance',
          'direction', 'higher_is_better',
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 80, 'unit', 'percent'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 55, 'and_operator', '<', 'and_value', 80, 'unit', 'percent'),
            jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 55, 'unit', 'percent')
          ),
          'default_regression', 'Use guarded static balance, predictable indoor walking, hand support, and confidence-building exposure before eyes-closed, narrow-base, or community balance progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If fear, avoidance, near falls, freezing, dizziness, or caregiver guarding demand increases, reduce balance challenge and reassess confidence and fall context.',
          'review_note', 'ABC is a confidence and fall-risk context signal; pair with objective gait/balance performance and freezing/orthostatic context.'
        ),
        'seed_wave', 'p92_parkinson_freezing_fall_l2_l3_bridge'
      )
    ),
    (
      'tinetti_gait_balance_capacity',
      'Tinetti gait and balance capacity',
      'Tinetti 보행/균형 능력',
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
        'capability_v2_secondary_families', jsonb_build_array('walking', 'transfer', 'fall_risk'),
        'source_observations', jsonb_build_array('TINETTI_total_score'),
        'source_tools', jsonb_build_array('TINETTI'),
        'source_refs', jsonb_build_array(
          'https://www.sralab.org/rehabilitation-measures/tinetti-performance-oriented-mobility-assessment'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_gait_balance_screen_not_clearance',
          'direction', 'higher_is_better',
          'score_max', 28,
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 25, 'unit', 'score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 19, 'and_operator', '<', 'and_value', 25, 'unit', 'score'),
            jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 19, 'unit', 'score')
          ),
          'default_regression', 'Use supported sit-to-stand, stable-surface balance, lower step height, and close guarding before backward walking, cone touch, or faster gait progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If gait instability, freezing, unsafe turns, device misuse, orthostasis, or near falls increase, down-rank balance and gait challenge.',
          'review_note', 'Tinetti/POMA total score is a fall-risk screen; pair with Parkinson freezing, medication state, assist level, device fit, and home hazards.'
        ),
        'seed_wave', 'p92_parkinson_freezing_fall_l2_l3_bridge'
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
      'FOGQ_total_score',
      null::numeric,
      12::numeric,
      'MVP Parkinson freezing screen: lower is better; <=5 ready, 6-12 caution, >12 regress/easy-version review. Use with cue response, fall risk, supervision, and medication on/off timing.',
      jsonb_build_object(
        'seed_wave', 'p92_parkinson_freezing_fall_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'parkinson_freezing_turning_burden',
        'direction', 'lower_is_better',
        'decision_bands', jsonb_build_array('ready: <=5', 'caution: 6-12', 'regress: >12'),
        'safety_note', 'Not a stand-alone gait clearance rule; pair with freezing triggers, cue carryover, assist level, device safety, orthostasis, home hazards, and medication timing.'
      )
    ),
    (
      'ABC_balance_confidence_percent',
      55::numeric,
      100::numeric,
      'MVP balance-confidence screen: >=80% ready, 55-79% caution, <55% regress/easy-version review. Use with objective balance and fall history.',
      jsonb_build_object(
        'seed_wave', 'p92_parkinson_freezing_fall_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'parkinson_balance_confidence_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=80%', 'caution: 55-79%', 'regress: <55%'),
        'safety_note', 'Confidence is not objective balance clearance; pair with TUG/BBS/FGA/Tinetti, freezing, dizziness, supervision, and fall history.'
      )
    ),
    (
      'TINETTI_total_score',
      19::numeric,
      28::numeric,
      'MVP gait/balance screen: max 28; >=25 ready, 19-24 caution, <19 regress/easy-version review. Use with freezing, assistive device, and fall context.',
      jsonb_build_object(
        'seed_wave', 'p92_parkinson_freezing_fall_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'tinetti_gait_balance_capacity',
        'direction', 'higher_is_better',
        'score_max', 28,
        'decision_bands', jsonb_build_array('ready: >=25/28', 'caution: 19-24/28', 'regress: <19/28'),
        'safety_note', 'Fall-risk screens do not replace clinician guarding, device fit, orthostatic check, medication timing, or home-hazard review.'
      )
    ),
    (
      'MDS_UPDRS_motor_summary_score',
      null::numeric,
      null::numeric,
      'Parkinson motor summary anchor. Score type must be reviewed because summary cards may contain total, Part II, or Part III score; do not use as a stand-alone L3 exercise threshold yet.',
      jsonb_build_object(
        'seed_wave', 'p92_parkinson_freezing_fall_l2_l3_bridge',
        'plain_status', '평가값 연결',
        'capability_code', 'neurologic_motor_control',
        'direction', 'lower_is_better',
        'completion_level', 'L1',
        'safety_note', 'Requires score-type disambiguation and medication on/off context before L3 thresholds are claimed.'
      )
    )
  ) as seed(code, reference_range_low, reference_range_high, reference_range_text, interpretation_guide)
)
update public.observation_taxonomy ot
set
  default_value_type = 'quantity',
  default_unit = case
    when guide_seed.code = 'ABC_balance_confidence_percent' then 'percent'
    else 'score'
  end,
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
    ('FOGQ_total_score', 'parkinson_freezing_turning_burden', 'score', 'L3', 'FOG-Q total score anchors freezing/turning burden for guarded gait and dynamic balance reasoning.'),
    ('ABC_balance_confidence_percent', 'parkinson_balance_confidence_capacity', 'percent', 'L3', 'ABC confidence percent anchors balance confidence and fall-risk reasoning.'),
    ('TINETTI_total_score', 'tinetti_gait_balance_capacity', 'score', 'L3', 'Tinetti total score anchors gait/balance fall-risk reasoning.'),
    ('MDS_UPDRS_motor_summary_score', 'neurologic_motor_control', 'score', 'L1', 'MDS-UPDRS summary anchors Parkinson neurologic motor-control context; score type must be disambiguated before L3 thresholds.')
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
    'seed_wave', 'p92_parkinson_freezing_fall_l2_l3_bridge',
    'completion_level', mapping_seed.completion_level,
    'plain_status', case when mapping_seed.completion_level = 'L3' then '처방 판단 가능' else '평가값 연결' end,
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
      'EX_FBDY_NMR_005',
      'parkinson_freezing_turning_burden',
      'target',
      null::numeric,
      15::numeric,
      'score',
      1,
      'low',
      'Rhythmic initiation can target freezing/turning burden when challenge is simple and guarded.'
    ),
    (
      'EX_FBDY_BAL_008',
      'parkinson_freezing_turning_burden',
      'required',
      null::numeric,
      12::numeric,
      'score',
      2,
      'moderate',
      'Dynamic weight shift requires freezing burden and cue carryover to be safe enough for unsupported practice.'
    ),
    (
      'EX_FBDY_FNC_015',
      'parkinson_freezing_turning_burden',
      'progression_gate',
      null::numeric,
      8::numeric,
      'score',
      4,
      'high',
      'Gait-training progression should be gated when freezing/turning burden is high or cue response is poor.'
    ),
    (
      'EX_FBDY_BAL_001',
      'parkinson_balance_confidence_capacity',
      'target',
      50::numeric,
      null::numeric,
      'percent',
      1,
      'low',
      'Guarded static balance can target low balance confidence before harder community-balance exposure.'
    ),
    (
      'EX_FBDY_BAL_004',
      'parkinson_balance_confidence_capacity',
      'required',
      60::numeric,
      null::numeric,
      'percent',
      2,
      'moderate',
      'Tandem stance should consider balance confidence, fear, and supervision before narrowing base of support.'
    ),
    (
      'EX_FBDY_BAL_008',
      'parkinson_balance_confidence_capacity',
      'progression_gate',
      80::numeric,
      null::numeric,
      'percent',
      3,
      'high',
      'Dynamic weight shift progression needs stronger confidence plus objective balance and fall-risk context.'
    ),
    (
      'EX_FBDY_BAL_001',
      'tinetti_gait_balance_capacity',
      'target',
      15::numeric,
      null::numeric,
      'score',
      1,
      'low',
      'Guarded static balance can target low gait/balance capacity while fall-risk context is reviewed.'
    ),
    (
      'EX_FBDY_FNC_001',
      'tinetti_gait_balance_capacity',
      'required',
      19::numeric,
      null::numeric,
      'score',
      2,
      'moderate',
      'Sit-to-stand practice requires baseline gait/balance capacity and safe transfer setup.'
    ),
    (
      'EX_FBDY_BAL_008',
      'tinetti_gait_balance_capacity',
      'progression_gate',
      25::numeric,
      null::numeric,
      'score',
      3,
      'high',
      'Dynamic weight shift progression should wait for lower fall-risk gait/balance performance or close guarding.'
    ),
    (
      'EX_FBDY_FNC_015',
      'tinetti_gait_balance_capacity',
      'progression_gate',
      25::numeric,
      null::numeric,
      'score',
      4,
      'high',
      'Gait-training progression should consider Tinetti gait/balance performance, freezing, device fit, and supervision.'
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
    'seed_wave', 'p92_parkinson_freezing_fall_l2_l3_bridge',
    'requirement_rule_family', 'parkinson_freezing_fall_screen',
    'clinical_interpretation', 'Use as conservative exercise matching evidence only; pair with medication on/off timing, orthostatic symptoms, dyskinesia, assist level, device safety, supervision, cognition, home hazards, and clinician judgment.'
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
