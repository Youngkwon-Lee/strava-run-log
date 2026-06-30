-- Balance task-family L3 wave 8.
-- Purpose: promote grouped BBS task families from L2 to MVP L3 by adding
-- family-level screening bands, interpretation guides, and practical
-- regression handling.
--
-- Clinical safety note:
-- These family-level bands are MVP screening defaults for exercise matching.
-- They are not diagnostic standards. The BBS source defines 14 items scored
-- 0-4 and a 56-point total. These grouped family bands are inferred by scaling
-- the existing Wave 2 total-BBS ready/caution/regress bands to each family's
-- subtotal maximum. Clinician review by population is still required.

with capability_l3_seed as (
  select * from (values
    (
      'transfer_balance_task_capacity',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('BBS_grouped_task_family'),
        'source_items', jsonb_build_array('bbs_1', 'bbs_4', 'bbs_5'),
        'group_max_score', 12,
        'inference_method', 'scaled_from_wave2_total_bbs_bands',
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 11, 'unit', 'score'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 9, 'and_operator', '<=', 'and_value', 10, 'unit', 'score'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<=', 'value', 8, 'unit', 'score')
        ),
        'default_regression', 'Prefer chair-supported squat, sit-to-stand practice, hand-supported transfers, or close guarding before unsupported squat/lunge work.',
        'laterality_required', false,
        'review_note', 'Family band is an inferred subtotal rule scaled from the total BBS thresholds used in Wave 2.'
      )
    ),
    (
      'static_balance_task_capacity',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('BBS_grouped_task_family'),
        'source_items', jsonb_build_array('bbs_2', 'bbs_3', 'bbs_6', 'bbs_7'),
        'group_max_score', 16,
        'inference_method', 'scaled_from_wave2_total_bbs_bands',
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 14, 'unit', 'score'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 12, 'and_operator', '<=', 'and_value', 13, 'unit', 'score'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<=', 'value', 11, 'unit', 'score')
        ),
        'default_regression', 'Prefer stable wide-stance standing, eyes-open support, reduced duration, or hand contact before narrow-base or unsupported single-leg tasks.',
        'laterality_required', false,
        'review_note', 'Family band is an inferred subtotal rule scaled from the total BBS thresholds used in Wave 2.'
      )
    ),
    (
      'dynamic_balance_task_capacity',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('BBS_grouped_task_family'),
        'source_items', jsonb_build_array('bbs_8', 'bbs_9', 'bbs_10', 'bbs_11'),
        'group_max_score', 16,
        'inference_method', 'scaled_from_wave2_total_bbs_bands',
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 14, 'unit', 'score'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 12, 'and_operator', '<=', 'and_value', 13, 'unit', 'score'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<=', 'value', 11, 'unit', 'score')
        ),
        'default_regression', 'Prefer supported reach, reduced turn amplitude, stable surface work, or slower obstacle/rotation exposure before unstable or multi-directional tasks.',
        'laterality_required', false,
        'review_note', 'Family band is an inferred subtotal rule scaled from the total BBS thresholds used in Wave 2.'
      )
    ),
    (
      'step_single_leg_balance_capacity',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('BBS_grouped_task_family'),
        'source_items', jsonb_build_array('bbs_12', 'bbs_13', 'bbs_14'),
        'group_max_score', 12,
        'inference_method', 'scaled_from_wave2_total_bbs_bands',
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 11, 'unit', 'score'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 9, 'and_operator', '<=', 'and_value', 10, 'unit', 'score'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<=', 'value', 8, 'unit', 'score')
        ),
        'default_regression', 'Prefer static stance, supported step taps, reduced step height, or stationary split-stance work before tandem, obstacle, or walking-lunge progressions.',
        'laterality_required', false,
        'review_note', 'Family band is an inferred subtotal rule scaled from the total BBS thresholds used in Wave 2.'
      )
    )
  ) as seed(capability_code, l3_rules)
)
update public.movement_capabilities mc
set
  properties = coalesce(mc.properties, '{}'::jsonb)
    || jsonb_build_object(
      'mvp_completion_level', 'L3',
      'plain_status', '처방 판단 가능',
      'l3_rules', capability_l3_seed.l3_rules,
      'source_refs', jsonb_build_array(
        'https://www.sralab.org/rehabilitation-measures/berg-balance-scale',
        'https://www.sralab.org/sites/default/files/2017-07/berg.pdf',
        'https://www.sralab.org/sites/default/files/2024-03/core-measure-berg-balance-scale-%28bbs%29_final-2019.pdf'
      ),
      'seed_wave', 'balance_task_family_l3_wave8'
    ),
  updated_at = now()
