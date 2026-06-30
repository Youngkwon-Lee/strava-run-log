-- Seed P2 assessment templates for Encounter Room / Session Composer.
--
-- Copyright guardrail:
-- This migration avoids embedding official item wording for licensed or
-- potentially licensed instruments. SFMA is stored as a summary card only.

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
      'CARPAL_TUNNEL_SCREEN',
      'Carpal Tunnel Clinical Screen',
      '수근관 증후군 임상 선별',
      'screening',
      'Wrist and hand symptom screen for suspected median nerve irritation or carpal tunnel presentation. Aliases: carpal tunnel, CTS, Phalen, Tinel, Durkan, median nerve, wrist numbness, 손목 저림, 수근관.',
      'Record side, symptom reproduction on common provocation findings, sensory distribution, and referral/safety notes. This is a clinical finding card, not a scripted procedure.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','side','question_number',1,'question_text','Test side','question_text_korean','검사 측','answer_type','select','options',jsonb_build_array('left','right','bilateral','not_tested')),
        jsonb_build_object('score_key','phalen_result','question_number',2,'question_text','Phalen finding','question_text_korean','Phalen 소견','answer_type','select','options',jsonb_build_array('negative','positive','inconclusive','not_tested')),
        jsonb_build_object('score_key','tinel_result','question_number',3,'question_text','Tinel finding','question_text_korean','Tinel 소견','answer_type','select','options',jsonb_build_array('negative','positive','inconclusive','not_tested')),
        jsonb_build_object('score_key','carpal_compression_result','question_number',4,'question_text','Carpal compression finding','question_text_korean','수근관 압박 소견','answer_type','select','options',jsonb_build_array('negative','positive','inconclusive','not_tested')),
        jsonb_build_object('score_key','sensory_distribution','question_number',5,'question_text','Sensory distribution','question_text_korean','감각 증상 분포','answer_type','text'),
        jsonb_build_object('score_key','symptom_reproduction','question_number',6,'question_text','Familiar symptom reproduced','question_text_korean','익숙한 증상 재현','answer_type','select','options',jsonb_build_array('no','yes','unclear')),
        jsonb_build_object('score_key','notes','question_number',7,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'wrist_hand',
      array['physiotherapist','athletic_trainer']::text[],
      null,
      null,
      null,
      false,
      'clinical_practice',
      'Structured wrist and hand clinical screen; no official wording embedded'
    ),
    (
      'HIP_IMPINGEMENT_SCREEN',
      'Hip Impingement Clinical Screen',
      '고관절 충돌/관절내 병변 임상 선별',
      'screening',
      'Hip special-test summary card for suspected intra-articular hip pain or femoroacetabular impingement reasoning. Aliases: FADIR, FABER, hip impingement, FAI, scour, log roll, groin pain, 고관절 충돌.',
      'Record side, common hip provocation findings, familiar pain response, pain location, and clinical notes. This is a finding card, not official scripted wording.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','side','question_number',1,'question_text','Test side','question_text_korean','검사 측','answer_type','select','options',jsonb_build_array('left','right','bilateral','not_tested')),
        jsonb_build_object('score_key','fadir_result','question_number',2,'question_text','FADIR finding','question_text_korean','FADIR 소견','answer_type','select','options',jsonb_build_array('negative','positive','inconclusive','not_tested')),
        jsonb_build_object('score_key','faber_result','question_number',3,'question_text','FABER finding','question_text_korean','FABER 소견','answer_type','select','options',jsonb_build_array('negative','positive','inconclusive','not_tested')),
        jsonb_build_object('score_key','scour_result','question_number',4,'question_text','Scour finding','question_text_korean','Scour 소견','answer_type','select','options',jsonb_build_array('negative','positive','inconclusive','not_tested')),
        jsonb_build_object('score_key','log_roll_result','question_number',5,'question_text','Log roll finding','question_text_korean','Log roll 소견','answer_type','select','options',jsonb_build_array('negative','positive','inconclusive','not_tested')),
        jsonb_build_object('score_key','familiar_pain_reproduced','question_number',6,'question_text','Familiar pain reproduced','question_text_korean','익숙한 통증 재현','answer_type','select','options',jsonb_build_array('no','yes','unclear')),
        jsonb_build_object('score_key','pain_location','question_number',7,'question_text','Pain location','question_text_korean','통증 위치','answer_type','text'),
        jsonb_build_object('score_key','notes','question_number',8,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'hip',
      array['physiotherapist','athletic_trainer']::text[],
      null,
      null,
      null,
      false,
      'clinical_practice',
      'Structured hip clinical screen; no official wording embedded'
    ),
    (
      'SINGLE_LEG_SQUAT',
      'Single-Leg Squat Movement Screen',
      '싱글레그 스쿼트 동작 선별',
      'movement_quality',
      'Lower-extremity movement quality card for knee, hip, ankle, running, and return-to-sport reasoning. Aliases: single leg squat, SLS, dynamic valgus, knee control, 싱글레그, 한발 스쿼트.',
      'Record side, repetitions, knee control, pelvic/trunk control, depth, symptoms, and coaching notes.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','side','question_number',1,'question_text','Test side','question_text_korean','검사 측','answer_type','select','options',jsonb_build_array('left','right','bilateral','not_tested')),
        jsonb_build_object('score_key','reps_completed','question_number',2,'question_text','Repetitions completed','question_text_korean','수행 반복수','answer_type','number','unit','count'),
        jsonb_build_object('score_key','knee_control','question_number',3,'question_text','Knee control','question_text_korean','무릎 정렬/제어','answer_type','select','options',jsonb_build_array('good','mild_fault','moderate_fault','severe_fault','not_tested')),
        jsonb_build_object('score_key','pelvic_trunk_control','question_number',4,'question_text','Pelvic/trunk control','question_text_korean','골반/몸통 제어','answer_type','select','options',jsonb_build_array('good','mild_fault','moderate_fault','severe_fault','not_tested')),
        jsonb_build_object('score_key','depth_quality','question_number',5,'question_text','Depth quality','question_text_korean','깊이/가동범위 품질','answer_type','select','options',jsonb_build_array('adequate','limited','compensated','not_tested')),
        jsonb_build_object('score_key','pain_score','question_number',6,'question_text','Pain score','question_text_korean','통증 점수','answer_type','number','min_value',0,'max_value',10,'unit','NPRS'),
        jsonb_build_object('score_key','notes','question_number',7,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'lower_extremity',
      array['physiotherapist','athletic_trainer','crossfit_coach','wellness_coach']::text[],
      null,
      null,
      null,
      false,
      'clinical_practice',
      'Structured movement-quality clinical screen'
    ),
    (
      'LATERAL_STEP_DOWN',
      'Lateral Step-Down Test',
      '측면 스텝다운 검사',
      'movement_quality',
      'Step-down movement quality card for patellofemoral, knee, hip, ankle, and return-to-sport reasoning. Aliases: step down, lateral step-down, step-down test, knee valgus, 스텝다운.',
      'Record side, step height, repetitions, knee/pelvic control, pain, and overall movement quality.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','side','question_number',1,'question_text','Test side','question_text_korean','검사 측','answer_type','select','options',jsonb_build_array('left','right','bilateral','not_tested')),
        jsonb_build_object('score_key','step_height_cm','question_number',2,'question_text','Step height','question_text_korean','스텝 높이','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','reps_completed','question_number',3,'question_text','Repetitions completed','question_text_korean','수행 반복수','answer_type','number','unit','count'),
        jsonb_build_object('score_key','knee_control','question_number',4,'question_text','Knee control','question_text_korean','무릎 정렬/제어','answer_type','select','options',jsonb_build_array('good','mild_fault','moderate_fault','severe_fault','not_tested')),
        jsonb_build_object('score_key','pelvic_control','question_number',5,'question_text','Pelvic control','question_text_korean','골반 제어','answer_type','select','options',jsonb_build_array('good','mild_fault','moderate_fault','severe_fault','not_tested')),
        jsonb_build_object('score_key','pain_score','question_number',6,'question_text','Pain score','question_text_korean','통증 점수','answer_type','number','min_value',0,'max_value',10,'unit','NPRS'),
        jsonb_build_object('score_key','quality_rating','question_number',7,'question_text','Overall quality rating','question_text_korean','전체 동작 품질','answer_type','select','options',jsonb_build_array('pass','caution','fail','not_tested'))
      ),
      'lower_extremity',
      array['physiotherapist','athletic_trainer','crossfit_coach','wellness_coach']::text[],
      null,
      null,
      null,
      false,
      'clinical_practice',
      'Structured step-down movement-quality clinical screen'
    ),
    (
      'RUNNING_GAIT_SCREEN',
      'Running Gait Screen',
      '러닝 보행/주행 패턴 선별',
      'sports_rehab',
      'Running movement screen card for runners and return-to-run planning. Aliases: running gait, runner screen, cadence, foot strike, return to run, 러닝, 주행, 보행 분석.',
      'Record context, cadence, foot strike, step width, pelvic/trunk findings, symptom onset, and notes. MVP stores structured observations rather than video-derived analytics.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','running_context','question_number',1,'question_text','Running context','question_text_korean','러닝 조건','answer_type','text'),
        jsonb_build_object('score_key','cadence_spm','question_number',2,'question_text','Cadence','question_text_korean','케이던스','answer_type','number','unit','steps/min'),
        jsonb_build_object('score_key','foot_strike_pattern','question_number',3,'question_text','Foot strike pattern','question_text_korean','착지 패턴','answer_type','select','options',jsonb_build_array('rearfoot','midfoot','forefoot','mixed','not_observed')),
        jsonb_build_object('score_key','step_width_observation','question_number',4,'question_text','Step width observation','question_text_korean','스텝 폭 관찰','answer_type','select','options',jsonb_build_array('typical','narrow','wide','crossover','not_observed')),
        jsonb_build_object('score_key','pelvic_trunk_observation','question_number',5,'question_text','Pelvic/trunk observation','question_text_korean','골반/몸통 관찰','answer_type','text'),
        jsonb_build_object('score_key','symptom_onset','question_number',6,'question_text','Symptom onset','question_text_korean','증상 발생 시점','answer_type','text'),
        jsonb_build_object('score_key','notes','question_number',7,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'lower_extremity',
      array['physiotherapist','athletic_trainer','running_coach','wellness_coach']::text[],
      null,
      null,
      null,
      false,
      'clinical_practice',
      'Structured running gait observation card'
    ),
    (
      'OVERHEAD_SQUAT_SCREEN',
      'Overhead Squat Movement Screen',
      '오버헤드 스쿼트 동작 선별',
      'movement_quality',
      'Whole-body movement screen for CrossFit, lifting, wellness, and mobility reasoning. Aliases: overhead squat, OHS, squat screen, CrossFit screen, movement screen, 오버헤드 스쿼트.',
      'Record squat depth, trunk, shoulder, knee, heel/ankle observations, symptoms, and movement notes. This is not an official FMS item template.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','squat_depth','question_number',1,'question_text','Squat depth','question_text_korean','스쿼트 깊이','answer_type','select','options',jsonb_build_array('full','partial','limited','not_tested')),
        jsonb_build_object('score_key','trunk_control','question_number',2,'question_text','Trunk control','question_text_korean','몸통 제어','answer_type','select','options',jsonb_build_array('good','mild_fault','moderate_fault','severe_fault','not_tested')),
        jsonb_build_object('score_key','shoulder_position','question_number',3,'question_text','Shoulder position','question_text_korean','어깨/상지 위치','answer_type','select','options',jsonb_build_array('maintained','limited','compensated','not_tested')),
        jsonb_build_object('score_key','knee_tracking','question_number',4,'question_text','Knee tracking','question_text_korean','무릎 추적/정렬','answer_type','select','options',jsonb_build_array('good','mild_fault','moderate_fault','severe_fault','not_tested')),
        jsonb_build_object('score_key','heel_ankle_observation','question_number',5,'question_text','Heel/ankle observation','question_text_korean','발뒤꿈치/발목 관찰','answer_type','select','options',jsonb_build_array('stable','heel_rise','pronation_bias','mobility_limited','not_observed')),
        jsonb_build_object('score_key','pain_or_limit','question_number',6,'question_text','Pain or limiting factor','question_text_korean','통증 또는 제한 요인','answer_type','text'),
        jsonb_build_object('score_key','notes','question_number',7,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'whole_body',
      array['physiotherapist','athletic_trainer','crossfit_coach','wellness_coach']::text[],
      null,
      null,
      null,
      false,
      'clinical_practice',
      'Structured movement screen; not official FMS wording'
    ),
    (
      'WELLNESS_READINESS_PROM',
      'Wellness Readiness PROM',
      '웰니스 준비도 PROM',
      'wellness',
      'Brief wellness and training-readiness PROM for Pilates, CrossFit, running, and home exercise decisions. Aliases: readiness, wellness check, soreness, sleep, stress, recovery, 컨디션, 준비도, 회복.',
      'Record sleep, soreness, stress, energy, pain, readiness, and recent load notes for session intensity decisions.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','sleep_quality','question_number',1,'question_text','Sleep quality','question_text_korean','수면 질','answer_type','number','min_value',0,'max_value',10,'unit','score'),
        jsonb_build_object('score_key','soreness','question_number',2,'question_text','Soreness','question_text_korean','근육통/피로감','answer_type','number','min_value',0,'max_value',10,'unit','score'),
        jsonb_build_object('score_key','stress','question_number',3,'question_text','Stress','question_text_korean','스트레스','answer_type','number','min_value',0,'max_value',10,'unit','score'),
        jsonb_build_object('score_key','energy','question_number',4,'question_text','Energy','question_text_korean','에너지','answer_type','number','min_value',0,'max_value',10,'unit','score'),
        jsonb_build_object('score_key','pain_score','question_number',5,'question_text','Pain score','question_text_korean','통증 점수','answer_type','number','min_value',0,'max_value',10,'unit','NPRS'),
        jsonb_build_object('score_key','readiness_score','question_number',6,'question_text','Readiness score','question_text_korean','운동/세션 준비도','answer_type','number','min_value',0,'max_value',10,'unit','score'),
        jsonb_build_object('score_key','training_load_note','question_number',7,'question_text','Recent training load note','question_text_korean','최근 운동 부하 메모','answer_type','text')
      ),
      'whole_body',
      array['physiotherapist','athletic_trainer','pilates_instructor','crossfit_coach','running_coach','wellness_coach']::text[],
      0,
      10,
      10,
      true,
      'clinical_practice',
      'Custom wellness readiness summary for session planning'
    ),
    (
      'SFMA_SUMMARY',
      'Selective Functional Movement Assessment Summary',
      'SFMA 요약',
      'movement_quality',
      'Licensed-summary card for SFMA-style movement reasoning without official item wording. Aliases: SFMA, selective functional movement assessment, movement diagnosis, movement screen, 움직임 평가.',
      'Licensed wording may be needed for official administration. MVP stores top-tier summary, painful/dysfunctional counts, priority region, referral flag, and notes only.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','top_tier_summary','question_number',1,'question_text','Top-tier summary','question_text_korean','상위 패턴 요약','answer_type','text','requires_official_item_text',true),
        jsonb_build_object('score_key','painful_pattern_count','question_number',2,'question_text','Painful pattern count','question_text_korean','통증 패턴 수','answer_type','number','unit','count'),
        jsonb_build_object('score_key','dysfunctional_pattern_count','question_number',3,'question_text','Dysfunctional pattern count','question_text_korean','기능저하 패턴 수','answer_type','number','unit','count'),
        jsonb_build_object('score_key','priority_region','question_number',4,'question_text','Priority region','question_text_korean','우선 평가 부위','answer_type','text'),
        jsonb_build_object('score_key','referral_flag','question_number',5,'question_text','Referral or safety flag','question_text_korean','의뢰/안전 플래그','answer_type','select','options',jsonb_build_array('no','yes','unclear')),
        jsonb_build_object('score_key','notes','question_number',6,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'whole_body',
      array['physiotherapist','athletic_trainer']::text[],
      null,
      null,
      null,
      false,
      'licensed_summary',
      'Official SFMA item wording not embedded; use licensed/official materials for administration'
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
  is_active,
  updated_at
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
  true,
  now()
from template_seed
on conflict (form_code) do update
set form_name = excluded.form_name,
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
    is_active = true,
    updated_at = now();
with form_concepts as (
  select
    aft.form_code,
    aft.form_name,
    aft.category
  from public.assessment_form_templates aft
  where aft.form_code in (
    'CARPAL_TUNNEL_SCREEN','HIP_IMPINGEMENT_SCREEN','SINGLE_LEG_SQUAT','LATERAL_STEP_DOWN',
    'RUNNING_GAIT_SCREEN','OVERHEAD_SQUAT_SCREEN','WELLNESS_READINESS_PROM','SFMA_SUMMARY'
  )
)
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
  'assessment_template:' || lower(fc.form_code),
  fc.form_name,
  aft.form_name_korean,
  'assessment_template',
  array['core']::text[],
  'assessment_form_templates',
  aft.id::text,
  fc.form_code,
  'http://physiokorea.com/fhir/assessment-template',
  aft.description,
  jsonb_build_object(
    'category', fc.category,
    'seed', '20260603112514_seed_p2_assessment_template_cards',
    'license_guardrail', 'official item wording not embedded'
  ),
  'active'
from form_concepts fc
join public.assessment_form_templates aft
  on aft.form_code = fc.form_code
on conflict (concept_key) do update
set display = excluded.display,
    display_ko = excluded.display_ko,
    source_record_id_text = excluded.source_record_id_text,
    source_code = excluded.source_code,
    source_code_system = excluded.source_code_system,
    definition = excluded.definition,
    properties = excluded.properties,
    status = excluded.status,
    updated_at = now();
with taxonomy_seed(code, code_display, category, default_value_type, default_unit, notes) as (
  values
    ('CARPAL_TUNNEL_screen_result', 'Carpal tunnel screen result', array['exam','special_test']::text[], 'string', null, 'Carpal tunnel clinical screen finding'),
    ('HIP_IMPINGEMENT_screen_result', 'Hip impingement screen result', array['exam','special_test']::text[], 'string', null, 'Hip impingement clinical screen finding'),
    ('SINGLE_LEG_SQUAT_quality', 'Single-leg squat movement quality', array['exam','movement_quality']::text[], 'string', null, 'Single-leg squat movement quality'),
    ('SINGLE_LEG_SQUAT_pain', 'Single-leg squat pain score', array['exam','pain','movement_quality']::text[], 'quantity', 'NPRS', 'Pain during single-leg squat'),
    ('LATERAL_STEP_DOWN_quality', 'Lateral step-down movement quality', array['exam','movement_quality']::text[], 'string', null, 'Lateral step-down movement quality'),
    ('LATERAL_STEP_DOWN_pain', 'Lateral step-down pain score', array['exam','pain','movement_quality']::text[], 'quantity', 'NPRS', 'Pain during lateral step-down'),
    ('RUNNING_GAIT_cadence_spm', 'Running gait cadence', array['exam','running','performance']::text[], 'quantity', 'steps/min', 'Running cadence'),
    ('RUNNING_GAIT_symptom_onset', 'Running gait symptom onset', array['exam','running','symptom']::text[], 'string', null, 'Symptom onset during running screen'),
    ('OVERHEAD_SQUAT_quality', 'Overhead squat movement quality', array['exam','movement_quality']::text[], 'string', null, 'Overhead squat movement quality'),
    ('WELLNESS_READINESS_score', 'Wellness readiness score', array['wellness','readiness']::text[], 'quantity', 'score', 'Readiness score for session planning'),
    ('WELLNESS_READINESS_pain', 'Wellness readiness pain score', array['wellness','pain']::text[], 'quantity', 'NPRS', 'Pain score captured in readiness PROM'),
    ('SFMA_summary', 'SFMA summary', array['exam','movement_quality']::text[], 'string', null, 'SFMA-style licensed summary without official wording')
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
  code,
  'http://physiokorea.com/fhir/observation',
  code_display,
  category,
  default_value_type,
  default_unit,
  'p2_assessment_template_cards',
  notes,
  true
from taxonomy_seed
on conflict (code, code_system) do update
set code_display = excluded.code_display,
    category = excluded.category,
    default_value_type = excluded.default_value_type,
    default_unit = excluded.default_unit,
    data_source = excluded.data_source,
    notes = excluded.notes,
    is_active = true,
    updated_at = now();
with link_seed(form_code, score_key, binding_role, observation_code, display_override, category, default_value_type, default_unit, notes) as (
  values
    ('CARPAL_TUNNEL_SCREEN','phalen_result','result','CARPAL_TUNNEL_screen_result','Phalen finding',array['exam','special_test']::text[],'string',null,'Phalen clinical finding'),
    ('CARPAL_TUNNEL_SCREEN','tinel_result','result','CARPAL_TUNNEL_screen_result','Tinel finding',array['exam','special_test']::text[],'string',null,'Tinel clinical finding'),
    ('CARPAL_TUNNEL_SCREEN','carpal_compression_result','result','CARPAL_TUNNEL_screen_result','Carpal compression finding',array['exam','special_test']::text[],'string',null,'Carpal compression clinical finding'),
    ('HIP_IMPINGEMENT_SCREEN','fadir_result','result','HIP_IMPINGEMENT_screen_result','FADIR finding',array['exam','special_test']::text[],'string',null,'FADIR clinical finding'),
    ('HIP_IMPINGEMENT_SCREEN','faber_result','result','HIP_IMPINGEMENT_screen_result','FABER finding',array['exam','special_test']::text[],'string',null,'FABER clinical finding'),
    ('HIP_IMPINGEMENT_SCREEN','scour_result','result','HIP_IMPINGEMENT_screen_result','Scour finding',array['exam','special_test']::text[],'string',null,'Scour clinical finding'),
    ('HIP_IMPINGEMENT_SCREEN','log_roll_result','result','HIP_IMPINGEMENT_screen_result','Log roll finding',array['exam','special_test']::text[],'string',null,'Log roll clinical finding'),
    ('SINGLE_LEG_SQUAT','knee_control','result','SINGLE_LEG_SQUAT_quality','Single-leg squat knee control',array['exam','movement_quality']::text[],'string',null,'Knee control during single-leg squat'),
    ('SINGLE_LEG_SQUAT','pelvic_trunk_control','result','SINGLE_LEG_SQUAT_quality','Single-leg squat pelvic/trunk control',array['exam','movement_quality']::text[],'string',null,'Pelvic/trunk control during single-leg squat'),
    ('SINGLE_LEG_SQUAT','pain_score','result','SINGLE_LEG_SQUAT_pain','Single-leg squat pain',array['exam','pain','movement_quality']::text[],'quantity','NPRS','Pain during single-leg squat'),
    ('LATERAL_STEP_DOWN','quality_rating','result','LATERAL_STEP_DOWN_quality','Lateral step-down quality',array['exam','movement_quality']::text[],'string',null,'Overall lateral step-down quality'),
    ('LATERAL_STEP_DOWN','pain_score','result','LATERAL_STEP_DOWN_pain','Lateral step-down pain',array['exam','pain','movement_quality']::text[],'quantity','NPRS','Pain during lateral step-down'),
    ('RUNNING_GAIT_SCREEN','cadence_spm','result','RUNNING_GAIT_cadence_spm','Running cadence',array['exam','running','performance']::text[],'quantity','steps/min','Running cadence'),
    ('RUNNING_GAIT_SCREEN','symptom_onset','result','RUNNING_GAIT_symptom_onset','Running symptom onset',array['exam','running','symptom']::text[],'string',null,'Symptom onset during running screen'),
    ('OVERHEAD_SQUAT_SCREEN','knee_tracking','result','OVERHEAD_SQUAT_quality','Overhead squat knee tracking',array['exam','movement_quality']::text[],'string',null,'Knee tracking during overhead squat'),
    ('OVERHEAD_SQUAT_SCREEN','trunk_control','result','OVERHEAD_SQUAT_quality','Overhead squat trunk control',array['exam','movement_quality']::text[],'string',null,'Trunk control during overhead squat'),
    ('WELLNESS_READINESS_PROM','readiness_score','aggregate','WELLNESS_READINESS_score','Wellness readiness score',array['wellness','readiness']::text[],'quantity','score','Readiness score for session planning'),
    ('WELLNESS_READINESS_PROM','pain_score','result','WELLNESS_READINESS_pain','Wellness readiness pain score',array['wellness','pain']::text[],'quantity','NPRS','Pain score captured in readiness PROM'),
    ('SFMA_SUMMARY','top_tier_summary','aggregate','SFMA_summary','SFMA top-tier summary',array['exam','movement_quality']::text[],'string',null,'SFMA-style summary without official wording'),
    ('SFMA_SUMMARY','priority_region','context','SFMA_summary','SFMA priority region',array['exam','movement_quality']::text[],'string',null,'Priority region from SFMA-style summary')
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
  ls.score_key,
  nullif(item.item ->> 'question_number', '')::integer,
  ls.binding_role,
  ot.id,
  cc.id,
  ls.observation_code,
  'http://physiokorea.com/fhir/observation',
  ls.display_override,
  ls.category,
  ls.default_value_type,
  ls.default_unit,
  ls.notes,
  jsonb_build_object(
    'seed_migration', '20260603112514_seed_p2_assessment_template_cards',
    'form_code', ls.form_code,
    'license_guardrail', 'official item wording not embedded'
  ),
  'active'
from link_seed ls
join public.assessment_form_templates aft
  on aft.form_code = ls.form_code
left join lateral (
  select item
  from jsonb_array_elements(coalesce(aft.items, '[]'::jsonb)) item
  where item ->> 'score_key' = ls.score_key
  limit 1
) item on true
left join public.observation_taxonomy ot
  on ot.code = ls.observation_code
 and ot.code_system = 'http://physiokorea.com/fhir/observation'
left join public.clinical_concepts cc
  on cc.concept_key = 'assessment_template:' || lower(aft.form_code)
on conflict (form_template_id, score_key, binding_role) do update
set question_number = excluded.question_number,
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
