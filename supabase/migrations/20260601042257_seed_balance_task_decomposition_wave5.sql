-- Balance task decomposition wave 5.
-- Purpose: replace the overly generic BBS item observation path with a small
-- set of task families that can feed exercise reasoning.
--
-- Scope:
-- - Adds four grouped BBS task observation codes.
-- - Repoints BBS item semantic links from generic balance_task_score to grouped codes.
-- - Marks generic balance_task_score as legacy.
-- - Adds four grouped balance capabilities.
-- - Maps grouped observation codes to grouped capabilities.
-- - Seeds a small set of exercise requirements so the grouped task scores reach L2.
--
-- This is intentionally MVP grouping, not 14 separate BBS item codes.

with grouped_taxonomy_seed as (
  select * from (values
    (
      'balance_transfer_task_score',
      'Balance transfer task score',
      array['balance','function']::text[],
      'integer',
      'score',
      'Grouped BBS transfer-task score for sit-to-stand, stand-to-sit, and transfers.'
    ),
    (
      'balance_static_posture_task_score',
      'Balance static posture task score',
      array['balance','function']::text[],
      'integer',
      'score',
      'Grouped BBS static posture task score for unsupported standing/sitting and narrowed/sensory standing.'
    ),
    (
      'balance_reach_turn_task_score',
      'Balance reach and turn task score',
      array['balance','function']::text[],
      'integer',
      'score',
      'Grouped BBS dynamic reaching/turning task score.'
    ),
    (
      'balance_step_single_leg_task_score',
      'Balance step and single-leg task score',
      array['balance','function']::text[],
      'integer',
      'score',
      'Grouped BBS stepping, tandem, and single-leg task score.'
    )
  ) as seed(code, code_display, category, default_value_type, default_unit, notes)
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
  is_active,
  body_site_applicable,
  laterality_applicable,
  interpretation_guide
)
select
  grouped_taxonomy_seed.code,
  'http://physiokorea.com/fhir/observation',
  grouped_taxonomy_seed.code_display,
  grouped_taxonomy_seed.category,
  grouped_taxonomy_seed.default_value_type,
  grouped_taxonomy_seed.default_unit,
  'balance_task_decomposition_wave5',
  grouped_taxonomy_seed.notes,
  true,
  false,
  false,
  jsonb_build_object(
    'seed_wave', 'balance_task_decomposition_wave5',
    'plain_status', '운동 판단 연결',
    'grouping_model', 'bbs_task_family_mvp',
    'score_scale', '0_to_4'
  )
from grouped_taxonomy_seed
on conflict (code, code_system) do update set
  code_display = excluded.code_display,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  data_source = excluded.data_source,
  notes = excluded.notes,
  is_active = excluded.is_active,
  interpretation_guide = coalesce(public.observation_taxonomy.interpretation_guide, '{}'::jsonb)
    || excluded.interpretation_guide,
  updated_at = now();
with bbs_group_seed as (
  select * from (values
    ('bbs_1',  'balance_transfer_task_score',       '앉은 자세에서 일어서기',           'transfer_family'),
    ('bbs_4',  'balance_transfer_task_score',       '서있다가 앉기',                    'transfer_family'),
    ('bbs_5',  'balance_transfer_task_score',       '이동하기',                         'transfer_family'),
    ('bbs_2',  'balance_static_posture_task_score', '지지 없이 서기',                   'static_posture_family'),
    ('bbs_3',  'balance_static_posture_task_score', '지지 없이 앉기',                   'static_posture_family'),
    ('bbs_6',  'balance_static_posture_task_score', '눈 감고 서기',                     'static_posture_family'),
    ('bbs_7',  'balance_static_posture_task_score', '발 모으고 서기',                   'static_posture_family'),
    ('bbs_8',  'balance_reach_turn_task_score',     '팔 뻗어 앞으로 내밀기',            'reach_turn_family'),
    ('bbs_9',  'balance_reach_turn_task_score',     '바닥 물건 집기',                   'reach_turn_family'),
    ('bbs_10', 'balance_reach_turn_task_score',     '뒤돌아보기',                       'reach_turn_family'),
    ('bbs_11', 'balance_reach_turn_task_score',     '360도 회전',                       'reach_turn_family'),
    ('bbs_12', 'balance_step_single_leg_task_score','발판에 발 번갈아 올리기',          'step_single_leg_family'),
    ('bbs_13', 'balance_step_single_leg_task_score','한 발 앞에 놓고 서기 (일렬 서기)', 'step_single_leg_family'),
    ('bbs_14', 'balance_step_single_leg_task_score','한 발로 서기',                     'step_single_leg_family')
  ) as seed(score_key, observation_code, display_override, task_family)
)
update public.assessment_template_item_semantic_links links
set
  observation_code = bbs_group_seed.observation_code,
  observation_taxonomy_id = ot.id,
  display_override = bbs_group_seed.display_override,
  notes = 'Wave 5 grouped BBS item-level task binding',
  metadata = coalesce(links.metadata, '{}'::jsonb)
    || jsonb_build_object(
      'wave', 'balance_task_decomposition_wave5',
      'task_family', bbs_group_seed.task_family,
      'legacy_observation_code', 'balance_task_score'
    ),
  updated_at = now()
