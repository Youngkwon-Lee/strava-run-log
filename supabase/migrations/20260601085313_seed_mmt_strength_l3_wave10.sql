-- MMT strength L3 wave 10.
-- Purpose: promote the current canonical MMT strength fan-out set from L2 to MVP L3.
--
-- Scope:
-- - Adds common MMT/Oxford/MRC-style 0-5 decision metadata to 9 existing strength capabilities.
-- - Updates matching observation guides and observation-to-capability mapping metadata.
-- - Does not add new MMT targets, tables, or strong diagnosis-specific policy.
--
-- Clinical safety note:
-- These values are MVP exercise-matching defaults, not diagnostic thresholds.
-- Manual muscle testing is ordinal and examiner-dependent; grade 4 is especially broad.
-- Use pain, effort, neurological signs, ROM, irritability, and clinician judgment before
-- strong automated loading or return-to-sport decisions.

do $$
declare
  missing_capabilities text[];
  missing_observations text[];
begin
  select array_agg(seed.capability_code order by seed.capability_code)
  into missing_capabilities
  from (
    values
      ('quadriceps_strength'),
      ('hip_abduction_strength'),
      ('hip_extension_strength'),
      ('shoulder_abduction_strength'),
      ('ankle_dorsiflexion_strength'),
      ('trunk_flexion_strength'),
      ('elbow_flexion_strength'),
      ('wrist_extension_strength'),
      ('great_toe_extension_strength')
  ) as seed(capability_code)
  left join public.movement_capabilities mc
    on mc.capability_code = seed.capability_code
   and mc.status = 'active'
  where mc.id is null;

  if coalesce(array_length(missing_capabilities, 1), 0) > 0 then
    raise exception 'Missing MMT capabilities for wave 10: %', missing_capabilities;
  end if;

  select array_agg(seed.observation_code order by seed.observation_code)
  into missing_observations
  from (
    values
      ('MMT_knee_extension'),
      ('MMT_hip_abduction'),
      ('MMT_hip_extension'),
      ('MMT_shoulder_abduction'),
      ('MMT_ankle_dorsiflexion'),
      ('MMT_trunk_flexion'),
      ('MMT_elbow_flexion'),
      ('MMT_wrist_extension'),
      ('MMT_great_toe_extension')
  ) as seed(observation_code)
  left join public.observation_taxonomy ot
    on ot.code = seed.observation_code
   and ot.code_system = 'http://physiokorea.com/fhir/observation'
  where ot.id is null;

  if coalesce(array_length(missing_observations, 1), 0) > 0 then
    raise exception 'Missing MMT observations for wave 10: %', missing_observations;
  end if;
