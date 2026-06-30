-- Exercise requirement seed wave 2.
-- Adds broader capability labels across core, lower-extremity, ankle balance,
-- cervical control, and upper-quarter strengthening without duplicating active rows.

with requirement_seed as (
  select * from (values
    ('pk_cat_cow','thoracic_extension_mobility','target',2::numeric,null::numeric,'level',null::boolean,2,null::text,'low','Cat-cow targets thoracic extension mobility.'),
    ('pk_cat_cow','lumbar_flexion_tolerance','required',2,null,'level',null,2,null,'low','Cat-cow requires basic lumbar flexion tolerance.'),
    ('pk_cat_cow','lumbar_extension_tolerance','required',2,null,'level',null,2,null,'low','Cat-cow requires basic lumbar extension tolerance.'),
    ('pk_cat_cow','breathing_diaphragmatic_control','target',2,null,'level',null,2,null,'info','Cat-cow can reinforce breathing-movement coordination.'),

    ('edb_Alternate_Heel_Touchers','lateral_trunk_stability','required',2,null,'level',null,2,null,'moderate','Heel touchers require lateral trunk control.'),
    ('edb_Alternate_Heel_Touchers','trunk_rotary_control','target',2,null,'level',null,2,null,'moderate','Heel touchers target controlled trunk rotation.'),
    ('edb_Alternate_Heel_Touchers','lumbar_neutral_control','required',2,null,'level',null,2,null,'moderate','Heel touchers require avoiding excessive lumbar compensation.'),

    ('edb_90_90_Hamstring','hip_flexion_rom','target',70,null,'deg',null,2,null,'low','90/90 hamstring work targets hip flexion mobility.'),
    ('edb_90_90_Hamstring','knee_extension_rom','target',0,null,'deg',null,2,null,'low','90/90 hamstring work targets terminal knee extension tolerance.'),
    ('edb_All_Fours_Quad_Stretch','knee_flexion_rom','target',110,null,'deg',null,2,null,'low','All-fours quad stretch targets knee flexion mobility.'),
    ('edb_All_Fours_Quad_Stretch','hip_extension_control','target',2,null,'level',null,2,null,'low','All-fours quad stretch requires gentle hip extension positioning.'),

    ('edb_Bodyweight_Squat','ankle_dorsiflexion_rom','required',10,null,'deg',null,3,null,'moderate','Bodyweight squat requires ankle dorsiflexion.'),
    ('edb_Bodyweight_Squat','squat_depth_control','required',2,null,'level',null,3,null,'moderate','Bodyweight squat requires basic squat control.'),
    ('edb_Bodyweight_Squat','quadriceps_strength','target',3,null,'grade',null,3,null,'moderate','Bodyweight squat targets quadriceps strength.'),
    ('edb_Bodyweight_Squat','hip_extension_strength','target',3,null,'grade',null,3,null,'moderate','Bodyweight squat targets hip extension strength.'),

    ('edb_Barbell_Squat','ankle_dorsiflexion_rom','required',12,null,'deg',null,4,null,'high','Loaded squat requires adequate ankle dorsiflexion.'),
    ('edb_Barbell_Squat','squat_depth_control','required',3,null,'level',null,4,null,'high','Loaded squat requires reliable squat depth and control.'),
    ('edb_Barbell_Squat','lumbar_neutral_control','required',3,null,'level',null,4,null,'high','Loaded squat requires lumbar neutral control.'),
    ('edb_Barbell_Squat','quadriceps_strength','target',4,null,'grade',null,4,null,'high','Loaded squat targets quadriceps strength.'),

    ('edb_Box_Squat','squat_depth_control','required',2,null,'level',null,3,null,'moderate','Box squat requires controlled squat patterning.'),
    ('edb_Box_Squat','lumbar_neutral_control','required',3,null,'level',null,3,null,'moderate','Box squat requires lumbar neutral control.'),
    ('edb_Box_Squat','quadriceps_strength','target',3,null,'grade',null,3,null,'moderate','Box squat targets quadriceps strength.'),

    ('edb_Bodyweight_Walking_Lunge','single_leg_balance_seconds','required',8,null,'sec',null,3,null,'moderate','Walking lunge requires single-leg balance.'),
    ('edb_Bodyweight_Walking_Lunge','ankle_dorsiflexion_rom','required',10,null,'deg',null,3,null,'moderate','Walking lunge requires ankle dorsiflexion.'),
    ('edb_Bodyweight_Walking_Lunge','quadriceps_strength','required',3,null,'grade',null,3,null,'moderate','Walking lunge requires quadriceps strength.'),
    ('edb_Bodyweight_Walking_Lunge','hip_extension_control','target',3,null,'level',null,3,null,'moderate','Walking lunge targets hip extension control.'),

    ('edb_Barbell_Lunge','single_leg_balance_seconds','required',10,null,'sec',null,4,null,'high','Loaded lunge requires single-leg balance.'),
    ('edb_Barbell_Lunge','quadriceps_strength','required',4,null,'grade',null,4,null,'high','Loaded lunge requires quadriceps strength.'),
    ('edb_Barbell_Lunge','lumbar_neutral_control','required',3,null,'level',null,4,null,'high','Loaded lunge requires trunk control under load.'),

    ('edb_Barbell_Step_Ups','single_leg_balance_seconds','required',8,null,'sec',null,3,null,'moderate','Step-ups require single-leg stance control.'),
    ('edb_Barbell_Step_Ups','quadriceps_strength','required',3,null,'grade',null,3,null,'moderate','Step-ups require quadriceps strength.'),
    ('edb_Barbell_Step_Ups','hip_extension_strength','target',3,null,'grade',null,3,null,'moderate','Step-ups target hip extension strength.'),

    ('edb_Balance_Board','single_leg_balance_seconds','required',10,null,'sec',null,3,null,'moderate','Balance board work requires baseline stance control.'),
    ('edb_Balance_Board','ankle_proprioception_control','target',3,null,'level',null,3,null,'moderate','Balance board work targets ankle proprioception.'),
    ('edb_Balance_Board','weight_bearing_tolerance','required',75,null,'percent',null,3,null,'moderate','Balance board work requires lower-limb weight-bearing tolerance.'),

    ('edb_Calf_Raises_-_With_Bands','ankle_dorsiflexion_rom','required',5,null,'deg',null,2,null,'low','Band calf raises require basic ankle mobility.'),
    ('edb_Calf_Raises_-_With_Bands','calf_strength_endurance','target',10,null,'reps',null,2,null,'moderate','Band calf raises target calf endurance.'),
    ('edb_Calf_Raises_-_With_Bands','single_leg_balance_seconds','target',5,null,'sec',null,2,null,'low','Band calf raises can reinforce stance balance.'),

    ('edb_Calf_Stretch_Hands_Against_Wall','ankle_dorsiflexion_rom','target',10,null,'deg',null,2,null,'low','Wall calf stretch targets ankle dorsiflexion.'),
    ('edb_Calf_Stretch_Hands_Against_Wall','weight_bearing_tolerance','required',50,null,'percent',null,2,null,'low','Wall calf stretch requires partial weight-bearing tolerance.'),

    ('EX_ANKL_BAL_001','weight_bearing_tolerance','required',50,null,'percent',null,1,null,'low','Eyes-open static balance requires basic weight bearing.'),
    ('EX_ANKL_BAL_001','single_leg_balance_seconds','target',10,null,'sec',null,1,null,'low','Eyes-open static balance targets single-leg balance.'),
    ('EX_ANKL_BAL_002','single_leg_balance_seconds','required',10,null,'sec',null,2,null,'moderate','Eyes-closed balance requires baseline single-leg stance.'),
    ('EX_ANKL_BAL_002','ankle_proprioception_control','target',2,null,'level',null,2,null,'moderate','Eyes-closed balance targets ankle proprioception.'),
    ('EX_ANKL_BAL_003','single_leg_balance_seconds','required',10,null,'sec',null,2,null,'moderate','Foam balance requires baseline single-leg stance.'),
    ('EX_ANKL_BAL_003','ankle_proprioception_control','target',3,null,'level',null,2,null,'moderate','Foam balance targets ankle proprioception.'),
    ('EX_ANKL_BAL_006','single_leg_balance_seconds','required',15,null,'sec',null,3,null,'moderate','Star excursion requires single-leg stance capacity.'),
    ('EX_ANKL_BAL_006','ankle_proprioception_control','target',3,null,'level',null,3,null,'moderate','Star excursion targets ankle proprioception.'),
    ('EX_ANKL_BAL_006','ankle_dorsiflexion_rom','required',10,null,'deg',null,3,null,'moderate','Star excursion requires ankle dorsiflexion.'),
    ('EX_ANKL_BAL_007','single_leg_balance_seconds','required',15,null,'sec',null,3,null,'moderate','Y-balance requires single-leg stance capacity.'),
    ('EX_ANKL_BAL_007','ankle_proprioception_control','target',3,null,'level',null,3,null,'moderate','Y-balance targets ankle proprioception.'),
    ('EX_ANKL_BAL_007','ankle_dorsiflexion_rom','required',10,null,'deg',null,3,null,'moderate','Y-balance requires ankle dorsiflexion.'),

    ('EX_ANKL_FNC_007','ankle_dorsiflexion_rom','required',10,null,'deg',null,3,null,'moderate','Lunge with rotation requires ankle dorsiflexion.'),
    ('EX_ANKL_FNC_007','trunk_rotary_control','target',3,null,'level',null,3,null,'moderate','Lunge with rotation targets trunk rotary control.'),
    ('EX_ANKL_FNC_007','weight_bearing_tolerance','required',75,null,'percent',null,3,null,'moderate','Lunge with rotation requires weight-bearing tolerance.'),
    ('EX_ANKL_FNC_008','gait_without_limp','required',null,null,null,true,2,null,'moderate','Step-over work requires gait without significant limp.'),
    ('EX_ANKL_FNC_008','single_leg_balance_seconds','required',8,null,'sec',null,2,null,'moderate','Step-over work requires stance balance.'),
    ('EX_ANKL_FNC_008','ankle_dorsiflexion_rom','required',8,null,'deg',null,2,null,'moderate','Step-over work requires ankle dorsiflexion.'),
    ('EX_ANKL_STB_002','weight_bearing_tolerance','required',75,null,'percent',null,2,null,'moderate','Balance board stabilization requires weight-bearing tolerance.'),
    ('EX_ANKL_STB_002','ankle_proprioception_control','target',3,null,'level',null,2,null,'moderate','Balance board stabilization targets ankle proprioception.'),

    ('edb_Bent_Over_Barbell_Row','hip_hinge_control','required',3,null,'level',null,3,null,'moderate','Bent-over row requires hip hinge control.'),
    ('edb_Bent_Over_Barbell_Row','lumbar_neutral_control','required',3,null,'level',null,3,null,'moderate','Bent-over row requires lumbar neutral control.'),
    ('edb_Bent_Over_Barbell_Row','scapular_control','target',3,null,'level',null,3,null,'moderate','Bent-over row targets scapular control.'),
    ('edb_Bodyweight_Mid_Row','scapular_control','required',2,null,'level',null,2,null,'moderate','Bodyweight row requires scapular control.'),
    ('edb_Bodyweight_Mid_Row','shoulder_stability','target',2,null,'level',null,2,null,'moderate','Bodyweight row targets shoulder stability.'),
    ('edb_Bodyweight_Mid_Row','grip_strength','target',3,null,'grade',null,2,null,'low','Bodyweight row uses grip strength.'),

    ('edb_Anti-Gravity_Press','shoulder_flexion_rom','required',120,null,'deg',null,2,null,'moderate','Anti-gravity press requires shoulder flexion ROM.'),
    ('edb_Anti-Gravity_Press','shoulder_stability','target',2,null,'level',null,2,null,'moderate','Anti-gravity press targets shoulder stability.'),
    ('edb_Cable_Shoulder_Press','shoulder_flexion_rom','required',140,null,'deg',null,3,null,'moderate','Cable shoulder press requires shoulder flexion ROM.'),
    ('edb_Cable_Shoulder_Press','shoulder_stability','required',3,null,'level',null,3,null,'moderate','Cable shoulder press requires shoulder stability.'),
    ('edb_Cable_Shoulder_Press','scapular_control','target',3,null,'level',null,3,null,'moderate','Cable shoulder press targets scapular control.'),
    ('edb_Arnold_Dumbbell_Press','shoulder_flexion_rom','required',150,null,'deg',null,4,null,'high','Arnold press requires overhead shoulder mobility.'),
    ('edb_Arnold_Dumbbell_Press','shoulder_external_rotation_rom','required',60,null,'deg',null,4,null,'high','Arnold press requires shoulder external rotation.'),
    ('edb_Arnold_Dumbbell_Press','shoulder_stability','required',3,null,'level',null,4,null,'high','Arnold press requires shoulder stability.'),

    ('EX_CSPN_BAL_001','cervical_deep_flexor_control','target',2,null,'level',null,1,null,'low','Cervical eyes-open balance targets deep neck flexor control.'),
    ('EX_CSPN_BAL_001','cervical_isometric_tolerance','required',2,null,'level',null,1,null,'low','Cervical eyes-open balance requires basic isometric tolerance.'),
    ('EX_CSPN_BAL_002','cervical_deep_flexor_control','required',2,null,'level',null,2,null,'moderate','Eyes-closed cervical balance requires neck control.'),
    ('EX_CSPN_BAL_002','cervical_isometric_tolerance','required',2,null,'level',null,2,null,'moderate','Eyes-closed cervical balance requires isometric tolerance.'),
    ('EX_CSPN_FNC_007','cervical_rotation_rom','required',45,null,'deg',null,3,null,'moderate','Cervical lunge rotation requires cervical rotation ROM.'),
    ('EX_CSPN_FNC_007','trunk_rotary_control','target',3,null,'level',null,3,null,'moderate','Cervical lunge rotation targets trunk rotary control.'),
    ('EX_CSPN_STB_013','cervical_isometric_tolerance','required',3,null,'level',null,3,null,'moderate','Cervical anti-rotation press requires isometric neck tolerance.'),
    ('EX_CSPN_STB_013','cervical_deep_flexor_control','target',3,null,'level',null,3,null,'moderate','Cervical anti-rotation press targets deep neck flexor control.'),
    ('EX_CSPN_STB_013','trunk_rotary_control','required',3,null,'level',null,3,null,'moderate','Cervical anti-rotation press requires trunk anti-rotation control.')
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
  jsonb_build_object('seed_wave', 'exercise_requirements_wave2'),
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
