-- Thoracic/Rib/Scapulothoracic Evidence Pack v2
-- Purpose: strengthen RAG for thoracic spine/rib/scapulothoracic pain, rib-fracture and cardiopulmonary red flags,
-- thoracic radicular/myelopathy screens, breathing-load context, thoracic mobility, scapular control,
-- respiratory mechanics, loaded carry and rotation progression.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[] language sql immutable as $$
  select array(select distinct v from unnest(coalesce(base,'{}'::text[]) || coalesce(extras,'{}'::text[])) t(v) where v is not null and btrim(v) <> '' order by v)
$$;
update public.assessment_form_templates
set
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, case when form_code in ('NPRS','VAS') then 10 when form_code = 'PSFS' then 10 when form_code = 'FMS' then 21 else 100 end),
  max_possible_score = coalesce(max_possible_score, case when form_code in ('NPRS','VAS') then 10 when form_code = 'PSFS' then 10 when form_code = 'FMS' then 21 else 100 end),
  higher_is_better = case when form_code in ('NPRS','VAS','ODI','OREBRO_SF') then false else true end,
  mcid_value = coalesce(mcid_value, case when form_code in ('NPRS','VAS') then 2 when form_code = 'PSFS' then 2 when form_code = 'ODI' then 10 when form_code = 'OREBRO_SF' then 8 when form_code = 'FMS' then 2 else 8 end),
  mdc_value = coalesce(mdc_value, case when form_code in ('NPRS','VAS') then 2 when form_code = 'PSFS' then 2 when form_code = 'ODI' then 12.8 when form_code = 'OREBRO_SF' then 8 when form_code = 'FMS' then 2 else 8 end),
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Thoracic/rib/scapulothoracic outcome and screening literature; pain scales, PSFS, ODI/Örebro spine risk screening, FMS movement context'),
  condition_overrides = coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition','thoracic_rib_scapulothoracic_pain_red_flag_progression',
    'interpretation','Use with symptom location, trauma history, breathing/cough/load response, thoracic ROM, scapulothoracic control, neurological screen, cardiopulmonary red flags, osteoporosis/fracture risk, irritability, work/sport demand and 24-hour response. NPRS/VAS are lower-is-better pain scores; PSFS is higher-is-better function; ODI/Örebro/FMS provide broader spine risk and movement context rather than a thoracic-specific diagnosis.',
    'references',jsonb_build_array('Thoracic spine pain and red flag screening literature','Rib fracture and cardiopulmonary differential screening literature','Scapular dyskinesis and thoracic mobility rehabilitation literature')
  )),
  updated_at = now()
where form_code in ('NPRS','VAS','PSFS','ODI','OREBRO_SF','FMS');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Scapular dyskinesis and scapular assistance/retraction clinical assessment literature.',
    'Scapulothoracic contribution should be interpreted with thoracic mobility, serratus/lower-trapezius control, symptom modification, overhead-load demand and cervical/shoulder differential.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '견갑흉곽 scapulothoracic scapular dyskinesis scapular assistance serratus anterior lower trapezius thoracic mobility rib breathing overhead control'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret scapular assistance as a symptom-modification finding, not a stand-alone diagnosis. Combine overhead symptom change with thoracic extension/rotation mobility, rib/breathing response, serratus anterior/lower trapezius control, cervical screen, rotator-cuff/instability findings and work/sport load. Escalate trauma, fracture/rib red flags, neurological deficits or cardiopulmonary symptoms before progressive loading.'),
  updated_at = now()
where id in ('ST_SHLDR_022');
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array['thoracic pain','thoracic back pain','upper back pain','rib pain','costovertebral pain','chest wall pain','scapulothoracic pain','scapular dyskinesis','postural kyphosis','dorsalgia','흉추통','등통증','늑골 통증','흉벽 통증','견갑흉곽 통증','견갑골 조절 문제']::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'acute trauma, osteoporosis/steroid use/older age, focal bony tenderness, deformity, suspected rib/vertebral fracture or inability to take deep breaths after injury',
    'cardiopulmonary red flags: chest pressure, shortness of breath, syncope, diaphoresis, unexplained tachycardia, hypoxia, hemoptysis, PE/aortic/cardiac concern or symptoms not mechanically reproducible',
    'progressive neurological deficit, gait disturbance, bilateral symptoms, thoracic myelopathy signs, bowel/bladder change, saddle anesthesia or severe radicular band-like pain with neuro changes',
    'systemic/infection/cancer signs: fever, unexplained weight loss, cancer history, immunosuppression, night sweats, severe unrelenting night/rest pain or non-mechanical pattern',
    'post-surgical sternotomy/rib/thoracic procedure complications, wound issue, sternal instability/dehiscence, hardware failure suspicion or sudden loss of function'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Evidence Pack v2: classify thoracic/rib/scapulothoracic presentations by mechanical thoracic mobility or load sensitivity, rib/chest-wall pain and breathing/cough response, scapulothoracic control, postural kyphosis/scoliosis context, cardiopulmonary differential, thoracic radicular/myelopathy screen, fracture/osteoporosis risk and post-operative restrictions. Combine symptom location, irritability, thoracic extension/rotation ROM, respiratory mechanics, overhead/carry/rotation demand and 24-hour response.'),
  updated_at = now()
