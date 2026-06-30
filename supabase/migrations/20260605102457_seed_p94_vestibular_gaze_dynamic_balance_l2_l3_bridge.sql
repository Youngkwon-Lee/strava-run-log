-- Seed P94 vestibular gaze/dynamic-balance L2-L3 bridge.
--
-- Purpose:
-- - connect high-value vestibular/dynamic-balance observations that already
--   have Encounter cards and semantic links
-- - promote DVA line loss into an honest L3 capability path for gaze/postural
--   tolerance without creating a vestibular if/then recommendation engine
-- - connect FGA and Mini-BEST totals to the existing dynamic balance capability
--   so BBS-ceiling and vestibular gait/balance recommendations have stronger
--   capability evidence
--
-- Clinical safety note:
-- These are MVP vestibular rehab-screen defaults for exercise matching. They
-- are not independent BPPV, central vestibular, fall-risk, return-to-driving,
-- or community ambulation clearance rules. New diplopia, dysarthria, ataxia,
-- unilateral weakness/numbness, severe new headache, suspected stroke/TIA,
-- syncope/near-syncope, orthostatic/cardiac symptoms, medication timing,
-- nausea tolerance, fall history, assist level, and 24-hour response remain
-- clinician-reviewed context.

with taxonomy_seed (
  code,
  reference_range_low,
  reference_range_high,
  reference_range_text,
  interpretation_guide,
  notes
) as (
  values
    (
      'DVA_line_loss',
      0::numeric,
      null::numeric,
      'Dynamic visual acuity line loss. MVP screen: <=2 lines ready, 3 lines caution, >=4 lines regress/support-first review. Pair with VOR/gaze-stability tolerance, dizziness/nausea response, fall risk, and central red-flag screen.',
      jsonb_build_object(
        'seed_wave', 'p94_vestibular_gaze_dynamic_balance_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'vestibular_gaze_postural_control',
        'direction', 'lower_is_better',
        'decision_bands', jsonb_build_array('ready: <=2 lines', 'caution: 3 lines', 'regress/support-first: >=4 lines'),
        'safety_note', 'DVA line loss is gaze-stability evidence, not a stand-alone vestibular clearance rule. Screen central neurologic and orthostatic/cardiac red flags before progression.'
      ),
      'DVA line loss anchor for visual-vestibular tolerance and gaze-stability progression.'
    ),
    (
      'FGA_total',
      0::numeric,
      30::numeric,
      'Functional Gait Assessment total score. MVP screen: >=23 ready, 19-22 caution/fall-risk review, <19 regress/support-first review. Use with assistive device, dizziness, dual-task demand, and fall history.',
      jsonb_build_object(
        'seed_wave', 'p94_vestibular_gaze_dynamic_balance_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'dynamic_balance_task_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=23/30', 'caution: 19-22/30', 'regress/support-first: <19/30'),
        'safety_note', 'FGA supports dynamic gait/balance reasoning; it does not clear community ambulation without device, supervision, vitals, dizziness, and fall-risk context.'
      ),
      'FGA total score anchor for dynamic gait and balance capability.'
    ),
    (
      'MINI_BEST_total',
      0::numeric,
      28::numeric,
      'Mini-BESTest total score. MVP screen: >=24 ready, 20-23 caution/fall-risk review, <20 regress/support-first review. Use with reactive balance, sensory orientation, dynamic gait, dizziness, and supervision context.',
      jsonb_build_object(
        'seed_wave', 'p94_vestibular_gaze_dynamic_balance_l2_l3_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'dynamic_balance_task_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=24/28', 'caution: 20-23/28', 'regress/support-first: <20/28'),
        'safety_note', 'Mini-BEST supports dynamic balance reasoning; pair with fall history, assist level, vestibular irritability, device fit, and 24-hour response.'
      ),
      'Mini-BESTest total score anchor for dynamic balance capability.'
    )
),
taxonomy_targets as (
  select ot.id, seed.*
  from taxonomy_seed seed
  join public.observation_taxonomy ot
    on ot.code = seed.code
   and ot.code_system = 'http://physiokorea.com/fhir/observation'
)
update public.observation_taxonomy ot
set
  reference_range_low = taxonomy_targets.reference_range_low,
  reference_range_high = taxonomy_targets.reference_range_high,
  reference_range_text = taxonomy_targets.reference_range_text,
  interpretation_guide = coalesce(ot.interpretation_guide, '{}'::jsonb) || taxonomy_targets.interpretation_guide,
  notes = coalesce(taxonomy_targets.notes, ot.notes),
  is_active = true,
  updated_at = now()
