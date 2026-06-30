with concept_seed (
  form_code,
  concept_key,
  display,
  display_ko,
  definition,
  properties
) as (
  values
    (
      'ROM_CERVICAL',
      'assessment_template:rom_cervical',
      'Cervical Range of Motion',
      '경추 관절가동범위',
      'Cervical ROM template with axis-level findings projected to canonical observations.',
      jsonb_build_object('body_region', 'cervical', 'wave', 'pt_template_semantics_wave2a')
    ),
    (
      'ROM_HIP',
      'assessment_template:rom_hip',
      'Hip Range of Motion',
      '고관절 관절가동범위',
      'Hip ROM template with axis-level findings projected to canonical observations.',
      jsonb_build_object('body_region', 'hip', 'wave', 'pt_template_semantics_wave2a')
    ),
    (
      'ROM_SHOULDER',
      'assessment_template:rom_shoulder',
      'Shoulder Range of Motion',
      '어깨 관절가동범위',
      'Shoulder ROM template with axis-level findings projected to canonical observations.',
      jsonb_build_object('body_region', 'shoulder', 'wave', 'pt_template_semantics_wave2a')
    ),
    (
      'ROM_ANKLE',
      'assessment_template:rom_ankle',
      'Ankle Range of Motion',
      '발목 관절가동범위',
      'Ankle ROM template with axis-level findings projected to canonical observations.',
      jsonb_build_object('body_region', 'ankle', 'wave', 'pt_template_semantics_wave2a')
    ),
    (
      'SLR',
      'assessment_template:slr',
      'Straight Leg Raise Test',
      '하지직거상 검사',
      'SLR template with bilateral angle capture and positive/negative reproduction finding.',
      jsonb_build_object('body_region', 'lumbar', 'wave', 'pt_template_semantics_wave2a')
    ),
    (
      'TUG',
      'assessment_template:tug',
      'Timed Up and Go Test',
      '일어나 걷기 검사',
      'Timed Up and Go template with elapsed seconds and assistive-device context.',
      jsonb_build_object('body_region', 'general', 'wave', 'pt_template_semantics_wave2a')
    ),
    (
      'BBS',
      'assessment_template:bbs',
      'Berg Balance Scale',
      '버그 균형 척도',
      'Balance battery template with aggregate total score and item-level balance task scores.',
      jsonb_build_object('body_region', 'general', 'wave', 'pt_template_semantics_wave2a')
    ),
    (
      'MMT',
      'assessment_template:mmt',
      'Manual Muscle Testing',
      '도수근력검사',
      'Generic MMT template with target muscle context and left/right grade capture.',
      jsonb_build_object('body_region', 'general', 'wave', 'pt_template_semantics_wave2a')
    )
),
upserted_concepts as (
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
    cs.concept_key,
    cs.display,
    cs.display_ko,
    'assessment_template',
    array['core']::text[],
    'assessment_form_templates',
    aft.id::text,
    cs.form_code,
    'http://physiokorea.com/fhir/assessment-template',
    cs.definition,
    cs.properties,
    case when aft.is_active then 'active' else 'deprecated' end
  from concept_seed cs
  join public.assessment_form_templates aft
    on aft.form_code = cs.form_code
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
    updated_at = now()
  returning id, concept_key
),
taxonomy_seed (
  code,
  code_display,
  category,
  default_value_type,
  default_unit,
  data_source,
  notes
) as (
  values
    ('ROM_cervical_flexion', 'Cervical flexion ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_CERVICAL template linkage'),
    ('ROM_cervical_extension', 'Cervical extension ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_CERVICAL template linkage'),
    ('ROM_cervical_lateral_flexion_left', 'Cervical left lateral flexion ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_CERVICAL template linkage'),
    ('ROM_cervical_lateral_flexion_right', 'Cervical right lateral flexion ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_CERVICAL template linkage'),
    ('ROM_cervical_rotation_left', 'Cervical left rotation ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_CERVICAL template linkage'),
    ('ROM_cervical_rotation_right', 'Cervical right rotation ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_CERVICAL template linkage'),
    ('ROM_hip_flexion', 'Hip flexion ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_HIP template linkage'),
    ('ROM_hip_extension', 'Hip extension ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_HIP template linkage'),
    ('ROM_hip_abduction', 'Hip abduction ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_HIP template linkage'),
    ('ROM_hip_adduction', 'Hip adduction ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_HIP template linkage'),
    ('ROM_hip_internal_rotation', 'Hip internal rotation ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_HIP template linkage'),
    ('ROM_hip_external_rotation', 'Hip external rotation ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_HIP template linkage'),
    ('ROM_shoulder_flexion', 'Shoulder flexion ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_SHOULDER template linkage'),
    ('ROM_shoulder_abduction', 'Shoulder abduction ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_SHOULDER template linkage'),
    ('ROM_shoulder_external_rotation', 'Shoulder external rotation ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_SHOULDER template linkage'),
    ('ROM_shoulder_internal_rotation', 'Shoulder internal rotation ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_SHOULDER template linkage'),
    ('ROM_ankle_dorsiflexion', 'Ankle dorsiflexion ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_ANKLE template linkage'),
    ('ROM_ankle_plantarflexion', 'Ankle plantarflexion ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_ANKLE template linkage'),
    ('ROM_ankle_inversion', 'Ankle inversion ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_ANKLE template linkage'),
    ('ROM_ankle_eversion', 'Ankle eversion ROM', array['rom']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for ROM_ANKLE template linkage'),
    ('special_test_slr_angle', 'Straight Leg Raise angle', array['special_test','neuro','msk']::text[], 'quantity', 'deg', 'pt_template_semantics_wave2a', 'Wave 2A seed for SLR angle capture'),
    ('AMBULATION_device', 'Assistive device used', array['gait','function','mobility']::text[], 'string', null, 'pt_template_semantics_wave2a', 'Wave 2A seed for TUG assistive-device context'),
    ('balance_task_score', 'Balance task score', array['balance','function']::text[], 'integer', 'score', 'pt_template_semantics_wave2a', 'Wave 2A seed for item-level balance task scoring'),
    ('MMT_generic', 'Manual muscle test grade', array['strength','function']::text[], 'string', null, 'pt_template_semantics_wave2a', 'Wave 2A seed for generic MMT grade capture'),
    ('mmt_target_muscle', 'MMT target muscle group', array['strength','function']::text[], 'string', null, 'pt_template_semantics_wave2a', 'Wave 2A seed for generic MMT target muscle context')
),
upserted_taxonomy as (
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
    ts.data_source,
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
    updated_at = now()
  returning id, code
),
semantic_seed_static (
  form_code,
  score_key,
  binding_role,
  observation_code,
  display_override,
  category,
  default_value_type,
  default_unit,
  body_site_code,
  laterality,
  notes,
  metadata
) as (
  values
    ('ROM_CERVICAL', 'crom_flexion', 'result', 'ROM_cervical_flexion', 'Cervical flexion', array['rom']::text[], 'quantity', 'deg', 'cervical', null, 'Wave 2A cervical ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_CERVICAL', 'crom_extension', 'result', 'ROM_cervical_extension', 'Cervical extension', array['rom']::text[], 'quantity', 'deg', 'cervical', null, 'Wave 2A cervical ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_CERVICAL', 'crom_lat_flex_l', 'result', 'ROM_cervical_lateral_flexion_left', 'Cervical left lateral flexion', array['rom']::text[], 'quantity', 'deg', 'cervical', 'left', 'Wave 2A cervical ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_CERVICAL', 'crom_lat_flex_r', 'result', 'ROM_cervical_lateral_flexion_right', 'Cervical right lateral flexion', array['rom']::text[], 'quantity', 'deg', 'cervical', 'right', 'Wave 2A cervical ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_CERVICAL', 'crom_rot_l', 'result', 'ROM_cervical_rotation_left', 'Cervical left rotation', array['rom']::text[], 'quantity', 'deg', 'cervical', 'left', 'Wave 2A cervical ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_CERVICAL', 'crom_rot_r', 'result', 'ROM_cervical_rotation_right', 'Cervical right rotation', array['rom']::text[], 'quantity', 'deg', 'cervical', 'right', 'Wave 2A cervical ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_HIP', 'hrom_flexion', 'result', 'ROM_hip_flexion', 'Hip flexion', array['rom']::text[], 'quantity', 'deg', 'hip', null, 'Wave 2A hip ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_HIP', 'hrom_extension', 'result', 'ROM_hip_extension', 'Hip extension', array['rom']::text[], 'quantity', 'deg', 'hip', null, 'Wave 2A hip ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_HIP', 'hrom_abd', 'result', 'ROM_hip_abduction', 'Hip abduction', array['rom']::text[], 'quantity', 'deg', 'hip', null, 'Wave 2A hip ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_HIP', 'hrom_add', 'result', 'ROM_hip_adduction', 'Hip adduction', array['rom']::text[], 'quantity', 'deg', 'hip', null, 'Wave 2A hip ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_HIP', 'hrom_ir', 'result', 'ROM_hip_internal_rotation', 'Hip internal rotation', array['rom']::text[], 'quantity', 'deg', 'hip', null, 'Wave 2A hip ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_HIP', 'hrom_er', 'result', 'ROM_hip_external_rotation', 'Hip external rotation', array['rom']::text[], 'quantity', 'deg', 'hip', null, 'Wave 2A hip ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_SHOULDER', 'srom_flexion', 'result', 'ROM_shoulder_flexion', 'Shoulder flexion', array['rom']::text[], 'quantity', 'deg', 'shoulder', null, 'Wave 2A shoulder ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_SHOULDER', 'srom_abduction', 'result', 'ROM_shoulder_abduction', 'Shoulder abduction', array['rom']::text[], 'quantity', 'deg', 'shoulder', null, 'Wave 2A shoulder ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_SHOULDER', 'srom_er', 'result', 'ROM_shoulder_external_rotation', 'Shoulder external rotation', array['rom']::text[], 'quantity', 'deg', 'shoulder', null, 'Wave 2A shoulder ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_SHOULDER', 'srom_ir', 'result', 'ROM_shoulder_internal_rotation', 'Shoulder internal rotation', array['rom']::text[], 'quantity', 'deg', 'shoulder', null, 'Wave 2A shoulder ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_ANKLE', 'arom_df', 'result', 'ROM_ankle_dorsiflexion', 'Ankle dorsiflexion', array['rom']::text[], 'quantity', 'deg', 'ankle', null, 'Wave 2A ankle ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_ANKLE', 'arom_pf', 'result', 'ROM_ankle_plantarflexion', 'Ankle plantarflexion', array['rom']::text[], 'quantity', 'deg', 'ankle', null, 'Wave 2A ankle ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_ANKLE', 'arom_inv', 'result', 'ROM_ankle_inversion', 'Ankle inversion', array['rom']::text[], 'quantity', 'deg', 'ankle', null, 'Wave 2A ankle ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('ROM_ANKLE', 'arom_ev', 'result', 'ROM_ankle_eversion', 'Ankle eversion', array['rom']::text[], 'quantity', 'deg', 'ankle', null, 'Wave 2A ankle ROM item binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('SLR', 'slr_left', 'result', 'special_test_slr_angle', 'Left SLR angle', array['special_test','neuro','msk']::text[], 'quantity', 'deg', null, 'left', 'Wave 2A SLR angle binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a', 'side', 'left')),
    ('SLR', 'slr_right', 'result', 'special_test_slr_angle', 'Right SLR angle', array['special_test','neuro','msk']::text[], 'quantity', 'deg', null, 'right', 'Wave 2A SLR angle binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a', 'side', 'right')),
    ('SLR', 'slr_positive', 'result', 'special_test_slr', 'SLR pain reproduction', array['special_test','neuro','msk']::text[], 'string', null, null, null, 'Wave 2A SLR positive/negative binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('TUG', 'tug_time', 'result', 'TUG_seconds', 'Timed Up and Go seconds', array['balance','function','mobility']::text[], 'quantity', 's', null, null, 'Wave 2A TUG elapsed time binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('TUG', 'tug_device', 'context', 'AMBULATION_device', 'Assistive device used', array['gait','function','mobility']::text[], 'string', null, null, null, 'Wave 2A TUG assistive-device binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('TUG', 'total_score', 'aggregate', 'TUG_seconds', 'Timed Up and Go total seconds', array['balance','function','mobility']::text[], 'quantity', 's', null, null, 'Wave 2A TUG aggregate binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('BBS', 'total_score', 'aggregate', 'BBS_total', 'Berg Balance Scale total', array['balance','function']::text[], 'integer', 'score', null, null, 'Wave 2A BBS aggregate binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('MMT', 'mmt_muscle', 'context', 'mmt_target_muscle', 'Target muscle group', array['strength','function']::text[], 'string', null, null, null, 'Wave 2A generic MMT target-muscle binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a')),
    ('MMT', 'mmt_left', 'result', 'MMT_generic', 'Left MMT grade', array['strength','function']::text[], 'string', null, null, 'left', 'Wave 2A generic MMT left-grade binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a', 'side', 'left')),
    ('MMT', 'mmt_right', 'result', 'MMT_generic', 'Right MMT grade', array['strength','function']::text[], 'string', null, null, 'right', 'Wave 2A generic MMT right-grade binding', jsonb_build_object('wave', 'pt_template_semantics_wave2a', 'side', 'right'))
),
bbs_item_seed as (
  select
    'BBS'::text as form_code,
    item ->> 'score_key' as score_key,
    'result'::text as binding_role,
    'balance_task_score'::text as observation_code,
    coalesce(nullif(item ->> 'question_text_korean', ''), item ->> 'question_text', item ->> 'score_key') as display_override,
    array['balance','function']::text[] as category,
    'integer'::text as default_value_type,
    'score'::text as default_unit,
    null::text as body_site_code,
    null::text as laterality,
    'Wave 2A BBS item-level task score binding'::text as notes,
    jsonb_build_object(
      'wave', 'pt_template_semantics_wave2a',
      'task_key', item ->> 'score_key',
      'question_text', item ->> 'question_text'
    ) as metadata
  from public.assessment_form_templates aft
  cross join lateral jsonb_array_elements(coalesce(aft.items, '[]'::jsonb)) item
  where aft.form_code = 'BBS'
    and item ? 'score_key'
),
semantic_seed as (
  select * from semantic_seed_static
  union all
  select * from bbs_item_seed
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
  body_site_code,
  laterality,
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
  ss.body_site_code,
  ss.laterality,
  ss.notes,
  ss.metadata,
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
  body_site_code = excluded.body_site_code,
  laterality = excluded.laterality,
  notes = excluded.notes,
  metadata = excluded.metadata,
  status = excluded.status,
  updated_at = now();
