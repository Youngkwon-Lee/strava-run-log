-- ACL Post-op Protocol Pack v1
-- Purpose: strengthen Knowledge AI RAG for ACL reconstruction/repair rehabilitation,
-- criteria-based phase progression, graft/meniscus precautions, red flags, return-to-run,
-- return-to-sport and outcome-test interpretation.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[] language sql immutable as $$
  select array(select distinct v from unnest(coalesce(base,'{}'::text[]) || coalesce(extras,'{}'::text[])) t(v) where v is not null and btrim(v) <> '' order by v)
$$;
update public.assessment_form_templates
set
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, case when form_code in ('NPRS','VAS','PSFS','TEGNER') then 10 when form_code = 'LEFS' then 80 else 100 end),
  max_possible_score = coalesce(max_possible_score, case when form_code in ('NPRS','VAS','PSFS','TEGNER') then 10 when form_code = 'LEFS' then 80 else 100 end),
  higher_is_better = case when form_code in ('NPRS','VAS') then false else true end,
  mcid_value = coalesce(mcid_value, case when form_code in ('NPRS','VAS','PSFS') then 2 when form_code = 'LEFS' then 9 when form_code in ('IKDC','KOOS','KOOS_PS','ACL_RSI','LYSHOLM') then 9 when form_code = 'TEGNER' then 1 else 8 end),
  mdc_value = coalesce(mdc_value, case when form_code in ('NPRS','VAS','PSFS') then 2 when form_code = 'LEFS' then 9.3 when form_code in ('IKDC','KOOS','KOOS_PS','ACL_RSI','LYSHOLM') then 8 when form_code = 'TEGNER' then 1 else 8 end),
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'ACL reconstruction rehabilitation CPGs and return-to-sport outcome measurement literature'),
  condition_overrides = coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition','acl_reconstruction_postoperative_rehabilitation',
    'interpretation','Post-op ACL outcomes should be interpreted by phase and criteria, not time alone. Combine pain/effusion, full extension, flexion ROM, gait, quadriceps activation/strength symmetry, hop/Y-balance/step-down quality, ACL-RSI psychological readiness, surgeon restrictions and concomitant meniscus/cartilage procedure precautions.',
    'references',jsonb_build_array('MOON ACL rehabilitation and return-to-sport literature','Delaware-Oslo ACL cohort and criterion-based RTS literature','APTA/JOSPT knee ligament sprain CPG revision literature')
  )),
  updated_at = now()
where form_code in ('ACL_RSI','IKDC','KOOS','KOOS_PS','LEFS','LYSHOLM','TEGNER','ROM_KNEE','NPRS','VAS','PSFS');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'ACL post-operative rehabilitation should use surgeon protocol, graft type and concomitant procedures to determine precautions and progression.',
    'Return-to-sport testing should combine strength symmetry, hop/Y-balance/step-down quality, effusion, ROM, confidence/readiness and sport-specific demands rather than one test alone.',
    'APTA/JOSPT Knee Stability and Movement Coordination Impairments CPG; MOON/Delaware-Oslo ACL rehabilitation literature.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, 'ACL reconstruction post-op 전방십자인대 재건술 수술후 재활 graft precautions effusion ROM quadriceps activation strength symmetry hop test Y-balance return to run return to sport ACL-RSI'),
  interpretation = concat_ws(E'\n', interpretation, 'ACL Post-op Protocol Pack v1: after ACL reconstruction/repair, interpret ligament and functional findings within healing phase, graft type, surgeon restrictions, meniscus/cartilage precautions, pain/effusion, ROM, quadriceps control, movement quality and psychological readiness. RTS decisions should not rely on a single hop or laxity test.'),
  updated_at = now()
where id in ('ST_KNEE_001','ST_KNEE_002','ST_KNEE_008','ST_KNEE_005','ST_KNEE_006','ST_KNEE_014','ST_KNEE_016','ST_KNEE_018','ST_KNEE_019');
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array['ACL reconstruction','ACL repair','post-op ACL','postoperative ACL rehab','전방십자인대 재건술','전방십자인대 수술후 재활','return to run','return to sport','graft precautions','meniscus repair precautions']::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'post-operative fever, wound drainage, spreading redness/warmth, suspected infection or septic arthritis',
    'calf pain/swelling, shortness of breath, chest pain, suspected DVT/PE or vascular compromise',
    'new loss of extension, locked knee, rapidly increasing effusion, acute pop/giving-way, suspected graft failure or meniscus repair complication',
    'uncontrolled pain, neurovascular symptoms, compartment-syndrome concern or sudden marked weakness',
    'surgeon-specific restrictions, graft type precautions or concomitant meniscus/cartilage procedure limits not available or not cleared'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'ACL Post-op Protocol Pack v1: for post-operative ACL cases, classify by surgical procedure/graft/concomitant meniscus or cartilage work, time since surgery, surgeon restrictions, pain/effusion, wound status, extension/flexion ROM, quadriceps activation/lag, gait/weight-bearing status, strength symmetry, hop/Y-balance/step-down quality, ACL-RSI readiness and sport/work demand. Escalate infection, DVT/PE, neurovascular, graft-failure or locked-knee signs before progressing load.'),
  updated_at = now()
