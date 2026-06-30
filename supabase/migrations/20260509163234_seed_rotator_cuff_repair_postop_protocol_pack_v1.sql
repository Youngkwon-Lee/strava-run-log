-- Rotator Cuff Repair Post-op Protocol Pack v1
-- Purpose: strengthen Knowledge AI RAG for rotator cuff repair rehabilitation,
-- sling/ROM/loading restrictions, repair-protection red flags, active ROM/strength criteria,
-- overhead and return-to-work/sport progression.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[] language sql immutable as $$
  select array(select distinct v from unnest(coalesce(base,'{}'::text[]) || coalesce(extras,'{}'::text[])) t(v) where v is not null and btrim(v) <> '' order by v)
$$;
update public.assessment_form_templates
set
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, case when form_code in ('NPRS','VAS','PSFS') then 10 else 100 end),
  max_possible_score = coalesce(max_possible_score, case when form_code in ('NPRS','VAS','PSFS') then 10 else 100 end),
  higher_is_better = case when form_code in ('SPADI','DASH','QUICKDASH','NPRS','VAS') then false else true end,
  mcid_value = coalesce(mcid_value, case when form_code in ('NPRS','VAS','PSFS') then 2 when form_code='SPADI' then 13 when form_code='DASH' then 10 when form_code='QUICKDASH' then 16 else 8 end),
  mdc_value = coalesce(mdc_value, case when form_code in ('NPRS','VAS','PSFS') then 2 when form_code='SPADI' then 18 when form_code='DASH' then 13 when form_code='QUICKDASH' then 19 else 8 end),
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Rotator cuff repair rehabilitation and shoulder outcome measurement literature'),
  condition_overrides = coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition','rotator_cuff_repair_postoperative_rehabilitation',
    'interpretation','Interpret shoulder outcomes by surgical phase and repair restrictions. Combine SPADI/DASH/QuickDASH/ASES/Penn/Constant/Shoulder-RSI with pain, night pain, wound status, sling/immobilization, PROM/AAROM/AROM limits, repair size/tissue quality, biceps/subscapularis precautions, scapular control, strength, overhead demand and surgeon clearance.',
    'references',jsonb_build_array('ASSET/American Society of Shoulder and Elbow Therapists rotator cuff repair rehabilitation consensus','AAOS rotator cuff injuries guideline/patient-care literature','APTA rotator cuff tendinopathy and shoulder rehabilitation principles')
  )),
  updated_at = now()
where form_code in ('SPADI','DASH','QUICKDASH','ASES','CONSTANT_MURLEY','PENN_SHOULDER','SHOULDER_RSI','ROM_SHOULDER','NPRS','VAS','PSFS');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Post-operative rotator cuff repair testing should respect repair phase, tendon healing, repair size, tissue quality and surgeon restrictions.',
    'Avoid resisted rotator cuff strength testing or aggressive end-range provocation until cleared by protocol.',
    'ASSET rotator cuff repair rehabilitation consensus; AAOS rotator cuff injuries guideline/patient-care literature.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, 'rotator cuff repair post-op 회전근개 봉합술 수술후 재활 sling PROM AAROM AROM repair protection tendon healing subscapularis biceps precautions active elevation overhead return to sport'),
  interpretation = concat_ws(E'\n', interpretation, 'Rotator Cuff Repair Post-op Protocol Pack v1: after rotator cuff repair, interpret cuff tests and symptom-modification findings within surgical phase, repair size/tissue quality, sling/ROM restrictions, biceps/subscapularis precautions, pain/irritability, scapular control and surgeon clearance. Do not use provocative resisted tests as routine early-phase clearance.'),
  updated_at = now()
