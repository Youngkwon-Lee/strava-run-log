-- Knee Evidence Pack v2
-- Purpose:
-- - Strengthen Knowledge AI RAG for ACL/meniscus/patellofemoral/knee OA reasoning.
-- - Add outcome interpretation, special-test references, knee exercise progression,
--   red flags and return-to-function criteria.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[]
language sql
immutable
as $$
  select array(
    select distinct v
    from unnest(coalesce(base, '{}'::text[]) || coalesce(extras, '{}'::text[])) as t(v)
    where v is not null and btrim(v) <> ''
    order by v
  );
$$;
-- Outcome measures: KOOS, KOOS-PS, LEFS, IKDC
update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, 8),
  mdc_value = coalesce(mdc_value, 8),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, 100),
  max_possible_score = coalesce(max_possible_score, 100),
  higher_is_better = true,
  condition_overrides = coalesce(condition_overrides, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition', 'knee_pain_acl_meniscus_patellofemoral_or_oa',
    'interpretation', 'Use subscales and patient goals; meaningful change varies by population and subscale, often around 8-10 points.',
    'references', jsonb_build_array('Roos et al. KOOS', 'Collins et al. KOOS measurement properties')
  )),
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'KOOS measurement literature; knee CPG outcome-monitoring principles'),
  updated_at = now()
where form_code in ('KOOS','KOOS_PS');
update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, 9),
  mdc_value = coalesce(mdc_value, 9),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, 80),
  max_possible_score = coalesce(max_possible_score, 80),
  higher_is_better = true,
  condition_overrides = coalesce(condition_overrides, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition', 'lower_extremity_knee_function',
    'interpretation', 'Higher is better. About 9 points is commonly used as a practical MDC/meaningful-change marker; interpret with diagnosis and baseline severity.',
    'references', jsonb_build_array('Binkley et al. LEFS 1999')
  )),
  evidence_level = coalesce(evidence_level, 'A'),
  evidence_source = coalesce(evidence_source, 'Binkley et al. 1999 LEFS'),
  updated_at = now()
where form_code = 'LEFS';
update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, 11),
  mdc_value = coalesce(mdc_value, 8.8),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, 100),
  max_possible_score = coalesce(max_possible_score, 100),
  higher_is_better = true,
  condition_overrides = coalesce(condition_overrides, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition', 'acl_meniscus_knee_sports_function',
    'interpretation', 'Higher is better. Use with hop/strength/effusion/ROM and patient-specific sport goals; about 9-12 points is a practical meaningful-change marker depending on population.',
    'references', jsonb_build_array('Irrgang et al. IKDC subjective knee form', 'ACL/knee outcome measurement literature')
  )),
  evidence_level = coalesce(evidence_level, 'Level I'),
  evidence_source = coalesce(evidence_source, 'IKDC subjective knee form literature'),
  updated_at = now()
where form_code = 'IKDC';
-- Special tests references and Korean clinical keywords
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Benjaminse A et al. Clinical diagnosis of an anterior cruciate ligament rupture: a meta-analysis. J Orthop Sports Phys Ther. 2006.',
    'van Eck CF et al. Methods to diagnose acute ACL rupture: Lachman, pivot shift, anterior drawer systematic review literature.',
    'APTA/JOSPT Knee Stability and Movement Coordination Impairments CPG.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, 'ACL 전방십자인대 라크만 전방전위 피벗시프트 급성 무릎 불안정성 hemarthrosis giving way Lachman anterior drawer pivot shift'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret ACL tests as a cluster with history of pivot injury, rapid effusion/hemarthrosis, giving-way, ROM loss, and patient irritability. Pivot shift is often more specific but may be limited by guarding.'),
  updated_at = now()
where id in ('ST_KNEE_001','ST_KNEE_002','ST_KNEE_008');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Hegedus EJ et al. Physical examination tests of the knee: systematic review/meta-analysis literature.',
    'Smith BE et al. Diagnostic accuracy of clinical tests for meniscal tears: systematic review/meta-analysis.',
    'APTA/JOSPT Meniscal and Articular Cartilage Lesions CPG Revision 2018.',
    'AAOS Clinical Practice Guideline for Acute Isolated Meniscal Pathology.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '반월상연골 meniscus McMurray Thessaly joint line locking catching effusion twisting pain squat pain'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: meniscus tests have variable accuracy. Combine with joint-line pain, mechanical symptoms, effusion, loss of extension, squat/twist response, age/degenerative context, and trauma history.'),
  updated_at = now()
where id in ('ST_KNEE_003','ST_KNEE_007');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Willy RW et al. Patellofemoral Pain Clinical Practice Guideline. J Orthop Sports Phys Ther. 2019.',
    'Patellofemoral pain diagnostic and movement coordination classification literature.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '슬개대퇴 통증 PFP PFPS anterior knee pain squat stairs prolonged sitting step-down dynamic valgus patellar apprehension'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: for patellofemoral pain/instability, prioritize pain reproduction with squat/stairs/prolonged sitting, step-down quality, dynamic valgus, hip/knee strength, and apprehension/instability signs.'),
  updated_at = now()