end $$;
with mmt_l3_seed as (
  select * from (values
    (
      'quadriceps_strength',
      'MMT_knee_extension',
      true,
      'Use quad set, short-arc knee extension, straight-leg raise, chair squat, or supported sit-to-stand before lunge, step-up, or loaded squat work.',
      'MMT knee extension affects squat, sit-to-stand, step-up, stair, and lunge loading. Treat pain inhibition and extensor lag as separate safety signals.'
    ),
    (
      'hip_abduction_strength',
      'MMT_hip_abduction',
      true,
      'Use clamshell, side-lying abduction with short lever, standing supported abduction, or band-free lateral stepping before monster walk or loaded frontal-plane work.',
      'Hip abduction MMT should influence side-specific frontal-plane loading and pelvis/knee control cues.'
    ),
    (
      'hip_extension_strength',
      'MMT_hip_extension',
      true,
      'Use pelvic tilt bridge, bilateral hip bridge, reduced range hip hinge, or supported sit-to-stand before single-leg bridge, step-up, deadlift, or loaded squat work.',
      'Hip extension MMT is only one signal; also check lumbopelvic control and hamstring/lumbar substitution.'
    ),
    (
      'shoulder_abduction_strength',
      'MMT_shoulder_abduction',
      true,
      'Use assisted seated abduction, short-lever scaption, isometric abduction, or low-range band work before full-range lateral raise or overhead loading.',
      'Shoulder abduction MMT should be interpreted with pain arc, scapular control, and irritability before resistance progressions.'
    ),
    (
      'ankle_dorsiflexion_strength',
      'MMT_ankle_dorsiflexion',
      true,
      'Use gravity-minimized dorsiflexion, active ROM, light band dorsiflexion, or gait cueing before resisted toe raise, heel walk, or dynamic foot-clearance tasks.',
      'Dorsiflexion weakness may affect foot clearance and fall risk; check neurological signs and gait context before progression.'
    ),
    (
      'trunk_flexion_strength',
      'MMT_trunk_flexion',
      false,
      'Use abdominal bracing, posterior pelvic tilt, dead-bug arms-only, heel taps, or supported curl-up before loaded crunch or advanced trunk-flexion work.',
      'Trunk flexion MMT is not a lumbar safety clearance rule by itself; pair with pain response and motor-control findings.'
    ),
    (
      'elbow_flexion_strength',
      'MMT_elbow_flexion',
      true,
      'Use active-assisted elbow flexion, isometrics, light band curl, or partial range before dumbbell, preacher, or heavier curl work.',
      'Elbow flexion MMT should be paired with pain, tendon irritability, grip symptoms, and neurological screen when relevant.'
    ),
    (
      'wrist_extension_strength',
      'MMT_wrist_extension',
      true,
      'Use wrist extension isometrics, gravity-minimized motion, light band work, or forearm support before wrist roller or loaded wrist extension work.',
      'Wrist extension MMT should be interpreted with radial nerve signs, grip tolerance, and lateral elbow pain when relevant.'
    ),
    (
      'great_toe_extension_strength',
      'MMT_great_toe_extension',
      true,
      'Use active great-toe extension, towel/toe control drills, light resisted toe extension, or gait cueing before higher-demand foot-clearance or push-off tasks.',
      'Great-toe extension MMT may indicate foot clearance or neurological concerns; pair with sensation, gait, and red-flag screening.'
    )
  ) as seed(capability_code, observation_code, laterality_required, default_regression, review_note)
),
mmt_rule_seed as (
  select
    capability_code,
    observation_code,
    jsonb_build_object(
      'basis', 'mvp_screening_default_not_diagnostic',
      'source_tools', jsonb_build_array('MMT', 'MRC/Oxford 0-5 strength scale'),
      'value_scale', '0_to_5_ordinal_grade',
      'decision_bands', jsonb_build_array(
        jsonb_build_object(
          'label', 'ready',
          'plain_ko', '기본 저항 운동 가능',
          'operator', '>=',
          'value', 4,
          'unit', 'grade',
          'requires', 'pain and compensation acceptable'
        ),
        jsonb_build_object(
          'label', 'caution',
          'plain_ko', '주의/보조 필요',
          'operator', '>=',
          'value', 3,
          'and_operator', '<',
          'and_value', 4,
          'unit', 'grade',
          'requires', 'full active range against gravity'
        ),
        jsonb_build_object(
          'label', 'regress',
          'plain_ko', '쉬운 버전 우선',
          'operator', '<',
          'value', 3,
          'unit', 'grade',
          'or', 'pain inhibition, substitution, extensor lag, or neurological concern'
        )
      ),
      'requirement_interpretation', jsonb_build_object(
        'grade_1_to_2', 'activation or gravity-minimized entry point',
        'grade_3', 'anti-gravity, low-load entry point with supervision/cues',
        'grade_4_to_5', 'resistance progression may be considered if symptoms and movement quality allow'
      ),
      'default_regression', default_regression,
      'laterality_required', laterality_required,
      'symptom_response_rule', 'If pain, substitution, giving-way, extensor lag, or neurological symptoms increase, reduce load/range or choose the easier version and reassess.',
      'review_note', review_note,
      'ordinal_scale_warning', 'MMT grades are ordinal and examiner-dependent; do not treat grade differences as equal intervals.'
    ) as l3_rules
  from mmt_l3_seed
)
update public.movement_capabilities mc
set
  properties = coalesce(mc.properties, '{}'::jsonb)
    || jsonb_build_object(
      'mvp_completion_level', 'L3',
      'plain_status', '처방 판단 가능',
      'l3_rules', mmt_rule_seed.l3_rules,
      'source_refs', jsonb_build_array(
        'https://www.ncbi.nlm.nih.gov/books/NBK436008/',
        'https://www.merckmanuals.com/professional/multimedia/table/grades-of-muscle-strength-a',
        'https://pmc.ncbi.nlm.nih.gov/articles/PMC3338921/'
      ),
      'seed_wave', 'mmt_strength_l3_wave10'
    ),
  updated_at = now()