where body_region = 'thoracic_spine';
update public.exercises
set
  evidence_level = case when evidence_level is null or evidence_level = 'not_reviewed' then 'B' else evidence_level end,
  clinical_tier = greatest(coalesce(clinical_tier,0),2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'suspected rib/vertebral fracture, acute trauma with deformity or severe focal bony tenderness, unstable thoracic injury, pneumothorax concern, cardiopulmonary red flags, hypoxia, PE/aortic/cardiac concern or non-mechanical chest pain',
    'progressive neurological deficit, myelopathy signs, gait disturbance, bowel/bladder change, systemic infection/cancer signs, severe unrelenting night/rest pain or unexplained systemic symptoms',
    'post-operative sternotomy/thoracic/rib restrictions not cleared by surgeon/protocol, sternal instability, wound issue, hardware failure suspicion or sudden loss of function',
    'exercise causes sharp chest/rib pain, increasing shortness of breath, dizziness/syncope, neurological symptoms, marked next-day flare, or pain escalation beyond tolerance'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'monitor pain irritability, breathing/cough response, thoracic extension/rotation ROM, rib provocation, scapulothoracic control, neurological screen, cardiopulmonary symptoms, work/sport load and 24-hour response',
    'progress from education, breathing mechanics, gentle thoracic ROM and scapular setting to extension/rotation mobility, serratus/lower-trapezius control, rows/carries, anti-rotation and loaded rotation',
    'for rib/chest-wall symptoms, avoid aggressive end-range compression or high-velocity loading early; use symptom-guided breathing expansion, mobility and graded trunk/upper-limb load',
    'for osteoporosis, kyphosis or post-operative contexts, respect tissue healing, bone load tolerance and surgical restrictions before thrust, heavy carry, overhead or plyometric progressions'
  ]::text[]),
  description_ko = coalesce(description_ko, '흉추/늑골/견갑흉곽 통증에서 호흡 반응, 흉추 신전·회전 ROM, 견갑골 조절, 신경학적·심폐 레드플래그, 24시간 반응을 확인하며 단계적으로 진행하는 핵심 운동 후보입니다.'),
  updated_at = now()
