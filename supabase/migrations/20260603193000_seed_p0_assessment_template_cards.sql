-- Seed P0 assessment templates for Encounter Room / Session Composer.
--
-- Copyright guardrail:
-- This migration intentionally avoids embedding official item wording for
-- licensed or potentially licensed instruments. Those templates store only
-- domain placeholders, raw-score fields, subscale fields, or summary results
-- so clinicians can record results from a legitimately administered tool.

with template_seed (
  form_code,
  form_name,
  form_name_korean,
  category,
  description,
  instructions,
  total_score_calculation,
  items,
  body_region,
  applicable_expert_types,
  score_min,
  score_max,
  max_possible_score,
  higher_is_better,
  evidence_level,
  evidence_source
) as (
  values
    (
      'SLUMP',
      'Slump Test',
      '슬럼프 검사',
      'screening',
      'Neurodynamic screening card for lumbar radicular symptoms and neural mechanosensitivity. Aliases: slump, 슬럼프, neurodynamic, neural tension, sciatica, 방사통.',
      'Record side, positive/negative result, symptom location, sensitizer response, and comparable baseline. This is a structured clinical finding template, not a copyrighted script.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','slump_left_result','question_number',1,'question_text','Left result','question_text_korean','좌측 결과','answer_type','select','options',jsonb_build_array('negative','positive','not_tested')),
        jsonb_build_object('score_key','slump_right_result','question_number',2,'question_text','Right result','question_text_korean','우측 결과','answer_type','select','options',jsonb_build_array('negative','positive','not_tested')),
        jsonb_build_object('score_key','symptom_location','question_number',3,'question_text','Symptom location','question_text_korean','증상 위치','answer_type','text'),
        jsonb_build_object('score_key','sensitizer_response','question_number',4,'question_text','Sensitizer response','question_text_korean','민감화 동작 반응','answer_type','select','options',jsonb_build_array('none','neck_flexion','ankle_dorsiflexion','both','other')),
        jsonb_build_object('score_key','baseline_comparable','question_number',5,'question_text','Comparable baseline','question_text_korean','추적 비교 기준','answer_type','text')
      ),
      'lumbar',
      array['physiotherapist','athletic_trainer']::text[],
      null,
      null,
      null,
      false,
      'clinical_practice',
      'Structured neurodynamic clinical finding; no official wording embedded'
    ),
    (
      'HOP_TEST_BATTERY',
      'Hop Test Battery',
      '홉 테스트 배터리',
      'sports_rehab',
      'Return-to-sport lower-extremity hop battery with limb symmetry index. Aliases: hop, single hop, triple hop, crossover hop, 6m timed hop, LSI, ACL, return to sport, RTS, 홉, 스포츠 복귀.',
      'Record involved/uninvolved limb performance and calculate LSI. Use alongside strength, movement quality, symptoms, time since injury/surgery, and psychological readiness.',
      'composite',
      jsonb_build_array(
        jsonb_build_object('score_key','single_hop_involved_cm','question_number',1,'question_text','Single hop involved limb distance','question_text_korean','싱글 홉 환측 거리','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','single_hop_uninvolved_cm','question_number',2,'question_text','Single hop uninvolved limb distance','question_text_korean','싱글 홉 건측 거리','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','triple_hop_involved_cm','question_number',3,'question_text','Triple hop involved limb distance','question_text_korean','트리플 홉 환측 거리','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','triple_hop_uninvolved_cm','question_number',4,'question_text','Triple hop uninvolved limb distance','question_text_korean','트리플 홉 건측 거리','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','crossover_hop_involved_cm','question_number',5,'question_text','Crossover hop involved limb distance','question_text_korean','크로스오버 홉 환측 거리','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','crossover_hop_uninvolved_cm','question_number',6,'question_text','Crossover hop uninvolved limb distance','question_text_korean','크로스오버 홉 건측 거리','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','six_meter_timed_hop_involved_sec','question_number',7,'question_text','6m timed hop involved limb','question_text_korean','6m 시간 홉 환측','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','six_meter_timed_hop_uninvolved_sec','question_number',8,'question_text','6m timed hop uninvolved limb','question_text_korean','6m 시간 홉 건측','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','overall_lsi_percent','question_number',9,'question_text','Overall limb symmetry index','question_text_korean','전체 하지 대칭 지수','answer_type','number','unit','percent','calculation_note','Distance tests: involved/uninvolved x 100. Timed test: uninvolved/involved x 100.'),
        jsonb_build_object('score_key','movement_quality_notes','question_number',10,'question_text','Movement quality notes','question_text_korean','착지/동작 품질 메모','answer_type','text')
      ),
      'knee',
      array['physiotherapist','athletic_trainer','crossfit_coach']::text[],
      0,
      100,
      100,
      true,
      'clinical_practice',
      'ACL return-to-sport literature commonly uses hop testing as part of a multi-factor battery'
    ),
    (
      'HHD_STRENGTH_SYMMETRY',
      'Handheld Dynamometry Strength Symmetry',
      '휴대용 동력계 근력 대칭 검사',
      'strength',
      'Handheld dynamometer force and limb symmetry card for return-to-sport and rehab progression. Aliases: HHD, dynamometer, handheld dynamometry, force, torque, LSI, strength symmetry, 근력 대칭.',
      'Record test movement, position, involved/uninvolved peak force, optional lever arm/torque, body-weight normalization, pain, and LSI.',
      'composite',
      jsonb_build_array(
        jsonb_build_object('score_key','target_movement','question_number',1,'question_text','Target movement','question_text_korean','검사 동작','answer_type','select','options',jsonb_build_array('knee_extension','knee_flexion','hip_abduction','hip_extension','ankle_dorsiflexion','shoulder_external_rotation','shoulder_abduction','other')),
        jsonb_build_object('score_key','test_position','question_number',2,'question_text','Test position','question_text_korean','검사 자세','answer_type','text'),
        jsonb_build_object('score_key','involved_peak_force_n','question_number',3,'question_text','Involved limb peak force','question_text_korean','환측 최대 힘','answer_type','number','unit','N'),
        jsonb_build_object('score_key','uninvolved_peak_force_n','question_number',4,'question_text','Uninvolved limb peak force','question_text_korean','건측 최대 힘','answer_type','number','unit','N'),
        jsonb_build_object('score_key','limb_symmetry_index_percent','question_number',5,'question_text','Limb symmetry index','question_text_korean','사지 대칭 지수','answer_type','number','unit','percent','calculation_note','involved/uninvolved x 100'),
        jsonb_build_object('score_key','pain_during_test','question_number',6,'question_text','Pain during test','question_text_korean','검사 중 통증','answer_type','number','min_value',0,'max_value',10,'unit','score')
      ),
      'general',
      array['physiotherapist','athletic_trainer','crossfit_coach']::text[],
      0,
      100,
      100,
      true,
      'clinical_practice',
      'Structured performance measure; no proprietary item wording'
    ),
    (
      '30CST',
      '30-Second Chair Stand Test',
      '30초 의자 일어서기 검사',
      'strength',
      'Lower-extremity functional strength/endurance screen. Aliases: 30CST, 30 second chair stand, chair stand, sit to stand, STS, 30초, 의자 일어서기.',
      'Record repetitions in 30 seconds, chair/arm-use context, symptoms, and safety notes.',
      'raw_score',
      jsonb_build_array(
        jsonb_build_object('score_key','repetitions','question_number',1,'question_text','Completed repetitions','question_text_korean','완료 횟수','answer_type','number','unit','reps'),
        jsonb_build_object('score_key','arm_use','question_number',2,'question_text','Arm use','question_text_korean','팔 사용 여부','answer_type','select','options',jsonb_build_array('no_arm_use','used_arms','unable_without_assist')),
        jsonb_build_object('score_key','chair_height_cm','question_number',3,'question_text','Chair height','question_text_korean','의자 높이','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','symptom_response','question_number',4,'question_text','Symptom response','question_text_korean','증상 반응','answer_type','text')
      ),
      'general',
      array['physiotherapist','athletic_trainer','wellness_coach']::text[],
      0,
      null,
      null,
      true,
      'clinical_practice',
      'Common functional performance test; raw repetitions stored'
    ),
    (
      'FGA',
      'Functional Gait Assessment',
      '기능적 보행 평가 (FGA)',
      'balance',
      'Dynamic gait and fall-risk outcome measure. Aliases: FGA, functional gait, dynamic gait, gait assessment, 보행 평가, 동적 보행.',
      'Licensed wording may be needed for official item criteria. MVP stores item numbers/domains, total score, assistive-device context, and safety notes only.',
      'sum',
      (
        select jsonb_agg(
          jsonb_build_object(
            'score_key', concat('fga_item_', lpad(i::text, 2, '0')),
            'question_number', i,
            'question_text', concat('FGA item ', i, ' score'),
            'question_text_korean', concat('FGA ', i, '번 항목 점수'),
            'answer_type', 'ordinal_0_3',
            'min_value', 0,
            'max_value', 3,
            'requires_official_item_text', true,
            'license_note', 'Official FGA item wording/scoring criteria are not embedded.'
          )
          order by i
        )
        from generate_series(1, 10) as i
      ) || jsonb_build_array(
        jsonb_build_object('score_key','fga_total_score','question_number',11,'question_text','FGA total score','question_text_korean','FGA 총점','answer_type','number','min_value',0,'max_value',30,'unit','score'),
        jsonb_build_object('score_key','assistive_device','question_number',12,'question_text','Assistive device','question_text_korean','보조기구','answer_type','text')
      ),
      'general',
      array['physiotherapist','athletic_trainer','wellness_coach']::text[],
      0,
      30,
      30,
      true,
      'licensed_summary',
      'Official item wording not embedded; use licensed instrument for administration'
    ),
    (
      'MINI_BEST',
      'Mini-BESTest',
      '미니 BESTest',
      'balance',
      'Dynamic balance assessment summary for Parkinson, vestibular, stroke, and fall-risk reasoning. Aliases: Mini-BESTest, mini best, BESTest, reactive balance, anticipatory balance, sensory orientation.',
      'Licensed wording may be needed for official item criteria. MVP stores item numbers/subdomain scores and total score only.',
      'sum',
      (
        select jsonb_agg(
          jsonb_build_object(
            'score_key', concat('mini_best_item_', lpad(i::text, 2, '0')),
            'question_number', i,
            'question_text', concat('Mini-BESTest item ', i, ' score'),
            'question_text_korean', concat('Mini-BESTest ', i, '번 항목 점수'),
            'answer_type', 'ordinal_0_2',
            'min_value', 0,
            'max_value', 2,
            'requires_official_item_text', true,
            'license_note', 'Official Mini-BESTest item wording/scoring criteria are not embedded.'
          )
          order by i
        )
        from generate_series(1, 14) as i
      ) || jsonb_build_array(
        jsonb_build_object('score_key','anticipatory_subscore','question_number',15,'question_text','Anticipatory subscore','question_text_korean','예측성 균형 소계','answer_type','number','unit','score'),
        jsonb_build_object('score_key','reactive_subscore','question_number',16,'question_text','Reactive postural control subscore','question_text_korean','반응성 자세조절 소계','answer_type','number','unit','score'),
        jsonb_build_object('score_key','sensory_subscore','question_number',17,'question_text','Sensory orientation subscore','question_text_korean','감각 지향 소계','answer_type','number','unit','score'),
        jsonb_build_object('score_key','dynamic_gait_subscore','question_number',18,'question_text','Dynamic gait subscore','question_text_korean','동적 보행 소계','answer_type','number','unit','score'),
        jsonb_build_object('score_key','mini_best_total_score','question_number',19,'question_text','Mini-BESTest total score','question_text_korean','Mini-BESTest 총점','answer_type','number','min_value',0,'max_value',28,'unit','score')
      ),
      'general',
      array['physiotherapist']::text[],
      0,
      28,
      28,
      true,
      'licensed_summary',
      'Official item wording not embedded; use licensed instrument for administration'
    ),
    (
      'ISNCSCI_SUMMARY',
      'ISNCSCI / ASIA Impairment Scale Summary',
      'ISNCSCI / ASIA 손상척도 요약',
      'neurological',
      'SCI neurological classification summary card. Aliases: ISNCSCI, ASIA, AIS, spinal cord injury, SCI, neurological level, motor level, sensory level, 척수손상.',
      'Do not embed the official worksheet. Record summary outputs from a properly performed ISNCSCI exam: sensory/motor levels, NLI, AIS grade, ZPP, and key notes.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','sensory_level_left','question_number',1,'question_text','Left sensory level','question_text_korean','좌측 감각 수준','answer_type','text'),
        jsonb_build_object('score_key','sensory_level_right','question_number',2,'question_text','Right sensory level','question_text_korean','우측 감각 수준','answer_type','text'),
        jsonb_build_object('score_key','motor_level_left','question_number',3,'question_text','Left motor level','question_text_korean','좌측 운동 수준','answer_type','text'),
        jsonb_build_object('score_key','motor_level_right','question_number',4,'question_text','Right motor level','question_text_korean','우측 운동 수준','answer_type','text'),
        jsonb_build_object('score_key','neurological_level_of_injury','question_number',5,'question_text','Neurological level of injury','question_text_korean','신경학적 손상 수준','answer_type','text'),
        jsonb_build_object('score_key','ais_grade','question_number',6,'question_text','AIS grade','question_text_korean','AIS 등급','answer_type','select','options',jsonb_build_array('A','B','C','D','E','unknown')),
        jsonb_build_object('score_key','zpp_summary','question_number',7,'question_text','Zone of partial preservation summary','question_text_korean','부분 보존 구역 요약','answer_type','text')
      ),
      'spine',
      array['physiotherapist']::text[],
      null,
      null,
      null,
      true,
      'licensed_summary',
      'Official ISNCSCI worksheet not embedded; summary-only template'
    ),
    (
      'PEDI_CAT_SUMMARY',
      'PEDI-CAT Summary',
      'PEDI-CAT 요약',
      'pediatric',
      'Pediatric Evaluation of Disability Inventory Computer Adaptive Test summary card. Aliases: PEDI-CAT, PEDICAT, pediatric ADL, caregiver report, mobility, responsibility, 소아 기능, 보호자 보고.',
      'PEDI-CAT is distributed commercially. MVP stores official report summary scores only; do not embed item bank wording.',
      'composite',
      jsonb_build_array(
        jsonb_build_object('score_key','daily_activities_t_score','question_number',1,'question_text','Daily Activities T-score','question_text_korean','일상활동 T점수','answer_type','number','unit','T-score'),
        jsonb_build_object('score_key','mobility_t_score','question_number',2,'question_text','Mobility T-score','question_text_korean','이동 T점수','answer_type','number','unit','T-score'),
        jsonb_build_object('score_key','social_cognitive_t_score','question_number',3,'question_text','Social/Cognitive T-score','question_text_korean','사회/인지 T점수','answer_type','number','unit','T-score'),
        jsonb_build_object('score_key','responsibility_t_score','question_number',4,'question_text','Responsibility T-score','question_text_korean','책임 영역 T점수','answer_type','number','unit','T-score'),
        jsonb_build_object('score_key','report_version','question_number',5,'question_text','Report version/source','question_text_korean','보고서 버전/출처','answer_type','text')
      ),
      'general',
      array['physiotherapist']::text[],
      null,
      null,
      null,
      true,
      'licensed_summary',
      'PEDI-CAT item bank/report requires licensed source; summary-only template'
    ),
    (
      'PROMIS_PF_PI',
      'PROMIS Physical Function / Pain Interference Summary',
      'PROMIS 신체기능 / 통증간섭 요약',
      'quality_of_life',
      'PROMIS summary card for physical function and pain interference. Aliases: PROMIS, physical function, pain interference, T-score, function PROM, wellness PROM, 신체기능, 통증간섭.',
      'Store raw score and T-score from HealthMeasures/PROMIS short forms or scoring service. Do not embed item wording unless permission and correct version are confirmed.',
      'composite',
      jsonb_build_array(
        jsonb_build_object('score_key','physical_function_raw_score','question_number',1,'question_text','Physical Function raw score','question_text_korean','신체기능 원점수','answer_type','number','unit','raw'),
        jsonb_build_object('score_key','physical_function_t_score','question_number',2,'question_text','Physical Function T-score','question_text_korean','신체기능 T점수','answer_type','number','unit','T-score'),
        jsonb_build_object('score_key','pain_interference_raw_score','question_number',3,'question_text','Pain Interference raw score','question_text_korean','통증간섭 원점수','answer_type','number','unit','raw'),
        jsonb_build_object('score_key','pain_interference_t_score','question_number',4,'question_text','Pain Interference T-score','question_text_korean','통증간섭 T점수','answer_type','number','unit','T-score'),
        jsonb_build_object('score_key','instrument_version','question_number',5,'question_text','Instrument version','question_text_korean','도구 버전','answer_type','text')
      ),
      'general',
      array['physiotherapist','athletic_trainer','pilates_instructor','crossfit_coach','wellness_coach']::text[],
      null,
      null,
      null,
      true,
      'public_measure_summary',
      'PROMIS measures are publicly available through HealthMeasures; e-administration/versioning should be permission-checked'
    )
)
insert into public.assessment_form_templates (
  form_code,
  form_name,
  form_name_korean,
  category,
  description,
  instructions,
  total_score_calculation,
  items,
  body_region,
  applicable_expert_types,
  score_min,
  score_max,
  max_possible_score,
  higher_is_better,
  evidence_level,
  evidence_source,
  is_active
)
select
  form_code,
  form_name,
  form_name_korean,
  category,
  description,
  instructions,
  total_score_calculation,
  items,
  body_region,
  applicable_expert_types,
  score_min,
  score_max,
  max_possible_score,
  higher_is_better,
  evidence_level,
  evidence_source,
  true
