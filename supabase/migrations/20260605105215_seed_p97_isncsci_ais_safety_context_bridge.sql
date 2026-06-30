-- Seed P97 ISNCSCI/AIS safety context bridge.
--
-- Purpose:
-- - split ISNCSCI_SUMMARY.ais_grade away from the broad JSON summary anchor
--   into a dedicated AIS-grade observation
-- - connect AIS grade to a safety/context capability so AI/RAG/reasoning can
--   ask for neurologic-level context before standing, gait, loading, or home
--   progression
-- - avoid creating SCI/AIS if/then exercise recommendations
--
-- Clinical safety note:
-- AIS grade is neurologic classification context, not an independent exercise,
-- standing, gait, transfer, skin, autonomic, driving, or community-clearance
-- rule. Neurologic level, motor/sensory level, zone of partial preservation,
-- completeness, autonomic dysreflexia risk, orthostatic tolerance, skin/pressure
-- safety, spasticity, pain, device/orthosis fit, assist level, caregiver support,
-- fatigue, and 24-hour response remain clinician-reviewed context.

with taxonomy_seed (
  code,
  code_display,
  category,
  default_value_type,
  default_unit,
  reference_range_text,
  interpretation_guide,
  notes
) as (
  values
    (
      'ISNCSCI_AIS_grade',
      'ISNCSCI AIS grade',
      array['exam', 'spinal_cord_injury', 'neurologic_classification', 'safety']::text[],
      'string',
      null::text,
      'AIS grade A-E or unknown. MVP context: A/B often signals complete or sensory-incomplete context, C/D motor-incomplete context, E normal exam context. Use only with neurologic level, motor/sensory level, ZPP, medical/autonomic/skin status, and clinician review.',
      jsonb_build_object(
        'seed_wave', 'p97_isncsci_ais_safety_context_bridge',
        'plain_status', '안전 우선 확인',
        'capability_code', 'sci_neurologic_classification_context',
        'direction', 'classification_string',
        'ordered_values', jsonb_build_array('A', 'B', 'C', 'D', 'E', 'unknown'),
        'safety_note', 'AIS grade is neurologic classification context and should not be used as a stand-alone exercise threshold.'
      ),
      'Dedicated AIS grade anchor for ISNCSCI summary. Does not embed official worksheet wording.'
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
  updated_at
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
  'p97_isncsci_ais_safety_context_bridge',
  notes,
  true,
  now()
from taxonomy_seed
on conflict (code) do update
set
  code_display = excluded.code_display,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  reference_range_text = excluded.reference_range_text,
  interpretation_guide = coalesce(public.observation_taxonomy.interpretation_guide, '{}'::jsonb) || excluded.interpretation_guide,
  data_source = excluded.data_source,
  notes = excluded.notes,
  is_active = true,
  updated_at = now();
with link_target as (
  select
    aft.id as form_template_id,
    aft.form_code,
    'ais_grade'::text as score_key,
    (
      select (item ->> 'question_number')::integer
      from jsonb_array_elements(aft.items) item
      where item ->> 'score_key' = 'ais_grade'
      limit 1
    ) as question_number,
    'result'::text as binding_role,
    ot.id as observation_taxonomy_id,
    cc.id as clinical_concept_id
  from public.assessment_form_templates aft
  join public.observation_taxonomy ot
    on ot.code = 'ISNCSCI_AIS_grade'
   and ot.code_system = 'http://physiokorea.com/fhir/observation'
  left join public.clinical_concepts cc
    on cc.concept_key = 'assessment_template:isncsci_summary'
  where aft.form_code = 'ISNCSCI_SUMMARY'
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
  status,
  updated_at
)
select
  form_template_id,
  score_key,
  question_number,
  binding_role,
  observation_taxonomy_id,
  clinical_concept_id,
  'ISNCSCI_AIS_grade',
  'http://physiokorea.com/fhir/observation',
  'ISNCSCI AIS grade',
  array['exam', 'spinal_cord_injury', 'neurologic_classification', 'safety']::text[],
  'string',
  null::text,
  'AIS grade context from ISNCSCI summary; no official worksheet wording embedded.',
  jsonb_build_object(
    'seed_wave', 'p97_isncsci_ais_safety_context_bridge',
    'form_code', form_code,
    'safety_priority_layer', true,
    'replaces_broad_json_anchor', 'ISNCSCI_summary'
  ),
  'active',
  now()
from link_target
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
  metadata = public.assessment_template_item_semantic_links.metadata || excluded.metadata,
  status = 'active',
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
values (
  'sci_neurologic_classification_context',
  'SCI neurologic classification context',
  '척수손상 신경학적 분류 맥락',
  'functional',
  'global',
  false,
  'string',
  null,
  'contextual',
  jsonb_build_object(
    'mvp_completion_level', 'L2',
    'plain_status', '안전 우선 확인',
    'capability_v2_family', 'neurologic_motor',
    'capability_v2_family_ko', '신경계 운동',
    'capability_v2_secondary_families', jsonb_build_array('transfer', 'walking', 'safety'),
    'source_observations', jsonb_build_array('ISNCSCI_AIS_grade'),
    'source_tools', jsonb_build_array('ISNCSCI_SUMMARY'),
    'source_refs', jsonb_build_array(
      'https://asia-spinalinjury.org/international-standards-neurological-classification-sci-isncsci-worksheet/',
      'https://www.sralab.org/rehabilitation-measures/international-standards-neurological-classification-spinal-cord-injury'
    ),
    'safety_rules', jsonb_build_object(
      'classification_values', jsonb_build_array('A', 'B', 'C', 'D', 'E', 'unknown'),
      'priority_hint', 'AIS grade should retrieve neurologic level, completeness, motor/sensory level, ZPP, autonomic/skin safety, assist level, and device context before standing, gait, loading, or home progression.',
      'review_note', 'AIS grade is classification context, not a numeric exercise threshold. Keep L2 until parsing and policy around AIS grade plus neurologic level are reviewed.'
    ),
    'seed_wave', 'p97_isncsci_ais_safety_context_bridge'
  ),
  'active',
  now()
)
on conflict (capability_code) do update
set
  display = excluded.display,
  display_ko = excluded.display_ko,
  capability_domain = excluded.capability_domain,
  body_region = excluded.body_region,
  laterality_applicable = excluded.laterality_applicable,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  measurement_direction = excluded.measurement_direction,
  properties = public.movement_capabilities.properties || excluded.properties,
  status = 'active',
  updated_at = now();
insert into public.movement_capability_observation_mappings (
  observation_code,
  observation_code_system,
  capability_id,
  value_type_hint,
  default_unit,
  metadata,
  status,
  updated_at
)
select
  'ISNCSCI_AIS_grade',
  'http://physiokorea.com/fhir/observation',
  mc.id,
  'string',
  null::text,
  jsonb_build_object(
    'seed_wave', 'p97_isncsci_ais_safety_context_bridge',
    'completion_level', 'L2',
    'plain_status', '안전 우선 확인',
    'capability_code', 'sci_neurologic_classification_context',
    'normalization', jsonb_build_object('canonical_unit', null, 'allowed_values', jsonb_build_array('A', 'B', 'C', 'D', 'E', 'unknown')),
    'rationale', 'AIS grade anchors SCI neurologic classification context for safety-first reasoning.'
  ),
  'active',
  now()
from public.movement_capabilities mc
where mc.capability_code = 'sci_neurologic_classification_context'
on conflict (observation_code, observation_code_system, capability_id) do update
set
  value_type_hint = excluded.value_type_hint,
  default_unit = excluded.default_unit,
  metadata = public.movement_capability_observation_mappings.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
