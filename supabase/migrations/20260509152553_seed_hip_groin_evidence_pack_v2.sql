-- Hip/Groin Evidence Pack v2
-- Purpose: strengthen RAG for hip OA, FAI/labral pathology, athletic groin pain/adductor injury,
-- femoral stress fracture red flags, gluteal tendinopathy, and return-to-running/sport progression.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[] language sql immutable as $$
  select array(select distinct v from unnest(coalesce(base,'{}'::text[]) || coalesce(extras,'{}'::text[])) t(v) where v is not null and btrim(v) <> '' order by v)
$$;
update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, case when form_code = 'HOOS' then 10 when form_code = 'LEFS' then 9 when form_code = 'HIP_RSI' then 10 else 5 end),
  mdc_value = coalesce(mdc_value, case when form_code = 'HOOS' then 12 when form_code = 'LEFS' then 9.3 when form_code = 'HIP_RSI' then 10 else 5 end),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, case when form_code = 'LEFS' then 80 else 100 end),
  max_possible_score = coalesce(max_possible_score, case when form_code = 'LEFS' then 80 else 100 end),
  higher_is_better = case when form_code = 'ROM_HIP' then false else true end,
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Hip/groin outcome measurement literature; HOOS/LEFS/HIP_RSI/hip ROM clinical use'),
  condition_overrides = coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition','hip_groin_fai_labral_adductor_oa_stress_fracture',
    'interpretation','Use with symptom location (groin/lateral/posterior), load tolerance, gait, ROM, strength, hop/running response, imaging/referral red flags, and sport/work goals. HOOS/LEFS/HIP_RSI are generally higher is better; ROM_HIP is impairment context, not a stand-alone recovery score.',
    'references',jsonb_build_array('HOOS/LEFS hip outcome measurement literature','Warwick Agreement on femoroacetabular impingement syndrome','Doha agreement athletic groin pain taxonomy','Hip OA clinical practice guideline concepts')
  )),
  updated_at = now()
where form_code in ('HOOS','LEFS','HIP_RSI','ROM_HIP');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Warwick Agreement on femoroacetabular impingement syndrome: symptoms, clinical signs and imaging triad.',
    'Reiman MP et al. Diagnostic accuracy of clinical tests for hip femoroacetabular impingement/labral pathology: systematic review evidence.',
    'Interpret hip impingement/labral tests with symptom location, ROM loss, clicking/catching, gait, sport load and differential diagnosis; single tests are not definitive.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '고관절 FAI femoroacetabular impingement 관절순 labral tear FABER FADIR Scour log roll groin pain 사타구니 통증 충돌증후군 ROM clicking catching'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret FAI/labral findings as a cluster: groin/anterior hip pain, FADIR/FABER/scour/log-roll/Stinchfield response, hip IR/flexion ROM loss, clicking/catching, gait and sport-load behavior. Do not diagnose from one provocative test alone; consider lumbar/SI/adductor, stress fracture, OA and red flags.'),
  updated_at = now()
where id in ('ST_HIP_001','ST_HIP_002','ST_HIP_005','ST_HIP_006','ST_HIP_011','ST_HIP_012','ST_HIP_013','ST_HIP_014','ST_HIP_017','ST_HIP_018','ST_HIP_019','ST_HIP_020');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Doha agreement meeting on terminology and definitions in groin pain in athletes.',
    'Athletic groin pain/adductor-related groin pain clinical examination and load-capacity literature.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '서혜부 통증 groin pain adductor 내전근 Doha resisted adduction squeeze hip flexor iliopsoas hamstring piriformis lateral hip pain'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: classify athletic groin/hip soft-tissue presentations by adductor-related, iliopsoas-related, inguinal-related, pubic-related, hip-related or other causes. Combine palpation, resisted adduction/flexion, squeeze/load response, ROM, running/kicking/cutting demand and 24-hour response.'),
  updated_at = now()
where id in ('ST_HIP_003','ST_HIP_004','ST_HIP_008','ST_HIP_009','ST_HIP_010','ST_HIP_016');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Femoral neck stress fracture and serious hip pathology screening literature.',
    'Hip/groin red flag principles: fracture, avascular necrosis, infection, tumor, slipped capital femoral epiphysis, neurovascular compromise and inability to bear weight.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '대퇴골 피로골절 femoral stress fracture fulcrum hop test inability to bear weight AVN 감염 종양 야간통 외상 referral red flag'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: positive fulcrum/hop-style bony stress findings, night/rest pain, inability to bear weight, trauma, systemic symptoms, AVN risk, adolescent slipped capital femoral epiphysis pattern, neurovascular compromise or progressive severe pain warrants imaging/medical referral consideration before progressive loading.'),
  updated_at = now()
