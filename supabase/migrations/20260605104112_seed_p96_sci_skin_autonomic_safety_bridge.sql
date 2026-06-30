-- Seed P96 SCI skin/autonomic safety bridge.
--
-- Purpose:
-- - connect SCI-relevant orthostatic/autonomic and skin/pressure screens to
--   capability evidence and the existing exercise precaution layer
-- - make unsafe priority visible to AI/RAG/reasoning without creating an SCI
--   if/then recommendation engine
-- - keep skin/pressure string screens as safety-status evidence, not numeric
--   exercise clearance rules
--
-- Clinical safety note:
-- These are MVP safety-screen defaults. They are not diagnostic criteria,
-- emergency protocols, autonomic dysreflexia treatment instructions, wound-care
-- clearance, or independent exercise clearance. Sudden severe headache,
-- flushing/sweating, elevated blood pressure, bladder/bowel trigger, catheter
-- problem, new pressure injury, orthostatic syncope/near-syncope, chest pain,
-- acute neurologic change, medical instability, device fit, assist level,
-- caregiver support, and 24-hour response remain clinician-reviewed context.

with taxonomy_seed (
  code,
  code_display,
  category,
  default_value_type,
  default_unit,
  reference_range_low,
  reference_range_high,
  reference_range_text,
  interpretation_guide,
  notes
) as (
  values
    (
      'ORTHOSTATIC_systolic_drop',
      'Orthostatic systolic pressure drop',
      array['exam', 'screening', 'vitals', 'autonomic', 'safety']::text[],
      'quantity',
      'mmHg',
      0::numeric,
      null::numeric,
      'Orthostatic systolic pressure drop. MVP safety screen: <20 mmHg ready, 20-39 mmHg caution/relative contraindication review, >=40 mmHg stop/support-first medical review context.',
      jsonb_build_object(
        'seed_wave', 'p96_sci_skin_autonomic_safety_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'orthostatic_tolerance_safety',
        'direction', 'lower_is_better',
        'decision_bands', jsonb_build_array('ready: <20 mmHg', 'caution: 20-39 mmHg', 'stop/support-first: >=40 mmHg'),
        'safety_note', 'Orthostatic drop is a safety screen, not a stand-alone diagnosis or exercise clearance rule.'
      ),
      'Orthostatic systolic drop anchor for autonomic/vitals safety gating.'
    ),
    (
      'COMPASS31_symptom_burden_score',
      'COMPASS-31 autonomic symptom burden score',
      array['exam', 'autonomic', 'symptom', 'safety']::text[],
      'quantity',
      'score',
      0::numeric,
      100::numeric,
      'COMPASS-31 total weighted score. MVP safety screen: <=20 ready, 21-39 caution, >=40 autonomic burden review before higher-intensity standing/gait/conditioning.',
      jsonb_build_object(
        'seed_wave', 'p96_sci_skin_autonomic_safety_bridge',
        'plain_status', '처방 판단 가능',
        'capability_code', 'autonomic_symptom_burden_tolerance',
        'direction', 'lower_is_better',
        'decision_bands', jsonb_build_array('ready: <=20/100', 'caution: 21-39/100', 'review before progression: >=40/100'),
        'safety_note', 'COMPASS-31 is autonomic symptom burden evidence, not a stand-alone autonomic diagnosis or clearance rule.'
      ),
      'COMPASS-31 total score anchor for autonomic symptom burden safety gating.'
    ),
    (
      'SCI_skin_pressure_risk_level',
      'SCI skin and pressure risk level',
      array['exam', 'spinal_cord_injury', 'skin', 'pressure', 'safety']::text[],
      'string',
      null,
      null::numeric,
      null::numeric,
      'SCI skin/pressure risk level. MVP ordered values: none, low, moderate, high. High/moderate should trigger pressure-relief, cushion/device, and medical/wound review before loading or prolonged sitting/standing progression.',
      jsonb_build_object(
        'seed_wave', 'p96_sci_skin_autonomic_safety_bridge',
        'plain_status', '안전 우선 확인',
        'capability_code', 'sci_skin_pressure_safety_status',
        'direction', 'ordered_risk_string',
        'ordered_values', jsonb_build_array('none', 'low', 'moderate', 'high'),
        'blocked_or_review_values', jsonb_build_array('moderate', 'high'),
        'safety_note', 'String safety status is evidence for priority/safety review; it is not a numeric exercise threshold.'
      ),
      'SCI skin/pressure risk anchor for priority safety review.'
    ),
    (
      'SCI_pressure_relief_carryover_quality',
      'SCI pressure-relief carryover quality',
      array['exam', 'spinal_cord_injury', 'skin', 'pressure', 'self_management']::text[],
      'string',
      null,
      null::numeric,
      null::numeric,
      'SCI pressure-relief carryover quality. MVP ordered values: poor, limited, acceptable, good. Poor/limited should trigger pressure-relief education and setup review before prolonged sitting, standing, gait, cycling, or loading progression.',
      jsonb_build_object(
        'seed_wave', 'p96_sci_skin_autonomic_safety_bridge',
        'plain_status', '안전 우선 확인',
        'capability_code', 'sci_skin_pressure_safety_status',
        'direction', 'ordered_quality_string',
        'ordered_values', jsonb_build_array('poor', 'limited', 'acceptable', 'good'),
        'blocked_or_review_values', jsonb_build_array('poor', 'limited'),
        'safety_note', 'String carryover status is evidence for priority/safety review; it is not a numeric exercise threshold.'
      ),
      'SCI pressure-relief carryover anchor for priority safety review.'
    )
),
taxonomy_upsert as (
  insert into public.observation_taxonomy (
    code,
    code_system,
    code_display,
    category,
    default_value_type,
    default_unit,
    reference_range_low,
    reference_range_high,
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
    reference_range_low,
    reference_range_high,
    reference_range_text,
    interpretation_guide,
    'p96_sci_skin_autonomic_safety_bridge',
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
    reference_range_low = excluded.reference_range_low,
    reference_range_high = excluded.reference_range_high,
    reference_range_text = excluded.reference_range_text,
    interpretation_guide = coalesce(public.observation_taxonomy.interpretation_guide, '{}'::jsonb) || excluded.interpretation_guide,
    data_source = excluded.data_source,
    notes = excluded.notes,
    is_active = true,
    updated_at = now()
  returning id, code
),
link_seed (
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
    ('WHEELCHAIR_SEATING_SKIN_SCREEN', 'redness_skin_risk', 'risk', 'SCI_skin_pressure_risk_level', 'SCI skin and pressure risk level', array['exam', 'spinal_cord_injury', 'skin', 'pressure', 'safety']::text[], 'string', null, 'Redness or skin-risk level for SCI pressure safety.'),
    ('WHEELCHAIR_TRANSFER_PRESSURE_RELIEF_SCREEN', 'pressure_relief_carryover', 'readiness', 'SCI_pressure_relief_carryover_quality', 'SCI pressure-relief carryover quality', array['exam', 'spinal_cord_injury', 'skin', 'pressure', 'self_management']::text[], 'string', null, 'Pressure-relief carryover quality for SCI pressure safety.')
),
link_targets as (
  select
    t.id as form_template_id,
    t.form_code,
    ls.score_key,
    (
      select (item ->> 'question_number')::integer
      from jsonb_array_elements(t.items) item
      where item ->> 'score_key' = ls.score_key
      limit 1
    ) as question_number,
    ls.binding_role,
    ot.id as observation_taxonomy_id,
    cc.id as clinical_concept_id,
    ls.observation_code,
    'http://physiokorea.com/fhir/observation'::text as observation_code_system,
    ls.display_override,
    ls.category,
    ls.default_value_type,
    ls.default_unit,
    ls.notes
  from link_seed ls
  join public.assessment_form_templates t
    on t.form_code = ls.form_code
  join public.observation_taxonomy ot
    on ot.code = ls.observation_code
   and ot.code_system = 'http://physiokorea.com/fhir/observation'
  left join public.clinical_concepts cc
    on cc.concept_key = 'assessment_template:' || lower(ls.form_code)
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
  observation_code,
  observation_code_system,
  display_override,
  category,
  default_value_type,
  default_unit,
  notes,
  jsonb_build_object(
    'seed_wave', 'p96_sci_skin_autonomic_safety_bridge',
    'form_code', form_code,
    'safety_priority_layer', true
  ),
  'active',
  now()
from link_targets
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
with capability_seed as (
  select * from (values
    (
      'orthostatic_tolerance_safety',
      'Orthostatic tolerance safety',
      '기립성 안전 허용도',
      'endurance',
      'global',
      false,
      'quantity',
      'mmHg',
      'lower_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'endurance',
        'capability_v2_family_ko', '지구력',
        'capability_v2_secondary_families', jsonb_build_array('transfer', 'walking', 'safety'),
        'source_observations', jsonb_build_array('ORTHOSTATIC_systolic_drop'),
        'source_tools', jsonb_build_array('ORTHOSTATIC_VITALS_SCREEN'),
        'source_refs', jsonb_build_array(
          'https://www.ncbi.nlm.nih.gov/books/NBK448192/',
          'https://professional.heart.org/en/science-news/orthostatic-hypotension-in-adults-with-hypertension'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_orthostatic_safety_screen_not_clearance',
          'direction', 'lower_is_better',
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 진행 가능', 'operator', '<', 'value', 20, 'unit', 'mmHg'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/상대 금기 확인', 'operator', '>=', 'value', 20, 'and_operator', '<', 'and_value', 40, 'unit', 'mmHg'),
            jsonb_build_object('label', 'stop_review', 'plain_ko', '중지/의학적 확인 우선', 'operator', '>=', 'value', 40, 'unit', 'mmHg')
          ),
          'default_regression', 'Use seated/supine alternatives, slower transitions, shorter bouts, vitals monitoring, hydration/compression context, and medical review before standing, gait, or conditioning progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If dizziness, near syncope, chest symptoms, neurologic change, autonomic dysreflexia concern, or poor recovery appears, stop and reassess vitals/medical context.',
          'review_note', 'Orthostatic systolic drop gates safety priority; pair with symptoms, medications, hydration, SCI autonomic status, and clinician judgment.'
        ),
        'seed_wave', 'p96_sci_skin_autonomic_safety_bridge'
      )
    ),
    (
      'autonomic_symptom_burden_tolerance',
      'Autonomic symptom burden tolerance',
      '자율신경 증상 부담 허용도',
      'endurance',
      'global',
      false,
      'quantity',
      'score',
      'lower_is_better',
      jsonb_build_object(
        'mvp_completion_level', 'L3',
        'plain_status', '처방 판단 가능',
        'capability_v2_family', 'endurance',
        'capability_v2_family_ko', '지구력',
        'capability_v2_secondary_families', jsonb_build_array('participation', 'walking', 'safety'),
        'source_observations', jsonb_build_array('COMPASS31_symptom_burden_score'),
        'source_tools', jsonb_build_array('COMPASS31_SUMMARY'),
        'source_refs', jsonb_build_array(
          'https://pmc.ncbi.nlm.nih.gov/articles/PMC3541923/',
          'https://pmc.ncbi.nlm.nih.gov/articles/PMC4464987/'
        ),
        'l3_rules', jsonb_build_object(
          'basis', 'mvp_autonomic_symptom_burden_screen_not_diagnosis',
          'direction', 'lower_is_better',
          'decision_bands', jsonb_build_array(
            jsonb_build_object('label', 'ready', 'plain_ko', '기본 진행 가능', 'operator', '<=', 'value', 20, 'unit', 'score'),
            jsonb_build_object('label', 'caution', 'plain_ko', '주의/증상 모니터링', 'operator', '>', 'value', 20, 'and_operator', '<', 'and_value', 40, 'unit', 'score'),
            jsonb_build_object('label', 'review', 'plain_ko', '안전 확인 우선', 'operator', '>=', 'value', 40, 'unit', 'score')
          ),
          'default_regression', 'Use lower-intensity, shorter-duration, seated/supported, symptom-limited alternatives and check orthostatic/bladder/bowel/skin triggers before standing, gait, or conditioning progression.',
          'laterality_required', false,
          'symptom_response_rule', 'If orthostatic symptoms, flushing/sweating, headache, bladder/bowel trigger concern, temperature intolerance, or next-day autonomic flare worsens, stop or regress and reassess medical context.',
          'review_note', 'COMPASS-31 total score is autonomic symptom burden evidence; pair with vitals, SCI autonomic dysreflexia screen, bladder/bowel triggers, skin status, medications, and clinician judgment.'
        ),
        'seed_wave', 'p96_sci_skin_autonomic_safety_bridge'
      )
    ),
    (
      'sci_skin_pressure_safety_status',
      'SCI skin and pressure safety status',
      '척수손상 피부/압력 안전 상태',
      'functional',
      'global',
      false,
      'string',
      null,
      'contextual',
      jsonb_build_object(
        'mvp_completion_level', 'L2',
        'plain_status', '안전 우선 확인',
        'capability_v2_family', 'participation',
        'capability_v2_family_ko', '참여',
        'capability_v2_secondary_families', jsonb_build_array('transfer', 'wheelchair', 'safety'),
        'source_observations', jsonb_build_array('SCI_skin_pressure_risk_level', 'SCI_pressure_relief_carryover_quality'),
        'source_tools', jsonb_build_array('WHEELCHAIR_SEATING_SKIN_SCREEN', 'WHEELCHAIR_TRANSFER_PRESSURE_RELIEF_SCREEN'),
        'source_refs', jsonb_build_array(
          'https://www.merckmanuals.com/professional/neurologic-disorders/spinal-cord-disorders/spinal-cord-autonomic-dysreflexia',
          'https://www.ncbi.nlm.nih.gov/books/NBK448192/'
        ),
        'safety_rules', jsonb_build_object(
          'risk_values_needing_review', jsonb_build_array('high', 'moderate', 'poor', 'limited'),
          'priority_hint', 'Pressure/skin risk and poor pressure-relief carryover should down-rank loading, prolonged sitting/standing, gait, cycling, and unsupervised progression until cushion/device/skin plan is checked.',
          'review_note', 'String safety status is not numeric L3 execution yet; it is priority-layer evidence for RAG/QA and clinician review.'
        ),
        'seed_wave', 'p96_sci_skin_autonomic_safety_bridge'
      )
    )
  ) as seed(
    capability_code,
    display,
    display_ko,
    capability_domain,
    body_region,
    laterality_applicable,
    default_value_type,
    default_unit,
    measurement_direction,
    properties
  )
)
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
select
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
  'active',
  now()
