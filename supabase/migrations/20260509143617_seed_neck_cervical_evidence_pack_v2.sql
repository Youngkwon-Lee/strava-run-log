-- Neck/Cervical Evidence Pack v2
-- Purpose: strengthen RAG for neck pain, cervical radiculopathy, cervicogenic headache, whiplash, and myelopathy/red-flag reasoning.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[] language sql immutable as $$
  select array(select distinct v from unnest(coalesce(base,'{}'::text[]) || coalesce(extras,'{}'::text[])) t(v) where v is not null and btrim(v) <> '' order by v)
$$;
update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, case when form_code = 'NDI' then 7.5 when form_code in ('NPRS','VAS') then 2 else 5 end),
  mdc_value = coalesce(mdc_value, case when form_code = 'NDI' then 10.2 when form_code = 'NPRS' then 2.1 when form_code = 'VAS' then 25 else 5 end),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, case when form_code = 'NDI' then 50 when form_code in ('NPRS','VAS') then 10 else 100 end),
  max_possible_score = coalesce(max_possible_score, case when form_code = 'NDI' then 50 when form_code in ('NPRS','VAS') then 10 else 100 end),
  higher_is_better = false,
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Neck pain outcome measurement literature; NDI/NPRS/VAS/cervical ROM clinical use'),
  condition_overrides = coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition','neck_cervical_radiculopathy_headache_myelopathy',
    'interpretation','Use with neck/arm symptom irritability, neurological screen, myotomes/dermatomes/reflexes, cervical ROM, headache behavior, upper cervical safety screen, scapular control and patient-specific work/sport goals. NDI/NPRS/VAS lower is better.',
    'references',jsonb_build_array('Neck Disability Index measurement literature','APTA/JOSPT Neck Pain CPG','Cervical radiculopathy test cluster literature','Cervicogenic headache clinical examination literature')
  )),
  updated_at = now()
where form_code in ('NDI','NPRS','VAS','ROM_CERVICAL');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Wainner RS et al. Reliability and diagnostic accuracy of the clinical examination and patient self-report measures for cervical radiculopathy.',
    'APTA/JOSPT Neck Pain Clinical Practice Guideline: classification, examination and intervention principles.',
    'Cervical radiculopathy clinical test cluster literature: Spurling, distraction, ULTT, rotation limitation, shoulder abduction relief.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '경추 신경근증 cervical radiculopathy Spurling ULTT distraction shoulder abduction relief 상지 방사통 감각저하 근력저하 반사저하 목 디스크'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret cervical radiculopathy as a cluster with arm symptoms, Spurling/compression, distraction relief, ULTT/neural mechanosensitivity, shoulder abduction relief, cervical rotation limitation, dermatomes, myotomes and reflexes. Do not diagnose from one provocative test alone; screen myelopathy and progressive neurological deficit first.'),
  updated_at = now()
where id in ('ST_CERV_001','ST_CERV_002','ST_CERV_003','ST_CERV_004','ST_CERV_005','ST_CERV_006','ST_CERV_007','ST_CERV_015','ST_CERV_016','ST_CERV_017');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Cervicogenic headache examination literature; cervical flexion-rotation test and upper cervical dysfunction reasoning.',
    'Deep cervical flexor motor control/endurance literature for neck pain, cervicogenic headache and whiplash-associated disorders.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '경추성 두통 cervicogenic headache C1 C2 flexion rotation deep neck flexor cranio cervical flexion 목 굴곡근 지구력 상부경추'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret cervicogenic headache/motor-control findings with unilateral or neck-related headache behavior, cervical ROM limits, C1-C2 flexion-rotation response, deep neck flexor control/endurance, symptom irritability and exclusion of vascular/intracranial red flags.'),
  updated_at = now()
where id in ('ST_CERV_011','ST_CERV_012','ST_CERV_014');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'International IFOMPT cervical framework / cervical arterial dysfunction and upper cervical instability screening principles.',
    'Cervical myelopathy and upper motor neuron red flag screening literature.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '경추 안전성 upper cervical instability myelopathy 척수병증 vertebral artery VBI dizziness diplopia dysarthria drop attacks ataxia gait hand clumsiness Lhermitte'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: upper cervical instability, vascular symptoms, myelopathy signs, gait disturbance, hand clumsiness, bilateral neurological symptoms, bowel/bladder change, drop attacks, diplopia, dysarthria, dysphagia, dizziness/ataxia or Lhermitte-type cord symptoms require caution and medical referral consideration. Screening tests cannot rule out vascular risk by themselves.'),
  updated_at = now()
