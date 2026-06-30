-- Seed soccer / field-sport performance MVP wave 1.
--
-- Purpose:
-- - add the missing practical soccer test cards after existing CMJ, Y-Balance,
--   hop-test, Copenhagen, wellness, and ACWR waves
-- - keep the data on the existing assessment -> observation -> capability path
-- - store protocol/device context as structured card fields and metadata instead
--   of creating a parallel sports-science schema
--
-- Scope:
-- - 10/20 m sprint split screen
-- - 505 change-of-direction screen
-- - Yo-Yo IR1 intermittent endurance summary
--
-- Guardrails:
-- - no licensed/proprietary test manual wording is embedded
-- - no universal norm cutoffs are claimed
-- - these are coaching/rehab follow-up anchors, not stand-alone return-to-sport
--   clearance rules

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
      'SOCCER_SPRINT_10_20M',
      'Soccer Sprint Splits 10/20 m',
      '축구 스프린트 10/20m 스플릿',
      'functional_test',
      'Field sprint split card for acceleration follow-up. Aliases: 10m sprint, 20m sprint, acceleration, soccer speed.',
      'Record 10 m and 20 m sprint times with start rule, device method, surface, and fatigue/symptom context. Keep the same protocol for repeated comparisons.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','sprint_10m_seconds','question_number',1,'question_text','10 m time','question_text_korean','10m 기록','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','sprint_20m_seconds','question_number',2,'question_text','20 m time','question_text_korean','20m 기록','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','sprint_10_20m_seconds','question_number',3,'question_text','10-20 m split if known','question_text_korean','10-20m 스플릿(알면)','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','start_rule','question_number',4,'question_text','Start rule','question_text_korean','출발 규칙','answer_type','select','options',jsonb_build_array('standing_two_point','standing_split','falling_start','flying_start','other')),
        jsonb_build_object('score_key','device_method','question_number',5,'question_text','Device or method','question_text_korean','장비/측정 방식','answer_type','select','options',jsonb_build_array('timing_gate','video_app','laser_radar','manual_stopwatch','other')),
        jsonb_build_object('score_key','surface','question_number',6,'question_text','Surface','question_text_korean','표면','answer_type','select','options',jsonb_build_array('natural_grass','artificial_turf','track','indoor_court','other')),
        jsonb_build_object('score_key','pain_or_fatigue_response','question_number',7,'question_text','Pain or fatigue response','question_text_korean','통증/피로 반응','answer_type','select','options',jsonb_build_array('none','mild','moderate','severe')),
        jsonb_build_object('score_key','notes','question_number',8,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'lower_extremity',
      array['physiotherapist','athletic_trainer','wellness_coach']::text[],
      0,
      null,
      null,
      false,
      'clinical_practice',
      'Structured field-sprint split card; protocol and device context must be retained for repeated comparison'
    ),
    (
      'SOCCER_505_COD',
      '505 Change-of-Direction Screen',
      '505 방향전환 스크린',
      'functional_test',
      'Field 180-degree change-of-direction card for cutting, deceleration, and side-to-side follow-up. Aliases: 505, COD, cutting, deceleration.',
      'Record left and right 505 times, asymmetry if known, turning-foot rule, device method, surface, and symptom context. Do not compare results across changed protocols.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','left_505_seconds','question_number',1,'question_text','Left 505 time','question_text_korean','좌측 505 기록','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','right_505_seconds','question_number',2,'question_text','Right 505 time','question_text_korean','우측 505 기록','answer_type','number','unit','sec'),
        jsonb_build_object('score_key','asymmetry_percent','question_number',3,'question_text','Asymmetry if known','question_text_korean','비대칭(알면)','answer_type','number','unit','percent'),
        jsonb_build_object('score_key','turning_foot_rule','question_number',4,'question_text','Turning foot rule','question_text_korean','턴 발 규칙','answer_type','select','options',jsonb_build_array('left_turning_foot','right_turning_foot','best_each_side','not_recorded')),
        jsonb_build_object('score_key','device_method','question_number',5,'question_text','Device or method','question_text_korean','장비/측정 방식','answer_type','select','options',jsonb_build_array('timing_gate','video_app','manual_stopwatch','other')),
        jsonb_build_object('score_key','surface','question_number',6,'question_text','Surface','question_text_korean','표면','answer_type','select','options',jsonb_build_array('natural_grass','artificial_turf','track','indoor_court','other')),
        jsonb_build_object('score_key','cutting_quality','question_number',7,'question_text','Cutting quality','question_text_korean','방향전환 질','answer_type','select','options',jsonb_build_array('poor','limited','fair','good')),
        jsonb_build_object('score_key','pain_or_fatigue_response','question_number',8,'question_text','Pain or fatigue response','question_text_korean','통증/피로 반응','answer_type','select','options',jsonb_build_array('none','mild','moderate','severe')),
        jsonb_build_object('score_key','notes','question_number',9,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'lower_extremity',
      array['physiotherapist','athletic_trainer','wellness_coach']::text[],
      0,
      null,
      null,
      false,
      'clinical_practice',
      'Structured 505 COD card; interpretation requires side, protocol, surface, symptom, and movement-quality context'
    ),
    (
      'SOCCER_YYIR1',
      'Yo-Yo Intermittent Recovery Test Level 1 Summary',
      'Yo-Yo IR1 요약',
      'functional_test',
      'Intermittent endurance summary card for soccer and field-sport follow-up. Aliases: Yo-Yo IR1, YYIR1, intermittent recovery, shuttle endurance.',
      'Record total distance and protocol context such as audio version, surface, lane length, termination rule, and symptom response. Official audio/manual wording is not embedded.',
      'custom',
      jsonb_build_array(
        jsonb_build_object('score_key','total_distance_m','question_number',1,'question_text','Total distance','question_text_korean','총 거리','answer_type','number','unit','m'),
        jsonb_build_object('score_key','audio_version','question_number',2,'question_text','Audio or protocol version','question_text_korean','오디오/프로토콜 버전','answer_type','text'),
        jsonb_build_object('score_key','lane_length_m','question_number',3,'question_text','Lane length','question_text_korean','레인 길이','answer_type','number','unit','m'),
        jsonb_build_object('score_key','surface','question_number',4,'question_text','Surface','question_text_korean','표면','answer_type','select','options',jsonb_build_array('natural_grass','artificial_turf','track','indoor_court','other')),
        jsonb_build_object('score_key','termination_rule','question_number',5,'question_text','Termination rule','question_text_korean','종료 규칙','answer_type','select','options',jsonb_build_array('two_misses','voluntary_stop','symptom_stop','other')),
        jsonb_build_object('score_key','rpe_if_known','question_number',6,'question_text','RPE if known','question_text_korean','RPE(알면)','answer_type','number','unit','0-10'),
        jsonb_build_object('score_key','symptom_response','question_number',7,'question_text','Symptom response','question_text_korean','증상 반응','answer_type','select','options',jsonb_build_array('none','mild','moderate','severe')),
        jsonb_build_object('score_key','notes','question_number',8,'question_text','Notes','question_text_korean','메모','answer_type','text')
      ),
      'full_body',
      array['physiotherapist','athletic_trainer','wellness_coach']::text[],
      0,
      null,
      null,
      true,
      'clinical_practice',
      'Structured Yo-Yo IR1 summary card without official manual wording; protocol version and context are required for comparison'
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
  score_min::numeric,
  score_max::numeric,
  max_possible_score::numeric,
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
with concept_seed (
  form_code,
  display,
  display_ko,
  category,
  license_guardrail
) as (
  values
    ('SOCCER_SPRINT_10_20M', 'Soccer Sprint Splits 10/20 m', '축구 스프린트 10/20m 스플릿', 'sports_performance', 'generic field-test summary; no proprietary wording embedded'),
    ('SOCCER_505_COD', '505 Change-of-Direction Screen', '505 방향전환 스크린', 'sports_performance', 'generic field-test summary; no proprietary wording embedded'),
    ('SOCCER_YYIR1', 'Yo-Yo Intermittent Recovery Test Level 1 Summary', 'Yo-Yo IR1 요약', 'sports_performance', 'summary fields only; official audio/manual wording not embedded')
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
  'assessment_template:' || lower(cs.form_code),
  cs.display,
  cs.display_ko,
  'assessment_template',
  array['core','trainer','wellness']::text[],
  'assessment_form_templates',
  aft.id::text,
  aft.form_code,
  'http://physiokorea.com/fhir/assessment-template',
  aft.description,
  jsonb_build_object(
    'category', cs.category,
    'body_region', aft.body_region,
    'license_guardrail', cs.license_guardrail,
    'seed_wave', 'soccer_performance_mvp_wave1',
    'source_report', 'global soccer exercise and assessment database review'
  ),
  'active'
from concept_seed cs
join public.assessment_form_templates aft
  on aft.form_code = cs.form_code
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
with taxonomy_seed (
  code,
  code_display,
  category,
  default_value_type,
  default_unit,
  reference_range_text,
  interpretation_guide,
  notes,
  laterality_applicable
) as (
  values
    (
      'SOCCER_sprint_10m_seconds',
      'Soccer sprint 10 m time',
      array['exam','sports','performance','sprint']::text[],
      'quantity',
      'sec',
      'No universal norm. Compare only within a locked protocol/device/surface context and cohort-specific reference set.',
      jsonb_build_object(
        'seed_wave', 'soccer_performance_mvp_wave1',
        'direction', 'lower_is_better',
        'capability_code', 'sprint_acceleration_capacity',
        'protocol_context_required', jsonb_build_array('start_rule','device_method','surface','trial_count','rest_interval'),
        'safety_note', 'Sprint time is a performance anchor, not a stand-alone clearance rule. Pair with pain, fatigue, hamstring/calf status, and sport phase.'
      ),
      '10 m sprint split for acceleration follow-up.',
      false
    ),
    (
      'SOCCER_sprint_20m_seconds',
      'Soccer sprint 20 m time',
      array['exam','sports','performance','sprint']::text[],
      'quantity',
      'sec',
      'No universal norm. Compare only within a locked protocol/device/surface context and cohort-specific reference set.',
      jsonb_build_object(
        'seed_wave', 'soccer_performance_mvp_wave1',
        'direction', 'lower_is_better',
        'capability_code', 'sprint_acceleration_capacity',
        'protocol_context_required', jsonb_build_array('start_rule','device_method','surface','trial_count','rest_interval'),
        'safety_note', '20 m sprint time should be interpreted with 10 m split, symptoms, fatigue, and phase context.'
      ),
      '20 m sprint split for acceleration follow-up.',
      false
    ),
    (
      'SOCCER_sprint_10_20m_seconds',
      'Soccer sprint 10-20 m split time',
      array['exam','sports','performance','sprint']::text[],
      'quantity',
      'sec',
      'No universal norm. Useful only when timing setup and split method are consistent.',
      jsonb_build_object(
        'seed_wave', 'soccer_performance_mvp_wave1',
        'direction', 'lower_is_better',
        'capability_code', 'sprint_acceleration_capacity',
        'protocol_context_required', jsonb_build_array('start_rule','device_method','split_positions','surface'),
        'safety_note', 'Use as an optional sprint profile detail, not a stand-alone progression threshold.'
      ),
      'Optional 10-20 m split anchor.',
      false
    ),
    (
      'SOCCER_505_left_seconds',
      '505 left-side time',
      array['exam','sports','performance','change_of_direction']::text[],
      'quantity',
      'sec',
      'No universal norm. Compare only with the same 505 protocol, timing method, surface, and turn-foot rule.',
      jsonb_build_object(
        'seed_wave', 'soccer_performance_mvp_wave1',
        'direction', 'lower_is_better',
        'capability_code', 'cutting_deceleration_capacity',
        'protocol_context_required', jsonb_build_array('approach_distance','timing_zone','turning_foot_rule','device_method','surface'),
        'safety_note', '505 time is a COD anchor, not a stand-alone cutting or RTS clearance rule.'
      ),
      'Left-side 505 change-of-direction time.',
      true
    ),
    (
      'SOCCER_505_right_seconds',
      '505 right-side time',
      array['exam','sports','performance','change_of_direction']::text[],
      'quantity',
      'sec',
      'No universal norm. Compare only with the same 505 protocol, timing method, surface, and turn-foot rule.',
      jsonb_build_object(
        'seed_wave', 'soccer_performance_mvp_wave1',
        'direction', 'lower_is_better',
        'capability_code', 'cutting_deceleration_capacity',
        'protocol_context_required', jsonb_build_array('approach_distance','timing_zone','turning_foot_rule','device_method','surface'),
        'safety_note', '505 time is a COD anchor, not a stand-alone cutting or RTS clearance rule.'
      ),
      'Right-side 505 change-of-direction time.',
      true
    ),
    (
      'SOCCER_505_asymmetry_percent',
      '505 side-to-side asymmetry',
      array['exam','sports','performance','change_of_direction','asymmetry']::text[],
      'quantity',
      'percent',
      'No universal cutoff. Interpret with absolute times, pain, movement quality, side dominance, and sport phase.',
      jsonb_build_object(
        'seed_wave', 'soccer_performance_mvp_wave1',
        'direction', 'lower_is_better',
        'capability_code', 'cutting_deceleration_asymmetry',
        'protocol_context_required', jsonb_build_array('calculation_method','turning_foot_rule','device_method'),
        'safety_note', 'Asymmetry is contextual and should not automatically block progression without symptom and task-quality review.'
      ),
      '505 side-to-side asymmetry anchor.',
      false
    ),
    (
      'SOCCER_YYIR1_distance_m',
      'Yo-Yo IR1 total distance',
      array['exam','sports','performance','endurance']::text[],
      'quantity',
      'm',
      'No universal norm. Use cohort-specific references and keep audio/protocol version, surface, and termination rule fixed.',
      jsonb_build_object(
        'seed_wave', 'soccer_performance_mvp_wave1',
        'direction', 'higher_is_better',
        'capability_code', 'intermittent_endurance_capacity',
        'protocol_context_required', jsonb_build_array('audio_version','lane_length_m','surface','termination_rule'),
        'safety_note', 'YYIR1 distance is an intermittent endurance anchor, not a stand-alone load-progression or medical clearance rule.'
      ),
      'Yo-Yo IR1 total distance summary anchor.',
      false
    )
)
insert into public.observation_taxonomy (
  code,
  code_system,
  code_display,
  category,
  default_value_type,
  default_unit,
  reference_range_text,
  interpretation_guide,
  data_source,
  notes,
  is_active,
  laterality_applicable
)
select
  code,
  'http://physiokorea.com/fhir/observation',
  code_display,
  category,
  default_value_type,
  default_unit,
  reference_range_text,
  interpretation_guide,
  'soccer_performance_mvp_wave1',
  notes,
  true,
  laterality_applicable
from taxonomy_seed
on conflict (code, code_system) do update
set code_display = excluded.code_display,
    category = excluded.category,
    default_value_type = excluded.default_value_type,
    default_unit = excluded.default_unit,
    reference_range_text = excluded.reference_range_text,
    interpretation_guide = coalesce(public.observation_taxonomy.interpretation_guide, '{}'::jsonb) || excluded.interpretation_guide,
    data_source = excluded.data_source,
    notes = excluded.notes,
    is_active = true,
    laterality_applicable = excluded.laterality_applicable,
    updated_at = now();
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
values
  (
    'sprint_acceleration_capacity',
    'Sprint acceleration capacity',
    '스프린트 가속 능력',
    'functional',
    'lower_extremity',
    false,
    'quantity',
    'sec',
    'lower_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'capability_v2_family', 'gross_motor',
      'capability_v2_family_ko', '대동작 기능',
      'capability_v2_secondary_families', jsonb_build_array('participation','endurance'),
      'capability_v2_bridge_sources', jsonb_build_array('SOCCER_SPRINT_10_20M'),
      'source_observations', jsonb_build_array('SOCCER_sprint_10m_seconds','SOCCER_sprint_20m_seconds','SOCCER_sprint_10_20m_seconds'),
      'source_tools', jsonb_build_array('SOCCER_SPRINT_10_20M'),
      'l3_needed', jsonb_build_array('device_method','start_rule','surface','hamstring_calf_symptom_response','sport_phase','cohort_norm'),
      'review_note', 'Sprint split time is useful for acceleration follow-up but not a stand-alone high-speed running clearance rule.',
      'seed_wave', 'soccer_performance_mvp_wave1'
    ),
    'active',
    now()
  ),
  (
    'cutting_deceleration_capacity',
    'Cutting and deceleration capacity',
    '감속/방향전환 능력',
    'functional',
    'lower_extremity',
    true,
    'quantity',
    'sec',
    'lower_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'capability_v2_family', 'gross_motor',
      'capability_v2_family_ko', '대동작 기능',
      'capability_v2_secondary_families', jsonb_build_array('balance','participation'),
      'capability_v2_bridge_sources', jsonb_build_array('SOCCER_505_COD'),
      'source_observations', jsonb_build_array('SOCCER_505_left_seconds','SOCCER_505_right_seconds'),
      'source_tools', jsonb_build_array('SOCCER_505_COD'),
      'l3_needed', jsonb_build_array('turning_foot_rule','cutting_quality','pain_response','effusion','sport_phase','cohort_norm'),
      'review_note', '505 time anchors COD follow-up but does not clear cutting or return-to-sport without symptoms and movement-quality context.',
      'seed_wave', 'soccer_performance_mvp_wave1'
    ),
    'active',
    now()
  ),
  (
    'cutting_deceleration_asymmetry',
    'Cutting and deceleration asymmetry',
    '감속/방향전환 비대칭',
    'functional',
    'lower_extremity',
    false,
    'quantity',
    'percent',
    'lower_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L1',
      'capability_v2_family', 'gross_motor',
      'capability_v2_family_ko', '대동작 기능',
      'capability_v2_secondary_families', jsonb_build_array('balance','participation'),
      'capability_v2_bridge_sources', jsonb_build_array('SOCCER_505_COD'),
      'source_observations', jsonb_build_array('SOCCER_505_asymmetry_percent'),
      'source_tools', jsonb_build_array('SOCCER_505_COD'),
      'l3_needed', jsonb_build_array('calculation_method','absolute_times','side_dominance','pain_response','sport_phase'),
      'review_note', '505 asymmetry is a contextual review signal, not a direct automated progression threshold.',
      'seed_wave', 'soccer_performance_mvp_wave1'
    ),
    'active',
    now()
  ),
  (
    'intermittent_endurance_capacity',
    'Intermittent endurance capacity',
    '간헐적 지구력 능력',
    'endurance',
    'global',
    false,
    'quantity',
    'm',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'capability_v2_family', 'endurance',
      'capability_v2_family_ko', '지구력',
      'capability_v2_secondary_families', jsonb_build_array('participation','gross_motor'),
      'capability_v2_bridge_sources', jsonb_build_array('SOCCER_YYIR1'),
      'source_observations', jsonb_build_array('SOCCER_YYIR1_distance_m'),
      'source_tools', jsonb_build_array('SOCCER_YYIR1'),
      'l3_needed', jsonb_build_array('audio_version','surface','termination_rule','rpe','symptom_response','cohort_norm'),
      'review_note', 'YYIR1 total distance is useful for intermittent endurance follow-up but not a stand-alone conditioning dose rule.',
      'seed_wave', 'soccer_performance_mvp_wave1'
    ),
    'active',
    now()
  )