from capability_seed
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
with mapping_seed as (
  select * from (values
    ('ORTHOSTATIC_systolic_drop', 'orthostatic_tolerance_safety', 'quantity', 'mmHg', 'L3', 'Orthostatic systolic drop anchors vitals/autonomic safety gating.'),
    ('COMPASS31_symptom_burden_score', 'autonomic_symptom_burden_tolerance', 'quantity', 'score', 'L3', 'COMPASS-31 total anchors autonomic symptom burden safety gating.'),
    ('SCI_skin_pressure_risk_level', 'sci_skin_pressure_safety_status', 'string', null::text, 'L2', 'SCI skin risk level anchors pressure/skin priority review.'),
    ('SCI_pressure_relief_carryover_quality', 'sci_skin_pressure_safety_status', 'string', null::text, 'L2', 'SCI pressure-relief carryover anchors pressure/skin priority review.')
  ) as seed(observation_code, capability_code, value_type_hint, default_unit, completion_level, rationale)
)
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
  mapping_seed.observation_code,
  'http://physiokorea.com/fhir/observation',
  mc.id,
  mapping_seed.value_type_hint,
  mapping_seed.default_unit,
  jsonb_build_object(
    'seed_wave', 'p96_sci_skin_autonomic_safety_bridge',
    'completion_level', mapping_seed.completion_level,
    'plain_status', case when mapping_seed.completion_level = 'L3' then '처방 판단 가능' else '안전 우선 확인' end,
    'capability_code', mapping_seed.capability_code,
    'normalization', jsonb_build_object('canonical_unit', mapping_seed.default_unit, 'laterality_required', false),
    'rationale', mapping_seed.rationale
  ),
  'active',
  now()
