-- Assessment capability L3 wave 2.
-- Purpose: add MVP decision rules for the first high-value assessment bridge.
--
-- Scope:
-- - Marks TUG, 5xSTS, BBS, gait speed, 6MWT, and SLR/Slump capabilities as L3 MVP-ready.
-- - Stores cutoff/severity/laterality/regression guidance as rule metadata, not as diagnosis.
-- - Adds explicit regression edges so the recommendation service can suggest easier versions.
--
-- Clinical safety note:
-- These values are MVP screening defaults for exercise matching. They are not diagnostic
-- thresholds and should be reviewed per population, condition, assistive-device context,
-- and clinician judgment before strong automated prescribing.

with capability_l3_seed as (
  select * from (values
    (
      'functional_transfer_balance',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('TUG', '5xSTS'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '<=', 'value', 12, 'unit', 's'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>', 'value', 12, 'and_operator', '<=', 'and_value', 15, 'unit', 's'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '>', 'value', 15, 'unit', 's')
        ),
        'default_regression', 'Use chair-supported squat, reduced step height, unloaded stair practice, or close guarding before unsupported squat/lunge work.',
        'laterality_required', false,
        'review_note', 'TUG and 5xSTS are functional screens; cutoff performance varies by age, diagnosis, device use, and test setup.'
      )
    ),
    (
      'balance_function_score',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('BBS'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 50, 'unit', 'score'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 45, 'and_operator', '<', 'and_value', 50, 'unit', 'score'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 45, 'unit', 'score')
        ),
        'default_regression', 'Prefer supported static balance, wider stance, hand support, lower-complexity lunge variants, or non-unstable surfaces.',
        'laterality_required', false,
        'review_note', 'BBS has ceiling effects and fall-risk cutoffs vary across populations; use as one safety signal.'
      )
    ),
    (
      'gait_speed_capacity',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('gait_speed', '10m_walk_test'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 0.8, 'unit', 'm/s'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 0.6, 'and_operator', '<', 'and_value', 0.8, 'unit', 'm/s'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 0.6, 'unit', 'm/s')
        ),
        'default_regression', 'Use supported stepping, lower obstacle height, slower tempo, or balance-first drills before dynamic lunge/step-over work.',
        'laterality_required', false,
        'review_note', 'Gait speed classes are functional ambulation screens, not isolated exercise clearance rules.'
      )
    ),
    (
      'walking_endurance_capacity',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('6MWT'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 250, 'unit', 'm'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 150, 'and_operator', '<', 'and_value', 250, 'unit', 'm'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 150, 'unit', 'm')
        ),
        'default_regression', 'Use shorter intervals, seated/standing rest breaks, lower volume, and simple step patterns before walking lunges or higher-volume stair work.',
        'laterality_required', false,
        'review_note', '6MWT distance depends on diagnosis, age, height, sex, oxygen response, and test protocol.'
      )
    ),
    (
      'neural_symptom_tolerance',
      jsonb_build_object(
        'basis', 'mvp_screening_default_not_diagnostic',
        'source_tools', jsonb_build_array('SLR', 'Slump'),
        'decision_bands', jsonb_build_array(
          jsonb_build_object('label', 'ready', 'plain_ko', '기본 운동 가능', 'operator', '>=', 'value', 70, 'unit', 'deg', 'requires', 'no distal symptom reproduction'),
          jsonb_build_object('label', 'caution', 'plain_ko', '주의/보조 필요', 'operator', '>=', 'value', 45, 'and_operator', '<', 'and_value', 70, 'unit', 'deg', 'requires', 'mild or stable symptoms only'),
          jsonb_build_object('label', 'regress', 'plain_ko', '쉬운 버전 우선', 'operator', '<', 'value', 45, 'unit', 'deg', 'or', 'distal symptom worsening')
        ),
        'default_regression', 'Prefer symptom-guided short-arc mobility, 90/90 hamstring position, reduced range, or hold/stop rules when distal symptoms increase.',
        'laterality_required', true,
        'review_note', 'SLR/Slump angle alone is insufficient; symptom location, distal reproduction, structural differentiation, and side are required.'
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
        'https://www.aafp.org/pubs/afp/issues/2024/0500/falls-older-adults.html',
        'https://www.sralab.org/rehabilitation-measures/five-times-sit-stand-test',
        'https://www.sralab.org/rehabilitation-measures/berg-balance-scale',
        'https://pubmed.ncbi.nlm.nih.gov/17510461/',
        'https://www.ncbi.nlm.nih.gov/books/NBK576420/',
        'https://www.ncbi.nlm.nih.gov/books/NBK545299/'
      ),
      'seed_wave', 'assessment_capability_l3_wave2'
    ),
  updated_at = now()