from template_seed
on conflict (form_code) do update
set
  form_name = excluded.form_name,
  form_name_korean = excluded.form_name_korean,
  category = excluded.category,
  description = excluded.description,
  instructions = excluded.instructions,
  total_score_calculation = excluded.total_score_calculation,
  items = excluded.items,
  body_region = excluded.body_region,
  applicable_expert_types = excluded.applicable_expert_types,
  score_min = excluded.score_min,
  score_max = excluded.score_max,
  max_possible_score = excluded.max_possible_score,
  higher_is_better = excluded.higher_is_better,
  evidence_level = excluded.evidence_level,
  evidence_source = excluded.evidence_source,
  is_active = excluded.is_active,
  updated_at = now();
-- Replace partial copyrighted-question-like PROM items with licensed-safe
-- subscale/summary fields. Official item wording should be attached only after
-- permission/version review.
update public.assessment_form_templates
set
  description = 'Knee Injury and Osteoarthritis Outcome Score summary/subscale card. Aliases: KOOS, knee, ACL, meniscus, OA, TKA, pain, symptoms, ADL, sport, QOL, 무릎, 슬관절.',
  instructions = 'Permission is required to use KOOS; do not embed official item text unless licensed wording/version are confirmed. MVP records subscale scores transformed to 0-100.',
  total_score_calculation = 'composite',
  items = jsonb_build_array(
    jsonb_build_object('score_key','koos_pain_score','question_number',1,'question_text','KOOS Pain subscale score','question_text_korean','KOOS 통증 하위점수','answer_type','number','min_value',0,'max_value',100,'unit','score_0_100','requires_official_item_text',true),
    jsonb_build_object('score_key','koos_symptoms_score','question_number',2,'question_text','KOOS Symptoms subscale score','question_text_korean','KOOS 증상 하위점수','answer_type','number','min_value',0,'max_value',100,'unit','score_0_100','requires_official_item_text',true),
    jsonb_build_object('score_key','koos_adl_score','question_number',3,'question_text','KOOS ADL subscale score','question_text_korean','KOOS 일상생활 하위점수','answer_type','number','min_value',0,'max_value',100,'unit','score_0_100','requires_official_item_text',true),
    jsonb_build_object('score_key','koos_sport_rec_score','question_number',4,'question_text','KOOS Sport/Recreation subscale score','question_text_korean','KOOS 스포츠/레크리에이션 하위점수','answer_type','number','min_value',0,'max_value',100,'unit','score_0_100','requires_official_item_text',true),
    jsonb_build_object('score_key','koos_qol_score','question_number',5,'question_text','KOOS Quality of Life subscale score','question_text_korean','KOOS 삶의 질 하위점수','answer_type','number','min_value',0,'max_value',100,'unit','score_0_100','requires_official_item_text',true)
  ),
  score_min = 0,
  score_max = 100,
  max_possible_score = 100,
  higher_is_better = true,
  evidence_level = coalesce(evidence_level, 'licensed_summary'),
  evidence_source = 'KOOS official guidance requires permission; summary fields only',
  updated_at = now()
