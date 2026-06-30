-- Seed P90 sports capability L3 defaults for Copenhagen and CMJ.
-- Purpose:
-- - promote the new sports L2 capabilities to honest MVP L3 metadata
-- - add interpretation guidance for the canonical observations
-- - add simple regression edges so the exercise layer has easier fallback paths
--
-- Clinical safety note:
-- These are MVP sports-screen defaults for exercise matching, not return-to-sport clearance rules.
-- They must be interpreted with pain, symptom irritability, asymmetry, sport phase, and clinician judgment.

with capability_l3_seed as (
  select * from (values
    (
      'hip_adduction_endurance',
      jsonb_build_object(
        'basis', 'mvp_sports_default_not_return_to_sport',
        'source_tools', jsonb_build_array('COPENHAGEN_ADDUCTION_TEST'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 25, 'unit', 'seconds'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 15, 'and_operator', '<', 'and_value', 25, 'unit', 'seconds'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 15, 'unit', 'seconds')
        ),
        'default_regression', 'Use shorter-lever adductor strengthening, low-speed frontal-plane work, or simpler hop exposure before repeated hurdle hops or higher-speed cutting drills.',
        'laterality_required', true,
        'symptom_response_rule', 'If groin pain increases during the set or is worse over the next 24 hours, reduce lateral-load demand and reassess irritability before progression.',
        'review_note', 'Copenhagen hold time is a useful groin endurance screen but is not a stand-alone return-to-sport clearance rule.'
      ),
      jsonb_build_array(
        'https://pubmed.ncbi.nlm.nih.gov/35834724/',
        'https://pubmed.ncbi.nlm.nih.gov/34631242/'
      )
    ),
    (
      'jump_power_capacity',
      jsonb_build_object(
        'basis', 'mvp_sports_default_not_return_to_sport',
        'source_tools', jsonb_build_array('CMJ_SCREEN'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 25, 'unit', 'cm'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 15, 'and_operator', '<', 'and_value', 25, 'unit', 'cm'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 15, 'unit', 'cm')
        ),
        'default_regression', 'Use lower-amplitude jump drills or standing long-jump exposure before box-jump or repeated hurdle-hop progression.',
        'laterality_required', false,
        'asymmetry_review_required', true,
        'symptom_response_rule', 'If landing quality degrades, asymmetry becomes obvious, or pain rises, lower jump height and impact volume before further plyometric progression.',
        'review_note', 'CMJ height is a practical jump-power marker for sports follow-up but is not a stand-alone readiness or return-to-sport criterion.'
      ),
      jsonb_build_array(
        'https://www.jstage.jst.go.jp/article/scjj/32/7/32_33/_article/-char/en',
        'https://pmc.ncbi.nlm.nih.gov/articles/PMC9865236/'
      )
    )
  ) as seed(capability_code, l3_rules, source_refs)
)
update public.movement_capabilities mc
set
  properties = coalesce(mc.properties, '{}'::jsonb)
    || jsonb_build_object(
      'mvp_completion_level', 'L3',
      'plain_status', '처방 판단 가능',
      'l3_rules', capability_l3_seed.l3_rules,
      'source_refs', capability_l3_seed.source_refs,
      'seed_wave', 'p90_sports_capability_l3_defaults'
    ),
  updated_at = now()
from capability_l3_seed
where mc.capability_code = capability_l3_seed.capability_code;
with guide_seed as (
  select * from (values
    (
      'COPENHAGEN_hold_time_seconds',
      15::numeric,
      null::numeric,
      'MVP sports screen: >=25s ready, 15-24s caution, <15s regress/easy-version review.',
      jsonb_build_object(
        'seed_wave', 'p90_sports_capability_l3_defaults',
        'plain_status', '처방 판단 가능',
        'capability_code', 'hip_adduction_endurance',
        'direction', 'higher_is_better',
        'laterality_required', true,
        'decision_bands', jsonb_build_array('ready: >=25s', 'caution: 15-24s', 'regress: <15s'),
        'safety_note', 'Use with side-to-side comparison, groin irritability, and sport phase context before stronger RTS decisions.'
      ),
      'seconds'
    ),
    (
      'CMJ_best_jump_height',
      15::numeric,
      null::numeric,
      'MVP sports screen: >=25cm ready, 15-24cm caution, <15cm regress/easy-version review.',
      jsonb_build_object(
        'seed_wave', 'p90_sports_capability_l3_defaults',
        'plain_status', '처방 판단 가능',
        'capability_code', 'jump_power_capacity',
        'direction', 'higher_is_better',
        'laterality_required', false,
        'asymmetry_review_required', true,
        'decision_bands', jsonb_build_array('ready: >=25cm', 'caution: 15-24cm', 'regress: <15cm'),
        'safety_note', 'Use with landing quality, asymmetry, pain response, and sport phase context before stronger RTS decisions.'
      ),
      'cm'
    )
  ) as seed(code, reference_range_low, reference_range_high, reference_range_text, interpretation_guide, default_unit)
)
update public.observation_taxonomy ot
set
  default_value_type = 'quantity',
  default_unit = guide_seed.default_unit,
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
    ('COPENHAGEN_hold_time_seconds', 'hip_adduction_endurance', 'seconds', true),
    ('CMJ_best_jump_height', 'jump_power_capacity', 'cm', false)
  ) as seed(observation_code, capability_code, canonical_unit, laterality_required)
)
update public.movement_capability_observation_mappings map
set
  default_unit = mapping_seed.canonical_unit,
  value_type_hint = 'quantity',
  metadata = coalesce(map.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'seed_wave', 'p90_sports_capability_l3_defaults',
      'completion_level', 'L3',
      'plain_status', '처방 판단 가능',
      'capability_code', mapping_seed.capability_code,
      'normalization', jsonb_build_object(
        'canonical_unit', mapping_seed.canonical_unit,
        'laterality_required', mapping_seed.laterality_required
      )
    ),
  updated_at = now()