from taxonomy_targets
where ot.id = taxonomy_targets.id;
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
values (
  'vestibular_gaze_postural_control',
  'Vestibular gaze and postural control',
  '전정 시선/자세 조절',
  'balance',
  'global',
  false,
  'quantity',
  'lines',
  'lower_is_better',
  jsonb_build_object(
    'mvp_completion_level', 'L3',
    'plain_status', '처방 판단 가능',
    'capability_v2_family', 'balance',
    'capability_v2_family_ko', '균형',
    'capability_v2_secondary_families', jsonb_build_array('walking', 'participation', 'safety'),
    'source_observations', jsonb_build_array('DVA_line_loss'),
    'source_tools', jsonb_build_array('DVA_SCREEN', 'VOMS_SCREEN', 'DHI', 'ABC_SCALE', 'FGA'),
    'source_refs', jsonb_build_array(
      'https://www.neuropt.org/practice-resources/neurology-section-outcome-measures-recommendations/vestibular-disorders',
      'https://www.sralab.org/rehabilitation-measures/dynamic-visual-acuity-test',
      'https://www.sralab.org/rehabilitation-measures/functional-gait-assessment'
    ),
    'l3_rules', jsonb_build_object(
      'basis', 'mvp_vestibular_gaze_stability_screen_not_clearance',
      'direction', 'lower_is_better',
      'decision_bands', jsonb_build_array(
        jsonb_build_object('label', 'ready', 'plain_ko', '기본 진행 가능', 'operator', '<=', 'value', 2, 'unit', 'lines'),
        jsonb_build_object('label', 'caution', 'plain_ko', '주의/증상 모니터링', 'operator', '=', 'value', 3, 'unit', 'lines'),
        jsonb_build_object('label', 'regress', 'plain_ko', '지원/쉬운 버전 우선', 'operator', '>=', 'value', 4, 'unit', 'lines')
      ),
      'default_regression', 'Use seated or supported gaze-stability work, slower head speed, shorter bouts, stable background, larger target, and guarded balance before walking-with-head-turn or busy-environment progression.',
      'laterality_required', false,
      'symptom_response_rule', 'If dizziness, nausea, oscillopsia, gait instability, orthostatic symptoms, severe headache, diplopia, dysarthria, ataxia, unilateral symptoms, or next-day flare worsens, stop or regress and reassess safety context.',
      'review_note', 'DVA line loss supports vestibular gaze-stability reasoning; pair with central red-flag screen, orthostatic/cardiac differential, fall history, assist level, DHI/ABC burden, and 24-hour response.'
    ),
    'seed_wave', 'p94_vestibular_gaze_dynamic_balance_l2_l3_bridge'
  ),
  'active',
  now()
)
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
    ('DVA_line_loss', 'vestibular_gaze_postural_control', 'quantity', 'lines', 'L3', 'DVA line loss anchors visual-vestibular gaze-stability tolerance.'),
    ('FGA_total', 'dynamic_balance_task_capacity', 'integer', 'score', 'L3', 'FGA total anchors dynamic gait/balance capacity for vestibular, neurologic, and fall-risk reasoning.'),
    ('MINI_BEST_total', 'dynamic_balance_task_capacity', 'integer', 'score', 'L3', 'Mini-BESTest total anchors dynamic balance capacity when BBS may be too broad or near ceiling.')
  ) as seed(observation_code, capability_code, value_type_hint, default_unit, completion_level, rationale)
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
  mapping_seed.value_type_hint,
  mapping_seed.default_unit,
  jsonb_build_object(
    'seed_wave', 'p94_vestibular_gaze_dynamic_balance_l2_l3_bridge',
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
      'vestibular_gaze_postural_control',
      'target',
      null::numeric,
      6::numeric,
      'lines',
      1,
      'low',
      'Supported neuromuscular patterning can target vestibular gaze/postural tolerance when symptoms and red flags are monitored.'
    ),
    (
      'EX_FBDY_FNC_001',
      'vestibular_gaze_postural_control',
      'required',
      null::numeric,
      4::numeric,
      'lines',
      2,
      'moderate',
      'Sit-to-stand should remain guarded when gaze-stability loss or dizziness increases instability.'
    ),
    (
      'EX_FBDY_BAL_008',
      'vestibular_gaze_postural_control',
      'progression_gate',
      null::numeric,
      3::numeric,
      'lines',
      3,
      'high',
      'Dynamic weight-shift progression should be gated by gaze stability, dizziness/nausea response, and fall-risk context.'
    ),
    (
      'EX_FBDY_FNC_015',
      'vestibular_gaze_postural_control',
      'progression_gate',
      null::numeric,
      3::numeric,
      'lines',
      4,
      'high',
      'Gait-training progression with head turns or visual motion should wait for adequate gaze stability and central/orthostatic safety review.'
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
    'seed_wave', 'p94_vestibular_gaze_dynamic_balance_l2_l3_bridge',
    'requirement_rule_family', 'vestibular_gaze_stability_screen',
    'clinical_interpretation', 'Use as conservative exercise matching evidence only; pair with central red flags, orthostatic/cardiac differential, medication timing, nausea tolerance, fall risk, assist level, DHI/ABC burden, and clinician judgment.'
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