where id in ('ST_CERV_008','ST_CERV_009','ST_CERV_010','ST_CERV_013','ST_NEUR_011');
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array['neck pain','cervicalgia','cervical radiculopathy','cervical disc','cervical spondylosis','cervicogenic headache','whiplash','WAD','cervical myelopathy','목통증','경추 신경근증','경추성 두통','편타성 손상']::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'suspected cervical myelopathy: gait disturbance, hand clumsiness, bilateral neurological symptoms, hyperreflexia/clonus or progressive cord signs',
    'progressive motor weakness, worsening reflex loss, expanding sensory deficit or severe unremitting radicular pain',
    'vascular/cervical arterial dysfunction symptoms: drop attacks, diplopia, dysarthria, dysphagia, dizziness/ataxia, new severe unusual headache or neurological signs',
    'major trauma, suspected fracture/dislocation, upper cervical instability, rheumatoid/inflammatory instability risk or osteoporosis risk',
    'infection/systemic symptoms, fever, cancer history, unexplained weight loss, severe non-mechanical night pain',
    'bowel/bladder change, saddle symptoms, Lhermitte-type cord symptoms or rapidly worsening neurological status',
    'post-operative complication, dysphagia/airway concern, wound issue, hardware failure suspicion or sudden neurological change'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Evidence Pack v2: classify cervical/head-neck presentations by trauma/whiplash vs non-trauma, neck-dominant vs arm-dominant symptoms, radiculopathy cluster, myelopathy/vascular/upper-cervical safety screen, headache behavior, cervical ROM, neurological exam, deep neck flexor/scapular control, irritability and work/sport demands. Use NDI/NPRS/VAS/ROM with clinical exam rather than PROMs alone.'),
  updated_at = now()
where body_region in ('cervical_spine','head_neck')
   or icd10_display ilike '%cervical%'
   or icd10_display ilike '%radicul%'
   or icd10_display ilike '%whiplash%'
   or icd10_display ilike '%headache%';
update public.exercises
set
  evidence_level = case when evidence_level is null or evidence_level = 'not_reviewed' then 'B' else evidence_level end,
  clinical_tier = greatest(coalesce(clinical_tier,0),2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'suspected fracture/dislocation, upper cervical instability, cervical myelopathy, vascular red flags, infection, cancer/systemic signs, or unresolved neurological red flag',
    'progressive motor weakness, bilateral neurological symptoms, gait disturbance, hand clumsiness, bowel/bladder change, or Lhermitte-type cord symptoms',
    'post-operative restriction not cleared by surgeon/protocol',
    'exercise causes worsening arm symptoms, dizziness/visual/speech/swallowing symptoms, drop attack, sharp neurological symptoms, or significant next-day flare'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'monitor neck/arm symptom irritability, neurological status, headache behavior, cervical ROM, scapular control and 24-hour response',
    'progress from education, comfortable ROM, deep neck flexor activation and low-load isometrics to endurance, scapular control, resistance and work/sport-specific loading',
    'avoid high-velocity manipulation, end-range loading or provocative traction when vascular, instability, myelopathy or acute severe radicular signs are present',
    'for radiculopathy, track peripheralization/centralization, myotome/reflex change and response to unloading/traction positions'
  ]::text[]),
  description_ko = coalesce(description_ko, '경추/목 통증, 신경근증, 경추성 두통, 편타성 손상에서 신경학적 상태·통증 과민성·ROM·심부 목 굴곡근·견갑 조절·24시간 반응을 확인하며 단계적으로 진행하는 핵심 운동 후보입니다.'),
  updated_at = now()
