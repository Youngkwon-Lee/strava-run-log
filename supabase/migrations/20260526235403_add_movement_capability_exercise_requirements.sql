-- Movement capability and exercise requirement MVP.
--
-- Existing exercise library SSOT remains public.exercises.
-- This migration adds the missing bridge:
--   patient observations -> patient capabilities
--   exercises -> exercise capability requirements
--   patient capability vs exercise requirement -> recommendation/progression logic

create table if not exists public.movement_capabilities (
  id uuid primary key default gen_random_uuid(),
  capability_code text not null,
  display text not null,
  display_ko text,
  capability_domain text not null,
  body_region text,
  body_site_code character varying(50),
  body_site_display character varying(255),
  laterality_applicable boolean not null default false,
  default_value_type text not null default 'quantity',
  default_unit text,
  measurement_direction text not null default 'higher_is_better',
  observation_taxonomy_id uuid references public.observation_taxonomy(id) on delete set null,
  clinical_concept_id uuid references public.clinical_concepts(id) on delete set null,
  movement_pattern_id integer references public.movement_patterns(id) on delete set null,
  properties jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint movement_capabilities_code_unique unique (capability_code),
  constraint movement_capabilities_nonempty_code check (length(trim(capability_code)) > 0),
  constraint movement_capabilities_nonempty_display check (length(trim(display)) > 0),
  constraint movement_capabilities_domain_check check (
    capability_domain = any (array[
      'mobility'::text,
      'strength'::text,
      'motor_control'::text,
      'stability'::text,
      'balance'::text,
      'load_tolerance'::text,
      'endurance'::text,
      'breathing'::text,
      'weight_bearing'::text,
      'coordination'::text,
      'functional'::text,
      'other'::text
    ])
  ),
  constraint movement_capabilities_value_type_check check (
    default_value_type = any (array[
      'quantity'::text,
      'integer'::text,
      'boolean'::text,
      'string'::text,
      'json'::text
    ])
  ),
  constraint movement_capabilities_direction_check check (
    measurement_direction = any (array[
      'higher_is_better'::text,
      'lower_is_better'::text,
      'within_range'::text,
      'binary_present'::text,
      'binary_absent'::text,
      'contextual'::text
    ])
  ),
  constraint movement_capabilities_status_check check (
    status = any (array['draft'::text, 'active'::text, 'deprecated'::text])
  )
);
comment on table public.movement_capabilities
  is 'Canonical movement capability registry used to compare patient ability against exercise requirements.';
comment on column public.movement_capabilities.capability_domain
  is 'Capability family: mobility, strength, motor_control, stability, balance, load_tolerance, endurance, breathing, weight_bearing, coordination, functional, other.';
create index if not exists idx_movement_capabilities_domain
  on public.movement_capabilities (capability_domain, body_region, status);
create index if not exists idx_movement_capabilities_taxonomy
  on public.movement_capabilities (observation_taxonomy_id);
create index if not exists idx_movement_capabilities_concept
  on public.movement_capabilities (clinical_concept_id);
create index if not exists idx_movement_capabilities_pattern
  on public.movement_capabilities (movement_pattern_id);
create table if not exists public.exercise_requirements (
  id uuid primary key default gen_random_uuid(),
  exercise_id integer not null references public.exercises(id) on delete cascade,
  capability_id uuid not null references public.movement_capabilities(id) on delete cascade,
  requirement_role text not null default 'required',
  min_value numeric,
  max_value numeric,
  value_unit text,
  required_boolean boolean,
  requirement_level integer,
  laterality text,
  severity text not null default 'moderate',
  rationale text,
  evidence_level text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint exercise_requirements_role_check check (
    requirement_role = any (array[
      'required'::text,
      'target'::text,
      'caution'::text,
      'contraindication'::text,
      'progression_gate'::text,
      'regression_gate'::text
    ])
  ),
  constraint exercise_requirements_level_check check (
    requirement_level is null or requirement_level between 1 and 5
  ),
  constraint exercise_requirements_laterality_check check (
    laterality is null or laterality = any (array[
      'left'::text,
      'right'::text,
      'bilateral'::text,
      'either'::text
    ])
  ),
  constraint exercise_requirements_severity_check check (
    severity = any (array[
      'info'::text,
      'low'::text,
      'moderate'::text,
      'high'::text,
      'absolute'::text
    ])
  ),
  constraint exercise_requirements_status_check check (
    status = any (array['draft'::text, 'active'::text, 'deprecated'::text])
  ),
  constraint exercise_requirements_min_max_check check (
    min_value is null or max_value is null or min_value <= max_value
  )
);
comment on table public.exercise_requirements
  is 'Per-exercise capability requirements and targets. This is the core bridge from exercise library to clinical reasoning.';
create unique index if not exists uq_exercise_requirements_active_key
  on public.exercise_requirements (
    exercise_id,
    capability_id,
    requirement_role,
    coalesce(laterality, '')
  )
  where status = 'active';
create index if not exists idx_exercise_requirements_exercise
  on public.exercise_requirements (exercise_id, status, requirement_role);
create index if not exists idx_exercise_requirements_capability
  on public.exercise_requirements (capability_id, status, severity);
