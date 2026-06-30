-- Exercise requirement seed wave 3.
-- Broadens requirements for common mobility, core-control, pull/row, and posterior-chain exercises.

with requirement_seed as (
  select * from (values
    ('edb_Childs_Pose','lumbar_flexion_tolerance','target',2::numeric,null::numeric,'level',null::boolean,2,null::text,'low','Child pose targets tolerable lumbar flexion.'),
    ('edb_Childs_Pose','thoracic_extension_mobility','target',2,null,'level',null,2,null,'low','Child pose can support thoracic mobility and relaxed breathing.'),
    ('edb_Childs_Pose','breathing_diaphragmatic_control','target',2,null,'level',null,2,null,'info','Child pose can reinforce diaphragmatic breathing.'),

    ('edb_Chair_Lower_Back_Stretch','lumbar_flexion_tolerance','target',2,null,'level',null,1,null,'low','Chair lower back stretch targets lumbar flexion tolerance.'),
    ('edb_Chair_Lower_Back_Stretch','breathing_diaphragmatic_control','target',1,null,'level',null,1,null,'info','Seated stretch can pair with relaxed breathing.'),
    ('edb_Hug_Knees_To_Chest','lumbar_flexion_tolerance','target',2,null,'level',null,1,null,'low','Hug knees to chest targets lumbar flexion tolerance.'),
    ('edb_Hug_Knees_To_Chest','hip_flexion_rom','target',90,null,'deg',null,1,null,'low','Hug knees to chest targets hip flexion mobility.'),
    ('edb_Dynamic_Back_Stretch','lumbar_flexion_tolerance','required',2,null,'level',null,2,null,'low','Dynamic back stretch requires basic lumbar flexion tolerance.'),
    ('edb_Dynamic_Back_Stretch','thoracic_extension_mobility','target',2,null,'level',null,2,null,'low','Dynamic back stretch targets spinal mobility.'),
    ('edb_Side-Lying_Floor_Stretch','lumbar_flexion_tolerance','target',2,null,'level',null,1,null,'low','Side-lying floor stretch targets lumbar flexion tolerance.'),
    ('edb_Side-Lying_Floor_Stretch','thoracic_extension_mobility','target',2,null,'level',null,1,null,'low','Side-lying floor stretch targets thoracic mobility.'),
    ('edb_Standing_Pelvic_Tilt','lumbopelvic_control','target',2,null,'level',null,2,null,'low','Standing pelvic tilt targets lumbopelvic control.'),
    ('edb_Standing_Pelvic_Tilt','lumbar_neutral_control','required',2,null,'level',null,2,null,'low','Standing pelvic tilt requires basic lumbar neutral awareness.'),

    ('edb_Dead_Bug','lumbar_neutral_control','required',3,null,'level',null,3,null,'moderate','Dead bug requires lumbar neutral control.'),
    ('edb_Dead_Bug','lumbopelvic_control','required',3,null,'level',null,3,null,'moderate','Dead bug requires lumbopelvic control under limb movement.'),
    ('edb_Dead_Bug','breathing_diaphragmatic_control','target',2,null,'level',null,2,null,'info','Dead bug can reinforce breathing with trunk control.'),

    ('edb_Ab_Roller','lumbar_neutral_control','required',4,null,'level',null,4,null,'high','Ab roller requires strong lumbar neutral control.'),
    ('edb_Ab_Roller','lumbopelvic_stability','required',4,null,'level',null,4,null,'high','Ab roller requires lumbopelvic stability.'),
    ('edb_Barbell_Ab_Rollout_-_On_Knees','lumbar_neutral_control','required',4,null,'level',null,4,null,'high','Kneeling rollout requires strong lumbar neutral control.'),
    ('edb_Barbell_Ab_Rollout_-_On_Knees','shoulder_stability','required',3,null,'level',null,4,null,'high','Kneeling rollout requires shoulder stability.'),

    ('edb_Superman','lumbar_extension_tolerance','required',3,null,'level',null,3,null,'moderate','Superman requires lumbar extension tolerance.'),
    ('edb_Superman','hip_extension_control','target',3,null,'level',null,3,null,'moderate','Superman targets hip extension control.'),
    ('edb_Hyperextensions_Back_Extensions','lumbar_extension_tolerance','required',3,null,'level',null,3,null,'moderate','Back extension requires lumbar extension tolerance.'),
    ('edb_Hyperextensions_Back_Extensions','hip_hinge_control','target',3,null,'level',null,3,null,'moderate','Back extension targets hip hinge control.'),
    ('edb_Hyperextensions_Back_Extensions','hip_extension_strength','target',3,null,'grade',null,3,null,'moderate','Back extension targets posterior-chain strength.'),

    ('edb_Barbell_Deadlift','hip_hinge_control','required',4,null,'level',null,4,null,'high','Deadlift requires hip hinge control.'),
    ('edb_Barbell_Deadlift','lumbar_neutral_control','required',4,null,'level',null,4,null,'high','Deadlift requires lumbar neutral control under load.'),
    ('edb_Barbell_Deadlift','hip_extension_strength','target',4,null,'grade',null,4,null,'high','Deadlift targets hip extension strength.'),
    ('edb_Cable_Deadlifts','hip_hinge_control','required',3,null,'level',null,3,null,'moderate','Cable deadlift requires hip hinge control.'),
    ('edb_Cable_Deadlifts','lumbar_neutral_control','required',3,null,'level',null,3,null,'moderate','Cable deadlift requires lumbar neutral control.'),
    ('edb_Cable_Deadlifts','hip_extension_strength','target',3,null,'grade',null,3,null,'moderate','Cable deadlift targets hip extension strength.'),

    ('edb_Band_Assisted_Pull-Up','scapular_control','required',3,null,'level',null,3,null,'moderate','Band-assisted pull-up requires scapular control.'),
    ('edb_Band_Assisted_Pull-Up','shoulder_stability','required',3,null,'level',null,3,null,'moderate','Band-assisted pull-up requires shoulder stability.'),
    ('edb_Band_Assisted_Pull-Up','grip_strength','required',3,null,'grade',null,3,null,'moderate','Band-assisted pull-up requires grip strength.'),
    ('edb_Pullups','scapular_control','required',4,null,'level',null,4,null,'high','Pull-up requires scapular control.'),
    ('edb_Pullups','shoulder_stability','required',4,null,'level',null,4,null,'high','Pull-up requires shoulder stability.'),
    ('edb_Pullups','grip_strength','required',4,null,'grade',null,4,null,'high','Pull-up requires grip strength.'),
    ('edb_Dumbbell_Incline_Row','scapular_control','target',3,null,'level',null,3,null,'moderate','Dumbbell incline row targets scapular control.'),
    ('edb_Dumbbell_Incline_Row','shoulder_stability','target',3,null,'level',null,3,null,'moderate','Dumbbell incline row targets shoulder stability.'),
    ('edb_One-Arm_Dumbbell_Row','scapular_control','required',3,null,'level',null,3,null,'moderate','One-arm dumbbell row requires scapular control.'),
    ('edb_One-Arm_Dumbbell_Row','trunk_rotary_control','required',3,null,'level',null,3,null,'moderate','One-arm dumbbell row requires trunk anti-rotation control.'),
    ('edb_One-Arm_Dumbbell_Row','grip_strength','target',3,null,'grade',null,3,null,'moderate','One-arm dumbbell row uses grip strength.'),

    ('edb_Chair_Upper_Body_Stretch','shoulder_flexion_rom','target',120,null,'deg',null,1,null,'low','Chair upper body stretch targets shoulder flexion range.'),
    ('edb_Chair_Upper_Body_Stretch','thoracic_extension_mobility','target',2,null,'level',null,1,null,'low','Chair upper body stretch targets thoracic mobility.'),
    ('edb_Overhead_Lat','shoulder_flexion_rom','target',140,null,'deg',null,2,null,'low','Overhead lat stretch targets shoulder flexion range.'),
    ('edb_Overhead_Lat','thoracic_extension_mobility','target',2,null,'level',null,2,null,'low','Overhead lat stretch supports thoracic extension mobility.'),
    ('edb_Chest_And_Front_Of_Shoulder_Stretch','shoulder_external_rotation_rom','target',45,null,'deg',null,2,null,'low','Chest/front shoulder stretch targets shoulder external rotation.'),
    ('edb_Chest_And_Front_Of_Shoulder_Stretch','shoulder_flexion_rom','target',120,null,'deg',null,2,null,'low','Chest/front shoulder stretch targets shoulder flexion mobility.'),

    ('pk_foam_roller_thoracic','thoracic_extension_mobility','target',3,null,'level',null,2,null,'low','Foam roller thoracic extension targets thoracic extension mobility.'),
    ('pk_foam_roller_thoracic','shoulder_flexion_rom','target',120,null,'deg',null,2,null,'low','Thoracic extension can support overhead shoulder flexion.'),

    ('EX_KNEE_STR_011','hip_flexion_rom','target',90,null,'deg',null,2,null,'low','Figure-four stretch targets hip flexion positioning.'),
    ('EX_KNEE_STR_011','hip_abduction_strength','target',2,null,'grade',null,2,null,'info','Figure-four stretch can support hip abduction control context.'),
    ('EX_KNEE_STR_013','hip_flexion_rom','target',90,null,'deg',null,2,null,'low','Cross-body knee pull targets hip flexion mobility.'),
    ('EX_KNEE_STR_013','lumbar_flexion_tolerance','required',2,null,'level',null,2,null,'low','Cross-body knee pull requires lumbar flexion tolerance.'),
    ('EX_KNEE_STR_015','knee_flexion_rom','target',110,null,'deg',null,2,null,'low','Foam roller quadriceps release supports knee flexion mobility.'),
    ('EX_KNEE_STR_015','quadriceps_strength','target',2,null,'grade',null,2,null,'info','Quadriceps release is contextual to quadriceps capacity.'),

    ('EX_ANKL_STR_003','ankle_dorsiflexion_rom','target',10,null,'deg',null,1,null,'low','Assisted strap stretch targets ankle dorsiflexion.'),
    ('EX_ANKL_STR_004','ankle_dorsiflexion_rom','target',10,null,'deg',null,1,null,'low','Self mobilization stretch targets ankle dorsiflexion.'),
    ('EX_ANKL_STR_012','ankle_dorsiflexion_rom','target',10,null,'deg',null,2,null,'low','Wall-assisted ankle stretch targets ankle dorsiflexion.'),
    ('EX_ANKL_STB_008','single_leg_balance_seconds','required',10,null,'sec',null,2,null,'moderate','Single-leg stance requires single-leg balance duration.'),
    ('EX_ANKL_STB_008','ankle_proprioception_control','target',2,null,'level',null,2,null,'moderate','Single-leg stance targets ankle proprioception control.'),
    ('EX_ANKL_FNC_001','weight_bearing_tolerance','required',75,null,'percent',null,2,null,'moderate','Sit-to-stand requires lower-limb weight-bearing tolerance.'),
    ('EX_ANKL_FNC_001','quadriceps_strength','required',3,null,'grade',null,2,null,'moderate','Sit-to-stand requires quadriceps strength.'),
    ('EX_ANKL_FNC_002','gait_without_limp','required',null,null,null,true,2,null,'moderate','Stair climbing requires gait without significant limp.'),
    ('EX_ANKL_FNC_002','single_leg_balance_seconds','required',8,null,'sec',null,2,null,'moderate','Stair climbing requires single-leg stance control.'),
    ('EX_ANKL_FNC_002','quadriceps_strength','required',3,null,'grade',null,2,null,'moderate','Stair climbing requires quadriceps strength.')
  ) as seed(
    exercise_code,
    capability_code,
    requirement_role,
    min_value,
    max_value,
    value_unit,
    required_boolean,
    requirement_level,
    laterality,
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
  rs.required_boolean,
  rs.requirement_level,
  rs.laterality,
  rs.severity,
  rs.rationale,
  'expert_seed_mvp',
  jsonb_build_object('seed_wave', 'exercise_requirements_wave3'),
  'active'
from requirement_seed rs
join public.exercises e on e.exercise_code = rs.exercise_code
join public.movement_capabilities mc on mc.capability_code = rs.capability_code
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
  updated_at = now();
