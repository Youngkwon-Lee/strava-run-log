-- Add structured exercise precautions so clinical matching can explain
-- caution, contraindication, screening, and modification rules separately
-- from core movement requirements.

create table if not exists public.exercise_precautions (
  id uuid primary key default gen_random_uuid(),
  exercise_id integer not null references public.exercises(id) on delete cascade,
  capability_id uuid references public.movement_capabilities(id) on delete set null,
  precaution_type text not null,
  condition_scope text not null default 'general',
  trigger_min_value numeric,
  trigger_max_value numeric,
  trigger_boolean boolean,
  value_unit text,
  severity text not null default 'moderate',
  recommendation text,
  rationale text not null,
  guideline_name text,
  evidence_source text,
  evidence_url text,
  evidence_level text,
  applies_when jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_precautions_type_check check (
    precaution_type = any (array[
      'caution',
      'relative_contraindication',
      'contraindication',
      'screening_required',
      'modification',
      'stop_rule'
    ]::text[])
  ),
  constraint exercise_precautions_severity_check check (
    severity = any (array['info','low','moderate','high','absolute']::text[])
  ),
  constraint exercise_precautions_status_check check (
    status = any (array['draft','active','deprecated']::text[])
  ),
  constraint exercise_precautions_trigger_range_check check (
    trigger_min_value is null
    or trigger_max_value is null
    or trigger_min_value <= trigger_max_value
  )
);
create index if not exists idx_exercise_precautions_exercise
  on public.exercise_precautions (exercise_id, status, precaution_type);
create index if not exists idx_exercise_precautions_capability
  on public.exercise_precautions (capability_id, status, severity);
create index if not exists idx_exercise_precautions_scope
  on public.exercise_precautions (condition_scope, status, severity);
create unique index if not exists uq_exercise_precautions_active_key
  on public.exercise_precautions (
    exercise_id,
    precaution_type,
    condition_scope,
    coalesce(capability_id, '00000000-0000-0000-0000-000000000000'::uuid),
    md5(rationale)
  )
  where status = 'active';
drop trigger if exists exercise_precautions_set_updated_at
  on public.exercise_precautions;
create trigger exercise_precautions_set_updated_at
  before update on public.exercise_precautions
  for each row execute function public.set_updated_at();
alter table public.exercise_precautions enable row level security;
drop policy if exists exercise_precautions_read_all
  on public.exercise_precautions;
create policy exercise_precautions_read_all
  on public.exercise_precautions
  for select
  to authenticated
  using (true);
drop policy if exists exercise_precautions_service_write
  on public.exercise_precautions;
create policy exercise_precautions_service_write
  on public.exercise_precautions
  for all
  to service_role
  using (true)
  with check (true);