create table if not exists public.exercise_progressions (
  id uuid primary key default gen_random_uuid(),
  from_exercise_id integer not null references public.exercises(id) on delete cascade,
  to_exercise_id integer not null references public.exercises(id) on delete cascade,
  relation_type text not null,
  progression_axis text,
  gate_capability_id uuid references public.movement_capabilities(id) on delete set null,
  rationale text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint exercise_progressions_distinct_exercises check (from_exercise_id <> to_exercise_id),
  constraint exercise_progressions_relation_type_check check (
    relation_type = any (array[
      'progression'::text,
      'regression'::text,
      'lateral_variant'::text,
      'substitution'::text
    ])
  ),
  constraint exercise_progressions_axis_check check (
    progression_axis is null or progression_axis = any (array[
      'load'::text,
      'range'::text,
      'stability'::text,
      'speed'::text,
      'complexity'::text,
      'impact'::text,
      'position'::text,
      'assistance'::text,
      'equipment'::text,
      'volume'::text,
      'other'::text
    ])
  ),
  constraint exercise_progressions_status_check check (
    status = any (array['draft'::text, 'active'::text, 'deprecated'::text])
  )
);
comment on table public.exercise_progressions
  is 'Directed graph for exercise regression, progression, lateral variants, and substitutions.';
create unique index if not exists uq_exercise_progressions_active_edge
  on public.exercise_progressions (from_exercise_id, to_exercise_id, relation_type)
  where status = 'active';
create index if not exists idx_exercise_progressions_from
  on public.exercise_progressions (from_exercise_id, status, relation_type);
create index if not exists idx_exercise_progressions_to
  on public.exercise_progressions (to_exercise_id, status, relation_type);
create index if not exists idx_exercise_progressions_gate
  on public.exercise_progressions (gate_capability_id);
create table if not exists public.patient_capability_observations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  subject_person_id uuid not null references public.persons(id) on delete cascade,
  encounter_id uuid references public.encounters(id) on delete set null,
  source_observation_id uuid references public.observations(id) on delete cascade,
  capability_id uuid not null references public.movement_capabilities(id) on delete cascade,
  value_type text not null,
  value_quantity numeric,
  value_unit text,
  value_boolean boolean,
  value_string text,
  value_json jsonb,
  interpretation text,
  confidence numeric,
  source_type text not null default 'observation_projection',
  effective_datetime timestamp with time zone not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_by uuid references public.persons(id) on delete set null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint patient_capability_observations_value_type_check check (
    value_type = any (array[
      'quantity'::text,
      'integer'::text,
      'boolean'::text,
      'string'::text,
      'json'::text
    ])
  ),
  constraint patient_capability_observations_interpretation_check check (
    interpretation is null or interpretation = any (array[
      'meets_requirement'::text,
      'below_requirement'::text,
      'above_limit'::text,
      'limited'::text,
      'contraindicated'::text,
      'unknown'::text
    ])
  ),
  constraint patient_capability_observations_confidence_check check (
    confidence is null or (confidence >= 0 and confidence <= 1)
  ),
  constraint patient_capability_observations_source_type_check check (
    source_type = any (array[
      'observation_projection'::text,
      'manual'::text,
      'ai_inference'::text,
      'device'::text,
      'session_log'::text
    ])
  ),
  constraint patient_capability_observations_status_check check (
    status = any (array['draft'::text, 'active'::text, 'entered_in_error'::text])
  ),
  constraint patient_capability_observations_has_value check (
    value_quantity is not null
    or value_boolean is not null
    or value_string is not null
    or value_json is not null
  )
);
comment on table public.patient_capability_observations
  is 'Projected patient capabilities derived from observations, manual review, devices, or session logs.';
create unique index if not exists uq_patient_capability_observation_projection
  on public.patient_capability_observations (source_observation_id, capability_id)
  where source_observation_id is not null and status = 'active';
create index if not exists idx_patient_capability_observations_person
  on public.patient_capability_observations (
    organization_id,
    subject_person_id,
    capability_id,
    effective_datetime desc
  )
  where status = 'active';
create index if not exists idx_patient_capability_observations_encounter
  on public.patient_capability_observations (encounter_id)
  where encounter_id is not null;
create index if not exists idx_patient_capability_observations_observation
  on public.patient_capability_observations (source_observation_id)
  where source_observation_id is not null;
drop trigger if exists movement_capabilities_set_updated_at on public.movement_capabilities;
create trigger movement_capabilities_set_updated_at
  before update on public.movement_capabilities
  for each row execute function public.set_updated_at();
drop trigger if exists exercise_requirements_set_updated_at on public.exercise_requirements;
create trigger exercise_requirements_set_updated_at
  before update on public.exercise_requirements
  for each row execute function public.set_updated_at();
drop trigger if exists exercise_progressions_set_updated_at on public.exercise_progressions;
create trigger exercise_progressions_set_updated_at
  before update on public.exercise_progressions
  for each row execute function public.set_updated_at();
drop trigger if exists patient_capability_observations_set_updated_at on public.patient_capability_observations;
create trigger patient_capability_observations_set_updated_at
  before update on public.patient_capability_observations
  for each row execute function public.set_updated_at();
