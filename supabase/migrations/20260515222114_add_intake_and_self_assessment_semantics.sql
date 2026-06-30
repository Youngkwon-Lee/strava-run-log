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
  is_active
)
values
  (
    'physio_intake_v1',
    'Physio Intake v1',
    '물리치료 인테이크 v1',
    'intake',
    '초기 물리치료 문진과 통증, 병력, 기능 제한을 구조화해 저장하는 intake form.',
    '환자 주호소와 병력, 통증 특성, 기능 제한, 목표를 기록합니다.',
    'custom',
    '[
      {"score_key":"body_part","question_number":1,"question_text":"Primary body region","question_text_korean":"주요 통증 부위","answer_type":"select"},
      {"score_key":"vas_score","question_number":2,"question_text":"Current pain score (VAS)","question_text_korean":"현재 통증 점수 (VAS)","answer_type":"vas","min_value":0,"max_value":10},
      {"score_key":"red_flags","question_number":3,"question_text":"Red flag checklist","question_text_korean":"레드 플래그","answer_type":"multiselect"},
      {"score_key":"history","question_number":4,"question_text":"Structured history","question_text_korean":"구조화된 병력","answer_type":"json"},
      {"score_key":"chief_complaint","question_number":5,"question_text":"Chief complaint","question_text_korean":"주호소","answer_type":"text"},
      {"score_key":"pain_intensity","question_number":6,"question_text":"Pain intensity","question_text_korean":"통증 강도","answer_type":"number","min_value":0,"max_value":10},
      {"score_key":"pain_location","question_number":7,"question_text":"Pain location detail","question_text_korean":"통증 위치 상세","answer_type":"text"},
      {"score_key":"pain_quality","question_number":8,"question_text":"Pain quality","question_text_korean":"통증 양상","answer_type":"multiselect"},
      {"score_key":"onset","question_number":9,"question_text":"Onset timing","question_text_korean":"발병 시점","answer_type":"text"},
      {"score_key":"onset_type","question_number":10,"question_text":"Onset type","question_text_korean":"발병 양상","answer_type":"text"},
      {"score_key":"duration","question_number":11,"question_text":"Duration","question_text_korean":"지속 기간","answer_type":"text"},
      {"score_key":"aggravating_factors","question_number":12,"question_text":"Aggravating factors","question_text_korean":"악화 요인","answer_type":"text"},
      {"score_key":"relieving_factors","question_number":13,"question_text":"Relieving factors","question_text_korean":"완화 요인","answer_type":"text"},
      {"score_key":"functional_limitations","question_number":14,"question_text":"Functional limitations","question_text_korean":"기능 제한","answer_type":"text"},
      {"score_key":"goals","question_number":15,"question_text":"Patient goals","question_text_korean":"환자 목표","answer_type":"text"},
      {"score_key":"past_medical_history","question_number":16,"question_text":"Past medical history","question_text_korean":"과거력","answer_type":"text"},
      {"score_key":"surgical_history","question_number":17,"question_text":"Surgical history","question_text_korean":"수술력","answer_type":"text"},
      {"score_key":"medications","question_number":18,"question_text":"Medications","question_text_korean":"복용 약물","answer_type":"text"},
      {"score_key":"allergies","question_number":19,"question_text":"Allergies","question_text_korean":"알레르기","answer_type":"text"},
      {"score_key":"family_history","question_number":20,"question_text":"Family history","question_text_korean":"가족력","answer_type":"text"},
      {"score_key":"social_history","question_number":21,"question_text":"Social history","question_text_korean":"사회력","answer_type":"text"},
      {"score_key":"additional_notes","question_number":22,"question_text":"Additional notes","question_text_korean":"추가 메모","answer_type":"text"}
    ]'::jsonb,
    'general',
    true
  ),
  (
    'self_assessment_msk',
    'Self Assessment MSK',
    '자가평가 MSK',
    'self_assessment',
    '근골격계 self-assessment 결과와 분류 경로를 저장하는 환자 자가평가 form.',
    '부위, 통증, 레드 플래그, 병력, 알고리즘 경로와 분류 결과를 기록합니다.',
    'custom',
    '[
      {"score_key":"body_part","question_number":1,"question_text":"Body part","question_text_korean":"불편 부위","answer_type":"select"},
      {"score_key":"vas_score","question_number":2,"question_text":"Pain score (VAS)","question_text_korean":"통증 점수 (VAS)","answer_type":"vas","min_value":0,"max_value":10},
      {"score_key":"red_flags","question_number":3,"question_text":"Red flags","question_text_korean":"레드 플래그","answer_type":"multiselect"},
      {"score_key":"history","question_number":4,"question_text":"History answers","question_text_korean":"문진 응답","answer_type":"json"},
      {"score_key":"algorithm_path","question_number":5,"question_text":"Decision path","question_text_korean":"의사결정 경로","answer_type":"json"},
      {"score_key":"clinical_result","question_number":6,"question_text":"Clinical triage result","question_text_korean":"임상 분류 결과","answer_type":"json"}
    ]'::jsonb,
    'general',
    true
  ),
  (
    'self_assessment_neuro',
    'Self Assessment Neuro',
    '자가평가 신경계',
    'self_assessment',
    '신경계 self-assessment 분류 결과를 저장하는 간단 자가평가 form.',
    '임상 분류 결과를 기록합니다.',
    'custom',
    '[
      {"score_key":"clinical_result","question_number":1,"question_text":"Clinical triage result","question_text_korean":"임상 분류 결과","answer_type":"json"}
    ]'::jsonb,
    'general',
    true
  ),
  (
    'self_assessment_pediatric',
    'Self Assessment Pediatric',
    '자가평가 소아',
    'self_assessment',
    '소아 self-assessment 분류 결과를 저장하는 간단 자가평가 form.',
    '임상 분류 결과를 기록합니다.',
    'custom',
    '[
      {"score_key":"clinical_result","question_number":1,"question_text":"Clinical triage result","question_text_korean":"임상 분류 결과","answer_type":"json"}
    ]'::jsonb,
    'general',
    true
  ),
  (
    'self_assessment_sports',
    'Self Assessment Sports',
    '자가평가 스포츠',
    'self_assessment',
    '종목, movement profile, follow-up context를 포함한 return-to-sport self-assessment form.',
    '종목, movement profile, 병력, follow-up summary, 임상 분류 결과를 기록합니다.',
    'custom',
    '[
      {"score_key":"body_part","question_number":1,"question_text":"Body part context","question_text_korean":"신체 부위 맥락","answer_type":"text"},
      {"score_key":"sport_name","question_number":2,"question_text":"Sport name","question_text_korean":"종목","answer_type":"text"},
      {"score_key":"sport_name_label","question_number":3,"question_text":"Sport label","question_text_korean":"종목 표시명","answer_type":"text"},
      {"score_key":"movement_profile","question_number":4,"question_text":"Movement profile","question_text_korean":"무브먼트 프로필","answer_type":"text"},
      {"score_key":"movement_profile_label","question_number":5,"question_text":"Movement profile label","question_text_korean":"무브먼트 프로필 표시명","answer_type":"text"},
      {"score_key":"movement_demands","question_number":6,"question_text":"Movement demands","question_text_korean":"무브먼트 demand","answer_type":"json"},
      {"score_key":"movement_demand_labels","question_number":7,"question_text":"Movement demand labels","question_text_korean":"무브먼트 demand 표시명","answer_type":"json"},
      {"score_key":"movement_profile_source","question_number":8,"question_text":"Movement profile source","question_text_korean":"무브먼트 프로필 출처","answer_type":"text"},
      {"score_key":"effective_movement_profile","question_number":9,"question_text":"Effective movement profile","question_text_korean":"재가중 무브먼트 프로필","answer_type":"text"},
      {"score_key":"effective_movement_profile_label","question_number":10,"question_text":"Effective movement profile label","question_text_korean":"재가중 무브먼트 프로필 표시명","answer_type":"text"},
      {"score_key":"effective_movement_demands","question_number":11,"question_text":"Effective movement demands","question_text_korean":"재가중 무브먼트 demand","answer_type":"json"},
      {"score_key":"effective_movement_demand_labels","question_number":12,"question_text":"Effective movement demand labels","question_text_korean":"재가중 무브먼트 demand 표시명","answer_type":"json"},
      {"score_key":"effective_movement_profile_source","question_number":13,"question_text":"Effective movement source","question_text_korean":"재가중 출처","answer_type":"text"},
      {"score_key":"sport_primary_profile","question_number":14,"question_text":"Sport primary profile","question_text_korean":"종목 기본 프로필","answer_type":"text"},
      {"score_key":"sport_secondary_profiles","question_number":15,"question_text":"Sport secondary profiles","question_text_korean":"종목 보조 프로필","answer_type":"json"},
      {"score_key":"sport_demand_summary","question_number":16,"question_text":"Sport demand summary","question_text_korean":"종목 demand 요약","answer_type":"text"},
      {"score_key":"sport_taxonomy_summary","question_number":17,"question_text":"Sport taxonomy summary","question_text_korean":"종목 taxonomy 요약","answer_type":"text"},
      {"score_key":"season_phase","question_number":18,"question_text":"Season phase","question_text_korean":"시즌 단계","answer_type":"text"},
      {"score_key":"season_phase_label","question_number":19,"question_text":"Season phase label","question_text_korean":"시즌 단계 표시명","answer_type":"text"},
      {"score_key":"primary_goal","question_number":20,"question_text":"Primary goal","question_text_korean":"주요 목표","answer_type":"text"},
      {"score_key":"primary_goal_label","question_number":21,"question_text":"Primary goal label","question_text_korean":"주요 목표 표시명","answer_type":"text"},
      {"score_key":"limiting_factor","question_number":22,"question_text":"Limiting factor","question_text_korean":"주요 제한 요소","answer_type":"text"},
      {"score_key":"limiting_factor_label","question_number":23,"question_text":"Limiting factor label","question_text_korean":"주요 제한 요소 표시명","answer_type":"text"},
      {"score_key":"history","question_number":24,"question_text":"Structured history","question_text_korean":"구조화된 병력","answer_type":"json"},
      {"score_key":"red_flags","question_number":25,"question_text":"Red flags","question_text_korean":"레드 플래그","answer_type":"json"},
      {"score_key":"vas_score","question_number":26,"question_text":"Pain score (VAS)","question_text_korean":"통증 점수 (VAS)","answer_type":"vas","min_value":0,"max_value":10},
      {"score_key":"algorithm_path","question_number":27,"question_text":"Decision path","question_text_korean":"의사결정 경로","answer_type":"json"},
      {"score_key":"clinical_result","question_number":28,"question_text":"Clinical triage result","question_text_korean":"임상 분류 결과","answer_type":"json"},
      {"score_key":"sport_follow_up_summary","question_number":29,"question_text":"Sport follow-up summary","question_text_korean":"스포츠 후속 요약","answer_type":"json"},
      {"score_key":"sports_result_summary","question_number":30,"question_text":"Sports result summary","question_text_korean":"스포츠 결과 요약","answer_type":"text"}
    ]'::jsonb,
    'general',
    true
  )
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
  is_active = excluded.is_active,
  updated_at = now();
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
    'is_active', aft.is_active
  )),
  case when aft.is_active then 'active' else 'deprecated' end