with precaution_seed as (
  select *
  from (
    values
      ('pk_bird_dog', 'screening_required', 'low_back_pain', 'lumbar_neutral_control', null::numeric, 2::numeric, null::boolean, 'level', 'moderate',
        '요추 중립 조절이 낮으면 quadruped rock-back 또는 dead bug heel tap 같은 회귀 운동부터 사용합니다.',
        'Bird dog는 사지 움직임 중 요추 중립을 유지해야 하므로 movement control impairment가 있으면 회귀 또는 촉각 cue가 필요합니다.',
        'APTA/JOSPT Low Back Pain CPG 2021', 'J Orthop Sports Phys Ther. 2021;51(11):CPG1-CPG60. doi:10.2519/jospt.2021.0304', 'https://www.orthopt.org/content/s/interventions-for-the-management-of-acute-and-chronic-low-back-pain-revision-2021', 'clinical_practice_guideline'),
      ('edb_Dead_Bug', 'modification', 'low_back_pain', 'lumbar_neutral_control', null::numeric, 2::numeric, null::boolean, 'level', 'moderate',
        '허리 뜸이나 통증 증가가 있으면 heel tap, arms-only, 짧은 lever arm으로 조정합니다.',
        'Dead bug는 trunk activation에는 적합하지만 요추 중립 조절이 낮으면 보상 전략이 쉽게 나타납니다.',
        'APTA/JOSPT Low Back Pain CPG 2021', 'J Orthop Sports Phys Ther. 2021;51(11):CPG1-CPG60. doi:10.2519/jospt.2021.0304', 'https://www.orthopt.org/content/s/interventions-for-the-management-of-acute-and-chronic-low-back-pain-revision-2021', 'clinical_practice_guideline'),
      ('pk_hip_bridge', 'modification', 'low_back_pain', 'pain_activity_nprs', 7::numeric, null::numeric, null::boolean, 'score', 'moderate',
        '활동시 통증이 높으면 ROM, hold time, 반복수를 낮추고 posterior pelvic tilt cue를 우선합니다.',
        'Bridge는 active treatment로 유용하지만 높은 증상 irritability에서는 용량과 범위를 줄여야 합니다.',
        'APTA/JOSPT Low Back Pain CPG 2021', 'J Orthop Sports Phys Ther. 2021;51(11):CPG1-CPG60. doi:10.2519/jospt.2021.0304', 'https://www.orthopt.org/content/s/interventions-for-the-management-of-acute-and-chronic-low-back-pain-revision-2021', 'clinical_practice_guideline'),
      ('pk_side_plank', 'screening_required', 'shoulder', 'shoulder_weight_bearing_tolerance', null::numeric, 2::numeric, null::boolean, 'level', 'high',
        '어깨 체중부하 허용도가 낮으면 knees-bent side plank, wall side plank, Pallof press로 대체합니다.',
        'Side plank는 측면 몸통 안정성과 함께 상지 체중부하 허용도를 요구합니다.',
        'ACSM FITT-VP / Clinical exercise screening principle', 'ACSM exercise testing and prescription principles; APTA/JOSPT active treatment CPG framing', 'https://www.acsm.org/docs/default-source/publications-files/acsms-exercise-testing-prescription.pdf', 'guideline_principle'),
      ('pk_side_plank', 'modification', 'low_back_pain', 'lateral_trunk_stability', null::numeric, 2::numeric, null::boolean, 'level', 'moderate',
        '측면 몸통 안정성이 낮으면 lever arm을 줄이거나 hold time을 짧게 시작합니다.',
        'Side plank는 trunk endurance/stability 운동이지만 낮은 안정성에서는 회귀가 필요합니다.',
        'APTA/JOSPT Low Back Pain CPG 2021', 'J Orthop Sports Phys Ther. 2021;51(11):CPG1-CPG60. doi:10.2519/jospt.2021.0304', 'https://www.orthopt.org/content/s/interventions-for-the-management-of-acute-and-chronic-low-back-pain-revision-2021', 'clinical_practice_guideline'),

      ('edb_Ab_Roller', 'relative_contraindication', 'low_back_pain', 'lumbar_neutral_control', null::numeric, 2::numeric, null::boolean, 'level', 'high',
        '요추 중립 조절이 낮으면 ab rollout 대신 dead bug, plank from knees, anti-extension hold를 사용합니다.',
        'Ab rollout은 긴 lever arm의 anti-extension 부하가 크므로 요추 조절이 낮은 환자에게는 증상 악화 위험이 있습니다.',
        'ACSM FITT-VP / APTA/JOSPT Low Back Pain CPG 2021', 'Progressive overload and active low back pain treatment principles', 'https://www.acsm.org/docs/default-source/publications-files/acsms-exercise-testing-prescription.pdf', 'guideline_principle'),
      ('edb_Barbell_Ab_Rollout_-_On_Knees', 'relative_contraindication', 'low_back_pain', 'lumbar_neutral_control', null::numeric, 2::numeric, null::boolean, 'level', 'high',
        '무릎 버전이라도 요추 중립이 무너지면 범위를 제한하거나 낮은 단계 anti-extension 운동으로 회귀합니다.',
        'Kneeling rollout도 anti-extension demand가 높아 요추 중립 조절이 핵심 safety gate입니다.',
        'ACSM FITT-VP / APTA/JOSPT Low Back Pain CPG 2021', 'Progressive overload and active low back pain treatment principles', 'https://www.acsm.org/docs/default-source/publications-files/acsms-exercise-testing-prescription.pdf', 'guideline_principle'),
      ('edb_Superman', 'caution', 'low_back_pain', 'lumbar_extension_tolerance', null::numeric, 2::numeric, null::boolean, 'level', 'moderate',
        '요추 신전 허용도가 낮으면 prone arm/leg raise를 분리하거나 neutral spine 기반 운동을 선택합니다.',
        'Superman은 요추 신전 부하가 커서 extension-intolerant presentation에서는 증상 반응 확인이 필요합니다.',
        'APTA/JOSPT Low Back Pain CPG 2021', 'J Orthop Sports Phys Ther. 2021;51(11):CPG1-CPG60. doi:10.2519/jospt.2021.0304', 'https://www.orthopt.org/content/s/interventions-for-the-management-of-acute-and-chronic-low-back-pain-revision-2021', 'clinical_practice_guideline'),
      ('edb_Hyperextensions_Back_Extensions', 'caution', 'low_back_pain', 'lumbar_extension_tolerance', null::numeric, 2::numeric, null::boolean, 'level', 'moderate',
        '요추 신전 허용도가 낮으면 hip hinge drill 또는 bridge 계열로 대체합니다.',
        'Hyperextension은 posterior chain 운동이지만 lumbar extension tolerance가 낮으면 단계 조절이 필요합니다.',
        'APTA/JOSPT Low Back Pain CPG 2021', 'J Orthop Sports Phys Ther. 2021;51(11):CPG1-CPG60. doi:10.2519/jospt.2021.0304', 'https://www.orthopt.org/content/s/interventions-for-the-management-of-acute-and-chronic-low-back-pain-revision-2021', 'clinical_practice_guideline'),

      ('edb_Barbell_Deadlift', 'screening_required', 'low_back_pain', 'hip_hinge_control', null::numeric, 2::numeric, null::boolean, 'level', 'high',
        '힙힌지 조절이 낮으면 dowel hip hinge, elevated kettlebell deadlift, cable pull-through로 회귀합니다.',
        'Deadlift는 load progression 전에 hip hinge pattern과 trunk control 확인이 필요합니다.',
        'ACSM FITT-VP', 'Exercise prescription should individualize type, intensity, volume, and progression.', 'https://www.acsm.org/docs/default-source/publications-files/acsms-exercise-testing-prescription.pdf', 'guideline_principle'),
      ('edb_Barbell_Deadlift', 'caution', 'low_back_pain', 'pain_activity_nprs', 7::numeric, null::numeric, null::boolean, 'score', 'high',
        '활동시 통증이 높으면 external load를 보류하고 range/load를 낮춘 movement practice로 시작합니다.',
        'High-load hinge는 통증 irritability가 높은 환자에게 우선 처방하기보다 용량과 강도를 낮춰야 합니다.',
        'ACSM FITT-VP / APTA/JOSPT Low Back Pain CPG 2021', 'Progressive loading and active treatment principles', 'https://www.orthopt.org/content/s/interventions-for-the-management-of-acute-and-chronic-low-back-pain-revision-2021', 'clinical_practice_guideline'),
      ('edb_Cable_Deadlifts', 'screening_required', 'low_back_pain', 'hip_hinge_control', null::numeric, 2::numeric, null::boolean, 'level', 'moderate',
        '힙힌지 조절이 낮으면 cable load를 줄이고 supported hinge drill로 회귀합니다.',
        'Cable deadlift도 hinge pattern demand가 있어 조절 능력 확인이 필요합니다.',
        'ACSM FITT-VP', 'Exercise prescription should individualize type, intensity, volume, and progression.', 'https://www.acsm.org/docs/default-source/publications-files/acsms-exercise-testing-prescription.pdf', 'guideline_principle'),

      ('edb_Pullups', 'screening_required', 'shoulder', 'shoulder_stability', null::numeric, 2::numeric, null::boolean, 'level', 'high',
        '어깨 안정성이 낮으면 band-assisted, lat pulldown, scapular pull-up으로 회귀합니다.',
        'Pull-up은 높은 상지 견인 부하를 요구하므로 shoulder stability와 symptom response 확인이 필요합니다.',
        'ACSM FITT-VP', 'Exercise prescription should individualize intensity and progression to current capability.', 'https://www.acsm.org/docs/default-source/publications-files/acsms-exercise-testing-prescription.pdf', 'guideline_principle'),
      ('edb_Band_Assisted_Pull-Up', 'modification', 'shoulder', 'shoulder_stability', null::numeric, 2::numeric, null::boolean, 'level', 'moderate',
        '어깨 안정성이 낮으면 assistance를 늘리고 scapular control drill을 선행합니다.',
        'Assisted pull-up도 overhead pulling demand가 있어 shoulder stability에 따라 조절해야 합니다.',
        'ACSM FITT-VP', 'Exercise prescription should individualize intensity and progression to current capability.', 'https://www.acsm.org/docs/default-source/publications-files/acsms-exercise-testing-prescription.pdf', 'guideline_principle'),

      ('EX_ANKL_STB_008', 'screening_required', 'ankle_sprain', 'single_leg_balance_seconds', null::numeric, 5::numeric, null::boolean, 'seconds', 'moderate',
        '한발서기 시간이 낮으면 양발 지지, hand support, eyes-open balance부터 시작합니다.',
        'Ankle instability rehabilitation commonly progresses balance demand according to postural control capacity.',
        'APTA/JOSPT Ankle Stability and Movement Coordination CPG 2021', 'J Orthop Sports Phys Ther. 2021;51(4):CPG1-CPG80. doi:10.2519/jospt.2021.0302', 'https://www.orthopt.org/content/practice/clinical-practice-guidelines/cpgs', 'clinical_practice_guideline'),
      ('EX_ANKL_FNC_002', 'caution', 'ankle_sprain', 'gait_without_limp', null::numeric, null::numeric, false::boolean, null, 'moderate',
        '절뚝임이 남아 있으면 step height, repetition, support를 낮추고 gait quality를 먼저 회복합니다.',
        'Stair climbing은 체중부하와 eccentric control demand가 있어 보행 quality와 symptom response를 확인해야 합니다.',
        'APTA/JOSPT Ankle Stability and Movement Coordination CPG 2021', 'J Orthop Sports Phys Ther. 2021;51(4):CPG1-CPG80. doi:10.2519/jospt.2021.0302', 'https://www.orthopt.org/content/practice/clinical-practice-guidelines/cpgs', 'clinical_practice_guideline'),
      ('EX_ANKL_STR_012', 'modification', 'ankle_sprain', 'pain_activity_nprs', 7::numeric, null::numeric, null::boolean, 'score', 'low',
        '통증이 높으면 stretch intensity를 낮추고 짧은 hold부터 시작합니다.',
        'Mobility exercise도 높은 irritability에서는 intensity and time을 조절해야 합니다.',
        'ACSM FITT-VP / APTA/JOSPT Ankle CPG 2021', 'Progression and symptom-response principles', 'https://www.acsm.org/docs/default-source/publications-files/acsms-exercise-testing-prescription.pdf', 'guideline_principle')
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
  status
)
select
  e.id,
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
    'capability_code', ps.capability_code,
    'trigger_min_value', ps.trigger_min_value,
    'trigger_max_value', ps.trigger_max_value,
    'trigger_boolean', ps.trigger_boolean,
    'value_unit', ps.value_unit
  ),
  jsonb_build_object('seed_wave', 'exercise_precautions_v1_2026_05_27'),
  'active'
from precaution_seed ps
join public.exercises e
  on e.exercise_code = ps.exercise_code
join public.movement_capabilities mc
  on mc.capability_code = ps.capability_code
on conflict (
  exercise_id,
  precaution_type,
  condition_scope,
  (coalesce(capability_id, '00000000-0000-0000-0000-000000000000'::uuid)),
  (md5(rationale))
)
where status = 'active'
do update set
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
  updated_at = now();