where id in ('ST_SHLDR_001','ST_SHLDR_002','ST_SHLDR_003','ST_SHLDR_004','ST_SHLDR_012','ST_SHLDR_013','ST_SHLDR_014','ST_SHLDR_015','ST_SHLDR_016','ST_SHLDR_017','ST_SHLDR_021','ST_SHLDR_022');
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array['rotator cuff repair','post-op rotator cuff','RCR rehab','supraspinatus repair','subscapularis repair','biceps tenodesis precautions','회전근개 봉합술','회전근개 수술후 재활','sling phase','PROM phase','active ROM phase','return to overhead work']::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'post-operative fever, wound drainage, spreading redness/warmth, suspected infection or septic arthritis',
    'sudden pop, acute loss of active elevation, marked new weakness, rapidly increasing pain or suspected repair failure',
    'neurovascular symptoms, increasing numbness/weakness, hand swelling/color change, DVT/PE symptoms or unexplained shortness of breath/chest pain',
    'uncontrolled night/rest pain, rapidly worsening stiffness, severe swelling, hematoma concern or complex regional pain features',
    'surgeon-specific sling, ROM, biceps tenodesis, subscapularis or massive-tear restrictions not available or not cleared'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Rotator Cuff Repair Post-op Protocol Pack v1: classify shoulder post-op cases by procedure, repair size/tissue quality, time since surgery, sling/immobilization, PROM/AAROM/AROM restrictions, biceps or subscapularis precautions, wound status, pain/night pain, stiffness, active elevation quality, scapular control, strength phase, overhead/work/sport demand and surgeon clearance. Escalate infection, neurovascular, repair-failure or DVT/PE concerns before progressing load.'),
  updated_at = now()
where body_region = 'shoulder';
update public.exercises
set
  evidence_level = case when evidence_level is null or evidence_level = 'not_reviewed' then 'B' else evidence_level end,
  clinical_tier = greatest(coalesce(clinical_tier,0),2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'post-operative infection, wound complication, neurovascular compromise, suspected repair failure, DVT/PE concern or uncontrolled pain',
    'exercise violates surgeon protocol, sling/immobilization phase, ROM limit, biceps tenodesis/subscapularis precaution, massive-tear restriction or weight-bearing/overhead restriction',
    'exercise causes sharp tendon pain, sudden weakness, loss of active elevation, increased night pain, marked stiffness flare or significant next-day symptoms'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'progress by criteria: wound status, pain/night pain, PROM tolerance, repair protection, scapular control, active elevation quality, strength phase, overhead demand and 24-hour response',
    'early phase emphasizes sling/protection, distal mobility, gentle scapular setting and PROM within surgeon limits; avoid active cuff loading until cleared',
    'middle phase emphasizes AAROM to AROM, scapular control, low-load isometrics and gradual rotator cuff activation without compensation or night-pain flare',
    'late phase emphasizes progressive strengthening, closed-chain control, overhead endurance, work/sport-specific loading and plyometrics only after ROM, strength, pain and surgeon clearance are adequate'
  ]::text[]),
  description_ko = coalesce(description_ko, '회전근개 봉합술 후 재활에서 수술 프로토콜, sling/ROM 제한, 통증/야간통, PROM/AROM, 견갑골 조절, 근력 단계와 24시간 반응을 확인하며 단계적으로 진행하는 운동 후보입니다.'),
  updated_at = now()