where id in ('ST_HIP_015');
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array['hip pain','groin pain','FAI','femoroacetabular impingement','labral tear','hip OA','coxarthrosis','adductor-related groin pain','athletic groin pain','GTPS','gluteal tendinopathy','femoral neck stress fracture','고관절통','서혜부 통증','고관절 충돌증후군','고관절 관절순','고관절 관절염','내전근 통증']::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'acute trauma, suspected fracture/dislocation, inability to bear weight, severe bony tenderness, or positive stress-fracture screen',
    'night/rest pain, progressive non-mechanical pain, cancer history, unexplained weight loss, fever or infection/systemic symptoms',
    'avascular necrosis risk or rapidly worsening deep groin pain',
    'adolescent hip pain with limp or limited internal rotation suggesting SCFE/Perthes pattern',
    'neurovascular compromise, saddle symptoms, progressive neurological deficit, or cauda equina features',
    'post-operative complication, DVT signs, infection, dislocation, periprosthetic fracture or sudden functional loss after THR/arthroscopy',
    'large hematoma, suspected avulsion, tendon rupture, compartment syndrome or severe adductor/hamstring injury with marked weakness'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Evidence Pack v2: classify hip/groin presentations by intra-articular hip/FAI-labral, hip OA, adductor-related athletic groin pain, iliopsoas/hamstring/gluteal tendon, lateral hip/GTPS, SI/lumbar referral, bony stress injury and post-operative status. Combine symptom location, gait, ROM, strength, load response, hop/running/cutting tolerance, PROMs and red-flag screen.'),
  updated_at = now()
where body_region = 'hip';
update public.exercises
set
  evidence_level = case when evidence_level is null or evidence_level = 'not_reviewed' then 'B' else evidence_level end,
  clinical_tier = greatest(coalesce(clinical_tier,0),2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'suspected fracture/dislocation, femoral neck stress fracture, AVN, infection, tumor/systemic signs, neurovascular compromise, or unresolved severe red flag',
    'inability to bear weight, rapidly worsening pain, severe night/rest pain, progressive neurological deficit, cauda equina features, or adolescent SCFE-like presentation',
    'post-operative restriction not cleared by surgeon/protocol, THR dislocation precautions, DVT signs or periprosthetic fracture suspicion',
    'exercise causes sharp groin pain, catching/locking escalation, marked limp, next-day flare, neurological symptoms, or loss of weight-bearing tolerance'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'monitor groin/lateral/posterior hip symptom irritability, gait, ROM, strength, single-leg control, running/cutting response and 24-hour response',
    'progress from pain-controlled ROM/isometrics and gait/load management to gluteal/adductor capacity, lumbopelvic control, single-leg strength, plyometrics and sport/work-specific loading',
    'for FAI/labral irritability, avoid repeated provocative deep flexion-adduction-internal-rotation until symptoms and load tolerance improve',
    'for adductor-related groin pain, progress resisted adduction and change-of-direction load gradually using soreness and 24-hour response rules'
  ]::text[]),
  description_ko = coalesce(description_ko, '고관절/서혜부 통증, FAI/관절순, 내전근 관련 서혜부 통증, 고관절 OA, 둔근건병증, 복귀 단계에서 통증 과민성·보행·ROM·근력·단하지 조절·24시간 반응을 확인하며 단계적으로 진행하는 핵심 운동 후보입니다.'),
  updated_at = now()