where form_code = 'KOOS';
update public.assessment_form_templates
set
  description = 'QuickDASH summary card for upper-extremity disability. Aliases: QuickDASH, qDASH, DASH, upper limb, shoulder, elbow, wrist, hand, 상지, 어깨, 팔꿈치, 손목, 손.',
  instructions = 'DASH/QuickDASH commercial or translated use may require a license. MVP records raw/converted summary score only; official item wording is not embedded.',
  total_score_calculation = 'composite',
  items = jsonb_build_array(
    jsonb_build_object('score_key','quickdash_raw_sum','question_number',1,'question_text','QuickDASH raw item sum','question_text_korean','QuickDASH 원점수 합','answer_type','number','unit','raw','requires_official_item_text',true),
    jsonb_build_object('score_key','quickdash_completed_item_count','question_number',2,'question_text','Completed item count','question_text_korean','응답 완료 문항 수','answer_type','number','min_value',0,'max_value',11,'unit','items'),
    jsonb_build_object('score_key','quickdash_score_0_100','question_number',3,'question_text','QuickDASH converted score','question_text_korean','QuickDASH 변환 점수','answer_type','number','min_value',0,'max_value',100,'unit','score_0_100')
  ),
  score_min = 0,
  score_max = 100,
  max_possible_score = 100,
  higher_is_better = false,
  evidence_level = coalesce(evidence_level, 'licensed_summary'),
  evidence_source = 'DASH/QuickDASH license-sensitive; summary fields only',
  updated_at = now()
