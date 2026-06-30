-- Add structured exercise effects so recommendation can distinguish
-- "can the patient perform this?" from "why would we prescribe this?"

create table if not exists public.exercise_effects (
  id uuid primary key default gen_random_uuid(),
  exercise_id integer not null references public.exercises(id) on delete cascade,
  capability_id uuid not null references public.movement_capabilities(id) on delete cascade,
  effect_type text not null,
  adaptation_direction text not null default 'improve',
  effect_strength integer not null default 3,
  expected_time_horizon text not null default 'medium_term',
  dose_response jsonb not null default '{}'::jsonb,
  rationale text not null,
  guideline_name text,
  evidence_source text,
  evidence_url text,
  evidence_level text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_effects_type_check check (
    effect_type = any (array[
      'primary_target',
      'secondary_target',
      'mobility_gain',
      'strength_gain',
      'motor_control_gain',
      'stability_gain',
      'balance_gain',
      'endurance_gain',
      'load_tolerance_gain',
      'symptom_modulation',
      'breathing_control'
    ]::text[])
  ),
  constraint exercise_effects_direction_check check (
    adaptation_direction = any (array['increase','improve','decrease','maintain','contextual']::text[])
  ),
  constraint exercise_effects_strength_check check (effect_strength between 1 and 5),
  constraint exercise_effects_horizon_check check (
    expected_time_horizon = any (array['immediate','short_term','medium_term','long_term','contextual']::text[])
  ),
  constraint exercise_effects_status_check check (
    status = any (array['draft','active','deprecated']::text[])
  )
);
create index if not exists idx_exercise_effects_exercise
  on public.exercise_effects (exercise_id, status, effect_type);
create index if not exists idx_exercise_effects_capability
  on public.exercise_effects (capability_id, status, effect_strength desc);
create unique index if not exists uq_exercise_effects_active_key
  on public.exercise_effects (exercise_id, capability_id, effect_type)
  where status = 'active';
drop trigger if exists exercise_effects_set_updated_at
  on public.exercise_effects;
create trigger exercise_effects_set_updated_at
  before update on public.exercise_effects
  for each row execute function public.set_updated_at();
alter table public.exercise_effects enable row level security;
drop policy if exists exercise_effects_read_all
  on public.exercise_effects;
create policy exercise_effects_read_all
  on public.exercise_effects
  for select
  to authenticated
  using (true);
drop policy if exists exercise_effects_service_write
  on public.exercise_effects;
create policy exercise_effects_service_write
  on public.exercise_effects
  for all
  to service_role
  using (true)
  with check (true);
