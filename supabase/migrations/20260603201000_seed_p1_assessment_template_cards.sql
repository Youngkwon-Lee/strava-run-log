-- Seed P1 assessment templates for Encounter Room / Session Composer.
--
-- Copyright guardrail:
-- This migration avoids embedding official item wording for licensed or
-- potentially licensed instruments. Pediatric developmental instruments are
-- stored as summary/raw-score cards only.

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
      'ULTT',
      'Upper Limb Tension Test',
      '상지 신경긴장 검사',
      'screening',
      'Upper-limb neurodynamic screening card for cervical radicular or peripheral nerve sensitivity. Aliases: ULTT, ULNT, upper limb tension, neurodynamic, median nerve, radial nerve, ulnar nerve, 상지 신경긴장.',
      'Record side, nerve bias, positive/negative result, symptom location, sensitizer response, and comparable baseline. This template does not embed a proprietary script.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','side','question_number',1,'question_text','Test side','question_text_korean','검사 측','answer_type','select','options',jsonb_build_array('left','right','bilateral','not_tested')),
        jsonb_build_object('score_key','nerve_bias','question_number',2,'question_text','Nerve bias','question_text_korean','신경 바이어스','answer_type','select','options',jsonb_build_array('median','radial','ulnar','mixed','not_specified')),
        jsonb_build_object('score_key','result','question_number',3,'question_text','Result','question_text_korean','결과','answer_type','select','options',jsonb_build_array('negative','positive','inconclusive','not_tested')),
        jsonb_build_object('score_key','symptom_location','question_number',4,'question_text','Symptom location','question_text_korean','증상 위치','answer_type','text'),
        jsonb_build_object('score_key','sensitizer_response','question_number',5,'question_text','Sensitizer response','question_text_korean','민감화 동작 반응','answer_type','select','options',jsonb_build_array('none','cervical_sidebend','wrist_finger_position','both','other')),
        jsonb_build_object('score_key','baseline_comparable','question_number',6,'question_text','Comparable baseline','question_text_korean','추적 비교 기준','answer_type','text')
      ),
      'cervical',
      array['physiotherapist','athletic_trainer']::text[],
      null,
      null,
      null,
      false,
      'clinical_practice',
      'Structured neurodynamic clinical finding; no official wording embedded'
    ),
    (
      'SPURLING',
      'Spurling Test',
      '스펄링 검사',
      'screening',
      'Cervical radiculopathy provocation screening card. Aliases: Spurling, cervical radiculopathy, foraminal compression, neck arm pain, 목 방사통.',
      'Record side, reproduction of familiar arm symptoms, distraction response, and safety notes. This is a clinical result card, not a scripted procedure.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','left_result','question_number',1,'question_text','Left result','question_text_korean','좌측 결과','answer_type','select','options',jsonb_build_array('negative','positive','not_tested')),
        jsonb_build_object('score_key','right_result','question_number',2,'question_text','Right result','question_text_korean','우측 결과','answer_type','select','options',jsonb_build_array('negative','positive','not_tested')),
        jsonb_build_object('score_key','familiar_symptom_reproduced','question_number',3,'question_text','Familiar symptom reproduced','question_text_korean','익숙한 증상 재현','answer_type','select','options',jsonb_build_array('no','yes','unclear')),
        jsonb_build_object('score_key','distraction_response','question_number',4,'question_text','Distraction response','question_text_korean','견인 반응','answer_type','select','options',jsonb_build_array('not_tested','no_change','relief','worse')),
        jsonb_build_object('score_key','notes','question_number',5,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'cervical',
      array['physiotherapist','athletic_trainer']::text[],
      null,
      null,
      null,
      false,
      'clinical_practice',
      'Structured cervical radiculopathy clinical finding'
    ),
    (
      'CERVICAL_FRT',
      'Cervical Flexion-Rotation Test',
      '경추 굴곡-회전 검사',
      'mobility',
      'Upper cervical rotation mobility screen often used with cervicogenic headache reasoning. Aliases: FRT, flexion rotation test, cervical rotation, upper cervical, 경추 회전.',
      'Record left/right rotation in degrees, symptom response, asymmetry, and measurement context.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','left_rotation_deg','question_number',1,'question_text','Left rotation','question_text_korean','좌측 회전','answer_type','number','unit','deg'),
        jsonb_build_object('score_key','right_rotation_deg','question_number',2,'question_text','Right rotation','question_text_korean','우측 회전','answer_type','number','unit','deg'),
        jsonb_build_object('score_key','symptom_response','question_number',3,'question_text','Symptom response','question_text_korean','증상 반응','answer_type','text'),
        jsonb_build_object('score_key','asymmetry_deg','question_number',4,'question_text','Side-to-side asymmetry','question_text_korean','좌우 차이','answer_type','number','unit','deg'),
        jsonb_build_object('score_key','measurement_context','question_number',5,'question_text','Measurement context','question_text_korean','측정 조건','answer_type','text')
      ),
      'cervical',
      array['physiotherapist','athletic_trainer','wellness_coach']::text[],
      0,
      null,
      null,
      true,
      'clinical_practice',
      'Structured mobility measurement; no official wording embedded'
    ),
    (
      'Y_BALANCE',
      'Y-Balance Test',
      'Y-밸런스 검사',
      'sports_rehab',
      'Dynamic balance and reach symmetry card for lower-extremity rehab and return-to-sport. Aliases: Y Balance, YBT, Star Excursion, SEBT, dynamic balance, reach test, Y밸런스.',
      'Record reach distances, limb length if used, composite scores, asymmetry, LSI, and movement quality notes.',
      'composite',
      jsonb_build_array(
        jsonb_build_object('score_key','limb_length_cm','question_number',1,'question_text','Limb length','question_text_korean','하지 길이','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','left_anterior_cm','question_number',2,'question_text','Left anterior reach','question_text_korean','좌측 전방 도달','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','right_anterior_cm','question_number',3,'question_text','Right anterior reach','question_text_korean','우측 전방 도달','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','left_posteromedial_cm','question_number',4,'question_text','Left posteromedial reach','question_text_korean','좌측 후내측 도달','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','right_posteromedial_cm','question_number',5,'question_text','Right posteromedial reach','question_text_korean','우측 후내측 도달','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','left_posterolateral_cm','question_number',6,'question_text','Left posterolateral reach','question_text_korean','좌측 후외측 도달','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','right_posterolateral_cm','question_number',7,'question_text','Right posterolateral reach','question_text_korean','우측 후외측 도달','answer_type','number','unit','cm'),
        jsonb_build_object('score_key','left_composite_percent','question_number',8,'question_text','Left composite score','question_text_korean','좌측 종합 점수','answer_type','number','unit','percent'),
        jsonb_build_object('score_key','right_composite_percent','question_number',9,'question_text','Right composite score','question_text_korean','우측 종합 점수','answer_type','number','unit','percent'),
        jsonb_build_object('score_key','movement_quality_notes','question_number',10,'question_text','Movement quality notes','question_text_korean','동작 품질 메모','answer_type','text')
      ),
      'lower_extremity',
      array['physiotherapist','athletic_trainer','crossfit_coach','wellness_coach']::text[],
      0,
      100,
      100,
      true,
      'clinical_practice',
      'Structured dynamic balance performance card'
    ),
    (
      'CKCUEST',
      'Closed Kinetic Chain Upper Extremity Stability Test',
      '폐쇄사슬 상지 안정성 검사',
      'sports_rehab',
      'Upper-extremity closed-chain performance and shoulder stability card. Aliases: CKCUEST, closed kinetic chain, upper extremity stability, shoulder stability, 상지 안정성.',
      'Record touches, duration, normalized score if used, symptoms, and movement quality.',
      'raw_score',
      jsonb_build_array(
        jsonb_build_object('score_key','touch_count','question_number',1,'question_text','Touch count','question_text_korean','터치 횟수','answer_type','number','unit','count'),
        jsonb_build_object('score_key','duration_sec','question_number',2,'question_text','Duration','question_text_korean','측정 시간','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','normalized_score','question_number',3,'question_text','Normalized score','question_text_korean','정규화 점수','answer_type','number','unit','score'),
        jsonb_build_object('score_key','pain_during_test','question_number',4,'question_text','Pain during test','question_text_korean','검사 중 통증','answer_type','number','min_value',0,'max_value',10,'unit','score'),
        jsonb_build_object('score_key','movement_quality_notes','question_number',5,'question_text','Movement quality notes','question_text_korean','동작 품질 메모','answer_type','text')
      ),
      'shoulder',
      array['physiotherapist','athletic_trainer','crossfit_coach']::text[],
      0,
      null,
      null,
      true,
      'clinical_practice',
      'Structured upper-extremity performance card'
    ),
    (
      'FSST',
      'Four Square Step Test',
      '사각 스텝 검사',
      'balance',
      'Multidirectional stepping and fall-risk performance card. Aliases: FSST, four square step, stepping, fall risk, 사각 스텝, 낙상.',
      'Record time, attempt status, assistive device, loss of balance, and safety notes.',
      'raw_score',
      jsonb_build_array(
        jsonb_build_object('score_key','time_sec','question_number',1,'question_text','Completion time','question_text_korean','완료 시간','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','attempt_status','question_number',2,'question_text','Attempt status','question_text_korean','시도 상태','answer_type','select','options',jsonb_build_array('valid','invalid','unable','not_tested')),
        jsonb_build_object('score_key','assistive_device','question_number',3,'question_text','Assistive device','question_text_korean','보조기구','answer_type','text'),
        jsonb_build_object('score_key','loss_of_balance','question_number',4,'question_text','Loss of balance','question_text_korean','균형 상실','answer_type','select','options',jsonb_build_array('no','yes','near_loss')),
        jsonb_build_object('score_key','safety_notes','question_number',5,'question_text','Safety notes','question_text_korean','안전 메모','answer_type','text')
      ),
      'general',
      array['physiotherapist','athletic_trainer','wellness_coach']::text[],
      0,
      null,
      null,
      false,
      'clinical_practice',
      'Structured multidirectional stepping performance card'
    ),
    (
      '9HPT',
      'Nine-Hole Peg Test',
      '9홀 페그 검사',
      'neurological',
      'Hand dexterity performance card for stroke, SCI, Parkinson, MS, and hand rehab. Aliases: 9HPT, nine hole peg, peg test, hand dexterity, fine motor, 손 기능.',
      'Record left/right completion time, dominant hand, unable reason, and notes. This template stores performance summary fields only.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','left_time_sec','question_number',1,'question_text','Left hand time','question_text_korean','좌측 손 시간','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','right_time_sec','question_number',2,'question_text','Right hand time','question_text_korean','우측 손 시간','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','dominant_hand','question_number',3,'question_text','Dominant hand','question_text_korean','우세손','answer_type','select','options',jsonb_build_array('left','right','mixed','unknown')),
        jsonb_build_object('score_key','unable_reason','question_number',4,'question_text','Unable reason','question_text_korean','수행 불가 사유','answer_type','text'),
        jsonb_build_object('score_key','notes','question_number',5,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'hand',
      array['physiotherapist','athletic_trainer']::text[],
      0,
      null,
      null,
      false,
      'clinical_practice',
      'Structured dexterity performance card'
    ),
    (
      'MAS',
      'Modified Ashworth Scale Summary',
      '수정 애쉬워스 척도 요약',
      'neurological',
      'Spasticity/tone summary card for neuro rehab. Aliases: MAS, Modified Ashworth, Ashworth, spasticity, tone, 경직, 근긴장.',
      'Record muscle/body region, side, grade, velocity/context, and notes. Do not embed copyrighted training text.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','target_muscle_or_region','question_number',1,'question_text','Target muscle or region','question_text_korean','대상 근육/부위','answer_type','text'),
        jsonb_build_object('score_key','side','question_number',2,'question_text','Side','question_text_korean','측','answer_type','select','options',jsonb_build_array('left','right','bilateral','midline','not_applicable')),
        jsonb_build_object('score_key','mas_grade','question_number',3,'question_text','MAS grade','question_text_korean','MAS 등급','answer_type','select','options',jsonb_build_array('0','1','1+','2','3','4','not_tested')),
        jsonb_build_object('score_key','test_context','question_number',4,'question_text','Test context','question_text_korean','검사 조건','answer_type','text'),
        jsonb_build_object('score_key','notes','question_number',5,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'general',
      array['physiotherapist']::text[],
      0,
      4,
      4,
      false,
      'clinical_practice',
      'Summary tone rating card; no training text embedded'
    ),
    (
      'HINE_SUMMARY',
      'Hammersmith Infant Neurological Examination Summary',
      'HINE 영아 신경학적 검사 요약',
      'pediatric',
      'Infant neurological examination summary card. Aliases: HINE, Hammersmith infant, infant neuro, baby neuro, 영아 신경, 발달 지연.',
      'Licensed wording may be needed for official administration. MVP stores age, section summary scores, global score, asymmetry, and notes only.',
      'sum',
      jsonb_build_array(
        jsonb_build_object('score_key','age_months','question_number',1,'question_text','Age in months','question_text_korean','월령','answer_type','number','unit','months'),
        jsonb_build_object('score_key','cranial_nerve_subscore','question_number',2,'question_text','Cranial nerve subscore','question_text_korean','뇌신경 소계','answer_type','number','unit','score','requires_official_item_text',true),
        jsonb_build_object('score_key','posture_subscore','question_number',3,'question_text','Posture subscore','question_text_korean','자세 소계','answer_type','number','unit','score','requires_official_item_text',true),
        jsonb_build_object('score_key','movements_subscore','question_number',4,'question_text','Movements subscore','question_text_korean','움직임 소계','answer_type','number','unit','score','requires_official_item_text',true),
        jsonb_build_object('score_key','hine_global_score','question_number',5,'question_text','HINE global score','question_text_korean','HINE 총점','answer_type','number','min_value',0,'max_value',78,'unit','score'),
        jsonb_build_object('score_key','asymmetry_notes','question_number',6,'question_text','Asymmetry notes','question_text_korean','비대칭 메모','answer_type','text')
      ),
      'pediatric',
      array['physiotherapist']::text[],
      0,
      78,
      78,
      true,
      'licensed_summary',
      'Official item wording not embedded; use licensed/official materials for administration'
    ),
    (
      'AIMS_SUMMARY',
      'Alberta Infant Motor Scale Summary',
      'AIMS 영아 운동발달 척도 요약',
      'pediatric',
      'Infant motor development summary card. Aliases: AIMS, Alberta Infant Motor Scale, infant motor, baby motor, 영아 운동, 발달 지연.',
      'Licensed wording may be needed for official administration. MVP stores position/domain summary scores, total raw score, percentile, age, and notes only.',
      'sum',
      jsonb_build_array(
        jsonb_build_object('score_key','age_months','question_number',1,'question_text','Age in months','question_text_korean','월령','answer_type','number','unit','months'),
        jsonb_build_object('score_key','prone_summary_score','question_number',2,'question_text','Prone summary score','question_text_korean','엎드린 자세 요약 점수','answer_type','number','unit','score','requires_official_item_text',true),
        jsonb_build_object('score_key','supine_summary_score','question_number',3,'question_text','Supine summary score','question_text_korean','바로누운 자세 요약 점수','answer_type','number','unit','score','requires_official_item_text',true),
        jsonb_build_object('score_key','sitting_summary_score','question_number',4,'question_text','Sitting summary score','question_text_korean','앉기 요약 점수','answer_type','number','unit','score','requires_official_item_text',true),
        jsonb_build_object('score_key','standing_summary_score','question_number',5,'question_text','Standing summary score','question_text_korean','서기 요약 점수','answer_type','number','unit','score','requires_official_item_text',true),
        jsonb_build_object('score_key','aims_total_raw_score','question_number',6,'question_text','AIMS total raw score','question_text_korean','AIMS 원점수 총점','answer_type','number','min_value',0,'max_value',58,'unit','score'),
        jsonb_build_object('score_key','aims_percentile','question_number',7,'question_text','AIMS percentile','question_text_korean','AIMS 백분위','answer_type','number','min_value',0,'max_value',100,'unit','percent')
      ),
      'pediatric',
      array['physiotherapist']::text[],
      0,
      58,
      58,
      true,
      'licensed_summary',
      'Official item wording not embedded; use licensed/official materials for administration'
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
    'ULTT','SPURLING','CERVICAL_FRT','Y_BALANCE','CKCUEST',
    'FSST','9HPT','MAS','HINE_SUMMARY','AIMS_SUMMARY'
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
    'seed', '20260603201000_seed_p1_assessment_template_cards',
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
    ('ULTT_result', 'Upper limb tension test result', array['exam','special_test']::text[], 'string', null, 'Upper limb neurodynamic test result'),
    ('SPURLING_result', 'Spurling test result', array['exam','special_test']::text[], 'string', null, 'Cervical radiculopathy provocation result'),
    ('CERVICAL_FRT_rotation_deg', 'Cervical flexion-rotation range', array['exam','rom']::text[], 'quantity', 'deg', 'Cervical flexion-rotation test range'),
    ('Y_BALANCE_reach_cm', 'Y-Balance reach distance', array['exam','performance']::text[], 'quantity', 'cm', 'Y-Balance reach distance'),
    ('Y_BALANCE_composite_percent', 'Y-Balance composite score', array['exam','performance']::text[], 'quantity', 'percent', 'Y-Balance composite score'),
    ('CKCUEST_touch_count', 'CKCUEST touch count', array['exam','performance']::text[], 'integer', 'count', 'Closed-chain upper-extremity stability touch count'),
    ('FSST_seconds', 'Four Square Step Test time', array['exam','balance']::text[], 'quantity', 'sec', 'Four Square Step Test completion time'),
    ('9HPT_seconds', 'Nine-Hole Peg Test time', array['exam','dexterity']::text[], 'quantity', 'sec', 'Nine-Hole Peg Test completion time'),
    ('MAS_grade', 'Modified Ashworth Scale grade', array['exam','tone']::text[], 'string', 'score', 'Modified Ashworth Scale grade summary'),
    ('HINE_global_score', 'HINE global score', array['pediatric','neurological']::text[], 'quantity', 'score', 'HINE global summary score'),
    ('AIMS_total_raw_score', 'AIMS total raw score', array['pediatric','motor']::text[], 'quantity', 'score', 'AIMS total raw score'),
    ('AIMS_percentile', 'AIMS percentile', array['pediatric','motor']::text[], 'quantity', 'percent', 'AIMS percentile')
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
  'p1_assessment_template_cards',
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
    ('ULTT','result','result','ULTT_result','ULTT result',array['exam','special_test']::text[],'string',null,'Upper limb tension test result'),
    ('SPURLING','left_result','result','SPURLING_result','Spurling left result',array['exam','special_test']::text[],'string',null,'Spurling left result'),
    ('SPURLING','right_result','result','SPURLING_result','Spurling right result',array['exam','special_test']::text[],'string',null,'Spurling right result'),
    ('CERVICAL_FRT','left_rotation_deg','result','CERVICAL_FRT_rotation_deg','Cervical FRT left rotation',array['exam','rom']::text[],'quantity','deg','Left cervical flexion-rotation range'),
    ('CERVICAL_FRT','right_rotation_deg','result','CERVICAL_FRT_rotation_deg','Cervical FRT right rotation',array['exam','rom']::text[],'quantity','deg','Right cervical flexion-rotation range'),
    ('Y_BALANCE','left_anterior_cm','result','Y_BALANCE_reach_cm','Y-Balance left anterior reach',array['exam','performance']::text[],'quantity','cm','Y-Balance left anterior reach'),
    ('Y_BALANCE','right_anterior_cm','result','Y_BALANCE_reach_cm','Y-Balance right anterior reach',array['exam','performance']::text[],'quantity','cm','Y-Balance right anterior reach'),
    ('Y_BALANCE','left_composite_percent','aggregate','Y_BALANCE_composite_percent','Y-Balance left composite',array['exam','performance']::text[],'quantity','percent','Y-Balance left composite score'),
    ('Y_BALANCE','right_composite_percent','aggregate','Y_BALANCE_composite_percent','Y-Balance right composite',array['exam','performance']::text[],'quantity','percent','Y-Balance right composite score'),
    ('CKCUEST','touch_count','result','CKCUEST_touch_count','CKCUEST touch count',array['exam','performance']::text[],'integer','count','CKCUEST touch count'),
    ('FSST','time_sec','result','FSST_seconds','FSST completion time',array['exam','balance']::text[],'quantity','sec','Four Square Step Test completion time'),
    ('9HPT','left_time_sec','result','9HPT_seconds','9HPT left time',array['exam','dexterity']::text[],'quantity','sec','Nine-Hole Peg Test left hand time'),
    ('9HPT','right_time_sec','result','9HPT_seconds','9HPT right time',array['exam','dexterity']::text[],'quantity','sec','Nine-Hole Peg Test right hand time'),
    ('MAS','mas_grade','result','MAS_grade','MAS grade',array['exam','tone']::text[],'string','score','Modified Ashworth Scale grade'),
    ('HINE_SUMMARY','hine_global_score','aggregate','HINE_global_score','HINE global score',array['pediatric','neurological']::text[],'quantity','score','HINE global summary score'),
    ('AIMS_SUMMARY','aims_total_raw_score','aggregate','AIMS_total_raw_score','AIMS total raw score',array['pediatric','motor']::text[],'quantity','score','AIMS total raw score'),
    ('AIMS_SUMMARY','aims_percentile','aggregate','AIMS_percentile','AIMS percentile',array['pediatric','motor']::text[],'quantity','percent','AIMS percentile')
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
    'seed_migration', '20260603201000_seed_p1_assessment_template_cards',
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