where form_code = 'QUICKDASH';
update public.assessment_form_templates
set
  description = 'Shoulder Pain and Disability Index summary/subscale card. Aliases: SPADI, shoulder pain, shoulder disability, rotator cuff, frozen shoulder, 어깨 통증, 어깨 장애.',
  instructions = 'Do not embed official item wording unless the target version/license is confirmed. MVP records pain subscale, disability subscale, and total percentage.',
  total_score_calculation = 'percentage',
  items = jsonb_build_array(
    jsonb_build_object('score_key','spadi_pain_subscore_percent','question_number',1,'question_text','SPADI pain subscale percent','question_text_korean','SPADI 통증 하위점수','answer_type','number','min_value',0,'max_value',100,'unit','percent','requires_official_item_text',true),
    jsonb_build_object('score_key','spadi_disability_subscore_percent','question_number',2,'question_text','SPADI disability subscale percent','question_text_korean','SPADI 장애 하위점수','answer_type','number','min_value',0,'max_value',100,'unit','percent','requires_official_item_text',true),
    jsonb_build_object('score_key','spadi_total_percent','question_number',3,'question_text','SPADI total percent','question_text_korean','SPADI 총점','answer_type','number','min_value',0,'max_value',100,'unit','percent')
  ),
  score_min = 0,
  score_max = 100,
  max_possible_score = 100,
  higher_is_better = false,
  evidence_level = coalesce(evidence_level, 'licensed_summary'),
  evidence_source = 'License/version-sensitive; summary fields only',
  updated_at = now()