from bbs_group_seed,
     public.assessment_form_templates aft,
     public.observation_taxonomy ot
where aft.form_code = 'BBS'
  and aft.id = links.form_template_id
  and ot.code = bbs_group_seed.observation_code
  and ot.code_system = 'http://physiokorea.com/fhir/observation'
  and links.score_key = bbs_group_seed.score_key;
-- Keep legacy generic row for history, but stop treating it as the active BBS item path.
update public.observation_taxonomy
set
  is_active = false,
  notes = 'Legacy generic BBS item score code. Replaced by grouped balance task codes in Wave 5.',
  interpretation_guide = coalesce(interpretation_guide, '{}'::jsonb)
    || jsonb_build_object(
      'legacy_replaced_by', jsonb_build_array(
        'balance_transfer_task_score',
        'balance_static_posture_task_score',
        'balance_reach_turn_task_score',
        'balance_step_single_leg_task_score'
      ),
      'seed_wave', 'balance_task_decomposition_wave5'
    ),
  updated_at = now()
where code = 'balance_task_score'
  and code_system = 'http://physiokorea.com/fhir/observation';
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
  status
)
values
  (
    'transfer_balance_task_capacity',
    'Transfer balance task capacity',
    '전이 균형 과제 수행능력',
    'balance',
    'global',
    false,
    'integer',
    'score',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('balance_transfer_task_score'),
      'source_tool', 'BBS',
      'task_family', 'transfer'
    ),
    'active'
  ),
  (
    'static_balance_task_capacity',
    'Static balance task capacity',
    '정적 균형 과제 수행능력',
    'balance',
    'global',
    false,
    'integer',
    'score',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('balance_static_posture_task_score'),
      'source_tool', 'BBS',
      'task_family', 'static_posture'
    ),
    'active'
  ),
  (
    'dynamic_balance_task_capacity',
    'Dynamic balance task capacity',
    '동적 균형 과제 수행능력',
    'balance',
    'global',
    false,
    'integer',
    'score',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('balance_reach_turn_task_score'),
      'source_tool', 'BBS',
      'task_family', 'reach_turn'
    ),
    'active'
  ),
  (
    'step_single_leg_balance_capacity',
    'Step and single-leg balance capacity',
    '스텝/한발 균형 과제 수행능력',
    'balance',
    'global',
    false,
    'integer',
    'score',
    'higher_is_better',
    jsonb_build_object(
      'mvp_completion_level', 'L2',
      'plain_status', '운동 판단 연결',
      'source_observations', jsonb_build_array('balance_step_single_leg_task_score'),
      'source_tool', 'BBS',
      'task_family', 'step_single_leg'
    ),
    'active'
  )
on conflict (capability_code) do update set
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
    ('balance_transfer_task_score', 'transfer_balance_task_capacity', 'Grouped BBS transfer-task score -> transfer balance task capacity.'),
    ('balance_static_posture_task_score', 'static_balance_task_capacity', 'Grouped BBS static posture score -> static balance task capacity.'),
    ('balance_reach_turn_task_score', 'dynamic_balance_task_capacity', 'Grouped BBS reaching/turning score -> dynamic balance task capacity.'),
    ('balance_step_single_leg_task_score', 'step_single_leg_balance_capacity', 'Grouped BBS stepping/single-leg score -> step and single-leg balance capacity.')
  ) as seed(observation_code, capability_code, rationale)
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
  mapping_seed.observation_code,
  '',
  mc.id,
  'score',
  'integer',
  jsonb_build_object(
    'seed_wave', 'balance_task_decomposition_wave5',
    'completion_level', 'L2',
    'plain_status', '운동 판단 연결',
    'rationale', mapping_seed.rationale
  ),
  'active'
from mapping_seed
join public.movement_capabilities mc
  on mc.capability_code = mapping_seed.capability_code
on conflict (observation_code, observation_code_system, capability_id) do update set
  default_unit = excluded.default_unit,
  value_type_hint = excluded.value_type_hint,
  metadata = public.movement_capability_observation_mappings.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