alter table public.movement_capabilities enable row level security;
alter table public.exercise_requirements enable row level security;
alter table public.exercise_progressions enable row level security;
alter table public.patient_capability_observations enable row level security;
drop policy if exists movement_capabilities_read_all on public.movement_capabilities;
create policy movement_capabilities_read_all
  on public.movement_capabilities
  for select
  to authenticated
  using (true);
drop policy if exists movement_capabilities_service_write on public.movement_capabilities;
create policy movement_capabilities_service_write
  on public.movement_capabilities
  for all
  to service_role
  using (true)
  with check (true);
drop policy if exists exercise_requirements_read_all on public.exercise_requirements;
create policy exercise_requirements_read_all
  on public.exercise_requirements
  for select
  to authenticated
  using (true);
drop policy if exists exercise_requirements_service_write on public.exercise_requirements;
create policy exercise_requirements_service_write
  on public.exercise_requirements
  for all
  to service_role
  using (true)
  with check (true);
drop policy if exists exercise_progressions_read_all on public.exercise_progressions;
create policy exercise_progressions_read_all
  on public.exercise_progressions
  for select
  to authenticated
  using (true);
drop policy if exists exercise_progressions_service_write on public.exercise_progressions;
create policy exercise_progressions_service_write
  on public.exercise_progressions
  for all
  to service_role
  using (true)
  with check (true);
drop policy if exists patient_capability_observations_select_member on public.patient_capability_observations;
create policy patient_capability_observations_select_member
  on public.patient_capability_observations
  for select
  to authenticated
  using (
    subject_person_id = public.get_my_person_id()
    or public.is_org_member(organization_id)
  );
