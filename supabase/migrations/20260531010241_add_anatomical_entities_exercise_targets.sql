-- Normalize anatomy references for exercise reasoning.
-- Existing body_site_registry, muscle_reference, and joint_reference remain
-- the detailed reference sources. anatomical_entities is the shared index used
-- by movement/exercise features.

create table if not exists public.anatomical_entities (
  id uuid primary key default gen_random_uuid(),
  entity_code text not null,
  entity_type text not null,
  display_name text not null,
  display_name_ko text,
  body_region text,
  body_site_code text references public.body_site_registry(code) on delete set null,
  source_table text,
  source_id uuid,
  source_code text,
  laterality_applicable boolean not null default false,
  parent_entity_id uuid references public.anatomical_entities(id) on delete set null,
  synonyms text[] not null default '{}'::text[],
  properties jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint anatomical_entities_code_unique unique (entity_code),
  constraint anatomical_entities_code_nonempty check (length(trim(entity_code)) > 0),
  constraint anatomical_entities_type_check check (
    entity_type = any (array['body_site','muscle','joint','bone','ligament','tendon','nerve','region','other']::text[])
  ),
  constraint anatomical_entities_source_check check (
    source_table is null
    or source_table = any (array['body_site_registry','muscle_reference','joint_reference','manual_seed']::text[])
  ),
  constraint anatomical_entities_status_check check (
    status = any (array['draft','active','deprecated']::text[])
  )
);

create table if not exists public.exercise_anatomical_targets (
  id uuid primary key default gen_random_uuid(),
  exercise_id integer not null references public.exercises(id) on delete cascade,
  anatomical_entity_id uuid not null references public.anatomical_entities(id) on delete cascade,
  target_role text not null,
  target_priority integer not null default 3,
  laterality text,
  load_type text,
  contraction_type text,
  rationale text,
  evidence_level text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_anatomical_targets_role_check check (
    target_role = any (array[
      'primary_muscle',
      'secondary_muscle',
      'stabilizer',
      'mobility_region',
      'joint_motion',
      'load_bearing_joint',
      'stretch_target',
      'body_region'
    ]::text[])
  ),
  constraint exercise_anatomical_targets_priority_check check (target_priority between 1 and 5),
  constraint exercise_anatomical_targets_laterality_check check (
    laterality is null or laterality = any (array['left','right','bilateral','either']::text[])
  ),
  constraint exercise_anatomical_targets_load_type_check check (
    load_type is null
    or load_type = any (array['open_chain','closed_chain','weight_bearing','non_weight_bearing','isometric','dynamic','stretch','mixed']::text[])
  ),
  constraint exercise_anatomical_targets_contraction_check check (
    contraction_type is null
    or contraction_type = any (array['isometric','concentric','eccentric','isotonic','mobility','stability','mixed']::text[])
  ),
  constraint exercise_anatomical_targets_status_check check (
    status = any (array['draft','active','deprecated']::text[])
  )
);

create index if not exists idx_anatomical_entities_type_region
  on public.anatomical_entities (entity_type, body_region, status);

create index if not exists idx_anatomical_entities_body_site
  on public.anatomical_entities (body_site_code, status)
  where body_site_code is not null;

create index if not exists idx_exercise_anatomical_targets_exercise
  on public.exercise_anatomical_targets (exercise_id, status, target_role, target_priority);

create index if not exists idx_exercise_anatomical_targets_entity
  on public.exercise_anatomical_targets (anatomical_entity_id, status, target_role);

create unique index if not exists uq_exercise_anatomical_targets_active_key
  on public.exercise_anatomical_targets (exercise_id, anatomical_entity_id, target_role)
  where status = 'active';

drop trigger if exists anatomical_entities_set_updated_at
  on public.anatomical_entities;

create trigger anatomical_entities_set_updated_at
  before update on public.anatomical_entities
  for each row execute function public.set_updated_at();

drop trigger if exists exercise_anatomical_targets_set_updated_at
  on public.exercise_anatomical_targets;

create trigger exercise_anatomical_targets_set_updated_at
  before update on public.exercise_anatomical_targets
  for each row execute function public.set_updated_at();

alter table public.anatomical_entities enable row level security;
alter table public.exercise_anatomical_targets enable row level security;

drop policy if exists anatomical_entities_read_all
  on public.anatomical_entities;

create policy anatomical_entities_read_all
  on public.anatomical_entities
  for select
  to authenticated
  using (true);