on conflict (capability_code) do update
set display = excluded.display,
    display_ko = excluded.display_ko,
    capability_domain = excluded.capability_domain,
    body_region = excluded.body_region,
    laterality_applicable = excluded.laterality_applicable,
    default_value_type = excluded.default_value_type,
    default_unit = excluded.default_unit,
    measurement_direction = excluded.measurement_direction,
    properties = coalesce(public.movement_capabilities.properties, '{}'::jsonb) || excluded.properties,
    status = 'active',
    updated_at = now();
with mapping_seed (
  observation_code,
  capability_code,
  default_unit,
  value_type_hint,
  completion_level,
  rationale,
  interpretation_note
) as (
  values
    ('SOCCER_sprint_10m_seconds', 'sprint_acceleration_capacity', 'sec', 'quantity', 'L2', '10 m sprint time is a practical acceleration anchor for soccer and field-sport follow-up.', 'Use only within locked start/device/surface context.'),
    ('SOCCER_sprint_20m_seconds', 'sprint_acceleration_capacity', 'sec', 'quantity', 'L2', '20 m sprint time is a practical acceleration anchor for soccer and field-sport follow-up.', 'Use with 10 m split and symptom/fatigue context.'),
    ('SOCCER_sprint_10_20m_seconds', 'sprint_acceleration_capacity', 'sec', 'quantity', 'L1', '10-20 m split adds sprint profile context when available.', 'Optional detail; avoid automated thresholds.'),
    ('SOCCER_505_left_seconds', 'cutting_deceleration_capacity', 'sec', 'quantity', 'L2', 'Left 505 time anchors left-side COD/deceleration follow-up.', 'Use with turn-foot rule, cutting quality, symptoms, and phase.'),
    ('SOCCER_505_right_seconds', 'cutting_deceleration_capacity', 'sec', 'quantity', 'L2', 'Right 505 time anchors right-side COD/deceleration follow-up.', 'Use with turn-foot rule, cutting quality, symptoms, and phase.'),
    ('SOCCER_505_asymmetry_percent', 'cutting_deceleration_asymmetry', 'percent', 'quantity', 'L1', '505 side-to-side asymmetry is a practical review signal for COD follow-up.', 'Context signal only; avoid stand-alone progression blocks.'),
    ('SOCCER_YYIR1_distance_m', 'intermittent_endurance_capacity', 'm', 'quantity', 'L2', 'YYIR1 total distance anchors intermittent endurance follow-up for soccer and field sports.', 'Use with protocol version, RPE, symptoms, and cohort reference context.')
)
insert into public.movement_capability_observation_mappings (
  observation_code,
  observation_code_system,
  capability_id,
  default_unit,
  value_type_hint,
  metadata,
  status
)
select
  ms.observation_code,
  'http://physiokorea.com/fhir/observation',
  mc.id,
  ms.default_unit,
  ms.value_type_hint,
  jsonb_build_object(
    'seed_wave', 'soccer_performance_mvp_wave1',
    'completion_level', ms.completion_level,
    'rationale', ms.rationale,
    'capability_code', ms.capability_code,
    'clinical_interpretation', ms.interpretation_note,
    'norm_policy', 'cohort_specific_norm_required_before_benchmarking'
  ),
  'active'