from capability_l3_seed
where mc.capability_code = capability_l3_seed.capability_code;
with guide_seed as (
  select * from (values
    (
      'balance_transfer_task_score',
      9::numeric,
      12::numeric,
      'MVP family screen: >=11 ready, 9-10 caution, <=8 regress/easy-version review. This is an inferred subtotal rule scaled from total BBS bands.',
      jsonb_build_object(
        'seed_wave', 'balance_task_family_l3_wave8',
        'plain_status', '처방 판단 가능',
        'capability_code', 'transfer_balance_task_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=11/12', 'caution: 9-10/12', 'regress: <=8/12'),
        'inference_method', 'scaled_from_total_bbs_thresholds',
        'safety_note', 'Grouped family subtotal only. Transfer setup, guarding, chair height, and assist use still matter.'
      )
    ),
    (
      'balance_static_posture_task_score',
      12::numeric,
      16::numeric,
      'MVP family screen: >=14 ready, 12-13 caution, <=11 regress/easy-version review. This is an inferred subtotal rule scaled from total BBS bands.',
      jsonb_build_object(
        'seed_wave', 'balance_task_family_l3_wave8',
        'plain_status', '처방 판단 가능',
        'capability_code', 'static_balance_task_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=14/16', 'caution: 12-13/16', 'regress: <=11/16'),
        'inference_method', 'scaled_from_total_bbs_thresholds',
        'safety_note', 'Grouped family subtotal only. Vision, base of support, and guarding still matter.'
      )
    ),
    (
      'balance_reach_turn_task_score',
      12::numeric,
      16::numeric,
      'MVP family screen: >=14 ready, 12-13 caution, <=11 regress/easy-version review. This is an inferred subtotal rule scaled from total BBS bands.',
      jsonb_build_object(
        'seed_wave', 'balance_task_family_l3_wave8',
        'plain_status', '처방 판단 가능',
        'capability_code', 'dynamic_balance_task_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=14/16', 'caution: 12-13/16', 'regress: <=11/16'),
        'inference_method', 'scaled_from_total_bbs_thresholds',
        'safety_note', 'Grouped family subtotal only. Reach distance, turn speed, dizziness, and symptom response still matter.'
      )
    ),
    (
      'balance_step_single_leg_task_score',
      9::numeric,
      12::numeric,
      'MVP family screen: >=11 ready, 9-10 caution, <=8 regress/easy-version review. This is an inferred subtotal rule scaled from total BBS bands.',
      jsonb_build_object(
        'seed_wave', 'balance_task_family_l3_wave8',
        'plain_status', '처방 판단 가능',
        'capability_code', 'step_single_leg_balance_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=11/12', 'caution: 9-10/12', 'regress: <=8/12'),
        'inference_method', 'scaled_from_total_bbs_thresholds',
        'safety_note', 'Grouped family subtotal only. Step height, tandem setup, and close guarding still matter.'
      )
    )
  ) as seed(code, reference_range_low, reference_range_high, reference_range_text, interpretation_guide)
)
update public.observation_taxonomy ot
set
  reference_range_low = guide_seed.reference_range_low,
  reference_range_high = guide_seed.reference_range_high,
  reference_range_text = guide_seed.reference_range_text,
  interpretation_guide = coalesce(ot.interpretation_guide, '{}'::jsonb) || guide_seed.interpretation_guide,
  updated_at = now()
from guide_seed
where ot.code = guide_seed.code;
with progression_seed as (
  select * from (values
    (
      'pk_single_leg_stance',
      'EX_ANKL_BAL_001',
      'regression',
      'stability',
      'step_single_leg_balance_capacity',
      'If single-leg stance is not ready, regress to eyes-open supported static balance before tandem or single-leg loading.'
    ),
    (
      'edb_Balance_Board',
      'pk_single_leg_stance',
      'regression',
      'stability',
      'dynamic_balance_task_capacity',
      'If unstable-surface balance is not ready, regress to stable single-leg stance before balance board progression.'
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
    'seed_wave', 'balance_task_family_l3_wave8',
    'plain_rule', '쉬운 버전 규칙',
    'mvp_completion_level', 'L3'
  ),
  'active'
from progression_seed
join public.exercises ef
  on ef.exercise_code = progression_seed.from_exercise_code
join public.exercises et
  on et.exercise_code = progression_seed.to_exercise_code
left join public.movement_capabilities mc
  on mc.capability_code = progression_seed.gate_capability_code
on conflict (from_exercise_id, to_exercise_id, relation_type)
  where status = 'active'
do update set
  progression_axis = excluded.progression_axis,
  gate_capability_id = excluded.gate_capability_id,
  rationale = excluded.rationale,
  metadata = public.exercise_progressions.metadata || excluded.metadata,
  updated_at = now();