with effect_seed as (
  select *
  from (
    values
      ('pk_bird_dog','lumbar_neutral_control','motor_control_gain','improve',5,'medium_term','Bird dog trains lumbar neutral control while alternating limb movement.'),
      ('pk_bird_dog','hip_extension_control','secondary_target','improve',3,'medium_term','Bird dog reinforces hip extension control without lumbar compensation.'),
      ('pk_bird_dog','shoulder_stability','secondary_target','improve',2,'medium_term','Quadruped loading gives a low-load shoulder stability stimulus.'),

      ('pk_side_plank','lateral_trunk_stability','stability_gain','improve',5,'medium_term','Side plank primarily develops lateral trunk endurance and stability.'),
      ('pk_side_plank','shoulder_weight_bearing_tolerance','load_tolerance_gain','increase',3,'medium_term','The side plank provides progressive upper-quarter weight-bearing exposure.'),
      ('pk_side_plank','lumbopelvic_stability','secondary_target','improve',3,'medium_term','Maintaining pelvic position reinforces lumbopelvic stability.'),

      ('pk_hip_bridge','hip_extension_strength','strength_gain','increase',5,'medium_term','Bridge is a low-to-moderate load hip extension strengthening exercise.'),
      ('pk_hip_bridge','lumbopelvic_control','motor_control_gain','improve',4,'medium_term','Bridge can train lumbopelvic control during hip extension.'),
      ('pk_hip_bridge','hip_extension_control','secondary_target','improve',3,'medium_term','Bridge supports controlled terminal hip extension.'),

      ('edb_Dead_Bug','lumbar_neutral_control','motor_control_gain','improve',5,'medium_term','Dead bug trains anti-extension control with progressive limb leverage.'),
      ('edb_Dead_Bug','lumbopelvic_control','stability_gain','improve',4,'medium_term','Dead bug reinforces lumbopelvic control during alternating arm and leg movement.'),
      ('edb_Dead_Bug','breathing_diaphragmatic_control','breathing_control','improve',2,'short_term','Dead bug can pair breathing control with trunk stabilization.'),

      ('pk_cat_cow','thoracic_extension_mobility','mobility_gain','improve',3,'short_term','Cat-cow provides repeated thoracic extension and flexion exposure.'),
      ('pk_cat_cow','lumbar_flexion_tolerance','symptom_modulation','improve',3,'short_term','Cat-cow can provide gentle lumbar motion exposure when tolerated.'),
      ('pk_cat_cow','lumbar_extension_tolerance','symptom_modulation','improve',3,'short_term','Cat-cow can provide graded lumbar extension exposure when tolerated.'),
      ('edb_Cat_Stretch','thoracic_extension_mobility','mobility_gain','improve',3,'short_term','Cat stretch supports spinal mobility and unloaded symptom modulation.'),
      ('edb_Cat_Stretch','lumbar_flexion_tolerance','symptom_modulation','improve',3,'short_term','Cat stretch gives low-load lumbar flexion exposure.'),

      ('edb_Bodyweight_Squat','squat_depth_control','motor_control_gain','improve',4,'medium_term','Bodyweight squat trains lower-extremity coordination and depth control.'),
      ('edb_Bodyweight_Squat','quadriceps_strength','strength_gain','increase',4,'medium_term','Bodyweight squat loads knee extension in a functional pattern.'),
      ('edb_Bodyweight_Squat','hip_extension_strength','strength_gain','increase',3,'medium_term','Bodyweight squat contributes to hip extension strength.'),
      ('edb_Bodyweight_Squat','ankle_dorsiflexion_rom','mobility_gain','improve',2,'medium_term','Repeated squat exposure can maintain usable ankle dorsiflexion.'),

      ('pk_calf_raise','calf_strength_endurance','endurance_gain','increase',5,'medium_term','Calf raise directly targets plantarflexor strength endurance.'),
      ('pk_calf_raise','weight_bearing_tolerance','load_tolerance_gain','increase',3,'medium_term','Standing calf raises provide graded lower-limb weight-bearing load.'),
      ('edb_Calf_Raises_-_With_Bands','calf_strength_endurance','endurance_gain','increase',4,'medium_term','Band-assisted calf raises add resistance to plantarflexor endurance work.'),
      ('edb_Calf_Raises_-_With_Bands','single_leg_balance_seconds','balance_gain','improve',2,'medium_term','Standing calf raise variations can reinforce stance control.'),

      ('EX_ANKL_STB_008','single_leg_balance_seconds','balance_gain','improve',5,'medium_term','Single-leg stance directly trains postural control duration.'),
      ('EX_ANKL_STB_008','ankle_proprioception_control','balance_gain','improve',4,'medium_term','Single-leg stance challenges ankle proprioceptive control.'),
      ('EX_ANKL_STR_012','ankle_dorsiflexion_rom','mobility_gain','improve',5,'short_term','Wall-assisted ankle stretch targets dorsiflexion range.'),

      ('edb_Barbell_Deadlift','hip_extension_strength','strength_gain','increase',5,'medium_term','Deadlift is a high-load hip extension strengthening pattern.'),
      ('edb_Barbell_Deadlift','hip_hinge_control','motor_control_gain','improve',4,'medium_term','Deadlift reinforces loaded hip hinge control.'),
      ('edb_Barbell_Deadlift','lumbar_neutral_control','stability_gain','improve',4,'medium_term','Deadlift can train trunk stiffness and neutral spine control when appropriately dosed.'),
      ('edb_Cable_Deadlifts','hip_hinge_control','motor_control_gain','improve',4,'medium_term','Cable deadlift provides a more adjustable hinge-pattern stimulus.'),
      ('edb_Cable_Deadlifts','hip_extension_strength','strength_gain','increase',3,'medium_term','Cable deadlift develops posterior-chain strength with adjustable load.'),

      ('edb_Pullups','scapular_control','strength_gain','increase',5,'medium_term','Pull-up strongly loads scapular depression and retraction control.'),
      ('edb_Pullups','shoulder_stability','strength_gain','increase',4,'medium_term','Pull-up trains shoulder stability under vertical pulling load.'),
      ('edb_Pullups','grip_strength','strength_gain','increase',4,'medium_term','Pull-up demands sustained grip strength.'),
      ('edb_Band_Assisted_Pull-Up','scapular_control','strength_gain','increase',4,'medium_term','Band assistance allows scaled scapular pulling control.'),
      ('edb_Band_Assisted_Pull-Up','shoulder_stability','strength_gain','increase',3,'medium_term','Band-assisted pull-up gives a lower-load shoulder stability stimulus.'),

      ('edb_Pallof_Press_With_Rotation','trunk_rotary_control','motor_control_gain','improve',5,'medium_term','Pallof press with rotation trains controlled trunk rotation and anti-rotation.'),
      ('edb_Pallof_Press_With_Rotation','lumbopelvic_stability','stability_gain','improve',4,'medium_term','Resisted trunk work reinforces lumbopelvic stability.'),
      ('edb_Monster_Walk','hip_abduction_strength','strength_gain','increase',5,'medium_term','Monster walk targets hip abductor strength and endurance.'),
      ('edb_Monster_Walk','single_leg_balance_seconds','balance_gain','improve',3,'medium_term','Banded stepping challenges stance control.'),
      ('pk_clam_shell','hip_abduction_strength','strength_gain','increase',4,'medium_term','Clamshell targets hip abductor and external rotator capacity.'),
      ('pk_clam_shell','lumbopelvic_control','motor_control_gain','improve',2,'medium_term','Clamshell can reinforce pelvic control during isolated hip movement.'),

      ('pk_chin_tuck','cervical_deep_flexor_control','motor_control_gain','improve',5,'medium_term','Chin tuck directly trains deep cervical flexor control.'),
      ('pk_shoulder_external_rotation','shoulder_external_rotation_strength','strength_gain','increase',5,'medium_term','Shoulder external rotation directly targets rotator cuff strength.'),
      ('pk_shoulder_external_rotation','shoulder_external_rotation_rom','mobility_gain','improve',2,'medium_term','External rotation work may help maintain usable external rotation range.'),
      ('edb_External_Rotation_with_Band','shoulder_external_rotation_strength','strength_gain','increase',5,'medium_term','Band external rotation loads rotator cuff external rotation.'),
      ('edb_External_Rotation_with_Band','scapular_control','secondary_target','improve',3,'medium_term','Band external rotation benefits from scapular positioning control.'),

      ('pk_foam_roller_thoracic','thoracic_extension_mobility','mobility_gain','improve',5,'short_term','Foam roller thoracic extension targets thoracic mobility.'),
      ('pk_foam_roller_thoracic','shoulder_flexion_rom','secondary_target','improve',2,'short_term','Improved thoracic extension can support overhead shoulder flexion.'),

      ('edb_Bodyweight_Walking_Lunge','single_leg_balance_seconds','balance_gain','improve',4,'medium_term','Walking lunge challenges dynamic single-leg stance control.'),
      ('edb_Bodyweight_Walking_Lunge','quadriceps_strength','strength_gain','increase',4,'medium_term','Walking lunge loads knee extension in a functional pattern.'),
      ('edb_Barbell_Step_Ups','quadriceps_strength','strength_gain','increase',4,'medium_term','Step-ups develop knee extension strength in a stair-like task.'),
      ('edb_Barbell_Step_Ups','hip_extension_strength','strength_gain','increase',3,'medium_term','Step-ups reinforce hip extension strength during ascent.'),
      ('edb_Balance_Board','ankle_proprioception_control','balance_gain','improve',5,'medium_term','Balance board work targets ankle proprioceptive control.'),
      ('edb_Balance_Board','single_leg_balance_seconds','balance_gain','improve',4,'medium_term','Balance board exposure can improve stance balance capacity.'),
      ('EX_ANKL_BAL_005','ankle_proprioception_control','balance_gain','improve',5,'medium_term','Ankle balance work targets proprioceptive control.'),
      ('EX_ANKL_BAL_006','ankle_proprioception_control','balance_gain','improve',5,'medium_term','Star excursion challenges dynamic ankle proprioception.'),
      ('EX_ANKL_BAL_007','single_leg_balance_seconds','balance_gain','improve',5,'medium_term','Y-balance challenges dynamic single-leg balance.'),
      ('EX_ANKL_FNC_001','quadriceps_strength','strength_gain','increase',3,'medium_term','Sit-to-stand reinforces knee extension capacity in a functional task.'),
      ('EX_ANKL_FNC_002','gait_without_limp','secondary_target','improve',3,'medium_term','Stair work supports functional gait and step quality.'),

      ('edb_Superman','lumbar_extension_tolerance','load_tolerance_gain','increase',3,'medium_term','Superman provides lumbar extension exposure when tolerated.'),
      ('edb_Superman','hip_extension_control','motor_control_gain','improve',3,'medium_term','Superman reinforces hip extension with trunk extension demand.'),
      ('edb_Hyperextensions_Back_Extensions','hip_extension_strength','strength_gain','increase',4,'medium_term','Back extensions strengthen posterior-chain hip extension.'),
      ('edb_Hyperextensions_Back_Extensions','hip_hinge_control','motor_control_gain','improve',3,'medium_term','Back extensions can train controlled hip hinge extension.')
  ) as seed(
    exercise_code,
    capability_code,
    effect_type,
    adaptation_direction,
    effect_strength,
    expected_time_horizon,
    rationale
  )
)
insert into public.exercise_effects (
  exercise_id,
  capability_id,
  effect_type,
  adaptation_direction,
  effect_strength,
  expected_time_horizon,
  dose_response,
  rationale,
  guideline_name,
  evidence_source,
  evidence_url,
  evidence_level,
  metadata,
  status
)
select
  e.id,
  mc.id,
  es.effect_type,
  es.adaptation_direction,
  es.effect_strength,
  es.expected_time_horizon,
  jsonb_build_object(
    'dose_principle', 'FITT-VP individualized progression',
    'monitor', 'symptom response, movement quality, and next-day response'
  ),
  es.rationale,
  'ACSM FITT-VP / APTA-JOSPT rehabilitation exercise principles',
  'Exercise prescription should match type, intensity, volume, and progression to current capability and clinical presentation.',
  'https://www.acsm.org/docs/default-source/publications-files/acsms-exercise-testing-prescription.pdf',
  'guideline_principle',
  jsonb_build_object('seed_wave', 'exercise_effects_v1_2026_05_27'),
  'active'
from effect_seed es
join public.exercises e
  on e.exercise_code = es.exercise_code
join public.movement_capabilities mc
  on mc.capability_code = es.capability_code
on conflict (exercise_id, capability_id, effect_type)
  where status = 'active'
do update set
  adaptation_direction = excluded.adaptation_direction,
  effect_strength = excluded.effect_strength,
  expected_time_horizon = excluded.expected_time_horizon,
  dose_response = excluded.dose_response,
  rationale = excluded.rationale,
  guideline_name = excluded.guideline_name,
  evidence_source = excluded.evidence_source,
  evidence_url = excluded.evidence_url,
  evidence_level = excluded.evidence_level,
  metadata = public.exercise_effects.metadata || excluded.metadata,
  updated_at = now();