from mapping_seed
join public.movement_capabilities mc
  on mc.capability_code = mapping_seed.capability_code
where map.observation_code = mapping_seed.observation_code
  and map.capability_id = mc.id
  and map.status = 'active';
with requirement_seed as (
  select * from (values
    (
      'hip_adduction_endurance',
      jsonb_build_object(
        'requirement_rule_family', 'sports_adduction_endurance_seconds',
        'sports_interpretation', jsonb_build_object(
          'min_value_lt_15', 'requires regression to lower-speed groin strengthening or shorter-lever frontal-plane work',
          'min_value_15_to_24', 'caution zone: build tolerance with simpler hop exposure and symptom monitoring',
          'min_value_gte_25', 'higher-speed lateral hop progression may be considered if symptoms and movement quality are acceptable'
        )
      )
    ),
    (
      'jump_power_capacity',
      jsonb_build_object(
        'requirement_rule_family', 'sports_jump_power_height_cm',
        'sports_interpretation', jsonb_build_object(
          'min_value_lt_15', 'requires regression to lower-amplitude jump exposure or non-maximal power work',
          'min_value_15_to_24', 'caution zone: use simple plyometric exposure with landing-quality monitoring',
          'min_value_gte_25', 'higher-demand plyometric progression may be considered if landing quality and symptoms are acceptable'
        )
      )
    )
  ) as seed(capability_code, metadata_patch)
)
update public.exercise_requirements er
set
  metadata = coalesce(er.metadata, '{}'::jsonb)
    || jsonb_build_object('seed_wave', 'p90_sports_capability_l3_defaults')
    || requirement_seed.metadata_patch,
  updated_at = now()
from requirement_seed
join public.movement_capabilities mc
  on mc.capability_code = requirement_seed.capability_code
where er.capability_id = mc.id
  and er.status = 'active';
with progression_seed as (
  select * from (values
    (
      'edb_Hurdle_Hops',
      'EX_HIP_PLY_004',
      'regression',
      'stability',
      'hip_adduction_endurance',
      'If groin/adductor endurance is limited, regress repeated hurdle hops to hip single-leg hop exposure first.'
    ),
    (
      'EX_HIP_PLY_004',
      'edb_Thigh_Adductor',
      'regression',
      'impact',
      'hip_adduction_endurance',
      'If hop tolerance is not ready, regress to adductor strengthening before repeated single-leg plyometric work.'
    ),
    (
      'edb_Hurdle_Hops',
      'EX_KNEE_PLY_001',
      'regression',
      'impact',
      'jump_power_capacity',
      'If repeated hurdle hops are not ready, regress to box-jump exposure first.'
    ),
    (
      'EX_KNEE_PLY_001',
      'edb_Standing_Long_Jump',
      'regression',
      'complexity',
      'jump_power_capacity',
      'If box-jump landing demand is not ready, regress to standing long-jump power exposure first.'
    )
  ) as seed(
    from_exercise_code,
    to_exercise_code,
    relation_type,
    progression_axis,
    gate_capability_code,
    rationale
  )
)
insert into public.exercise_progressions (
  from_exercise_id,
  to_exercise_id,
  relation_type,
  progression_axis,
  gate_capability_id,
  rationale,
  metadata,
  status
)
select
  ef.id,
  et.id,
  progression_seed.relation_type,
  progression_seed.progression_axis,
  mc.id,
  progression_seed.rationale,
  jsonb_build_object(
    'seed_wave', 'p90_sports_capability_l3_defaults',
    'plain_rule', '쉬운 버전 규칙',
    'mvp_completion_level', 'L3'
  ),
  'active'
from progression_seed
join public.exercises ef
  on ef.exercise_code = progression_seed.from_exercise_code
join public.exercises et
  on et.exercise_code = progression_seed.to_exercise_code
join public.movement_capabilities mc
  on mc.capability_code = progression_seed.gate_capability_code
on conflict (from_exercise_id, to_exercise_id, relation_type)
  where status = 'active'
do update set
  progression_axis = excluded.progression_axis,
  gate_capability_id = excluded.gate_capability_id,
  rationale = excluded.rationale,
  metadata = public.exercise_progressions.metadata || excluded.metadata,
  updated_at = now();