where form_code = 'SPADI';
insert into public.clinical_concepts (
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  source_table,
  source_record_id_text,
  source_code,
  source_code_system,
  definition,
  properties,
  status
)
select
  'assessment_template:' || lower(aft.form_code),
  aft.form_name,
  aft.form_name_korean,
  'assessment_template',
  array['core']::text[],
  'assessment_form_templates',
  aft.id::text,
  aft.form_code,
  'http://physiokorea.com/fhir/assessment-template',
  aft.description,
  jsonb_strip_nulls(jsonb_build_object(
    'category', aft.category,
    'body_region', aft.body_region,
    'is_active', aft.is_active,
    'seed', '20260603193000_seed_p0_assessment_template_cards'
  )),
  case when aft.is_active then 'active' else 'deprecated' end
from public.assessment_form_templates aft
where aft.form_code in (
  'SLUMP',
  'HOP_TEST_BATTERY',
  'HHD_STRENGTH_SYMMETRY',
  '30CST',
  'FGA',
  'MINI_BEST',
  'ISNCSCI_SUMMARY',
  'PEDI_CAT_SUMMARY',
  'PROMIS_PF_PI',
  'KOOS',
  'QUICKDASH',
  'SPADI'
)
on conflict (concept_key) do update
set
  display = excluded.display,
  display_ko = excluded.display_ko,
  source_record_id_text = excluded.source_record_id_text,
  source_code = excluded.source_code,
  source_code_system = excluded.source_code_system,
  definition = excluded.definition,
  properties = excluded.properties,
  status = excluded.status,
  updated_at = now();