drop policy if exists anatomical_entities_service_write
  on public.anatomical_entities;

create policy anatomical_entities_service_write
  on public.anatomical_entities
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists exercise_anatomical_targets_read_all
  on public.exercise_anatomical_targets;

create policy exercise_anatomical_targets_read_all
  on public.exercise_anatomical_targets
  for select
  to authenticated
  using (true);

drop policy if exists exercise_anatomical_targets_service_write
  on public.exercise_anatomical_targets;

create policy exercise_anatomical_targets_service_write
  on public.exercise_anatomical_targets
  for all
  to service_role
  using (true)
  with check (true);

insert into public.anatomical_entities (
  entity_code,
  entity_type,
  display_name,
  display_name_ko,
  body_region,
  body_site_code,
  source_table,
  source_id,
  source_code,
  laterality_applicable,
  synonyms,
  properties,
  status
)
select
  'body_site:' || lower(bsr.code),
  'body_site',
  bsr.display,
  bsr.display_korean,
  lower(bsr.code),
  bsr.code,
  'body_site_registry',
  bsr.id,
  bsr.code,
  coalesce(bsr.laterality_applicable, false),
  coalesce(bsr.synonyms, '{}'::text[]),
  jsonb_build_object(
    'snomed_code', bsr.snomed_code,
    'body_system', bsr.body_system,
    'parent_code', bsr.parent_code
  ),
  case when coalesce(bsr.is_active, true) then 'active' else 'deprecated' end
from public.body_site_registry bsr
where bsr.code is not null
on conflict (entity_code) do update set
  display_name = excluded.display_name,
  display_name_ko = excluded.display_name_ko,
  body_region = excluded.body_region,
  body_site_code = excluded.body_site_code,
  source_table = excluded.source_table,
  source_id = excluded.source_id,
  source_code = excluded.source_code,
  laterality_applicable = excluded.laterality_applicable,
  synonyms = excluded.synonyms,
  properties = excluded.properties,
  status = excluded.status,
  updated_at = now();

insert into public.anatomical_entities (
  entity_code,
  entity_type,
  display_name,
  display_name_ko,
  body_region,
  source_table,
  source_id,
  source_code,
  laterality_applicable,
  synonyms,
  properties,
  status
)
select
  'muscle:' || lower(mr.muscle_code),
  'muscle',
  mr.muscle_name,
  mr.muscle_name_ko,
  mr.body_region,
  'muscle_reference',
  mr.id,
  mr.muscle_code,
  coalesce(mr.body_region not in ('trunk','neck','lumbar','thoracic'), true),
  array_remove(array[mr.muscle_name, mr.muscle_name_ko, mr.muscle_group], null),
  jsonb_build_object(
    'origin', mr.origin,
    'insertion', mr.insertion,
    'primary_action', mr.primary_action,
    'secondary_actions', mr.secondary_actions,
    'nerve', mr.nerve,
    'nerve_root', mr.nerve_root,
    'muscle_group', mr.muscle_group,
    'common_pathologies', mr.common_pathologies,
    'mmt_position', mr.mmt_position,
    'stretch_test', mr.stretch_test
  ),
  'active'
from public.muscle_reference mr
where mr.muscle_code is not null
on conflict (entity_code) do update set
  display_name = excluded.display_name,
  display_name_ko = excluded.display_name_ko,
  body_region = excluded.body_region,
  source_table = excluded.source_table,
  source_id = excluded.source_id,
  source_code = excluded.source_code,
  laterality_applicable = excluded.laterality_applicable,
  synonyms = excluded.synonyms,
  properties = excluded.properties,
  status = excluded.status,
  updated_at = now();

insert into public.anatomical_entities (
  entity_code,
  entity_type,
  display_name,
  display_name_ko,
  body_region,
  body_site_code,
  source_table,
  source_id,
  source_code,
  laterality_applicable,
  synonyms,
  properties,
  status
)
select
  'joint:' || lower(jr.joint_code),
  'joint',
  jr.joint_name,
  jr.joint_name_ko,
  jr.body_region,
  bsr.code,
  'joint_reference',
  jr.id,
  jr.joint_code,
  coalesce(jr.body_region not in ('cervical','thoracic','lumbar','sacral'), true),
  array_remove(array[jr.joint_name, jr.joint_name_ko, jr.joint_type, jr.joint_subtype], null),
  jsonb_build_object(
    'joint_type', jr.joint_type,
    'joint_subtype', jr.joint_subtype,
    'articulating_bones', jr.articulating_bones,
    'movements_allowed', jr.movements_allowed,
    'degrees_of_freedom', jr.degrees_of_freedom,
    'primary_ligaments', jr.primary_ligaments,
    'supporting_muscles', jr.supporting_muscles,
    'common_pathologies', jr.common_pathologies,
    'common_injuries', jr.common_injuries,
    'special_tests', jr.special_tests,
    'close_packed_position', jr.close_packed_position,
    'open_packed_position', jr.open_packed_position,
    'capsular_pattern', jr.capsular_pattern
  ),
  'active'