with requirement_seed as (
  select * from (values
    ('edb_Chair_Squat', 'transfer_balance_task_capacity', 'target', 2::numeric, null::numeric, 'score', 2, 'low', 'Chair squat targets transfer-task balance in a supported pattern.'),
    ('edb_Bodyweight_Squat', 'transfer_balance_task_capacity', 'required', 3::numeric, null::numeric, 'score', 3, 'moderate', 'Bodyweight squat benefits from better transfer-task balance control.'),
    ('EX_ANKL_BAL_001', 'static_balance_task_capacity', 'target', 2::numeric, null::numeric, 'score', 1, 'low', 'Eyes-open static balance directly trains static balance task capacity.'),
    ('pk_single_leg_stance', 'static_balance_task_capacity', 'required', 2::numeric, null::numeric, 'score', 2, 'moderate', 'Single-leg stance presumes basic static balance task control.'),
    ('edb_Balance_Board', 'dynamic_balance_task_capacity', 'required', 2::numeric, null::numeric, 'score', 3, 'moderate', 'Balance board requires dynamic balance challenge tolerance.'),
    ('EX_ANKL_FNC_008', 'dynamic_balance_task_capacity', 'target', 2::numeric, null::numeric, 'score', 2, 'moderate', 'Obstacle step-over trains dynamic reach/turn style balance capacity.'),
    ('pk_single_leg_stance', 'step_single_leg_balance_capacity', 'target', 2::numeric, null::numeric, 'score', 2, 'moderate', 'Single-leg stance directly trains the single-leg task family.'),
    ('pk_lunge', 'step_single_leg_balance_capacity', 'required', 2::numeric, null::numeric, 'score', 3, 'moderate', 'Lunge requires stepping and single-leg balance control.'),
    ('edb_Bodyweight_Walking_Lunge', 'step_single_leg_balance_capacity', 'required', 3::numeric, null::numeric, 'score', 3, 'high', 'Walking lunge requires higher-level stepping and single-leg balance capacity.')
  ) as seed(
    exercise_code,
    capability_code,
    requirement_role,
    min_value,
    max_value,
    value_unit,
    requirement_level,
    severity,
    rationale
  )
)
insert into public.exercise_requirements (
  exercise_id,
  capability_id,
  requirement_role,
  min_value,
  max_value,
  value_unit,
  required_boolean,
  requirement_level,
  laterality,
  severity,
  rationale,
  evidence_level,
  metadata,
  status
)
select
  e.id,
  mc.id,
  rs.requirement_role,
  rs.min_value,
  rs.max_value,
  rs.value_unit,
  null::boolean,
  rs.requirement_level,
  null::text,
  rs.severity,
  rs.rationale,
  'expert_seed_mvp',
  jsonb_build_object(
    'seed_wave', 'balance_task_decomposition_wave5',
    'plain_status', '운동 판단 연결',
    'source_tool', 'BBS'
  ),
  'active'
from requirement_seed rs
join public.exercises e
  on e.exercise_code = rs.exercise_code
join public.movement_capabilities mc
  on mc.capability_code = rs.capability_code
on conflict (exercise_id, capability_id, requirement_role, coalesce(laterality, ''))
  where status = 'active'
do update set
  min_value = excluded.min_value,
  max_value = excluded.max_value,
  value_unit = excluded.value_unit,
  required_boolean = excluded.required_boolean,
  requirement_level = excluded.requirement_level,
  severity = excluded.severity,
  rationale = excluded.rationale,
  evidence_level = excluded.evidence_level,
  metadata = public.exercise_requirements.metadata || excluded.metadata,
  status = 'active',
  updated_at = now();
with legacy_balance_obs as (
  select
    id,
    case
      when measurement_context->>'score_key' in ('bbs_1','bbs_4','bbs_5') then 'balance_transfer_task_score'
      when measurement_context->>'score_key' in ('bbs_2','bbs_3','bbs_6','bbs_7') then 'balance_static_posture_task_score'
      when measurement_context->>'score_key' in ('bbs_8','bbs_9','bbs_10','bbs_11') then 'balance_reach_turn_task_score'
      when measurement_context->>'score_key' in ('bbs_12','bbs_13','bbs_14') then 'balance_step_single_leg_task_score'
      else null
    end as remapped_code
  from public.observations
  where code = 'balance_task_score'
    and status <> all (array['entered-in-error'::text, 'cancelled'::text])
)
update public.observations obs
set
  code = legacy_balance_obs.remapped_code,
  code_display = cot.code_display,
  updated_at = now()
from legacy_balance_obs
join public.observation_taxonomy cot
  on cot.code = legacy_balance_obs.remapped_code
 and cot.code_system = 'http://physiokorea.com/fhir/observation'
where obs.id = legacy_balance_obs.id
  and legacy_balance_obs.remapped_code is not null;
select coalesce(sum(private.project_observation_to_patient_capability(observations.id)), 0)
from public.observations
where observations.status <> all (array['entered-in-error'::text, 'cancelled'::text])
  and observations.code in (
    'balance_transfer_task_score',
    'balance_static_posture_task_score',
    'balance_reach_turn_task_score',
    'balance_step_single_leg_task_score'
  )
  and exists (
    select 1
    from public.movement_capability_observation_mappings mapping
    where mapping.observation_code = observations.code
      and mapping.status = 'active'
      and (
        mapping.observation_code_system = ''
        or mapping.observation_code_system = coalesce(observations.code_system, '')
      )
  );
