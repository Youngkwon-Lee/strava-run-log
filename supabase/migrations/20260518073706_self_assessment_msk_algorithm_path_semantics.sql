with taxonomy_seed (
  code,
  code_display,
  category,
  default_value_type,
  default_unit,
  notes
) as (
  values
    (
      'SELF_ASSESSMENT_MSK_algorithm_path',
      'Self-assessment MSK algorithm path',
      array['self-assessment', 'triage', 'reasoning-trace']::text[],
      'json',
      null,
      'Decision path trace captured during MSK self-assessment. Stored as an observation for provenance until a richer context-event projector replaces it.'
    )
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
    (
      'self_assessment_msk',
      'algorithm_path',
      'result',
      'SELF_ASSESSMENT_MSK_algorithm_path',
      'Decision path',
      array['self-assessment', 'triage', 'reasoning-trace']::text[],
      'json',
      null,
      'Structured decision path from MSK self-assessment. Kept as a JSON observation to preserve triage reasoning provenance.'
    )
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
  jsonb_build_object('seed', '2026-05-18', 'form_code', ss.form_code, 'wave', 'self_assessment_msk_algorithm_path'),
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
where lower(afr.form_template_id) = 'self_assessment_msk';