from public.joint_reference jr
left join public.body_site_registry bsr
  on bsr.code = case
    when jr.body_region = 'shoulder' then 'SHOULDER'
    when jr.body_region = 'hip' then 'HIP'
    when jr.body_region = 'knee' then 'KNEE'
    when jr.body_region = 'ankle' then 'ANKLE'
    when jr.body_region = 'cervical' then 'CERVICAL_SPINE'
    when jr.body_region = 'thoracic' then 'THORACIC_SPINE'
    when jr.body_region = 'lumbar' then 'LUMBAR_SPINE'
    when jr.body_region = 'wrist' then 'WRIST'
    when jr.body_region = 'elbow' then 'ELBOW'
    else null
  end
where jr.joint_code is not null
on conflict (entity_code) do update set
  display_name = excluded.display_name,
  display_name_ko = excluded.display_name_ko,
  body_region = excluded.body_region,
  body_site_code = excluded.body_site_code,
  source_table = excluded.source_table,
  source_id = excluded.source_id,
  source_code = excluded.source_code,
  laterality_applicable = excluded.laterality_applicable,
  synonyms = excluded.synonyms,
  properties = excluded.properties,
  status = excluded.status,
  updated_at = now();

with target_seed as (
  select *
  from (
    values
      ('pk_bird_dog','muscle:multifidus','stabilizer',5,'mixed','stability','Bird dog loads segmental spinal stabilizers.'),
      ('pk_bird_dog','muscle:glut_max','secondary_muscle',4,'open_chain','isotonic','Bird dog includes controlled hip extension.'),
      ('pk_bird_dog','joint:l_l4l5','joint_motion',3,'non_weight_bearing','stability','Bird dog emphasizes lumbar neutral control.'),
      ('pk_bird_dog','joint:sh_st','stabilizer',3,'closed_chain','stability','Quadruped support requires scapulothoracic stability.'),
      ('pk_side_plank','muscle:ext_obl','primary_muscle',5,'closed_chain','isometric','Side plank primarily challenges lateral abdominal wall.'),
      ('pk_side_plank','muscle:int_obl','primary_muscle',5,'closed_chain','isometric','Side plank primarily challenges lateral abdominal wall.'),
      ('pk_side_plank','muscle:glut_med','secondary_muscle',4,'closed_chain','isometric','Hip abductor endurance supports pelvic alignment.'),
      ('pk_side_plank','joint:sh_gh','load_bearing_joint',4,'weight_bearing','isometric','Side plank transmits upper-quarter weight bearing through the shoulder.'),
      ('pk_hip_bridge','muscle:glut_max','primary_muscle',5,'closed_chain','isotonic','Bridge primarily targets hip extension strength.'),
      ('pk_hip_bridge','muscle:bic_fem','secondary_muscle',4,'closed_chain','isotonic','Hamstrings assist hip extension in bridge.'),
      ('pk_hip_bridge','joint:hip','joint_motion',5,'closed_chain','isotonic','Bridge trains hip extension.'),
      ('pk_hip_bridge','joint:l_l5s1','stabilizer',3,'closed_chain','stability','Bridge requires lumbopelvic control.'),
      ('edb_Dead_Bug','muscle:tva','primary_muscle',5,'open_chain','stability','Dead bug emphasizes deep abdominal anti-extension control.'),
      ('edb_Dead_Bug','muscle:rect_abd','secondary_muscle',3,'open_chain','stability','Rectus abdominis assists trunk anti-extension.'),
      ('edb_Dead_Bug','joint:l_l4l5','stabilizer',4,'non_weight_bearing','stability','Dead bug trains lumbar neutral under limb movement.'),
      ('pk_cat_cow','joint:l_l4l5','mobility_region',4,'non_weight_bearing','mobility','Cat-cow mobilizes lumbar flexion and extension.'),
      ('pk_cat_cow','joint:t_t6t7','mobility_region',4,'non_weight_bearing','mobility','Cat-cow mobilizes thoracic extension.'),
      ('edb_Cat_Stretch','joint:l_l4l5','mobility_region',4,'non_weight_bearing','mobility','Cat stretch targets lumbar mobility.'),
      ('edb_Cat_Stretch','joint:t_t6t7','mobility_region',4,'non_weight_bearing','mobility','Cat stretch targets thoracic mobility.'),
      ('edb_Bodyweight_Squat','muscle:glut_max','primary_muscle',5,'closed_chain','isotonic','Squat targets hip extension strength.'),
      ('edb_Bodyweight_Squat','muscle:rect_fem','primary_muscle',4,'closed_chain','isotonic','Squat loads the quadriceps group.'),
      ('edb_Bodyweight_Squat','muscle:vast_med','primary_muscle',4,'closed_chain','isotonic','Squat loads the quadriceps group.'),
      ('edb_Bodyweight_Squat','joint:hip','joint_motion',5,'weight_bearing','isotonic','Squat requires coordinated hip motion.'),
      ('edb_Bodyweight_Squat','joint:kn_tf','load_bearing_joint',5,'weight_bearing','isotonic','Squat is a knee load-bearing pattern.'),
      ('edb_Bodyweight_Squat','joint:an_tc','load_bearing_joint',4,'weight_bearing','isotonic','Squat requires ankle dorsiflexion.'),
      ('pk_calf_raise','muscle:gastroc','primary_muscle',5,'closed_chain','isotonic','Calf raise targets gastrocnemius strength endurance.'),
      ('pk_calf_raise','muscle:soleus','primary_muscle',5,'closed_chain','isotonic','Calf raise targets soleus strength endurance.'),
      ('pk_calf_raise','joint:an_tc','joint_motion',5,'weight_bearing','isotonic','Calf raise trains ankle plantarflexion.'),
      ('EX_ANKL_STB_008','joint:an_tc','load_bearing_joint',4,'weight_bearing','stability','Single-leg stance trains ankle stability.'),
      ('EX_ANKL_STB_008','muscle:tib_ant','stabilizer',3,'closed_chain','stability','Tibialis anterior assists ankle postural control.'),
      ('EX_ANKL_STB_008','muscle:peroneus_l','stabilizer',4,'closed_chain','stability','Peroneals contribute to lateral ankle stability.'),
      ('EX_ANKL_STR_012','joint:an_tc','mobility_region',5,'weight_bearing','mobility','Wall ankle stretch targets talocrural dorsiflexion.'),
      ('EX_ANKL_STR_012','muscle:gastroc','stretch_target',4,'stretch','mobility','Wall ankle stretch lengthens the gastrocnemius-soleus complex.'),
      ('edb_Barbell_Deadlift','muscle:glut_max','primary_muscle',5,'closed_chain','isotonic','Deadlift strongly targets hip extension.'),
      ('edb_Barbell_Deadlift','muscle:bic_fem','primary_muscle',4,'closed_chain','isotonic','Deadlift loads the posterior chain.'),
      ('edb_Barbell_Deadlift','muscle:erect_long','stabilizer',5,'closed_chain','stability','Deadlift requires trunk extensor stiffness.'),
      ('edb_Barbell_Deadlift','joint:hip','joint_motion',5,'weight_bearing','isotonic','Deadlift is a hip hinge pattern.'),
      ('edb_Barbell_Deadlift','joint:l_l5s1','stabilizer',4,'weight_bearing','stability','Deadlift requires lumbar neutral control.'),
      ('edb_Pullups','muscle:lat_dorsi','primary_muscle',5,'open_chain','isotonic','Pull-up strongly targets latissimus dorsi.'),
      ('edb_Pullups','muscle:biceps','secondary_muscle',4,'open_chain','isotonic','Pull-up requires elbow flexor contribution.'),
      ('edb_Pullups','joint:sh_gh','joint_motion',5,'open_chain','isotonic','Pull-up loads vertical shoulder pulling.'),
      ('edb_Pullups','joint:sh_st','stabilizer',4,'open_chain','stability','Scapulothoracic control is central in pull-up.'),
      ('edb_Pallof_Press_With_Rotation','muscle:ext_obl','primary_muscle',5,'mixed','stability','Pallof press variation trains trunk rotation and anti-rotation.'),
      ('edb_Pallof_Press_With_Rotation','muscle:int_obl','primary_muscle',5,'mixed','stability','Pallof press variation trains trunk rotation and anti-rotation.'),
      ('edb_Pallof_Press_With_Rotation','joint:l_l4l5','stabilizer',4,'mixed','stability','Pallof press requires lumbar-pelvic control.'),
      ('edb_Monster_Walk','muscle:glut_med','primary_muscle',5,'closed_chain','isotonic','Monster walk targets hip abductors.'),
      ('edb_Monster_Walk','muscle:tfl','secondary_muscle',3,'closed_chain','isotonic','TFL assists hip abduction.'),
      ('edb_Monster_Walk','joint:hip','joint_motion',4,'weight_bearing','isotonic','Monster walk trains frontal-plane hip control.'),
      ('pk_clam_shell','muscle:glut_med','primary_muscle',5,'open_chain','isotonic','Clamshell targets gluteus medius.'),
      ('pk_clam_shell','muscle:glut_min','secondary_muscle',4,'open_chain','isotonic','Clamshell recruits deep hip abductors.'),
      ('pk_clam_shell','joint:hip','joint_motion',4,'open_chain','isotonic','Clamshell trains hip external rotation/abduction.'),
      ('pk_chin_tuck','muscle:dnf','primary_muscle',5,'non_weight_bearing','isometric','Chin tuck targets deep neck flexors.'),
      ('pk_chin_tuck','joint:c_ao','joint_motion',4,'non_weight_bearing','stability','Chin tuck emphasizes craniocervical flexion control.'),
      ('pk_shoulder_external_rotation','muscle:infraspin','primary_muscle',5,'open_chain','isotonic','External rotation targets infraspinatus.'),
      ('pk_shoulder_external_rotation','muscle:teres_min','primary_muscle',5,'open_chain','isotonic','External rotation targets teres minor.'),
      ('pk_shoulder_external_rotation','joint:sh_gh','joint_motion',5,'open_chain','isotonic','External rotation trains glenohumeral rotation.'),
      ('pk_foam_roller_thoracic','joint:t_t6t7','mobility_region',5,'non_weight_bearing','mobility','Foam roller thoracic extension targets mid-thoracic mobility.'),
      ('pk_foam_roller_thoracic','joint:t_t7t8','mobility_region',5,'non_weight_bearing','mobility','Foam roller thoracic extension targets mid-thoracic mobility.'),
      ('edb_Superman','muscle:erect_long','primary_muscle',4,'open_chain','isometric','Superman loads spinal extensors.'),
      ('edb_Superman','muscle:glut_max','secondary_muscle',3,'open_chain','isometric','Superman includes hip extension effort.'),
      ('edb_Hyperextensions_Back_Extensions','muscle:erect_long','primary_muscle',4,'closed_chain','isotonic','Back extension loads spinal extensors.'),
      ('edb_Hyperextensions_Back_Extensions','muscle:glut_max','primary_muscle',4,'closed_chain','isotonic','Back extension trains posterior-chain hip extension.')
  ) as seed(
    exercise_code,
    entity_code,
    target_role,
    target_priority,
    load_type,
    contraction_type,
    rationale
  )
)
insert into public.exercise_anatomical_targets (
  exercise_id,
  anatomical_entity_id,
  target_role,
  target_priority,
  load_type,
  contraction_type,
  rationale,
  evidence_level,
  metadata,
  status
)
select
  e.id,
  ae.id,
  ts.target_role,
  ts.target_priority,
  ts.load_type,
  ts.contraction_type,
  ts.rationale,
  'expert_seed_mvp',
  jsonb_build_object('seed_wave', 'exercise_anatomical_targets_v1_2026_05_31'),
  'active'
from target_seed ts
join public.exercises e
  on e.exercise_code = ts.exercise_code
join public.anatomical_entities ae
  on ae.entity_code = ts.entity_code
on conflict (exercise_id, anatomical_entity_id, target_role)
  where status = 'active'
do update set
  target_priority = excluded.target_priority,
  load_type = excluded.load_type,
  contraction_type = excluded.contraction_type,
  rationale = excluded.rationale,
  evidence_level = excluded.evidence_level,
  metadata = public.exercise_anatomical_targets.metadata || excluded.metadata,
  updated_at = now();;
