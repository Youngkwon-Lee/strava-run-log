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
values (
  'intake_general_v1',
  'Intake General v1',
  '일반 인테이크 v1',
  'clinical',
  '간단 초기 통증/병력 intake를 구조화해 저장하는 일반 intake form.',
  '주호소, 통증 수준, 발현 양상, 악화/완화 요인을 기록합니다.',
  'custom',
  '[
    {"score_key":"chief_complaint","question_number":1,"question_text":"Chief complaint","question_text_korean":"주호소","answer_type":"text"},
    {"score_key":"pain_level","question_number":2,"question_text":"Pain level","question_text_korean":"통증 수준","answer_type":"number","min_value":0,"max_value":10,"unit":"score"},
    {"score_key":"onset","question_number":3,"question_text":"Onset","question_text_korean":"발현 양상","answer_type":"text"},
    {"score_key":"aggravating_factors","question_number":4,"question_text":"Aggravating factors","question_text_korean":"악화 요인","answer_type":"json"},
    {"score_key":"easing_factors","question_number":5,"question_text":"Easing factors","question_text_korean":"완화 요인","answer_type":"json"}
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
where aft.form_code in ('intake_general_v1')
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
    ('PRE_SESSION_CHECKIN', 'Pre-session check-in total score', array['checkin', 'pain']::text[], 'quantity', 'score', 'Aggregate total score emitted from the pre-session check-in form'),
    ('INTAKE_GENERAL_V1_chief_complaint', 'General intake chief complaint', array['intake', 'subjective']::text[], 'string', null, 'Chief complaint narrative captured during the general intake flow'),
    ('INTAKE_GENERAL_V1_pain_level', 'General intake pain level', array['intake', 'pain']::text[], 'quantity', 'score', 'Numeric pain level captured during the general intake flow'),
    ('INTAKE_GENERAL_V1_onset', 'General intake onset', array['intake', 'history']::text[], 'string', null, 'Structured onset text captured during the general intake flow'),
    ('INTAKE_GENERAL_V1_aggravating_factors', 'General intake aggravating factors', array['intake', 'history']::text[], 'json', null, 'Aggravating factors captured during the general intake flow'),
    ('INTAKE_GENERAL_V1_easing_factors', 'General intake easing factors', array['intake', 'history']::text[], 'json', null, 'Easing factors captured during the general intake flow')
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
    ('pre_session_checkin', 'total_score', 'aggregate', 'PRE_SESSION_CHECKIN', 'Pre-session check-in total score', array['checkin', 'pain']::text[], 'quantity', 'score', 'Binds pre-session aggregate total score to a first-class observation code'),
    ('intake_general_v1', 'chief_complaint', 'result', 'INTAKE_GENERAL_V1_chief_complaint', 'Chief complaint', array['intake', 'subjective']::text[], 'string', null, 'Chief complaint narrative from the general intake flow'),
    ('intake_general_v1', 'pain_level', 'result', 'INTAKE_GENERAL_V1_pain_level', 'Pain level', array['intake', 'pain']::text[], 'quantity', 'score', 'Numeric pain level from the general intake flow'),
    ('intake_general_v1', 'onset', 'result', 'INTAKE_GENERAL_V1_onset', 'Onset', array['intake', 'history']::text[], 'string', null, 'Onset text from the general intake flow'),
    ('intake_general_v1', 'aggravating_factors', 'result', 'INTAKE_GENERAL_V1_aggravating_factors', 'Aggravating factors', array['intake', 'history']::text[], 'json', null, 'Aggravating factors from the general intake flow'),
    ('intake_general_v1', 'easing_factors', 'result', 'INTAKE_GENERAL_V1_easing_factors', 'Easing factors', array['intake', 'history']::text[], 'json', null, 'Easing factors from the general intake flow')
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
  jsonb_build_object('seed', '2026-05-18', 'form_code', ss.form_code, 'wave', 'intake_general_pre_session_semantics'),
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
select coalesce(sum(private.project_assessment_response_to_observations(afr.id)), 0)
from public.assessment_form_responses afr
where lower(afr.form_template_id) in (
  '128',
  'pre_session_checkin',
  'intake_general_v1'
);
