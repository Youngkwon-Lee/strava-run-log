-- Shoulder Evidence Pack v2
-- Purpose: strengthen RAG for rotator cuff/subacromial pain/instability shoulder reasoning.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[] language sql immutable as $$
  select array(select distinct v from unnest(coalesce(base,'{}'::text[]) || coalesce(extras,'{}'::text[])) t(v) where v is not null and btrim(v) <> '' order by v)
$$;
update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, case when form_code in ('DASH','QUICKDASH') then 10 else 8 end),
  mdc_value = coalesce(mdc_value, case when form_code in ('DASH','QUICKDASH') then 10 else 8 end),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, 100),
  max_possible_score = coalesce(max_possible_score, 100),
  higher_is_better = case when form_code in ('DASH','QUICKDASH','SPADI') then false else true end,
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Shoulder outcome measurement literature; SPADI/DASH/QuickDASH/ASES clinical use'),
  condition_overrides = coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition','shoulder_rotator_cuff_subacromial_instability',
    'interpretation','Use with pain irritability, ROM, strength, scapular control, night pain and patient-specific functional goals. DASH/QuickDASH/SPADI lower is better; ASES higher is better.',
    'references',jsonb_build_array('Roach et al. SPADI','Hudak et al. DASH','Beaton et al. QuickDASH','ASES shoulder score literature')
  )),
  updated_at = now()
where form_code in ('SPADI','DASH','QUICKDASH','ASES','CONSTANT_MURLEY','PENN_SHOULDER','SHOULDER_RSI');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Hegedus EJ et al. Physical examination tests of the shoulder: systematic review/meta-analysis literature.',
    'APTA Clinical Practice Guideline: Rotator Cuff Tendinopathy Diagnosis, Non-surgical Medical Care and Rehabilitation.',
    'AAOS Rotator Cuff Injuries guideline/patient-care literature.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '회전근개 rotator cuff subacromial pain impingement painful arc Neer Hawkins Empty Can Jobe Drop Arm ER lag 외회전 지연 야간통 외전통'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret rotator cuff/subacromial tests as a cluster with painful arc, resisted abduction/external rotation, night pain, strength deficit, age/trauma context, and irritability. Do not over-rely on a single impingement sign.'),
  updated_at = now()
where id in ('ST_SHLDR_001','ST_SHLDR_002','ST_SHLDR_003','ST_SHLDR_014','ST_SHLDR_015');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Shoulder instability clinical examination and apprehension/relocation test diagnostic literature.',
    'Sports shoulder instability rehabilitation and return-to-sport clinical practice principles.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '어깨 불안정성 anterior instability posterior instability apprehension relocation labral tear Bankart recurrent dislocation subluxation apprehension position'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret instability tests with dislocation/subluxation history, apprehension rather than pain alone, relocation relief, direction of instability, hypermobility, neurovascular screen and sport/overhead demands.'),
  updated_at = now()
where id in ('ST_SHLDR_008','ST_SHLDR_009','ST_SHLDR_024');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Long head of biceps and SLAP clinical test diagnostic literature; interpret Speed test with low standalone certainty.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '상완이두근 biceps Speed SLAP anterior shoulder pain groove tenderness overhead athlete'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: Speed test should be interpreted with bicipital groove tenderness, resisted supination/flexion pain, labral signs and overhead history; standalone diagnostic certainty is limited.'),
  updated_at = now()
where id = 'ST_SHLDR_005';
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array['shoulder pain','어깨통증','rotator cuff','subacromial pain','impingement','instability','dislocation','frozen shoulder','labral tear']::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'acute trauma with deformity, suspected fracture/dislocation, or inability to actively elevate arm',
    'new neurological deficit, vascular compromise, severe neck/arm neurological symptoms',
    'fever, marked warmth/redness, suspected infection, unexplained systemic symptoms',
    'constant severe night pain, history of cancer, unexplained weight loss, non-mechanical pain',
    'post-operative complication, sudden loss of repair protection, or suspected re-tear after repair',
    'recurrent dislocation with neurovascular symptoms or failure to reduce'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Evidence Pack v2: classify shoulder presentations by trauma/non-trauma, night pain, painful arc, ROM pattern, resisted ER/abduction strength, scapular control, apprehension/instability, cervical referral screen, irritability and functional goal. Use SPADI/DASH/QuickDASH/ASES with ROM, strength and symptom response.'),
  updated_at = now()
where body_region = 'shoulder';
update public.exercises
set
  evidence_level = case when evidence_level is null or evidence_level = 'not_reviewed' then 'B' else evidence_level end,
  clinical_tier = greatest(coalesce(clinical_tier,0),2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'suspected fracture/dislocation, acute infection, neurovascular compromise, or unresolved red flag',
    'post-operative restriction not cleared by surgeon/protocol',
    'exercise causes instability/apprehension, sharp catching, neurological symptoms, or significant next-day flare',
    'acute traumatic rotator cuff tear suspected with marked weakness or inability to elevate arm'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'monitor night pain, irritability, painful arc, ROM, strength and 24-hour response',
    'avoid early provocative overhead loading, heavy end-range abduction/external rotation, and painful impingement positions',
    'progress scapular control, rotator cuff load, range, speed and overhead demand gradually',
    'for instability/labral repair, match progression to direction of instability and surgical protocol'
  ]::text[]),
  description_ko = coalesce(description_ko, '어깨 통증/회전근개/불안정성에서 통증, 가동범위, 견갑 조절, 외회전/외전 근력, 24시간 반응을 확인하며 단계적으로 진행하는 핵심 운동 후보입니다.'),
  updated_at = now()