where id = 'ST_KNEE_014';
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Ottawa Knee Rule validation literature for fracture screening after acute knee injury.',
    'Stiell IG et al. Ottawa Knee Rule derivation/validation literature.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, 'Ottawa knee rule 골절 선별 급성 외상 체중부하 불가 슬개골 비골두 굴곡 제한'),
  updated_at = now()
where name ilike '%Ottawa%' and body_region = 'knee';
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Knee collateral ligament clinical examination literature.',
    'APTA/JOSPT knee ligament injury clinical practice principles.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, 'MCL LCL 내측측부인대 외측측부인대 valgus varus stress ligament laxity joint opening endpoint'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret collateral ligament stress tests with side-to-side laxity, endpoint quality, pain location, swelling, mechanism, and possible multi-ligament injury.'),
  updated_at = now()
where id in ('ST_KNEE_005','ST_KNEE_006');
-- Knee conditions: red flags and presentation context
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array['knee pain','무릎통증','ACL','meniscus','patellofemoral','knee OA','giving way','locking','effusion']::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'inability to bear weight after acute trauma or suspected fracture/dislocation',
    'large rapid effusion/hemarthrosis after pivot injury',
    'true locked knee or inability to fully extend after trauma',
    'progressive neurological or vascular compromise, cold foot, absent pulses, severe calf swelling',
    'fever, marked warmth/redness, suspected infection, unexplained systemic symptoms',
    'suspected DVT, compartment syndrome, tumor, or inflammatory arthritis flare requiring medical review'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Evidence Pack v2: classify knee presentations by trauma/non-trauma, effusion timing, locking/catching/giving-way, ROM, weight-bearing tolerance, patellofemoral load response, and function goals. Use KOOS/LEFS/IKDC plus strength, hop/step-down quality, swelling and pain irritability.'),
  updated_at = now()
where body_region = 'knee';
-- Exercises: core knee recommendation candidates
update public.exercises
set
  evidence_level = case when evidence_level = 'not_reviewed' or evidence_level is null then 'B' else evidence_level end,
  clinical_tier = greatest(coalesce(clinical_tier, 0), 2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'suspected fracture/dislocation, acute infection, DVT, or unresolved red flag',
    'true locked knee or rapidly worsening effusion after trauma',
    'post-operative restriction not cleared by surgeon/protocol',
    'exercise causes instability, giving-way, or significant next-day flare'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'monitor effusion, pain irritability, extension loss, and 24-hour response',
    'avoid dynamic valgus, uncontrolled tibial rotation, and painful deep flexion early',
    'progress range, load, speed, and single-leg demand gradually',
    'for ACL/meniscus, match progression to tissue healing/protocol and clinician clearance'
  ]::text[]),
  description_ko = coalesce(description_ko, '무릎 통증/손상에서 통증, 부종, 가동범위, 정렬 조절, 24시간 반응을 확인하며 단계적으로 진행하는 핵심 운동 후보입니다.'),
  updated_at = now()