drop policy if exists patient_capability_observations_service_write on public.patient_capability_observations;
create policy patient_capability_observations_service_write
  on public.patient_capability_observations
  for all
  to service_role
  using (true)
  with check (true);
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
  properties
)
values
  ('pain_rest_nprs', 'Resting pain NPRS', '안정시 통증 NPRS', 'load_tolerance', 'global', false, 'quantity', 'score', 'lower_is_better', '{"scale_min":0,"scale_max":10}'::jsonb),
  ('pain_activity_nprs', 'Activity pain NPRS', '활동시 통증 NPRS', 'load_tolerance', 'global', false, 'quantity', 'score', 'lower_is_better', '{"scale_min":0,"scale_max":10}'::jsonb),
  ('pain_24h_response', '24-hour symptom response', '24시간 증상 반응', 'load_tolerance', 'global', false, 'string', null, 'contextual', '{"values":["better","same","worse"]}'::jsonb),
  ('weight_bearing_tolerance', 'Weight-bearing tolerance', '체중부하 허용도', 'weight_bearing', 'global', true, 'quantity', 'percent', 'higher_is_better', '{}'::jsonb),
  ('single_leg_balance_seconds', 'Single-leg balance duration', '한발서기 시간', 'balance', 'global', true, 'quantity', 'sec', 'higher_is_better', '{}'::jsonb),
  ('gait_without_limp', 'Gait without limp', '절뚝임 없는 보행', 'functional', 'global', false, 'boolean', null, 'binary_present', '{}'::jsonb),
  ('squat_depth_control', 'Squat depth and control', '스쿼트 깊이와 조절', 'motor_control', 'lower_extremity', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('hip_hinge_control', 'Hip hinge control', '힙힌지 조절', 'motor_control', 'lumbar_hip', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('lumbar_neutral_control', 'Lumbar neutral control', '요추 중립 조절', 'motor_control', 'lumbar', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('trunk_rotary_control', 'Trunk rotary control', '몸통 회전 조절', 'motor_control', 'trunk', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('hip_extension_control', 'Hip extension control', '고관절 신전 조절', 'motor_control', 'hip', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('lumbopelvic_stability', 'Lumbopelvic stability', '요추-골반 안정성', 'stability', 'lumbar_pelvis', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('lumbopelvic_control', 'Lumbopelvic control', '요추-골반 조절', 'motor_control', 'lumbar_pelvis', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5,"related_capability":"lumbopelvic_stability"}'::jsonb),
  ('lateral_trunk_stability', 'Lateral trunk stability', '측면 몸통 안정성', 'stability', 'trunk', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('scapular_control', 'Scapular control', '견갑 조절', 'motor_control', 'shoulder', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('shoulder_stability', 'Shoulder stability', '어깨 안정성', 'stability', 'shoulder', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('shoulder_weight_bearing_tolerance', 'Shoulder weight-bearing tolerance', '어깨 체중부하 허용도', 'weight_bearing', 'shoulder', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('shoulder_flexion_rom', 'Shoulder flexion ROM', '어깨 굴곡 ROM', 'mobility', 'shoulder', true, 'quantity', 'deg', 'higher_is_better', '{}'::jsonb),
  ('shoulder_external_rotation_rom', 'Shoulder external rotation ROM', '어깨 외회전 ROM', 'mobility', 'shoulder', true, 'quantity', 'deg', 'higher_is_better', '{}'::jsonb),
  ('shoulder_external_rotation_strength', 'Shoulder external rotation strength', '어깨 외회전 근력', 'strength', 'shoulder', true, 'quantity', 'grade', 'higher_is_better', '{"mmt":true}'::jsonb),
  ('cervical_deep_flexor_control', 'Deep cervical flexor control', '심부 경부 굴곡근 조절', 'motor_control', 'cervical', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('cervical_flexion_rom', 'Cervical flexion ROM', '경추 굴곡 ROM', 'mobility', 'cervical', false, 'quantity', 'deg', 'higher_is_better', '{}'::jsonb),
  ('cervical_lateral_flexion_rom', 'Cervical lateral flexion ROM', '경추 측굴 ROM', 'mobility', 'cervical', true, 'quantity', 'deg', 'higher_is_better', '{}'::jsonb),
  ('cervical_rotation_rom', 'Cervical rotation ROM', '경추 회전 ROM', 'mobility', 'cervical', true, 'quantity', 'deg', 'higher_is_better', '{}'::jsonb),
  ('cervical_isometric_tolerance', 'Cervical isometric tolerance', '경추 등척성 허용도', 'load_tolerance', 'cervical', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('lumbar_flexion_tolerance', 'Lumbar flexion tolerance', '요추 굴곡 허용도', 'load_tolerance', 'lumbar', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('lumbar_extension_tolerance', 'Lumbar extension tolerance', '요추 신전 허용도', 'load_tolerance', 'lumbar', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('hip_flexion_rom', 'Hip flexion ROM', '고관절 굴곡 ROM', 'mobility', 'hip', true, 'quantity', 'deg', 'higher_is_better', '{}'::jsonb),
  ('hip_abduction_strength', 'Hip abduction strength', '고관절 외전 근력', 'strength', 'hip', true, 'quantity', 'grade', 'higher_is_better', '{"mmt":true}'::jsonb),
  ('hip_adduction_strength', 'Hip adduction strength', '고관절 내전 근력', 'strength', 'hip', true, 'quantity', 'grade', 'higher_is_better', '{"mmt":true}'::jsonb),
  ('hip_extension_strength', 'Hip extension strength', '고관절 신전 근력', 'strength', 'hip', true, 'quantity', 'grade', 'higher_is_better', '{"mmt":true}'::jsonb),
  ('knee_flexion_rom', 'Knee flexion ROM', '무릎 굴곡 ROM', 'mobility', 'knee', true, 'quantity', 'deg', 'higher_is_better', '{}'::jsonb),
  ('knee_extension_rom', 'Knee extension ROM', '무릎 신전 ROM', 'mobility', 'knee', true, 'quantity', 'deg', 'higher_is_better', '{}'::jsonb),
  ('quadriceps_strength', 'Quadriceps strength', '대퇴사두근 근력', 'strength', 'knee', true, 'quantity', 'grade', 'higher_is_better', '{"mmt":true}'::jsonb),
  ('hamstring_strength', 'Hamstring strength', '햄스트링 근력', 'strength', 'knee', true, 'quantity', 'grade', 'higher_is_better', '{"mmt":true}'::jsonb),
  ('knee_proprioception_control', 'Knee proprioception control', '무릎 고유수용성 조절', 'coordination', 'knee', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('ankle_dorsiflexion_rom', 'Ankle dorsiflexion ROM', '발목 배측굴곡 ROM', 'mobility', 'ankle', true, 'quantity', 'deg', 'higher_is_better', '{}'::jsonb),
  ('calf_strength_endurance', 'Calf strength endurance', '종아리 근지구력', 'endurance', 'ankle', true, 'quantity', 'reps', 'higher_is_better', '{}'::jsonb),
  ('ankle_proprioception_control', 'Ankle proprioception control', '발목 고유수용성 조절', 'coordination', 'ankle', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('foot_intrinsic_control', 'Foot intrinsic control', '발 내재근 조절', 'motor_control', 'foot', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('breathing_diaphragmatic_control', 'Diaphragmatic breathing control', '횡격막 호흡 조절', 'breathing', 'thorax', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('thoracic_extension_mobility', 'Thoracic extension mobility', '흉추 신전 가동성', 'mobility', 'thoracic_spine', false, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('wrist_mobility_control', 'Wrist mobility control', '손목 가동성 조절', 'mobility', 'wrist_hand', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('grip_strength', 'Grip strength', '악력', 'strength', 'wrist_hand', true, 'quantity', 'grade', 'higher_is_better', '{"mmt":true}'::jsonb),
  ('elbow_flexion_strength', 'Elbow flexion strength', '팔꿈치 굴곡 근력', 'strength', 'elbow', true, 'quantity', 'grade', 'higher_is_better', '{"mmt":true}'::jsonb),
  ('median_nerve_symptom_tolerance', 'Median nerve symptom tolerance', '정중신경 증상 허용도', 'load_tolerance', 'upper_extremity', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb),
  ('upper_limb_closed_chain_tolerance', 'Upper-limb closed-chain tolerance', '상지 폐쇄사슬 부하 허용도', 'load_tolerance', 'upper_extremity', true, 'quantity', 'level', 'higher_is_better', '{"level_min":1,"level_max":5}'::jsonb)
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
  properties = excluded.properties,
  status = 'active',
  updated_at = now();
with requirement_seed as (
  select *
  from (values
    ('pk_hip_bridge', 'hip_extension_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 3, 'moderate', 'Bridge targets hip extension strength.'),
    ('pk_hip_bridge', 'lumbopelvic_control', 'target', 2::numeric, null::numeric, 'level', null::boolean, 2, 'moderate', 'Bridge targets lumbopelvic control.'),
    ('edb_Pelvic_Tilt_Into_Bridge', 'lumbopelvic_control', 'required', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Pelvic tilt into bridge requires basic lumbopelvic control.'),
    ('edb_Pelvic_Tilt_Into_Bridge', 'hip_extension_strength', 'target', 2::numeric, null::numeric, 'grade', null::boolean, 2, 'low', 'Pelvic tilt into bridge begins hip extension loading.'),
    ('pk_side_plank', 'lateral_trunk_stability', 'required', 3::numeric, null::numeric, 'level', null::boolean, 4, 'moderate', 'Side plank requires lateral trunk stability.'),
    ('pk_side_plank', 'shoulder_weight_bearing_tolerance', 'required', 3::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Side plank requires upper-quarter weight-bearing tolerance.'),
    ('edb_Side_Bridge', 'lateral_trunk_stability', 'required', 3::numeric, null::numeric, 'level', null::boolean, 4, 'moderate', 'Side bridge requires lateral trunk stability.'),
    ('edb_Side_Bridge', 'shoulder_weight_bearing_tolerance', 'required', 2::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Side bridge requires shoulder weight-bearing tolerance.'),
    ('pk_bird_dog', 'lumbar_neutral_control', 'required', 3::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Bird dog requires lumbar neutral control.'),
    ('pk_bird_dog', 'shoulder_stability', 'required', 2::numeric, null::numeric, 'level', null::boolean, 2, 'moderate', 'Bird dog requires shoulder stability during quadruped loading.'),
    ('pk_bird_dog', 'hip_extension_control', 'required', 2::numeric, null::numeric, 'level', null::boolean, 2, 'moderate', 'Bird dog requires controlled hip extension without lumbar compensation.'),
    ('edb_Cat_Stretch', 'lumbar_flexion_tolerance', 'required', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Cat stretch requires tolerable lumbar flexion.'),
    ('edb_Cat_Stretch', 'thoracic_extension_mobility', 'target', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Cat stretch targets spinal mobility.'),
    ('edb_Torso_Rotation', 'trunk_rotary_control', 'target', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Torso rotation targets controlled trunk rotation.'),
    ('edb_Torso_Rotation', 'thoracic_extension_mobility', 'required', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Torso rotation requires basic thoracic mobility.'),
    ('edb_Pallof_Press_With_Rotation', 'trunk_rotary_control', 'required', 3::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Pallof press with rotation requires trunk rotary control.'),
    ('edb_Pallof_Press_With_Rotation', 'lumbopelvic_stability', 'required', 2::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Pallof press with rotation requires lumbopelvic stability.'),
    ('edb_Middle_Back_Stretch', 'thoracic_extension_mobility', 'target', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Middle back stretch targets thoracic mobility.'),
    ('edb_Upper_Back_Stretch', 'thoracic_extension_mobility', 'target', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Upper back stretch targets thoracic mobility.'),
    ('pk_chin_tuck', 'cervical_deep_flexor_control', 'target', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Chin tuck targets deep neck flexor control.'),
    ('edb_Chin_To_Chest_Stretch', 'cervical_flexion_rom', 'target', 30::numeric, null::numeric, 'deg', null::boolean, 2, 'low', 'Chin-to-chest stretch targets cervical flexion range.'),
    ('edb_Side_Neck_Stretch', 'cervical_lateral_flexion_rom', 'target', 25::numeric, null::numeric, 'deg', null::boolean, 2, 'low', 'Side neck stretch targets cervical lateral flexion range.'),
    ('edb_Isometric_Neck_Exercise_-_Front_And_Back', 'cervical_isometric_tolerance', 'required', 2::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Front/back neck isometrics require cervical isometric tolerance.'),
    ('edb_Isometric_Neck_Exercise_-_Sides', 'cervical_isometric_tolerance', 'required', 2::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Side neck isometrics require cervical isometric tolerance.'),
    ('pk_shoulder_external_rotation', 'shoulder_external_rotation_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 3, 'moderate', 'External rotation exercise targets rotator cuff strength.'),
    ('pk_shoulder_external_rotation', 'shoulder_external_rotation_rom', 'required', 30::numeric, null::numeric, 'deg', null::boolean, 2, 'low', 'External rotation exercise requires enough shoulder external rotation range.'),
    ('edb_External_Rotation', 'shoulder_external_rotation_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 3, 'moderate', 'External rotation targets rotator cuff strength.'),
    ('edb_External_Rotation_with_Band', 'shoulder_external_rotation_strength', 'required', 3::numeric, null::numeric, 'grade', null::boolean, 4, 'moderate', 'Band external rotation requires baseline external rotation strength.'),
    ('edb_External_Rotation_with_Band', 'scapular_control', 'required', 2::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Band external rotation requires scapular control.'),
    ('edb_Scapular_Pull-Up', 'scapular_control', 'required', 3::numeric, null::numeric, 'level', null::boolean, 4, 'moderate', 'Scapular pull-up requires scapular control.'),
    ('edb_Scapular_Pull-Up', 'shoulder_stability', 'required', 3::numeric, null::numeric, 'level', null::boolean, 4, 'moderate', 'Scapular pull-up requires shoulder stability.'),
    ('edb_Seated_Cable_Rows', 'scapular_control', 'required', 2::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Seated cable row requires scapular control.'),
    ('edb_Inverted_Row', 'scapular_control', 'required', 3::numeric, null::numeric, 'level', null::boolean, 4, 'moderate', 'Inverted row requires scapular control.'),
    ('edb_Inverted_Row', 'upper_limb_closed_chain_tolerance', 'required', 3::numeric, null::numeric, 'level', null::boolean, 4, 'moderate', 'Inverted row requires upper-limb closed-chain tolerance.'),
    ('pk_clam_shell', 'hip_abduction_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 2, 'moderate', 'Clamshell targets hip abduction strength.'),
    ('pk_clam_shell', 'lumbopelvic_control', 'required', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Clamshell requires basic lumbopelvic control.'),
    ('edb_Monster_Walk', 'hip_abduction_strength', 'required', 3::numeric, null::numeric, 'grade', null::boolean, 4, 'moderate', 'Monster walk requires hip abduction strength.'),
    ('edb_Monster_Walk', 'single_leg_balance_seconds', 'required', 10::numeric, null::numeric, 'sec', null::boolean, 3, 'moderate', 'Monster walk requires standing balance tolerance.'),
    ('edb_Side_Leg_Raises', 'hip_abduction_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 3, 'moderate', 'Side leg raise targets hip abduction strength.'),
    ('edb_Single_Leg_Glute_Bridge', 'hip_extension_strength', 'required', 3::numeric, null::numeric, 'grade', null::boolean, 4, 'moderate', 'Single-leg glute bridge requires hip extension strength.'),
    ('edb_Single_Leg_Glute_Bridge', 'lumbopelvic_control', 'required', 3::numeric, null::numeric, 'level', null::boolean, 4, 'moderate', 'Single-leg glute bridge requires lumbopelvic control.'),
    ('edb_Step-up_with_Knee_Raise', 'weight_bearing_tolerance', 'required', 75::numeric, null::numeric, 'percent', null::boolean, 4, 'moderate', 'Step-up with knee raise requires weight-bearing tolerance.'),
    ('edb_Step-up_with_Knee_Raise', 'single_leg_balance_seconds', 'required', 10::numeric, null::numeric, 'sec', null::boolean, 4, 'moderate', 'Step-up with knee raise requires single-leg balance.'),
    ('edb_Thigh_Abductor', 'hip_abduction_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 3, 'moderate', 'Thigh abductor targets hip abduction strength.'),
    ('edb_Thigh_Adductor', 'hip_adduction_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 3, 'moderate', 'Thigh adductor targets hip adduction strength.'),
    ('pk_calf_raise', 'calf_strength_endurance', 'target', 10::numeric, null::numeric, 'reps', null::boolean, 3, 'moderate', 'Calf raise targets plantarflexor strength endurance.'),
    ('pk_calf_raise', 'weight_bearing_tolerance', 'required', 75::numeric, null::numeric, 'percent', null::boolean, 3, 'moderate', 'Requires meaningful standing weight-bearing tolerance.'),
    ('pk_straight_leg_raise', 'quadriceps_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 2, 'moderate', 'Straight leg raise targets quadriceps control.'),
    ('EX_KNEE_PRP_004', 'quadriceps_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 3, 'moderate', 'Knee proprioception exercise benefits from quadriceps control.'),
    ('EX_KNEE_PRP_004', 'knee_proprioception_control', 'target', 2::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Knee proprioception exercise targets knee control.'),
    ('EX_KNEE_PRP_005', 'knee_proprioception_control', 'target', 3::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Knee proprioception progression targets knee control.'),
    ('EX_KNEE_PRP_006', 'single_leg_balance_seconds', 'required', 10::numeric, null::numeric, 'sec', null::boolean, 4, 'moderate', 'Advanced knee proprioception requires single-leg balance.'),
    ('EX_ANKL_PRP_004', 'ankle_proprioception_control', 'target', 2::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Ankle proprioception exercise targets ankle control.'),
    ('EX_ANKL_PRP_005', 'ankle_proprioception_control', 'target', 3::numeric, null::numeric, 'level', null::boolean, 3, 'moderate', 'Ankle proprioception progression targets ankle control.'),
    ('EX_ANKL_BAL_005', 'single_leg_balance_seconds', 'required', 10::numeric, null::numeric, 'sec', null::boolean, 4, 'moderate', 'Ankle balance exercise requires single-leg balance tolerance.'),
    ('EX_ANKL_BAL_005', 'ankle_proprioception_control', 'target', 3::numeric, null::numeric, 'level', null::boolean, 4, 'moderate', 'Ankle balance exercise targets proprioceptive control.'),
    ('EX_ANKL_SGT_001', 'ankle_dorsiflexion_rom', 'target', 10::numeric, null::numeric, 'deg', null::boolean, 2, 'moderate', 'Ankle sagittal-plane exercise targets dorsiflexion range.'),
    ('EX_ANKL_STR_001', 'calf_strength_endurance', 'target', 8::numeric, null::numeric, 'reps', null::boolean, 3, 'moderate', 'Ankle strengthening exercise targets calf endurance.'),
    ('pk_nerve_glide_median', 'median_nerve_symptom_tolerance', 'caution', null::numeric, null::numeric, 'level', null::boolean, 1, 'info', 'Median nerve glide should stay symptom-guided rather than load-focused.'),
    ('edb_Wrist_Circles', 'wrist_mobility_control', 'target', 2::numeric, null::numeric, 'level', null::boolean, 2, 'low', 'Wrist circles target wrist mobility control.'),
    ('edb_Finger_Curls', 'grip_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 2, 'moderate', 'Finger curls target grip strength.'),
    ('edb_Hammer_Curls', 'elbow_flexion_strength', 'target', 3::numeric, null::numeric, 'grade', null::boolean, 3, 'moderate', 'Hammer curls target elbow flexion strength.'),
    ('edb_Hammer_Curls', 'grip_strength', 'required', 3::numeric, null::numeric, 'grade', null::boolean, 3, 'moderate', 'Hammer curls require grip strength.')
  ) as seed(
    exercise_code,
    capability_code,
    requirement_role,
    min_value,
    max_value,
    value_unit,
    required_boolean,
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
  severity,
  rationale,
  metadata
)
select
  e.id,
  mc.id,
  rs.requirement_role,
  rs.min_value,
  rs.max_value,
  rs.value_unit,
  rs.required_boolean,
  rs.requirement_level,
  rs.severity,
  rs.rationale,
  jsonb_build_object('seed_source', 'movement_capability_mvp')
from requirement_seed rs
join public.exercises e
  on e.exercise_code = rs.exercise_code
join public.movement_capabilities mc
  on mc.capability_code = rs.capability_code
on conflict do nothing;
with observation_capability_map as (
  select *
  from (values
    ('VAS', 'pain_activity_nprs', 'score'),
    ('NPRS', 'pain_activity_nprs', 'score'),
    ('ROM_shoulder_flexion', 'shoulder_flexion_rom', 'deg'),
    ('ROM_shoulder_external_rotation', 'shoulder_external_rotation_rom', 'deg'),
    ('ROM_cervical_flexion', 'cervical_flexion_rom', 'deg'),
    ('ROM_cervical_lateral_flexion', 'cervical_lateral_flexion_rom', 'deg'),
    ('ROM_cervical_rotation', 'cervical_rotation_rom', 'deg'),
    ('ROM_hip_flexion', 'hip_flexion_rom', 'deg'),
    ('ROM_knee_flexion', 'knee_flexion_rom', 'deg'),
    ('ROM_knee_extension', 'knee_extension_rom', 'deg'),
    ('ROM_ankle_dorsiflexion', 'ankle_dorsiflexion_rom', 'deg'),
    ('MMT_shoulder_external_rotation', 'shoulder_external_rotation_strength', 'grade'),
    ('MMT_hip_abduction', 'hip_abduction_strength', 'grade'),
    ('MMT_hip_adduction', 'hip_adduction_strength', 'grade'),
    ('MMT_hip_extension', 'hip_extension_strength', 'grade'),
    ('MMT_knee_extension', 'quadriceps_strength', 'grade'),
    ('MMT_knee_flexion', 'hamstring_strength', 'grade'),
    ('grip_strength', 'grip_strength', 'grade'),
    ('single_leg_stance_seconds', 'single_leg_balance_seconds', 'sec')
  ) as mapped(observation_code, capability_code, default_unit)
),
projected_observations as (
  select
    obs.organization_id,
    obs.subject_person_id,
    obs.encounter_id,
    obs.id as source_observation_id,
    mc.id as capability_id,
    case
      when obs.value_quantity is not null then 'quantity'
      when obs.value_integer is not null then 'quantity'
      when obs.value_json ->> 'numeric_equivalent' ~ '^-?[0-9]+(\.[0-9]+)?$' then 'quantity'
      when obs.value_boolean is not null then 'boolean'
      when obs.value_json is not null then 'json'
      else 'string'
    end as value_type,
    coalesce(
      obs.value_quantity,
      obs.value_integer::numeric,
      case
        when obs.value_json ->> 'numeric_equivalent' ~ '^-?[0-9]+(\.[0-9]+)?$'
          then (obs.value_json ->> 'numeric_equivalent')::numeric
        else null
      end
    ) as value_quantity,
    coalesce(obs.value_unit, ocm.default_unit) as value_unit,
    obs.value_boolean,
    obs.value_string,
    obs.value_json,
    obs.effective_datetime,
    obs.created_by,
    obs.code,
    obs.code_system,
    obs.laterality
  from public.observations obs
  join observation_capability_map ocm
    on ocm.observation_code = obs.code
  join public.movement_capabilities mc
    on mc.capability_code = ocm.capability_code
  where obs.status <> all (array['entered_in_error'::text, 'cancelled'::text])
)
insert into public.patient_capability_observations (
  organization_id,
  subject_person_id,
  encounter_id,
  source_observation_id,
  capability_id,
  value_type,
  value_quantity,
  value_unit,
  value_boolean,
  value_string,
  value_json,
  interpretation,
  confidence,
  source_type,
  effective_datetime,
  metadata,
  created_by
)
select
  po.organization_id,
  po.subject_person_id,
  po.encounter_id,
  po.source_observation_id,
  po.capability_id,
  po.value_type,
  po.value_quantity,
  po.value_unit,
  po.value_boolean,
  po.value_string,
  po.value_json,
  'unknown',
  1,
  'observation_projection',
  po.effective_datetime,
  jsonb_strip_nulls(jsonb_build_object(
    'source_observation_code', po.code,
    'source_observation_code_system', po.code_system,
    'laterality', po.laterality,
    'projection_wave', 'movement_capability_mvp'
  )),
  po.created_by
from projected_observations po
where po.value_quantity is not null
   or po.value_boolean is not null
   or po.value_string is not null
   or po.value_json is not null
on conflict do nothing;
with progression_seed as (
  select *
  from (values
    ('pk_chin_tuck', 'pk_bird_dog', 'progression', 'complexity', 'lumbar_neutral_control', 'Progress from isolated motor control to quadruped trunk control when tolerated.'),
    ('edb_Pelvic_Tilt_Into_Bridge', 'pk_hip_bridge', 'progression', 'complexity', 'lumbopelvic_control', 'Progress from pelvic tilt bridge patterning to canonical bridge.'),
    ('pk_hip_bridge', 'pk_side_plank', 'progression', 'stability', 'lateral_trunk_stability', 'Progress sagittal-plane bridge control toward frontal-plane trunk stability.'),
    ('pk_hip_bridge', 'edb_Single_Leg_Glute_Bridge', 'progression', 'stability', 'lumbopelvic_control', 'Progress bilateral bridge to single-leg bridge when pelvis control is sufficient.'),
    ('pk_side_plank', 'edb_Side_Bridge', 'lateral_variant', 'position', 'lateral_trunk_stability', 'Side bridge is a close side-plank variant when the canonical side plank needs substitution.'),
    ('pk_side_plank', 'edb_Pallof_Press_With_Rotation', 'substitution', 'stability', 'trunk_rotary_control', 'Pallof press variation can substitute anti-rotation trunk control when shoulder weight-bearing is not tolerated.'),
    ('pk_clam_shell', 'edb_Side_Leg_Raises', 'progression', 'load', 'hip_abduction_strength', 'Progress hip abductor activation to side leg raise loading.'),
    ('edb_Side_Leg_Raises', 'edb_Monster_Walk', 'progression', 'load', 'hip_abduction_strength', 'Progress open-chain hip abduction to banded standing hip abduction control.'),
    ('pk_straight_leg_raise', 'EX_KNEE_PRP_004', 'progression', 'complexity', 'knee_proprioception_control', 'Progress isolated quadriceps control to knee proprioception work.'),
    ('EX_KNEE_PRP_004', 'EX_KNEE_PRP_005', 'progression', 'complexity', 'knee_proprioception_control', 'Progress early knee proprioception to a higher-control variant.'),
    ('EX_KNEE_PRP_005', 'EX_KNEE_PRP_006', 'progression', 'stability', 'single_leg_balance_seconds', 'Progress knee proprioception when single-leg balance is sufficient.'),
    ('pk_calf_raise', 'EX_ANKL_STR_001', 'lateral_variant', 'load', 'calf_strength_endurance', 'Pair calf raise with ankle strengthening when plantarflexor endurance is appropriate.'),
    ('EX_ANKL_PRP_004', 'EX_ANKL_PRP_005', 'progression', 'complexity', 'ankle_proprioception_control', 'Progress early ankle proprioception to a higher-control variant.'),
    ('EX_ANKL_PRP_005', 'EX_ANKL_BAL_005', 'progression', 'stability', 'single_leg_balance_seconds', 'Progress ankle proprioception to balance work when standing tolerance allows.'),
    ('edb_Wrist_Circles', 'edb_Finger_Curls', 'progression', 'load', 'grip_strength', 'Progress wrist mobility control to light grip loading.'),
    ('edb_Finger_Curls', 'edb_Hammer_Curls', 'progression', 'load', 'elbow_flexion_strength', 'Progress grip work to elbow flexion strengthening.')
  ) as seed(
    from_exercise_code,
    to_exercise_code,
    relation_type,
    progression_axis,
    gate_capability_code,
    rationale
  )
)
insert into public.exercise_progressions (
  from_exercise_id,
  to_exercise_id,
  relation_type,
  progression_axis,
  gate_capability_id,
  rationale,
  metadata
)
select
  from_exercise.id,
  to_exercise.id,
  ps.relation_type,
  ps.progression_axis,
  mc.id,
  ps.rationale,
  jsonb_build_object('seed_source', 'movement_capability_mvp')
from progression_seed ps
join public.exercises from_exercise
  on from_exercise.exercise_code = ps.from_exercise_code
join public.exercises to_exercise
  on to_exercise.exercise_code = ps.to_exercise_code
left join public.movement_capabilities mc
  on mc.capability_code = ps.gate_capability_code
on conflict do nothing;