where exercise_code like 'EX_SHLD_%' or body_region = 'shoulder' or body_region_normalized = 'shoulder';
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v1-rcr-phase-protection-rom','Rotator Cuff Repair Phase Criteria: protection, PROM, AAROM and AROM','Rotator Cuff Repair Post-op Protocol Pack v1. Early phase prioritizes repair protection, sling use, wound/red-flag screen, distal mobility, scapular setting and PROM only within surgeon restrictions. Progression should not be time alone; consider repair size, tissue quality, pain/night pain, stiffness, PROM tolerance and surgeon clearance before AAROM/AROM.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','rotator-cuff-repair-postop-v1','source_quality','curated_protocol_summary','topics',jsonb_build_array('rotator cuff repair','sling','PROM','AAROM','AROM','repair protection'))),
('web_pages','clinical-pack-v1-rcr-precautions-red-flags','Rotator Cuff Repair Precautions and Red Flags','Rotator Cuff Repair Post-op Protocol Pack v1. Hold or escalate for fever, wound drainage, spreading redness, suspected infection, sudden pop, acute loss of active elevation, marked new weakness, rapidly increasing pain, neurovascular symptoms, DVT/PE symptoms, severe swelling/hematoma, CRPS features or missing surgeon restrictions. Respect biceps tenodesis, subscapularis, massive-tear and tissue-quality precautions.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','rotator-cuff-repair-postop-v1','source_quality','curated_protocol_summary','topics',jsonb_build_array('red flags','infection','repair failure','biceps tenodesis','subscapularis precautions'))),
('web_pages','clinical-pack-v1-rcr-strength-overhead-progression','Rotator Cuff Repair Strength and Overhead Progression','Rotator Cuff Repair Post-op Protocol Pack v1. Strength progression moves from scapular setting and low-load isometrics to rotator cuff activation, rows, serratus/lower-trap control, closed-chain stability and then overhead endurance. Progress only when pain/night pain, ROM, active elevation quality, scapular compensation, strength and 24-hour response are acceptable.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','rotator-cuff-repair-postop-v1','source_quality','curated_protocol_summary','topics',jsonb_build_array('rotator cuff strengthening','scapular control','overhead progression','serratus','lower trapezius'))),
('web_pages','clinical-pack-v1-rcr-return-to-work-sport','Rotator Cuff Repair Return-to-Work and Sport Criteria','Rotator Cuff Repair Post-op Protocol Pack v1. Return-to-work/sport combines surgeon clearance, full or functional ROM, controlled pain/night pain, adequate cuff/scapular strength, overhead endurance, closed-chain/perturbation tolerance, no repair-failure signs, task-specific graded exposure and confidence. Heavy lifting, throwing, swimming, contact and repetitive overhead work require later-phase criteria rather than pain alone.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','rotator-cuff-repair-postop-v1','source_quality','curated_protocol_summary','topics',jsonb_build_array('return to work','return to sport','overhead athlete','lifting','throwing','work hardening')))
on conflict (source_type, source_id) do update
set title=excluded.title, content=excluded.content, category=excluded.category, metadata=excluded.metadata, updated_at=now();
update public.vector_search
set content = case when content ilike '%Rotator Cuff Repair Post-op Protocol Pack v1:%' then content else concat_ws(E'\n', content, 'Rotator Cuff Repair Post-op Protocol Pack v1: shoulder post-op rehabilitation evidence enriched with sling/ROM/loading restrictions, repair-protection red flags, active ROM/strength criteria, overhead and return-to-work/sport progression.') end,
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('evidence_pack','rotator-cuff-repair-postop-v1','source_quality','rotator_cuff_repair_protocol_pack'),
    updated_at = now()
where (source_type='assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('SPADI','DASH','QUICKDASH','ASES','CONSTANT_MURLEY','PENN_SHOULDER','SHOULDER_RSI','ROM_SHOULDER','NPRS','VAS','PSFS')))
   or (source_type='special_tests' and source_id in ('ST_SHLDR_001','ST_SHLDR_002','ST_SHLDR_003','ST_SHLDR_004','ST_SHLDR_012','ST_SHLDR_013','ST_SHLDR_014','ST_SHLDR_015','ST_SHLDR_016','ST_SHLDR_017','ST_SHLDR_021','ST_SHLDR_022'))
   or (source_type='exercises' and source_id in (select id::text from public.exercises where is_recommendation_candidate is true and (exercise_code like 'EX_SHLD_%' or body_region = 'shoulder' or body_region_normalized = 'shoulder')))
   or (source_type='web_pages' and metadata->>'evidence_pack' = 'rotator-cuff-repair-postop-v1');
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