from mapping_seed
join public.movement_capabilities mc
  on mc.capability_code = mapping_seed.capability_code
on conflict (observation_code, observation_code_system, capability_id) do update
set
  value_type_hint = excluded.value_type_hint,
  default_unit = excluded.default_unit,
  metadata = public.movement_capability_observation_mappings.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
with precaution_seed as (
  select * from (values
    (
      'EX_FBDY_FNC_001',
      'relative_contraindication',
      'sci_orthostatic_autonomic_safety',
      'orthostatic_tolerance_safety',
      20::numeric,
      null::numeric,
      null::boolean,
      'mmHg',
      'high',
      'If systolic orthostatic drop is >=20 mmHg, down-rank sit-to-stand volume and check vitals, symptoms, hydration/compression, medication, and medical context before progression.',
      'Orthostatic hypotension criteria use a systolic drop of at least 20 mmHg within 3 minutes of standing; standing exercise should be gated by symptom and vitals safety.',
      'Orthostatic hypotension safety screen',
      'NCBI Bookshelf StatPearls Orthostatic Hypotension',
      'https://www.ncbi.nlm.nih.gov/books/NBK448192/',
      'clinical_reference'
    ),
    (
      'EX_FBDY_BAL_008',
      'relative_contraindication',
      'sci_orthostatic_autonomic_safety',
      'orthostatic_tolerance_safety',
      20::numeric,
      null::numeric,
      null::boolean,
      'mmHg',
      'high',
      'If systolic orthostatic drop is >=20 mmHg, defer higher-challenge dynamic balance until vitals and symptoms are stable.',
      'Dynamic balance can amplify fall risk when orthostatic symptoms or blood-pressure drops are present.',
      'Orthostatic hypotension safety screen',
      'NCBI Bookshelf StatPearls Orthostatic Hypotension',
      'https://www.ncbi.nlm.nih.gov/books/NBK448192/',
      'clinical_reference'
    ),
    (
      'EX_FBDY_FNC_015',
      'relative_contraindication',
      'sci_orthostatic_autonomic_safety',
      'orthostatic_tolerance_safety',
      20::numeric,
      null::numeric,
      null::boolean,
      'mmHg',
      'high',
      'If systolic orthostatic drop is >=20 mmHg, defer gait-training progression until orthostatic symptoms and vitals context are reviewed.',
      'Gait progression should be gated by orthostatic/vitals safety in neurologic and SCI contexts.',
      'Orthostatic hypotension safety screen',
      'NCBI Bookshelf StatPearls Orthostatic Hypotension',
      'https://www.ncbi.nlm.nih.gov/books/NBK448192/',
      'clinical_reference'
    ),
    (
      'EX_FBDY_CRD_006',
      'relative_contraindication',
      'sci_orthostatic_autonomic_safety',
      'orthostatic_tolerance_safety',
      20::numeric,
      null::numeric,
      null::boolean,
      'mmHg',
      'high',
      'If systolic orthostatic drop is >=20 mmHg, defer higher-volume stepping until vitals, symptoms, and medical context are reviewed.',
      'Higher-volume conditioning should be gated by orthostatic/vitals safety.',
      'Orthostatic hypotension safety screen',
      'NCBI Bookshelf StatPearls Orthostatic Hypotension',
      'https://www.ncbi.nlm.nih.gov/books/NBK448192/',
      'clinical_reference'
    ),
    (
      'EX_FBDY_FNC_001',
      'screening_required',
      'sci_orthostatic_autonomic_safety',
      'autonomic_symptom_burden_tolerance',
      40::numeric,
      null::numeric,
      null::boolean,
      'score',
      'moderate',
      'If COMPASS-31 burden is >=40, check orthostatic/autonomic triggers and use lower-dose supported transfer practice before progression.',
      'COMPASS-31 provides a weighted autonomic symptom score from 0 to 100; higher burden should trigger safety review before progression.',
      'COMPASS-31 autonomic symptom burden screen',
      'COMPASS 31: A Refined and Abbreviated Composite Autonomic Symptom Score',
      'https://pmc.ncbi.nlm.nih.gov/articles/PMC3541923/',
      'clinical_reference'
    ),
    (
      'EX_FBDY_BAL_008',
      'screening_required',
      'sci_orthostatic_autonomic_safety',
      'autonomic_symptom_burden_tolerance',
      40::numeric,
      null::numeric,
      null::boolean,
      'score',
      'moderate',
      'If COMPASS-31 burden is >=40, check autonomic triggers before dynamic balance progression.',
      'Autonomic symptom burden should modify balance progression intensity and monitoring.',
      'COMPASS-31 autonomic symptom burden screen',
      'COMPASS 31: A Refined and Abbreviated Composite Autonomic Symptom Score',
      'https://pmc.ncbi.nlm.nih.gov/articles/PMC3541923/',
      'clinical_reference'
    ),
    (
      'EX_FBDY_FNC_015',
      'relative_contraindication',
      'sci_orthostatic_autonomic_safety',
      'autonomic_symptom_burden_tolerance',
      40::numeric,
      null::numeric,
      null::boolean,
      'score',
      'high',
      'If COMPASS-31 burden is >=40, defer gait-training progression until orthostatic/autonomic triggers and symptom response are reviewed.',
      'Autonomic symptom burden can change gait and standing tolerance in SCI and neurologic contexts.',
      'COMPASS-31 autonomic symptom burden screen',
      'COMPASS 31: A Refined and Abbreviated Composite Autonomic Symptom Score',
      'https://pmc.ncbi.nlm.nih.gov/articles/PMC3541923/',
      'clinical_reference'
    ),
    (
      'EX_FBDY_CRD_006',
      'relative_contraindication',
      'sci_orthostatic_autonomic_safety',
      'autonomic_symptom_burden_tolerance',
      40::numeric,
      null::numeric,
      null::boolean,
      'score',
      'high',
      'If COMPASS-31 burden is >=40, defer higher-volume stepping until autonomic tolerance and medical context are reviewed.',
      'Higher-volume conditioning should be gated by autonomic symptom burden and symptom response.',
      'COMPASS-31 autonomic symptom burden screen',
      'COMPASS 31: A Refined and Abbreviated Composite Autonomic Symptom Score',
      'https://pmc.ncbi.nlm.nih.gov/articles/PMC3541923/',
      'clinical_reference'
    )
  ) as seed(
    exercise_code,
    precaution_type,
    condition_scope,
    capability_code,
    trigger_min_value,
    trigger_max_value,
    trigger_boolean,
    value_unit,
    severity,
    recommendation,
    rationale,
    guideline_name,
    evidence_source,
    evidence_url,
    evidence_level
  )
)
insert into public.exercise_precautions (
  exercise_id,
  capability_id,
  precaution_type,
  condition_scope,
  trigger_min_value,
  trigger_max_value,
  trigger_boolean,
  value_unit,
  severity,
  recommendation,
  rationale,
  guideline_name,
  evidence_source,
  evidence_url,
  evidence_level,
  applies_when,
  metadata,
  status,
  updated_at
)
select
  ex.id,
  mc.id,
  ps.precaution_type,
  ps.condition_scope,
  ps.trigger_min_value,
  ps.trigger_max_value,
  ps.trigger_boolean,
  ps.value_unit,
  ps.severity,
  ps.recommendation,
  ps.rationale,
  ps.guideline_name,
  ps.evidence_source,
  ps.evidence_url,
  ps.evidence_level,
  jsonb_build_object(
    'domains', jsonb_build_array('spinal_cord_injury', 'neurologic', 'autonomic', 'safety'),
    'safety_priority_layer', true
  ),
  jsonb_build_object(
    'seed_wave', 'p96_sci_skin_autonomic_safety_bridge',
    'trigger_min_value', ps.trigger_min_value,
    'trigger_max_value', ps.trigger_max_value,
    'value_unit', ps.value_unit,
    'plain_status', 'unsafe priority guard'
  ),
  'active',
  now()
from precaution_seed ps
join public.exercises ex
  on ex.exercise_code = ps.exercise_code
 and ex.is_active = true
join public.movement_capabilities mc
  on mc.capability_code = ps.capability_code
on conflict (
  exercise_id,
  precaution_type,
  condition_scope,
  (coalesce(capability_id, '00000000-0000-0000-0000-000000000000'::uuid)),
  (md5(rationale))
) where status = 'active'
do update
set
  trigger_min_value = excluded.trigger_min_value,
  trigger_max_value = excluded.trigger_max_value,
  trigger_boolean = excluded.trigger_boolean,
  value_unit = excluded.value_unit,
  severity = excluded.severity,
  recommendation = excluded.recommendation,
  guideline_name = excluded.guideline_name,
  evidence_source = excluded.evidence_source,
  evidence_url = excluded.evidence_url,
  evidence_level = excluded.evidence_level,
  applies_when = excluded.applies_when,
  metadata = public.exercise_precautions.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