where exercise_code in (
  'pk_chin_tuck','edb_Chin_To_Chest_Stretch','edb_Side_Neck_Stretch','edb_Neck-SMR','edb_Isometric_Neck_Exercise_-_Front_And_Back','edb_Isometric_Neck_Exercise_-_Sides',
  'EX_CSPN_MOB_001','EX_CSPN_MOB_002','EX_CSPN_MOB_003','EX_CSPN_MOB_005','EX_CSPN_MOB_009','EX_CSPN_MOB_011','EX_CSPN_MOB_014',
  'EX_CSPN_NMR_005','EX_CSPN_NMR_006','EX_CSPN_NMR_011','EX_CSPN_NMR_012','EX_CSPN_NMR_015',
  'EX_CSPN_PRP_001','EX_CSPN_PRP_007','EX_CSPN_PRP_011','EX_CSPN_PRP_012','EX_CSPN_PRP_014',
  'EX_CSPN_SGT_001','EX_CSPN_SGT_004','EX_CSPN_SGT_006','EX_CSPN_SGT_010','EX_CSPN_SGT_011','EX_CSPN_SGT_014','EX_CSPN_SGT_015',
  'EX_CSPN_STB_001','EX_CSPN_STB_005','EX_CSPN_STB_006','EX_CSPN_STB_011','EX_CSPN_STB_013','EX_CSPN_STB_015',
  'EX_CSPN_STR_001','EX_CSPN_STR_004','EX_CSPN_STR_010','EX_CSPN_STR_011','EX_CSPN_STR_012',
  'EX_CSPN_FNC_004','EX_CSPN_FNC_005','EX_CSPN_FNC_008','EX_CSPN_FNC_013','EX_CSPN_FNC_015'
);
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v2-neck-outcome-measures','Neck/Cervical Outcome Measures: NDI, NPRS, VAS, C-ROM','Clinical Evidence Pack v2. Neck/cervical outcomes. NDI/NPRS/VAS are lower-is-better; cervical ROM adds impairment context. Interpret meaningful change with baseline severity, neck/arm symptom irritability, neurological status, headache behavior, work/sport goals and 24-hour response. Do not use PROMs alone.','clinical_evidence_pack',jsonb_build_object('evidence_pack','neck-v2','source_quality','curated_summary','topics',jsonb_build_array('NDI','NPRS','VAS','cervical ROM','neck pain'))),
('web_pages','clinical-pack-v2-neck-radiculopathy-cluster','Cervical Radiculopathy Test Cluster','Clinical Evidence Pack v2. Cervical radiculopathy reasoning: interpret Spurling/compression, distraction relief, ULTT/neural mechanosensitivity, shoulder abduction relief, cervical rotation limitation, dermatomes, myotomes and reflexes as a cluster with arm-dominant symptoms. Screen myelopathy, progressive deficit and vascular/upper cervical red flags before routine exercise or manual loading.','clinical_evidence_pack',jsonb_build_object('evidence_pack','neck-v2','source_quality','curated_summary','topics',jsonb_build_array('cervical radiculopathy','Spurling','ULTT','distraction','myotome'))),
('web_pages','clinical-pack-v2-neck-headache-myelopathy-red-flags','Cervicogenic Headache, Myelopathy and Cervical Red Flags','Clinical Evidence Pack v2. Cervicogenic headache reasoning uses neck-related headache behavior, C1-C2 flexion-rotation response, cervical ROM, deep neck flexor control/endurance and exclusion of vascular/intracranial red flags. Escalate for myelopathy signs, gait disturbance, hand clumsiness, bilateral neuro symptoms, bowel/bladder change, Lhermitte-type symptoms, drop attacks, diplopia, dysarthria, dysphagia, dizziness/ataxia, major trauma, infection/cancer/systemic signs or upper cervical instability suspicion.','clinical_evidence_pack',jsonb_build_object('evidence_pack','neck-v2','source_quality','curated_summary','topics',jsonb_build_array('cervicogenic headache','myelopathy','red flags','upper cervical instability','vascular screen'))),
('web_pages','clinical-pack-v2-neck-exercise-progression-matrix','Neck/Cervical Exercise Progression Matrix','Clinical Evidence Pack v2. Neck/cervical progression matrix. High irritability/acute: education, symptom modulation, comfortable ROM, deep neck flexor activation, low-load isometrics, gentle scapular setting and avoid provocative end-range/arm symptom loading. Moderate: deep neck flexor endurance, cervical/thoracic mobility, scapular control, graded resistance and nerve-sensitive loading if tolerated. Low irritability/return: endurance, perturbation, work/overhead/sport-specific loading and self-management only when neuro status, ROM, headache/arm symptoms and 24-hour response are controlled.','clinical_evidence_pack',jsonb_build_object('evidence_pack','neck-v2','source_quality','curated_summary','topics',jsonb_build_array('exercise progression','deep neck flexor','scapular control','cervical mobility','return to work')))
on conflict (source_type, source_id) do update
set title=excluded.title, content=excluded.content, category=excluded.category, metadata=excluded.metadata, updated_at=now();
update public.vector_search
set content = case when content ilike '%Clinical Evidence Pack v2:%' then content else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: neck/cervical evidence enriched with outcome interpretation, radiculopathy cluster reasoning, myelopathy/vascular red flags, headache reasoning, and progression criteria.') end,
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('evidence_pack','neck-v2','source_quality','neck_evidence_pack'),
    updated_at = now()
where (source_type='assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('NDI','NPRS','VAS','ROM_CERVICAL')))
   or (source_type='special_tests' and source_id in ('ST_CERV_001','ST_CERV_002','ST_CERV_003','ST_CERV_004','ST_CERV_005','ST_CERV_006','ST_CERV_007','ST_CERV_008','ST_CERV_009','ST_CERV_010','ST_CERV_011','ST_CERV_012','ST_CERV_013','ST_CERV_014','ST_CERV_015','ST_CERV_016','ST_CERV_017','ST_NEUR_011'))
   or (source_type='exercises' and source_id in (select id::text from public.exercises where is_recommendation_candidate is true and (body_region in ('cervical','cervical_spine') or exercise_code like 'EX_CSPN_%' or exercise_code in ('pk_chin_tuck'))))
   or (source_type='web_pages' and (title ilike '%neck%' or title ilike '%cervical%' or title ilike '%radiculopathy%' or title ilike '%myelopathy%'));
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