from capability_l3_seed
where mc.capability_code = capability_l3_seed.capability_code;
with guide_seed as (
  select * from (values
    (
      'TUG_seconds',
      null::numeric,
      12::numeric,
      'MVP screen: <=12s ready, >12-15s caution, >15s regress/easy-version review.',
      jsonb_build_object(
        'seed_wave', 'assessment_capability_l3_wave2',
        'plain_status', '처방 판단 가능',
        'capability_code', 'functional_transfer_balance',
        'direction', 'lower_is_better',
        'decision_bands', jsonb_build_array('ready: <=12s', 'caution: >12-15s', 'regress: >15s'),
        'safety_note', 'Functional screen only; device use and setup affect interpretation.'
      )
    ),
    (
      'five_times_sit_to_stand_seconds',
      null::numeric,
      15::numeric,
      'MVP screen: <=12s ready, >12-15s caution, >15s regress/easy-version review.',
      jsonb_build_object(
        'seed_wave', 'assessment_capability_l3_wave2',
        'plain_status', '처방 판단 가능',
        'capability_code', 'functional_transfer_balance',
        'direction', 'lower_is_better',
        'decision_bands', jsonb_build_array('ready: <=12s', 'caution: >12-15s', 'regress: >15s'),
        'safety_note', 'Functional lower-limb screen only; chair height and arm use matter.'
      )
    ),
    (
      'BBS_total',
      45::numeric,
      56::numeric,
      'MVP screen: >=50 ready, 45-49 caution, <45 regress/easy-version review.',
      jsonb_build_object(
        'seed_wave', 'assessment_capability_l3_wave2',
        'plain_status', '처방 판단 가능',
        'capability_code', 'balance_function_score',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=50', 'caution: 45-49', 'regress: <45'),
        'safety_note', 'BBS is a balance/fall-risk screen and has population-specific limits.'
      )
    ),
    (
      'gait_speed',
      0.6::numeric,
      null::numeric,
      'MVP screen: >=0.8 m/s ready, 0.6-0.79 caution, <0.6 regress/easy-version review.',
      jsonb_build_object('seed_wave', 'assessment_capability_l3_wave2', 'plain_status', '처방 판단 가능', 'capability_code', 'gait_speed_capacity', 'direction', 'higher_is_better', 'decision_bands', jsonb_build_array('ready: >=0.8 m/s', 'caution: 0.6-0.79 m/s', 'regress: <0.6 m/s'))
    ),
    (
      'GAIT_speed',
      0.6::numeric,
      null::numeric,
      'MVP screen: >=0.8 m/s ready, 0.6-0.79 caution, <0.6 regress/easy-version review.',
      jsonb_build_object('seed_wave', 'assessment_capability_l3_wave2', 'plain_status', '처방 판단 가능', 'capability_code', 'gait_speed_capacity', 'direction', 'higher_is_better', 'decision_bands', jsonb_build_array('ready: >=0.8 m/s', 'caution: 0.6-0.79 m/s', 'regress: <0.6 m/s'))
    ),
    (
      'PHYSIO-GAIT-SPEED',
      0.6::numeric,
      null::numeric,
      'MVP screen: >=0.8 m/s ready, 0.6-0.79 caution, <0.6 regress/easy-version review.',
      jsonb_build_object('seed_wave', 'assessment_capability_l3_wave2', 'plain_status', '처방 판단 가능', 'capability_code', 'gait_speed_capacity', 'direction', 'higher_is_better', 'decision_bands', jsonb_build_array('ready: >=0.8 m/s', 'caution: 0.6-0.79 m/s', 'regress: <0.6 m/s'))
    ),
    (
      'ten_meter_walk_speed',
      0.6::numeric,
      null::numeric,
      'MVP screen: >=0.8 m/s ready, 0.6-0.79 caution, <0.6 regress/easy-version review.',
      jsonb_build_object('seed_wave', 'assessment_capability_l3_wave2', 'plain_status', '처방 판단 가능', 'capability_code', 'gait_speed_capacity', 'direction', 'higher_is_better', 'decision_bands', jsonb_build_array('ready: >=0.8 m/s', 'caution: 0.6-0.79 m/s', 'regress: <0.6 m/s'))
    ),
    (
      'six_minute_walk_distance',
      150::numeric,
      null::numeric,
      'MVP screen: >=250m ready, 150-249m caution, <150m regress/easy-version review.',
      jsonb_build_object(
        'seed_wave', 'assessment_capability_l3_wave2',
        'plain_status', '처방 판단 가능',
        'capability_code', 'walking_endurance_capacity',
        'direction', 'higher_is_better',
        'decision_bands', jsonb_build_array('ready: >=250m', 'caution: 150-249m', 'regress: <150m'),
        'safety_note', 'Use vitals, SpO2, dyspnea, diagnosis, and protocol context before intensity decisions.'
      )
    ),
    (
      'special_test_slr_angle',
      45::numeric,
      null::numeric,
      'MVP screen: >=70deg without distal reproduction ready, 45-69deg caution, <45deg or distal symptom worsening regress.',
      jsonb_build_object(
        'seed_wave', 'assessment_capability_l3_wave2',
        'plain_status', '처방 판단 가능',
        'capability_code', 'neural_symptom_tolerance',
        'direction', 'higher_is_better_when_symptom_free',
        'laterality_required', true,
        'decision_bands', jsonb_build_array('ready: >=70deg and symptom-free', 'caution: 45-69deg stable/mild symptoms', 'regress: <45deg or distal worsening'),
        'safety_note', 'Angle alone is insufficient; pair with symptom distribution and side.'
      )
    ),
    (
      'special_test_slr',
      null::numeric,
      null::numeric,
      'MVP screen: positive/distal reproduction triggers caution/regression; side and symptom behavior required.',
      jsonb_build_object('seed_wave', 'assessment_capability_l3_wave2', 'plain_status', '처방 판단 가능', 'capability_code', 'neural_symptom_tolerance', 'laterality_required', true, 'safety_note', 'Use positive/negative result only with symptom location, side, and irritability.')
    ),
    (
      'SLR',
      null::numeric,
      null::numeric,
      'MVP screen: positive/distal reproduction triggers caution/regression; side and symptom behavior required.',
      jsonb_build_object('seed_wave', 'assessment_capability_l3_wave2', 'plain_status', '처방 판단 가능', 'capability_code', 'neural_symptom_tolerance', 'laterality_required', true, 'safety_note', 'Use positive/negative result only with symptom location, side, and irritability.')
    ),
    (
      'special_test_slump',
      null::numeric,
      null::numeric,
      'MVP screen: positive/distal reproduction triggers caution/regression; side and symptom behavior required.',
      jsonb_build_object('seed_wave', 'assessment_capability_l3_wave2', 'plain_status', '처방 판단 가능', 'capability_code', 'neural_symptom_tolerance', 'laterality_required', true, 'safety_note', 'Slump requires symptom modification/structural differentiation context.')
    ),
    (
      'SLUMP',
      null::numeric,
      null::numeric,
      'MVP screen: positive/distal reproduction triggers caution/regression; side and symptom behavior required.',
      jsonb_build_object('seed_wave', 'assessment_capability_l3_wave2', 'plain_status', '처방 판단 가능', 'capability_code', 'neural_symptom_tolerance', 'laterality_required', true, 'safety_note', 'Slump requires symptom modification/structural differentiation context.')
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
      'edb_Bodyweight_Squat',
      'edb_Chair_Squat',
      'regression',
      'assistance',
      'functional_transfer_balance',
      'If transfer/balance time is limited, use chair squat before unsupported bodyweight squat.'
    ),
    (
      'edb_Barbell_Step_Ups',
      'EX_ANKL_FNC_002',
      'regression',
      'load',
      'functional_transfer_balance',
      'If functional transfer or gait capacity is limited, regress loaded step-ups to unloaded stair practice.'
    ),
    (
      'EX_ANKL_FNC_002',
      'edb_Chair_Squat',
      'regression',
      'assistance',
      'functional_transfer_balance',
      'If stair practice is not ready, use supported chair squat transfer work first.'
    ),
    (
      'EX_ANKL_FNC_008',
      'EX_ANKL_BAL_001',
      'regression',
      'stability',
      'gait_speed_capacity',
      'If obstacle step-over is not ready, regress to eyes-open static balance before dynamic stepping.'
    ),
    (
      'edb_Balance_Board',
      'EX_ANKL_BAL_001',
      'regression',
      'stability',
      'balance_function_score',
      'If unstable-surface balance is not ready, regress to stable eyes-open balance.'
    ),
    (
      'pk_lunge',
      'edb_Bodyweight_Squat',
      'regression',
      'complexity',
      'balance_function_score',
      'If split-stance balance is limited, regress lunge to bilateral squat pattern.'
    ),
    (
      'edb_Bodyweight_Walking_Lunge',
      'pk_lunge',
      'regression',
      'complexity',
      'balance_function_score',
      'If walking lunge is not ready, regress to stationary lunge.'
    ),
    (
      'pk_straight_leg_raise',
      'edb_90_90_Hamstring',
      'regression',
      'range',
      'neural_symptom_tolerance',
      'If neural symptom tolerance is limited, regress straight-leg raise exercise to symptom-guided 90/90 hamstring position.'
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
    'seed_wave', 'assessment_capability_l3_wave2',
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