where exercise_code like 'EX_TSPN_%'
   or exercise_code in (
    'edb_Cat_Stretch','edb_Middle_Back_Stretch','edb_Upper_Back_Stretch','edb_Rhomboids-SMR','edb_Scapular_Pull-Up','edb_Seated_Cable_Rows','edb_Inverted_Row','edb_Inverted_Row_with_Straps','edb_One-Arm_Dumbbell_Row','edb_Seated_One-arm_Cable_Pulley_Rows','edb_Suspended_Row','edb_Torso_Rotation','edb_Pallof_Press_With_Rotation','edb_Straight-Arm_Dumbbell_Pullover','edb_Straight-Arm_Pulldown','edb_Straight_Bar_Bench_Mid_Rows','edb_Two-Arm_Kettlebell_Row','edb_Kneeling_High_Pulley_Row','edb_Serratus_Chair_Shrug','edb_Rickshaw_Carry','edb_Standing_Two-Arm_Overhead_Throw','edb_Supine_Two-Arm_Overhead_Throw','edb_Supine_One-Arm_Overhead_Throw','edb_Medicine_Ball_Scoop_Throw'
   );
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v2-thoracic-outcome-measures','Thoracic/Rib/Scapulothoracic Outcome Measures: NPRS, VAS, PSFS, ODI, Örebro, FMS','Clinical Evidence Pack v2. Thoracic/rib/scapulothoracic outcomes. NPRS/VAS are lower-is-better pain scores, PSFS is higher-is-better patient-specific function, and ODI/Örebro/FMS provide broader spine risk and movement context. Interpret with trauma history, breathing/cough/load response, thoracic ROM, scapular control, red flags, irritability and 24-hour response.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','thoracic-v2','source_quality','curated_summary','topics',jsonb_build_array('NPRS','VAS','PSFS','ODI','Orebro','FMS','thoracic ROM'))),
('web_pages','clinical-pack-v2-thoracic-rib-red-flags','Thoracic and Rib Red Flags: Fracture, Cardiopulmonary and Neurological Screen','Clinical Evidence Pack v2. Thoracic/rib red flags include acute trauma with focal bony tenderness or osteoporosis risk, suspected rib/vertebral fracture, difficulty breathing after injury, chest pressure, dyspnea, syncope, hypoxia, hemoptysis, PE/aortic/cardiac concern, systemic infection/cancer signs, severe non-mechanical night/rest pain, progressive neurological deficit, gait disturbance, bowel/bladder change or thoracic myelopathy/radiculopathy signs.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','thoracic-v2','source_quality','curated_summary','topics',jsonb_build_array('rib fracture','cardiopulmonary red flags','thoracic myelopathy','radicular pain','osteoporosis'))),
('web_pages','clinical-pack-v2-thoracic-scapulothoracic-control','Scapulothoracic Control and Thoracic Mobility Reasoning','Clinical Evidence Pack v2. Scapulothoracic reasoning combines symptom modification during scapular assistance/retraction, thoracic extension/rotation mobility, rib/breathing mechanics, serratus anterior and lower trapezius control, cervical/shoulder differential, overhead or carry load and 24-hour response. Do not diagnose from a single scapular sign; use it to guide mobility/control/load progression.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','thoracic-v2','source_quality','curated_summary','topics',jsonb_build_array('scapular assistance','scapular dyskinesis','serratus anterior','lower trapezius','thoracic mobility'))),
('web_pages','clinical-pack-v2-thoracic-exercise-progression-matrix','Thoracic/Rib/Scapulothoracic Exercise Progression Matrix','Clinical Evidence Pack v2. Progression matrix: high irritability or rib/chest-wall sensitivity = education, breathing mechanics, supported positions, gentle ROM, scapular setting and low-load walking; moderate irritability = thoracic extension/rotation mobility, rib expansion, rows, serratus/lower-trap activation, anti-rotation and controlled carries; low irritability/return = loaded rotation, overhead reach/press patterns, carries, rowing, throwing and sport/work tasks when red flags, breathing response, ROM, scapular control and 24-hour response are controlled.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','thoracic-v2','source_quality','curated_summary','topics',jsonb_build_array('breathing mechanics','thoracic rotation','loaded carry','anti-rotation','return to sport')))
on conflict (source_type, source_id) do update
set title=excluded.title, content=excluded.content, category=excluded.category, metadata=excluded.metadata, updated_at=now();
update public.vector_search
set content = case when content ilike '%Clinical Evidence Pack v2:%' then content else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: thoracic/rib/scapulothoracic evidence enriched with outcome interpretation, rib/fracture/cardiopulmonary red flags, thoracic radicular/myelopathy screen, breathing mechanics, scapular control and loaded rotation/carry progression criteria.') end,
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('evidence_pack','thoracic-v2','source_quality','thoracic_evidence_pack'),
    updated_at = now()
where (source_type='assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('NPRS','VAS','PSFS','ODI','OREBRO_SF','FMS')))
   or (source_type='special_tests' and source_id in ('ST_SHLDR_022'))
   or (source_type='exercises' and source_id in (select id::text from public.exercises where is_recommendation_candidate is true and (exercise_code like 'EX_TSPN_%' or body_region = 'thoracic_spine' or exercise_code in ('edb_Cat_Stretch','edb_Middle_Back_Stretch','edb_Upper_Back_Stretch','edb_Rhomboids-SMR','edb_Scapular_Pull-Up','edb_Seated_Cable_Rows','edb_Inverted_Row','edb_Inverted_Row_with_Straps','edb_One-Arm_Dumbbell_Row','edb_Seated_One-arm_Cable_Pulley_Rows','edb_Suspended_Row','edb_Torso_Rotation','edb_Pallof_Press_With_Rotation','edb_Straight-Arm_Dumbbell_Pullover','edb_Straight-Arm_Pulldown','edb_Straight_Bar_Bench_Mid_Rows','edb_Two-Arm_Kettlebell_Row','edb_Kneeling_High_Pulley_Row','edb_Serratus_Chair_Shrug','edb_Rickshaw_Carry','edb_Standing_Two-Arm_Overhead_Throw','edb_Supine_Two-Arm_Overhead_Throw','edb_Supine_One-Arm_Overhead_Throw','edb_Medicine_Ball_Scoop_Throw'))))
   or (source_type='web_pages' and metadata->>'evidence_pack' = 'thoracic-v2');
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