from public.assessment_form_templates aft
where aft.form_code in (
  'physio_intake_v1',
  'self_assessment_msk',
  'self_assessment_neuro',
  'self_assessment_pediatric',
  'self_assessment_sports'
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
    ('PRE_SESSION_CHECKIN_pain_direction', 'Pre-session pain direction', array['checkin', 'pain']::text[], 'string', null, 'Patient-reported directional pain change before a treatment session'),
    ('PHYSIO_INTAKE_V1_body_part', 'Intake body part', array['intake', 'body-site']::text[], 'string', null, 'Primary body part captured during physio intake'),
    ('PHYSIO_INTAKE_V1_history', 'Intake structured history', array['intake', 'history']::text[], 'json', null, 'Structured onset and pain history from intake'),
    ('PHYSIO_INTAKE_V1_red_flags', 'Intake red flags', array['intake', 'screening']::text[], 'json', null, 'Intake red flag checklist'),
    ('PHYSIO_INTAKE_V1_chief_complaint', 'Intake chief complaint', array['intake', 'subjective']::text[], 'string', null, 'Chief complaint narrative from intake'),
    ('PHYSIO_INTAKE_V1_pain_intensity', 'Intake pain intensity', array['intake', 'pain']::text[], 'quantity', 'score', 'Numeric pain intensity captured during intake'),
    ('PHYSIO_INTAKE_V1_pain_location', 'Intake pain location detail', array['intake', 'body-site']::text[], 'string', null, 'Detailed patient-entered pain location from intake'),
    ('SELF_ASSESSMENT_MSK_body_part', 'Self-assessment MSK body part', array['self-assessment', 'body-site']::text[], 'string', null, 'Body part selected during MSK self-assessment'),
    ('SELF_ASSESSMENT_MSK_history', 'Self-assessment MSK history', array['self-assessment', 'history']::text[], 'json', null, 'History answers collected during MSK self-assessment'),
    ('SELF_ASSESSMENT_MSK_red_flags', 'Self-assessment MSK red flags', array['self-assessment', 'screening']::text[], 'json', null, 'Red flag checklist from MSK self-assessment'),
    ('SELF_ASSESSMENT_MSK_clinical_result', 'Self-assessment MSK clinical result', array['self-assessment', 'triage']::text[], 'json', null, 'Clinical classification output from MSK self-assessment'),
    ('SELF_ASSESSMENT_NEURO_clinical_result', 'Self-assessment neuro clinical result', array['self-assessment', 'triage']::text[], 'json', null, 'Clinical classification output from neuro self-assessment'),
    ('SELF_ASSESSMENT_PEDIATRIC_clinical_result', 'Self-assessment pediatric clinical result', array['self-assessment', 'triage']::text[], 'json', null, 'Clinical classification output from pediatric self-assessment'),
    ('SELF_ASSESSMENT_SPORTS_history', 'Self-assessment sports history', array['self-assessment', 'sports', 'history']::text[], 'json', null, 'Structured sports follow-up history'),
    ('SELF_ASSESSMENT_SPORTS_clinical_result', 'Self-assessment sports clinical result', array['self-assessment', 'sports', 'triage']::text[], 'json', null, 'Clinical classification output from sports self-assessment'),
    ('SELF_ASSESSMENT_SPORTS_movement_profile', 'Self-assessment sports movement profile', array['self-assessment', 'sports']::text[], 'string', null, 'Primary sports movement profile'),
    ('SELF_ASSESSMENT_SPORTS_sport_name_label', 'Self-assessment sport label', array['self-assessment', 'sports']::text[], 'string', null, 'Sport label shown to the patient'),
    ('SELF_ASSESSMENT_SPORTS_sport_follow_up_summary', 'Self-assessment sports follow-up summary', array['self-assessment', 'sports']::text[], 'json', null, 'Generated sports follow-up summary bullets')
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
  'assessment_template_item_semantics',
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
    ('pre_session_checkin', 'nprs_score', 'result', 'NPRS', 'Numeric Pain Rating Scale', array['checkin', 'pain']::text[], 'quantity', 'score', 'Maps pre-session pain score to canonical NPRS observation'),
    ('pre_session_checkin', 'pain_direction', 'result', 'PRE_SESSION_CHECKIN_pain_direction', 'Pain direction since last session', array['checkin', 'pain']::text[], 'string', null, 'Directional pain change since the previous session'),
    ('physio_intake_v1', 'vas_score', 'result', 'VAS', 'Visual Analog Scale', array['intake', 'pain']::text[], 'quantity', 'score', 'Maps intake pain score to canonical VAS observation'),
    ('physio_intake_v1', 'body_part', 'result', 'PHYSIO_INTAKE_V1_body_part', 'Primary body region', array['intake', 'body-site']::text[], 'string', null, 'Body part selected during intake'),
    ('physio_intake_v1', 'history', 'result', 'PHYSIO_INTAKE_V1_history', 'Structured history', array['intake', 'history']::text[], 'json', null, 'Structured onset and pain history'),
    ('physio_intake_v1', 'red_flags', 'result', 'PHYSIO_INTAKE_V1_red_flags', 'Red flag checklist', array['intake', 'screening']::text[], 'json', null, 'Intake red flags'),
    ('physio_intake_v1', 'chief_complaint', 'result', 'PHYSIO_INTAKE_V1_chief_complaint', 'Chief complaint', array['intake', 'subjective']::text[], 'string', null, 'Chief complaint narrative'),
    ('physio_intake_v1', 'pain_intensity', 'result', 'PHYSIO_INTAKE_V1_pain_intensity', 'Pain intensity', array['intake', 'pain']::text[], 'quantity', 'score', 'Numeric pain intensity entered during intake'),
    ('physio_intake_v1', 'pain_location', 'result', 'PHYSIO_INTAKE_V1_pain_location', 'Pain location detail', array['intake', 'body-site']::text[], 'string', null, 'Detailed pain location entered during intake'),
    ('self_assessment_msk', 'vas_score', 'result', 'VAS', 'Visual Analog Scale', array['self-assessment', 'pain']::text[], 'quantity', 'score', 'Maps MSK self-assessment pain score to canonical VAS observation'),
    ('self_assessment_msk', 'body_part', 'result', 'SELF_ASSESSMENT_MSK_body_part', 'Body part', array['self-assessment', 'body-site']::text[], 'string', null, 'MSK self-assessment selected body part'),
    ('self_assessment_msk', 'history', 'result', 'SELF_ASSESSMENT_MSK_history', 'History answers', array['self-assessment', 'history']::text[], 'json', null, 'MSK self-assessment history answers'),
    ('self_assessment_msk', 'red_flags', 'result', 'SELF_ASSESSMENT_MSK_red_flags', 'Red flags', array['self-assessment', 'screening']::text[], 'json', null, 'MSK self-assessment red flags'),
    ('self_assessment_msk', 'clinical_result', 'result', 'SELF_ASSESSMENT_MSK_clinical_result', 'Clinical triage result', array['self-assessment', 'triage']::text[], 'json', null, 'MSK self-assessment clinical classification'),
    ('self_assessment_neuro', 'clinical_result', 'result', 'SELF_ASSESSMENT_NEURO_clinical_result', 'Clinical triage result', array['self-assessment', 'triage']::text[], 'json', null, 'Neuro self-assessment clinical classification'),
    ('self_assessment_pediatric', 'clinical_result', 'result', 'SELF_ASSESSMENT_PEDIATRIC_clinical_result', 'Clinical triage result', array['self-assessment', 'triage']::text[], 'json', null, 'Pediatric self-assessment clinical classification'),
    ('self_assessment_sports', 'history', 'result', 'SELF_ASSESSMENT_SPORTS_history', 'Structured history', array['self-assessment', 'sports', 'history']::text[], 'json', null, 'Sports self-assessment structured history'),
    ('self_assessment_sports', 'clinical_result', 'result', 'SELF_ASSESSMENT_SPORTS_clinical_result', 'Clinical triage result', array['self-assessment', 'sports', 'triage']::text[], 'json', null, 'Sports self-assessment clinical classification'),
    ('self_assessment_sports', 'movement_profile', 'result', 'SELF_ASSESSMENT_SPORTS_movement_profile', 'Movement profile', array['self-assessment', 'sports']::text[], 'string', null, 'Sports movement profile'),
    ('self_assessment_sports', 'sport_name_label', 'result', 'SELF_ASSESSMENT_SPORTS_sport_name_label', 'Sport label', array['self-assessment', 'sports']::text[], 'string', null, 'Displayed sport label'),
    ('self_assessment_sports', 'sport_follow_up_summary', 'result', 'SELF_ASSESSMENT_SPORTS_sport_follow_up_summary', 'Sport follow-up summary', array['self-assessment', 'sports']::text[], 'json', null, 'Sports follow-up summary bullets')
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
  jsonb_build_object('seed', '2026-05-16', 'form_code', ss.form_code, 'wave', 'intake_self_assessment_semantics'),
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
create or replace function private.assessment_item_semantic_binding(
  p_form_template_id text,
  p_form_code text,
  p_score_key text,
  p_binding_role text
)
returns table (
  binding_id uuid,
  binding_status text,
  observation_taxonomy_id uuid,
  clinical_concept_id uuid,
  terminology_registry_id uuid,
  observation_code text,
  observation_code_system text,
  display_override text,
  category text[],
  default_value_type text,
  default_unit text,
  body_site_code text,
  body_site_display text,
  laterality text,
  metadata jsonb
)
language sql
stable
set search_path to ''
as $function$
  select
    l.id,
    l.status,
    l.observation_taxonomy_id,
    l.clinical_concept_id,
    l.terminology_registry_id,
    l.observation_code,
    l.observation_code_system,
    l.display_override,
    l.category,
    l.default_value_type,
    l.default_unit,
    l.body_site_code::text,
    l.body_site_display::text,
    l.laterality::text,
    l.metadata
  from public.assessment_template_item_semantic_links l
  join public.assessment_form_templates aft
    on aft.id = l.form_template_id
  where l.status = 'active'
    and l.score_key = p_score_key
    and l.binding_role = p_binding_role
    and (
      aft.id::text = p_form_template_id
      or aft.form_code = p_form_template_id
      or private.assessment_normalized_form_code(aft.form_code)
         = private.assessment_normalized_form_code(coalesce(nullif(p_form_code, ''), p_form_template_id))
    )
  order by
    case when aft.id::text = p_form_template_id then 0 else 1 end,
    case when aft.form_code = p_form_template_id then 0 else 1 end,
    l.question_number nulls last,
    l.created_at
  limit 1;
$function$;
select coalesce(sum(private.project_assessment_response_to_observations(afr.id)), 0)
from public.assessment_form_responses afr
where lower(afr.form_template_id) in (
  '128',
  'pre_session_checkin',
  'physio_intake_v1',
  'self_assessment_msk',
  'self_assessment_neuro',
  'self_assessment_pediatric',
  'self_assessment_sports'
);