with taxonomy_seed (
  code,
  code_display,
  category,
  default_value_type,
  default_unit,
  notes
) as (
  values
    ('special_test_slump', 'Slump test result', array['special_test','neuro','msk']::text[], 'string', null, 'Slump test positive/negative side-specific clinical finding'),
    ('special_test_slump_symptom_response', 'Slump test symptom response', array['special_test','neuro','msk']::text[], 'string', null, 'Symptom location and sensitizer response during Slump test'),
    ('hop_test_lsi_percent', 'Hop test limb symmetry index', array['sports','function','strength']::text[], 'quantity', 'percent', 'Overall limb symmetry index from hop battery'),
    ('hop_test_distance_cm', 'Hop test distance', array['sports','function']::text[], 'quantity', 'cm', 'Distance captured during hop testing'),
    ('hop_test_time_seconds', 'Timed hop seconds', array['sports','function']::text[], 'quantity', 'sec', 'Time captured during 6m timed hop'),
    ('hhd_peak_force_n', 'Handheld dynamometry peak force', array['strength']::text[], 'quantity', 'N', 'Peak force from handheld dynamometry'),
    ('hhd_lsi_percent', 'Handheld dynamometry limb symmetry index', array['strength','sports']::text[], 'quantity', 'percent', 'Limb symmetry index from HHD force values'),
    ('thirty_second_chair_stand_reps', '30-second chair stand repetitions', array['strength','function']::text[], 'integer', 'reps', 'Completed repetitions during 30-second chair stand'),
    ('FGA_total', 'Functional Gait Assessment total score', array['balance','gait']::text[], 'integer', 'score', 'FGA total summary score'),
    ('MINI_BEST_total', 'Mini-BESTest total score', array['balance']::text[], 'integer', 'score', 'Mini-BESTest total summary score'),
    ('ISNCSCI_summary', 'ISNCSCI neurological classification summary', array['neuro','sci']::text[], 'json', null, 'SCI neurological classification summary fields'),
    ('PEDI_CAT_domain_t_scores', 'PEDI-CAT domain T-scores', array['pediatric','function']::text[], 'json', 'T-score', 'PEDI-CAT domain summary scores'),
    ('PROMIS_t_scores', 'PROMIS T-scores', array['prom','quality_of_life']::text[], 'json', 'T-score', 'PROMIS physical function and pain interference summary scores')
)
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
select
  ts.code,
  'http://physiokorea.com/fhir/observation',
  ts.code_display,
  ts.category,
  ts.default_value_type,
  ts.default_unit,
  'p0_assessment_template_cards',
  ts.notes,
  true