where exercise_code in (
  'EX_KNEE_SGT_001','EX_KNEE_SGT_002','EX_KNEE_SGT_003','EX_KNEE_SGT_004','EX_KNEE_SGT_008','EX_KNEE_SGT_012','EX_KNEE_SGT_013','EX_KNEE_SGT_014','EX_KNEE_SGT_015',
  'EX_KNEE_BAL_005','EX_KNEE_BAL_006','EX_KNEE_BAL_007','EX_KNEE_BAL_008','EX_KNEE_BAL_011',
  'EX_KNEE_FNC_001','EX_KNEE_FNC_002','EX_KNEE_FNC_003','EX_KNEE_FNC_008','EX_KNEE_FNC_015',
  'EX_KNEE_NMR_011','EX_KNEE_NMR_012','EX_KNEE_NMR_015',
  'EX_KNEE_PRP_001','EX_KNEE_PRP_004','EX_KNEE_PRP_005','EX_KNEE_PRP_006','EX_KNEE_PRP_007'
);
-- Curated RAG rows
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v2-knee-outcome-measures','Knee Outcome Measures: KOOS, LEFS, IKDC interpretation','Clinical Evidence Pack v2. Knee outcome interpretation. KOOS/KOOS-PS: higher is better, use subscales and patient goals; practical meaningful change often around 8-10 points depending on population/subscale. LEFS: higher is better, 0-80, about 9 points commonly used as MDC/meaningful-change marker. IKDC: higher is better, 0-100, useful for ACL/meniscus/sports knee function; interpret with strength, hop/step-down, effusion, ROM, and sport goals. Do not use PROMs alone for return-to-sport decisions.','clinical_evidence_pack',jsonb_build_object('evidence_pack','knee-v2','source_quality','curated_summary','topics',jsonb_build_array('KOOS','LEFS','IKDC','MCID','MDC','knee'))),
('web_pages','clinical-pack-v2-knee-acl-meniscus-tests','Knee Special Tests: ACL and meniscus interpretation','Clinical Evidence Pack v2. ACL: Lachman, anterior drawer and pivot shift should be interpreted with mechanism, rapid effusion/hemarthrosis, giving-way, ROM loss and guarding. Pivot shift may be more specific but is limited by pain/guarding. Meniscus: McMurray and Thessaly accuracy is variable; combine with joint-line symptoms, locking/catching, effusion, loss of extension, squat/twist response, age and degenerative context. Use referral/imaging criteria when red flags or surgical indications are present.','clinical_evidence_pack',jsonb_build_object('evidence_pack','knee-v2','source_quality','curated_summary','topics',jsonb_build_array('ACL','Lachman','pivot shift','anterior drawer','McMurray','Thessaly','meniscus'))),
('web_pages','clinical-pack-v2-knee-patellofemoral-red-flags','Knee Patellofemoral Pain and Red Flags','Clinical Evidence Pack v2. Patellofemoral pain: anterior/retropatellar/peripatellar pain reproduced by squat, stairs, running, jumping or prolonged sitting. Check step-down/single-leg squat quality, dynamic valgus, hip and quadriceps strength, load tolerance and psychosocial factors. Red flags: inability to bear weight after trauma, suspected fracture/dislocation, true locked knee, rapid large effusion, fever/warmth/redness, vascular/neuro compromise, DVT symptoms, or post-op complication.','clinical_evidence_pack',jsonb_build_object('evidence_pack','knee-v2','source_quality','curated_summary','topics',jsonb_build_array('patellofemoral pain','red flags','step-down','dynamic valgus','knee'))),
('web_pages','clinical-pack-v2-knee-exercise-progression-matrix','Knee Exercise Progression Matrix','Clinical Evidence Pack v2. Knee progression matrix. High irritability/acute: control swelling/pain, restore extension, quad activation/isometrics, straight-leg raise if no lag, gentle ROM, gait/loading within tolerance. Moderate: closed-chain strength, wall squat, terminal knee extension, step-up, hip abductor/external rotator strengthening, balance/proprioception. Low irritability/return phase: single-leg squat/step-down quality, eccentric control, perturbation, Y-balance/star reach, agility, hopping/plyometrics only when swelling is controlled, ROM/strength are adequate and no giving-way. Progress by effusion, pain, ROM, strength symmetry, movement quality and 24-hour response.','clinical_evidence_pack',jsonb_build_object('evidence_pack','knee-v2','source_quality','curated_summary','topics',jsonb_build_array('exercise progression','quad set','SLR','TKE','step-up','step-down','balance','ACL','meniscus','patellofemoral')))
on conflict (source_type, source_id) do update
set title = excluded.title, content = excluded.content, category = excluded.category, metadata = excluded.metadata, updated_at = now();
-- Vector markers for affected rows
update public.vector_search
set
  content = case when content ilike '%Clinical Evidence Pack v2:%' then content else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: knee evidence enriched with outcome interpretation, special-test cluster reasoning, red flags, and progression criteria.') end,
  metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('evidence_pack','knee-v2','source_quality','knee_evidence_pack'),
  updated_at = now()
where (source_type = 'assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('KOOS','KOOS_PS','LEFS','IKDC')))
   or (source_type = 'special_tests' and source_id in ('ST_KNEE_001','ST_KNEE_002','ST_KNEE_003','ST_KNEE_005','ST_KNEE_006','ST_KNEE_007','ST_KNEE_008','ST_KNEE_014'))
   or (source_type = 'exercises' and source_id in (select id::text from public.exercises where exercise_code in ('EX_KNEE_SGT_001','EX_KNEE_SGT_002','EX_KNEE_SGT_003','EX_KNEE_SGT_004','EX_KNEE_SGT_008','EX_KNEE_SGT_012','EX_KNEE_SGT_013','EX_KNEE_SGT_014','EX_KNEE_SGT_015','EX_KNEE_BAL_005','EX_KNEE_BAL_006','EX_KNEE_BAL_007','EX_KNEE_BAL_008','EX_KNEE_BAL_011','EX_KNEE_FNC_001','EX_KNEE_FNC_002','EX_KNEE_FNC_003','EX_KNEE_FNC_008','EX_KNEE_FNC_015','EX_KNEE_NMR_011','EX_KNEE_NMR_012','EX_KNEE_NMR_015','EX_KNEE_PRP_001','EX_KNEE_PRP_004','EX_KNEE_PRP_005','EX_KNEE_PRP_006','EX_KNEE_PRP_007')))
   or (source_type = 'web_pages' and (title ilike '%knee%' or title ilike '%menisc%' or title ilike '%patellofemoral%' or title ilike '%ACL%'));
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