where exercise_code in (
  'edb_Adductor','edb_Adductor_Groin','edb_Band_Hip_Adductions','edb_Barbell_Glute_Bridge','edb_Barbell_Hip_Thrust','edb_Butt_Lift_Bridge','edb_Glute_Kickback','edb_Groin_and_Back_Stretch','edb_Groiners','edb_Hip_Circles_prone','edb_Hip_Extension_with_Bands','edb_Hip_Lift_with_Band','edb_Kneeling_Squat','edb_Lateral_Bound','edb_Lying_Bent_Leg_Groin','edb_Lying_Glute','edb_Monster_Walk','edb_One-Legged_Cable_Kickback','edb_Physioball_Hip_Bridge','edb_Pull_Through','edb_Side_Leg_Raises','edb_Side_Lying_Groin_Stretch','edb_Single_Leg_Glute_Bridge','edb_Standing_Hip_Circles','edb_Step-up_with_Knee_Raise','edb_Thigh_Abductor','edb_Thigh_Adductor','pk_clam_shell','pk_hip_bridge',
  'EX_HIP_BAL_005','EX_HIP_BAL_006','EX_HIP_BAL_007','EX_HIP_BAL_008','EX_HIP_CRD_003','EX_HIP_CRD_007','EX_HIP_FNC_001','EX_HIP_FNC_002','EX_HIP_FNC_004','EX_HIP_FNC_008','EX_HIP_FNC_009','EX_HIP_FNC_010','EX_HIP_FNC_014','EX_HIP_FNC_015','EX_HIP_MOB_003','EX_HIP_MOB_005','EX_HIP_MOB_008','EX_HIP_MOB_011','EX_HIP_NMR_011','EX_HIP_PRP_001','EX_HIP_PRP_007','EX_HIP_SGT_001','EX_HIP_SGT_004','EX_HIP_SGT_009','EX_HIP_SGT_010','EX_HIP_SGT_011','EX_HIP_SGT_014','EX_HIP_STB_001','EX_HIP_STB_005','EX_HIP_STB_006','EX_HIP_STB_008','EX_HIP_STB_013','EX_HIP_STR_001','EX_HIP_STR_004','EX_HIP_STR_010','EX_HIP_STR_011','EX_HIP_PLY_003','EX_HIP_PLY_004','EX_HIP_PLY_007','EX_HIP_PLY_013'
);
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v2-hip-outcome-measures','Hip/Groin Outcome Measures: HOOS, LEFS, HIP_RSI, Hip ROM','Clinical Evidence Pack v2. Hip/groin outcomes. HOOS/LEFS/HIP_RSI are generally higher-is-better; hip ROM is impairment context. Interpret with symptom location, gait, load tolerance, running/cutting response, strength, red flags and patient-specific work/sport goals. HOS/iHOT-12 were not present in the live form table at time of seeding.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','hip-v2','source_quality','curated_summary','topics',jsonb_build_array('HOOS','LEFS','HIP_RSI','hip ROM','hip pain'))),
('web_pages','clinical-pack-v2-hip-fai-labral-cluster','Hip FAI/Labral Cluster','Clinical Evidence Pack v2. FAI/labral reasoning: use groin/anterior hip pain, FADIR/FABER/scour/log-roll/Stinchfield response, hip IR/flexion ROM loss, clicking/catching, gait and sport-load behavior as a cluster. Single provocative tests are not definitive; consider lumbar/SI/adductor, OA, stress fracture and red flags.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','hip-v2','source_quality','curated_summary','topics',jsonb_build_array('FAI','labral tear','FADIR','FABER','hip ROM'))),
('web_pages','clinical-pack-v2-hip-groin-red-flags','Athletic Groin Pain and Hip Red Flags','Clinical Evidence Pack v2. Groin pain reasoning: classify adductor-related, iliopsoas-related, inguinal-related, pubic-related, hip-related or other causes using palpation, resisted adduction/flexion, squeeze/load response, running/kicking/cutting demand and 24-hour response. Escalate for femoral neck stress fracture signs, inability to bear weight, night/rest pain, fever/systemic signs, AVN risk, adolescent SCFE/Perthes pattern, neurovascular compromise, DVT or post-op complications.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','hip-v2','source_quality','curated_summary','topics',jsonb_build_array('groin pain','adductor','stress fracture','red flags','Doha'))),
('web_pages','clinical-pack-v2-hip-exercise-progression-matrix','Hip/Groin Exercise Progression Matrix','Clinical Evidence Pack v2. Hip/groin progression matrix. High irritability: education, load management, gait normalization, comfortable ROM, isometrics, low-load gluteal/adductor activation. Moderate: gluteal/adductor capacity, hip mobility, lumbopelvic control, step/squat/hinge and single-leg strength. Low irritability/return: running, cutting, plyometrics, adductor squeeze/capacity, hop/Y-balance/sport-specific progression when pain, ROM, strength, gait and 24-hour response are controlled.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','hip-v2','source_quality','curated_summary','topics',jsonb_build_array('exercise progression','gluteal strength','adductor capacity','return to running','sport')))
on conflict (source_type, source_id) do update
set title=excluded.title, content=excluded.content, category=excluded.category, metadata=excluded.metadata, updated_at=now();
update public.vector_search
set content = case when content ilike '%Clinical Evidence Pack v2:%' then content else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: hip/groin evidence enriched with outcome interpretation, FAI/labral clusters, athletic groin pain taxonomy, stress-fracture/red-flag screen, and return-to-running/sport progression criteria.') end,
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('evidence_pack','hip-v2','source_quality','hip_evidence_pack'),
    updated_at = now()
where (source_type='assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('HOOS','LEFS','HIP_RSI','ROM_HIP')))
   or (source_type='special_tests' and source_id like 'ST_HIP_%')
   or (source_type='exercises' and source_id in (select id::text from public.exercises where is_recommendation_candidate is true and (body_region='hip' or exercise_code like 'EX_HIP_%' or exercise_code in ('pk_clam_shell','pk_hip_bridge'))))
   or (source_type='web_pages' and metadata->>'evidence_pack' = 'hip-v2');
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