from taxonomy_seed ts
on conflict (code, code_system) do update
set
  code_display = excluded.code_display,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  data_source = excluded.data_source,
  notes = excluded.notes,
  is_active = excluded.is_active,
  updated_at = now();
with semantic_seed (
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
    ('SLUMP','slump_left_result','result','special_test_slump','Left Slump result',array['special_test','neuro','msk']::text[],'string',null,'Left Slump positive/negative result'),
    ('SLUMP','slump_right_result','result','special_test_slump','Right Slump result',array['special_test','neuro','msk']::text[],'string',null,'Right Slump positive/negative result'),
    ('SLUMP','symptom_location','context','special_test_slump_symptom_response','Slump symptom location',array['special_test','neuro','msk']::text[],'string',null,'Symptom location during Slump test'),
    ('SLUMP','sensitizer_response','context','special_test_slump_symptom_response','Slump sensitizer response',array['special_test','neuro','msk']::text[],'string',null,'Sensitizer response during Slump test'),
    ('HOP_TEST_BATTERY','single_hop_involved_cm','result','hop_test_distance_cm','Single hop involved distance',array['sports','function']::text[],'quantity','cm','Single hop involved limb distance'),
    ('HOP_TEST_BATTERY','single_hop_uninvolved_cm','result','hop_test_distance_cm','Single hop uninvolved distance',array['sports','function']::text[],'quantity','cm','Single hop uninvolved limb distance'),
    ('HOP_TEST_BATTERY','triple_hop_involved_cm','result','hop_test_distance_cm','Triple hop involved distance',array['sports','function']::text[],'quantity','cm','Triple hop involved limb distance'),
    ('HOP_TEST_BATTERY','triple_hop_uninvolved_cm','result','hop_test_distance_cm','Triple hop uninvolved distance',array['sports','function']::text[],'quantity','cm','Triple hop uninvolved limb distance'),
    ('HOP_TEST_BATTERY','crossover_hop_involved_cm','result','hop_test_distance_cm','Crossover hop involved distance',array['sports','function']::text[],'quantity','cm','Crossover hop involved limb distance'),
    ('HOP_TEST_BATTERY','crossover_hop_uninvolved_cm','result','hop_test_distance_cm','Crossover hop uninvolved distance',array['sports','function']::text[],'quantity','cm','Crossover hop uninvolved limb distance'),
    ('HOP_TEST_BATTERY','six_meter_timed_hop_involved_sec','result','hop_test_time_seconds','6m timed hop involved',array['sports','function']::text[],'quantity','sec','6m timed hop involved limb time'),
    ('HOP_TEST_BATTERY','six_meter_timed_hop_uninvolved_sec','result','hop_test_time_seconds','6m timed hop uninvolved',array['sports','function']::text[],'quantity','sec','6m timed hop uninvolved limb time'),
    ('HOP_TEST_BATTERY','overall_lsi_percent','aggregate','hop_test_lsi_percent','Hop battery overall LSI',array['sports','function','strength']::text[],'quantity','percent','Overall hop test limb symmetry index'),
    ('HHD_STRENGTH_SYMMETRY','involved_peak_force_n','result','hhd_peak_force_n','HHD involved peak force',array['strength']::text[],'quantity','N','Involved side peak force'),
    ('HHD_STRENGTH_SYMMETRY','uninvolved_peak_force_n','result','hhd_peak_force_n','HHD uninvolved peak force',array['strength']::text[],'quantity','N','Uninvolved side peak force'),
    ('HHD_STRENGTH_SYMMETRY','limb_symmetry_index_percent','aggregate','hhd_lsi_percent','HHD limb symmetry index',array['strength','sports']::text[],'quantity','percent','HHD force limb symmetry index'),
    ('30CST','repetitions','result','thirty_second_chair_stand_reps','30-second chair stand repetitions',array['strength','function']::text[],'integer','reps','Completed repetitions'),
    ('FGA','fga_total_score','aggregate','FGA_total','FGA total score',array['balance','gait']::text[],'integer','score','Functional Gait Assessment total score'),
    ('MINI_BEST','mini_best_total_score','aggregate','MINI_BEST_total','Mini-BESTest total score',array['balance']::text[],'integer','score','Mini-BESTest total score'),
    ('ISNCSCI_SUMMARY','ais_grade','result','ISNCSCI_summary','AIS grade',array['neuro','sci']::text[],'string',null,'ASIA impairment scale grade summary'),
    ('PEDI_CAT_SUMMARY','mobility_t_score','result','PEDI_CAT_domain_t_scores','PEDI-CAT mobility T-score',array['pediatric','function']::text[],'quantity','T-score','PEDI-CAT mobility domain T-score'),
    ('PROMIS_PF_PI','physical_function_t_score','result','PROMIS_t_scores','PROMIS physical function T-score',array['prom','quality_of_life']::text[],'quantity','T-score','PROMIS physical function T-score'),
    ('PROMIS_PF_PI','pain_interference_t_score','result','PROMIS_t_scores','PROMIS pain interference T-score',array['prom','quality_of_life']::text[],'quantity','T-score','PROMIS pain interference T-score')
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
  aft.id,
  ss.score_key,
  nullif(item.item ->> 'question_number', '')::integer,
  ss.binding_role,
  ot.id,
  cc.id,
  ss.observation_code,
  'http://physiokorea.com/fhir/observation',
  ss.display_override,
  ss.category,
  ss.default_value_type,
  ss.default_unit,
  ss.notes,
  jsonb_build_object('seed', '20260603193000_seed_p0_assessment_template_cards', 'form_code', ss.form_code),
  'active'
from semantic_seed ss
join public.assessment_form_templates aft
  on aft.form_code = ss.form_code
left join lateral (
  select item
  from jsonb_array_elements(coalesce(aft.items, '[]'::jsonb)) item
  where item ->> 'score_key' = ss.score_key
  limit 1
) item on true
left join public.observation_taxonomy ot
  on ot.code = ss.observation_code
 and ot.code_system = 'http://physiokorea.com/fhir/observation'
left join public.clinical_concepts cc
  on cc.concept_key = 'assessment_template:' || lower(aft.form_code)
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
  metadata = excluded.metadata,
  status = excluded.status,
  updated_at = now();