where body_region = 'knee';
update public.exercises
set
  evidence_level = case when evidence_level is null or evidence_level = 'not_reviewed' then 'B' else evidence_level end,
  clinical_tier = greatest(coalesce(clinical_tier,0),2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'post-operative infection, DVT/PE concern, neurovascular compromise, compartment syndrome, suspected graft failure, locked knee or rapidly worsening effusion',
    'exercise violates surgeon protocol, graft-specific restriction, meniscus repair/cartilage procedure restriction or weight-bearing/ROM precaution',
    'exercise causes giving-way, sharp joint-line pain, extension loss, marked swelling increase, wound symptoms or significant next-day flare'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'progress by criteria: pain/effusion, full extension, flexion ROM, quadriceps activation/no lag, gait quality, strength symmetry, movement quality and 24-hour response',
    'early phase emphasizes extension, swelling control, patellar mobility, quad set/SLR without lag, gait and safe ROM within protocol',
    'middle phase emphasizes closed-chain strength, step control, hip/trunk control, balance and gradual aerobic loading without effusion response',
    'late phase/RTS emphasizes running, deceleration, cutting, hopping/plyometrics and sport tasks only after strength, hop/Y-balance, movement quality, confidence and surgeon clearance are adequate'
  ]::text[]),
  description_ko = coalesce(description_ko, 'ACL 수술 후 재활에서 통증/부종, 완전 신전, ROM, 대퇴사두근 활성, 보행, 근력 대칭성, 움직임 질, 수술 프로토콜과 24시간 반응을 확인하며 단계적으로 진행하는 운동 후보입니다.'),
  updated_at = now()
where exercise_code like 'EX_KNEE_%' or body_region = 'knee' or body_region_normalized = 'knee';
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v1-acl-postop-phase-criteria','ACL Post-op Phase Criteria: protect, restore ROM, strength and function','ACL Post-op Protocol Pack v1. ACL reconstruction/repair rehabilitation should be criterion-based and surgeon-protocol aware. Early/protective phase: screen wound/infection/DVT, control pain/effusion, restore full extension, safe flexion ROM, patellar mobility, quadriceps activation and gait/weight-bearing within protocol. Progress when effusion is controlled, extension is full, SLR has no lag, gait is safe and restrictions are respected.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','acl-postop-v1','source_quality','curated_protocol_summary','topics',jsonb_build_array('ACL reconstruction','post-op phase','full extension','quad activation','effusion','gait'))),
('web_pages','clinical-pack-v1-acl-postop-precautions-red-flags','ACL Post-op Precautions and Red Flags','ACL Post-op Protocol Pack v1. Red flags/hold criteria: fever, wound drainage, spreading redness/warmth, suspected infection, calf swelling/pain, shortness of breath/chest pain, neurovascular compromise, compartment-syndrome concern, locked knee, rapidly increasing effusion, acute pop/giving-way, suspected graft failure, uncontrolled pain or missing surgeon restrictions. Meniscus repair/cartilage procedures may restrict weight-bearing, flexion angle, pivoting and loaded squats longer than isolated ACL reconstruction.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','acl-postop-v1','source_quality','curated_protocol_summary','topics',jsonb_build_array('red flags','DVT','infection','graft failure','meniscus repair precautions'))),
('web_pages','clinical-pack-v1-acl-return-to-run-strength','ACL Return-to-Run and Strength Progression','ACL Post-op Protocol Pack v1. Return-to-run should be considered only when pain/effusion are minimal, full extension and adequate flexion are restored, gait and step-down quality are controlled, quadriceps strength is sufficient, single-leg control is acceptable and surgeon protocol allows it. Progress from bike/walk/closed-chain strength to walk-jog intervals, then running volume and speed while monitoring swelling, pain, confidence and 24-hour response.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','acl-postop-v1','source_quality','curated_protocol_summary','topics',jsonb_build_array('return to run','quadriceps strength','step-down','walk-jog','24-hour response'))),
('web_pages','clinical-pack-v1-acl-return-to-sport-testing','ACL Return-to-Sport Testing: strength, hop, movement quality and readiness','ACL Post-op Protocol Pack v1. Return-to-sport should combine time from surgery, surgeon clearance, no effusion, full ROM, quadriceps/hamstring strength symmetry, hop test battery or Y-balance symmetry, deceleration/cutting/landing quality, sport-specific tolerance, no giving-way and psychological readiness such as ACL-RSI. Avoid clearing sport from a single hop distance; inspect dynamic valgus, trunk control, fatigue response, confidence and sport demands.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','acl-postop-v1','source_quality','curated_protocol_summary','topics',jsonb_build_array('return to sport','hop test','Y-balance','ACL-RSI','strength symmetry','dynamic valgus')))
on conflict (source_type, source_id) do update
set title=excluded.title, content=excluded.content, category=excluded.category, metadata=excluded.metadata, updated_at=now();
update public.vector_search
set content = case when content ilike '%ACL Post-op Protocol Pack v1:%' then content else concat_ws(E'\n', content, 'ACL Post-op Protocol Pack v1: ACL reconstruction/repair rehabilitation evidence enriched with phase criteria, surgeon/graft/meniscus precautions, red flags, return-to-run, return-to-sport and outcome-test interpretation.') end,
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('evidence_pack','acl-postop-v1','source_quality','acl_postop_protocol_pack'),
    updated_at = now()
where (source_type='assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('ACL_RSI','IKDC','KOOS','KOOS_PS','LEFS','LYSHOLM','TEGNER','ROM_KNEE','NPRS','VAS','PSFS')))
   or (source_type='special_tests' and source_id in ('ST_KNEE_001','ST_KNEE_002','ST_KNEE_008','ST_KNEE_005','ST_KNEE_006','ST_KNEE_014','ST_KNEE_016','ST_KNEE_018','ST_KNEE_019'))
   or (source_type='exercises' and source_id in (select id::text from public.exercises where is_recommendation_candidate is true and (exercise_code like 'EX_KNEE_%' or body_region = 'knee' or body_region_normalized = 'knee')))
   or (source_type='web_pages' and metadata->>'evidence_pack' = 'acl-postop-v1');
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