from mmt_rule_seed
where mc.capability_code = mmt_rule_seed.capability_code;
with mmt_l3_seed as (
  select * from (values
    ('MMT_knee_extension', 'quadriceps_strength', true, '대퇴사두근 근력'),
    ('MMT_hip_abduction', 'hip_abduction_strength', true, '고관절 외전 근력'),
    ('MMT_hip_extension', 'hip_extension_strength', true, '고관절 신전 근력'),
    ('MMT_shoulder_abduction', 'shoulder_abduction_strength', true, '어깨 외전 근력'),
    ('MMT_ankle_dorsiflexion', 'ankle_dorsiflexion_strength', true, '발목 배측굴곡 근력'),
    ('MMT_trunk_flexion', 'trunk_flexion_strength', false, '몸통 굴곡 근력'),
    ('MMT_elbow_flexion', 'elbow_flexion_strength', true, '팔꿈치 굴곡 근력'),
    ('MMT_wrist_extension', 'wrist_extension_strength', true, '손목 신전 근력'),
    ('MMT_great_toe_extension', 'great_toe_extension_strength', true, '엄지발가락 신전 근력')
  ) as seed(observation_code, capability_code, laterality_required, capability_label_ko)
)
update public.observation_taxonomy ot
set
  default_value_type = 'quantity',
  default_unit = 'grade',
  reference_range_low = coalesce(ot.reference_range_low, 0),
  reference_range_high = coalesce(ot.reference_range_high, 5),
  interpretation_guide = coalesce(ot.interpretation_guide, '{}'::jsonb)
    || jsonb_build_object(
      'seed_wave', 'mmt_strength_l3_wave10',
      'plain_status', '처방 판단 가능',
      'capability_code', mmt_l3_seed.capability_code,
      'capability_label_ko', mmt_l3_seed.capability_label_ko,
      'direction', 'higher_is_better',
      'value_scale', '0_to_5_ordinal_grade',
      'laterality_required', mmt_l3_seed.laterality_required,
      'decision_bands', jsonb_build_array(
        'ready: >=4/5 if pain and compensation acceptable',
        'caution: 3/5 to <4/5, anti-gravity low-load entry',
        'regress: <3/5 or pain inhibition/substitution/neurological concern'
      ),
      'safety_note', 'MMT is ordinal and examiner-dependent; use as one exercise-matching signal with pain, ROM, compensation, neurological screen, and clinician judgment.'
    ),
  updated_at = now()
from mmt_l3_seed
where ot.code = mmt_l3_seed.observation_code
  and ot.code_system = 'http://physiokorea.com/fhir/observation';
with mmt_l3_seed as (
  select * from (values
    ('MMT_knee_extension', 'quadriceps_strength', true),
    ('MMT_hip_abduction', 'hip_abduction_strength', true),
    ('MMT_hip_extension', 'hip_extension_strength', true),
    ('MMT_shoulder_abduction', 'shoulder_abduction_strength', true),
    ('MMT_ankle_dorsiflexion', 'ankle_dorsiflexion_strength', true),
    ('MMT_trunk_flexion', 'trunk_flexion_strength', false),
    ('MMT_elbow_flexion', 'elbow_flexion_strength', true),
    ('MMT_wrist_extension', 'wrist_extension_strength', true),
    ('MMT_great_toe_extension', 'great_toe_extension_strength', true)
  ) as seed(observation_code, capability_code, laterality_required)
)
update public.movement_capability_observation_mappings map
set
  default_unit = 'grade',
  value_type_hint = 'quantity',
  metadata = coalesce(map.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'seed_wave', 'mmt_strength_l3_wave10',
      'completion_level', 'L3',
      'plain_status', '처방 판단 가능',
      'capability_code', mmt_l3_seed.capability_code,
      'normalization', jsonb_build_object(
        'canonical_unit', 'grade',
        'accepted_source_units', jsonb_build_array('grade', 'mmt_grade', '/5'),
        'value_scale', '0_to_5_ordinal_grade',
        'laterality_required', mmt_l3_seed.laterality_required
      )
    ),
  updated_at = now()
from mmt_l3_seed
where map.observation_code = mmt_l3_seed.observation_code
  and map.status = 'active';
with mmt_requirement_seed as (
  select * from (values
    ('quadriceps_strength'),
    ('hip_abduction_strength'),
    ('hip_extension_strength'),
    ('shoulder_abduction_strength'),
    ('ankle_dorsiflexion_strength'),
    ('trunk_flexion_strength'),
    ('elbow_flexion_strength'),
    ('wrist_extension_strength'),
    ('great_toe_extension_strength')
  ) as seed(capability_code)
)
update public.exercise_requirements er
set
  value_unit = coalesce(er.value_unit, 'grade'),
  metadata = coalesce(er.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'seed_wave', 'mmt_strength_l3_wave10',
      'requirement_rule_family', 'mmt_strength_grade',
      'mmt_interpretation', jsonb_build_object(
        'min_value_lt_3', 'requires regression, assistance, gravity-minimized position, or clinician review',
        'min_value_3', 'anti-gravity low-load entry if symptoms and movement quality are acceptable',
        'min_value_gte_4', 'resistance progression may be considered if symptoms and movement quality are acceptable'
      )
    ),
  updated_at = now()
from mmt_requirement_seed
join public.movement_capabilities mc
  on mc.capability_code = mmt_requirement_seed.capability_code
where er.capability_id = mc.id
  and er.status = 'active';