where body_region = 'shoulder'
  and exercise_code in (
    'edb_External_Rotation','EX_SHLD_STR_004','EX_SHLD_STR_005','EX_SHLD_STR_006','EX_SHLD_STR_012',
    'EX_SHLD_NMR_011','EX_SHLD_NMR_012','EX_SHLD_NMR_015','EX_SHLD_PRP_001','EX_SHLD_PRP_003','EX_SHLD_PRP_006','EX_SHLD_PRP_007','EX_SHLD_PRP_008','EX_SHLD_PRP_011','EX_SHLD_PRP_012',
    'EX_SHLD_BAL_008','EX_SHLD_FNC_001','EX_SHLD_FNC_002','EX_SHLD_FNC_008','EX_SHLD_FNC_015'
  );
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v2-shoulder-outcome-measures','Shoulder Outcome Measures: SPADI, DASH, QuickDASH, ASES','Clinical Evidence Pack v2. Shoulder outcomes. SPADI/DASH/QuickDASH: lower is better; ASES/Constant/Penn generally higher is better. Interpret meaningful change with baseline severity, diagnosis and patient goals. Do not use PROMs alone; combine with ROM, strength, scapular control, night pain, irritability and functional demand.','clinical_evidence_pack',jsonb_build_object('evidence_pack','shoulder-v2','source_quality','curated_summary','topics',jsonb_build_array('SPADI','DASH','QuickDASH','ASES','shoulder'))),
('web_pages','clinical-pack-v2-shoulder-rotator-cuff-tests','Shoulder Rotator Cuff/Subacromial Test Cluster','Clinical Evidence Pack v2. Rotator cuff/subacromial reasoning: Neer, Hawkins-Kennedy, Empty Can/Jobe, Drop Arm and External Rotation Lag should be interpreted as a cluster with painful arc, resisted abduction/external rotation, night pain, trauma/age context and strength deficit. Single impingement signs are not definitive.','clinical_evidence_pack',jsonb_build_object('evidence_pack','shoulder-v2','source_quality','curated_summary','topics',jsonb_build_array('rotator cuff','subacromial pain','Neer','Hawkins','Empty Can','ER lag'))),
('web_pages','clinical-pack-v2-shoulder-instability-red-flags','Shoulder Instability and Red Flags','Clinical Evidence Pack v2. Instability reasoning: apprehension/relocation/posterior apprehension are interpreted with dislocation/subluxation history, apprehension not pain alone, direction of instability, hypermobility, sport demands and neurovascular screen. Red flags include deformity, suspected fracture/dislocation, neurovascular compromise, infection, cancer/systemic signs, severe constant night pain and post-operative complications.','clinical_evidence_pack',jsonb_build_object('evidence_pack','shoulder-v2','source_quality','curated_summary','topics',jsonb_build_array('shoulder instability','red flags','apprehension','relocation'))),
('web_pages','clinical-pack-v2-shoulder-exercise-progression-matrix','Shoulder Exercise Progression Matrix','Clinical Evidence Pack v2. Shoulder progression matrix. High irritability: pain control, education, gentle ROM, scapular setting, low-load isometrics, avoid provocative overhead/end-range positions. Moderate: rotator cuff ER/IR strengthening, rows, serratus/scapular control, closed-chain weight shifts within tolerance. Low irritability/return phase: progressive overhead strength, perturbation, plyometric/throwing or work-specific progression only when ROM, strength, scapular control, night pain and 24-hour response are controlled.','clinical_evidence_pack',jsonb_build_object('evidence_pack','shoulder-v2','source_quality','curated_summary','topics',jsonb_build_array('exercise progression','scapular setting','external rotation','serratus','overhead progression')))
on conflict (source_type, source_id) do update
set title=excluded.title, content=excluded.content, category=excluded.category, metadata=excluded.metadata, updated_at=now();
update public.vector_search
set content = case when content ilike '%Clinical Evidence Pack v2:%' then content else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: shoulder evidence enriched with outcome interpretation, test-cluster reasoning, red flags, and progression criteria.') end,
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('evidence_pack','shoulder-v2','source_quality','shoulder_evidence_pack'),
    updated_at = now()
where (source_type='assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('SPADI','DASH','QUICKDASH','ASES','CONSTANT_MURLEY','PENN_SHOULDER','SHOULDER_RSI')))
   or (source_type='special_tests' and source_id in ('ST_SHLDR_001','ST_SHLDR_002','ST_SHLDR_003','ST_SHLDR_005','ST_SHLDR_008','ST_SHLDR_009','ST_SHLDR_014','ST_SHLDR_015','ST_SHLDR_024'))
   or (source_type='exercises' and source_id in (select id::text from public.exercises where body_region='shoulder' and is_recommendation_candidate is true))
   or (source_type='web_pages' and (title ilike '%shoulder%' or title ilike '%rotator%' or title ilike '%subacromial%' or title ilike '%instability%'));
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