from mapping_seed ms
join public.movement_capabilities mc
  on mc.capability_code = ms.capability_code
 and mc.status = 'active'
on conflict (observation_code, observation_code_system, capability_id) do update
set default_unit = excluded.default_unit,
    value_type_hint = excluded.value_type_hint,
    metadata = coalesce(public.movement_capability_observation_mappings.metadata, '{}'::jsonb) || excluded.metadata,
    status = 'active',
    updated_at = now();
with link_seed (
  form_code,
  score_key,
  binding_role,
  observation_code,
  display_override,
  category,
  default_value_type,
  default_unit,
  laterality,
  notes,
  metadata
) as (
  values
    ('SOCCER_SPRINT_10_20M','sprint_10m_seconds','result','SOCCER_sprint_10m_seconds','10 m sprint time',array['exam','sports','performance','sprint']::text[],'quantity','sec',null,'10 m sprint split for acceleration follow-up.',jsonb_build_object('capability_bridge','sprint_acceleration_capacity','protocol_context_fields',jsonb_build_array('start_rule','device_method','surface'))),
    ('SOCCER_SPRINT_10_20M','sprint_20m_seconds','aggregate','SOCCER_sprint_20m_seconds','20 m sprint time',array['exam','sports','performance','sprint']::text[],'quantity','sec',null,'20 m sprint split for acceleration follow-up.',jsonb_build_object('capability_bridge','sprint_acceleration_capacity','protocol_context_fields',jsonb_build_array('start_rule','device_method','surface'))),
    ('SOCCER_SPRINT_10_20M','sprint_10_20m_seconds','result','SOCCER_sprint_10_20m_seconds','10-20 m sprint split',array['exam','sports','performance','sprint']::text[],'quantity','sec',null,'Optional 10-20 m split anchor.',jsonb_build_object('capability_bridge','sprint_acceleration_capacity','optional_metric',true)),
    ('SOCCER_505_COD','left_505_seconds','result','SOCCER_505_left_seconds','505 left-side time',array['exam','sports','performance','change_of_direction']::text[],'quantity','sec','left','Left 505 time.',jsonb_build_object('capability_bridge','cutting_deceleration_capacity','protocol_context_fields',jsonb_build_array('turning_foot_rule','device_method','surface'))),
    ('SOCCER_505_COD','right_505_seconds','result','SOCCER_505_right_seconds','505 right-side time',array['exam','sports','performance','change_of_direction']::text[],'quantity','sec','right','Right 505 time.',jsonb_build_object('capability_bridge','cutting_deceleration_capacity','protocol_context_fields',jsonb_build_array('turning_foot_rule','device_method','surface'))),
    ('SOCCER_505_COD','asymmetry_percent','aggregate','SOCCER_505_asymmetry_percent','505 side-to-side asymmetry',array['exam','sports','performance','change_of_direction','asymmetry']::text[],'quantity','percent',null,'505 side-to-side asymmetry.',jsonb_build_object('capability_bridge','cutting_deceleration_asymmetry','context_signal_only',true)),
    ('SOCCER_YYIR1','total_distance_m','aggregate','SOCCER_YYIR1_distance_m','Yo-Yo IR1 total distance',array['exam','sports','performance','endurance']::text[],'quantity','m',null,'Yo-Yo IR1 total distance summary anchor.',jsonb_build_object('capability_bridge','intermittent_endurance_capacity','protocol_context_fields',jsonb_build_array('audio_version','lane_length_m','surface','termination_rule')))
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
  laterality,
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
  ls.laterality,
  ls.notes,
  jsonb_build_object(
    'seed_migration', '20260621033128_seed_soccer_performance_mvp_wave1',
    'form_code', ls.form_code,
    'license_guardrail', 'no official protocol/manual wording embedded',
    'norm_policy', 'cohort_specific_norm_required_before_benchmarking'
  ) || ls.metadata,
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
    laterality = excluded.laterality,
    notes = excluded.notes,
    metadata = coalesce(public.assessment_template_item_semantic_links.metadata, '{}'::jsonb) || excluded.metadata,
    status = excluded.status,
    updated_at = now();
