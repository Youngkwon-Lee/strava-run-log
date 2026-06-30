-- Post-op Protocol Packs Batch v1
-- Packs: THR/Hip Arthroscopy, Distal Radius ORIF, Carpal Tunnel Release
-- Purpose: strengthen Knowledge AI RAG for high-yield post-operative rehabilitation protocols.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[] language sql immutable as $$
  select array(select distinct v from unnest(coalesce(base,'{}'::text[]) || coalesce(extras,'{}'::text[])) t(v) where v is not null and btrim(v) <> '' order by v)
$$;
-- THR / Hip Arthroscopy
update public.assessment_form_templates
set condition_overrides = coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
  'condition','thr_hip_arthroscopy_postoperative_rehabilitation',
  'interpretation','Interpret hip post-op outcomes with procedure type, surgical approach, WB/ROM restrictions, dislocation/impingement precautions, wound/DVT/infection screen, gait quality, hip flexor/adductor/gluteal irritability, strength, return-to-run/sport criteria and surgeon clearance.',
  'references',jsonb_build_array('THA/THR post-operative precautions and rehabilitation literature','Hip arthroscopy FAI/labral repair rehabilitation and return-to-sport literature')
)), updated_at=now()
where form_code in ('HOOS','LEFS','HIP_RSI','ROM_HIP','NPRS','VAS','PSFS','TUG','6MWT');
update public.special_tests
set reference_list=public._clinical_pack_append_text_array(reference_list,array['Post-operative hip testing must respect procedure-specific WB/ROM limits, dislocation/impingement precautions, labral repair/capsular closure restrictions and surgeon clearance.']::text[]),
 clinical_keywords_ko=concat_ws(' ',clinical_keywords_ko,'THR THA total hip replacement hip arthroscopy labral repair FAI postop 고관절 인공관절 고관절경 수술후 재활 체중부하 ROM 제한 탈구 주의'),
 interpretation=concat_ws(E'\n',interpretation,'THR/Hip Arthroscopy Post-op Protocol Pack v1: interpret hip tests within procedure phase, WB/ROM restrictions, approach-specific precautions, labral/capsular repair, irritability, gait and surgeon clearance. Avoid provocative impingement/end-range tests or aggressive loading when protocol-restricted.'),
 updated_at=now()
where id in ('ST_HIP_001','ST_HIP_002','ST_HIP_003','ST_HIP_004','ST_HIP_005','ST_HIP_006','ST_HIP_011','ST_HIP_012','ST_HIP_015','ST_HIP_016','ST_HIP_017','ST_HIP_019','ST_HIP_020');
update public.condition_library
set common_aliases=public._clinical_pack_append_text_array(common_aliases,array['THR','THA','total hip replacement','hip arthroscopy','labral repair','FAI surgery','post-op hip','고관절 인공관절','고관절경','고관절 수술후 재활']::text[]),
 red_flags=public._clinical_pack_append_text_array(red_flags,array['post-op fever, wound drainage, spreading redness/warmth or suspected infection','DVT/PE symptoms, calf swelling/pain, dyspnea or chest pain','new dislocation/subluxation feeling, leg length/rotation change, inability to bear weight, fracture or implant complication concern','neurovascular symptoms, progressive weakness/numbness, severe swelling/hematoma or uncontrolled night/rest pain','procedure-specific WB/ROM, hip precautions, labral repair or capsular restrictions unavailable or not cleared']::text[]),
 clinical_presentation=concat_ws(E'\n',clinical_presentation,'THR/Hip Arthroscopy Post-op Protocol Pack v1: classify by THR/THA approach vs hip arthroscopy/labral repair, time since surgery, WB status, ROM/hip precautions, wound/DVT/infection screen, gait, hip flexor/adductor/gluteal irritability, strength, running/sport/work demand and surgeon clearance before progression.'),
 updated_at=now()
where body_region='hip';
update public.exercises
set evidence_level=case when evidence_level is null or evidence_level='not_reviewed' then 'B' else evidence_level end,
 clinical_tier=greatest(coalesce(clinical_tier,0),2), is_recommendation_candidate=true,
 contraindications=public._clinical_pack_append_text_array(contraindications,array['post-op infection/wound issue, DVT/PE concern, dislocation/fracture/implant complication, neurovascular compromise or uncontrolled pain','exercise violates WB, ROM, hip precaution, labral/capsular repair, impact/running or surgeon-specific restriction','exercise causes sharp anterior/groin pain, instability, limp escalation, swelling/night-pain flare or poor 24-hour response']::text[]),
 cautions=public._clinical_pack_append_text_array(cautions,array['progress by procedure, approach, WB/ROM restrictions, pain/night pain, gait quality, gluteal control, hip flexor/adductor irritability, strength and 24-hour response','THR early phase emphasizes precautions, gait, bed mobility/transfers, swelling control and low-load activation; hip arthroscopy early phase emphasizes protected ROM, avoiding impingement positions and gradual muscle activation','running, cutting, pivoting, deep flexion/rotation and heavy loaded hip work require later-phase criteria and surgeon clearance']::text[]),
 description_ko=coalesce(description_ko,'THR/고관절경 수술 후 재활에서 체중부하, ROM/탈구/충돌 주의, 통증, 보행, 둔근 조절, 근력과 24시간 반응을 기준으로 단계적으로 진행하는 운동 후보입니다.'), updated_at=now()
where exercise_code like 'EX_HIP_%' or body_region='hip' or body_region_normalized='hip';
-- Distal radius ORIF + Carpal Tunnel Release
update public.assessment_form_templates
set condition_overrides=coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
  'condition','distal_radius_orif_carpal_tunnel_release_postoperative_rehabilitation',
  'interpretation','Interpret wrist/hand post-op outcomes with wound/neurovascular status, edema, pain, ROM, tendon/nerve irritability, scar sensitivity, grip/pinch progression, immobilization/hardware precautions, pillar pain and work demands.',
  'references',jsonb_build_array('Distal radius fracture ORIF post-operative hand therapy literature','Carpal tunnel release post-operative hand therapy literature')
)), updated_at=now()
where form_code in ('DASH','QUICKDASH','PRWE','GRIP','ROM_WRIST','ROM_ELBOW','NPRS','VAS','PSFS');
update public.special_tests
set reference_list=public._clinical_pack_append_text_array(reference_list,array['Post-operative wrist/hand testing should respect wound healing, immobilization, hardware stability, tendon irritation, nerve recovery and surgeon clearance.']::text[]),
 clinical_keywords_ko=concat_ws(' ',clinical_keywords_ko,'distal radius ORIF carpal tunnel release postop 손목 골절 수술 수근관 유리술 wound scar edema tendon glide nerve glide grip pinch CRPS pillar pain'),
 interpretation=concat_ws(E'\n',interpretation,'Distal Radius ORIF / Carpal Tunnel Release Protocol Pack v1: interpret wrist/hand tests within post-op phase, wound status, edema, neurovascular findings, tendon/nerve irritability, hardware/immobilization restrictions, scar sensitivity, grip/pinch tolerance and work demand. Avoid provocative loading when healing or surgeon restrictions are unclear.'),
 updated_at=now()
where id in ('ST_WRST_001','ST_WRST_002','ST_WRST_003','ST_WRST_004','ST_WRST_005','ST_WRST_006','ST_WRST_007','ST_WRST_008','ST_WRST_009','ST_WRST_010');
update public.condition_library
set common_aliases=public._clinical_pack_append_text_array(common_aliases,array['distal radius ORIF','volar plate','wrist fracture surgery','post-wrist fracture surgery','carpal tunnel release','post-CTR','median nerve decompression','요골 원위부 골절 내고정술','수근관 유리술','손목 수술후 재활']::text[]),
 red_flags=public._clinical_pack_append_text_array(red_flags,array['post-op fever, wound drainage, spreading redness/warmth, infection or tendon sheath infection concern','neurovascular compromise: cool/pale hand, delayed capillary refill, progressive numbness/weakness, severe swelling or compartment concern','CRPS features, disproportionate pain, color/temperature/sweating changes or severe stiffness','hardware failure/malunion concern, sudden loss of function, tendon irritation/rupture signs, new triggering or severe crepitus','worsening median nerve symptoms after CTR, thenar weakness/atrophy, severe pillar pain or recurrent/progressive neurologic symptoms']::text[]),
 clinical_presentation=concat_ws(E'\n',clinical_presentation,'Distal Radius ORIF / Carpal Tunnel Release Protocol Pack v1: classify by procedure, wound/scar status, edema, neurovascular screen, immobilization/hardware restrictions, ROM stage, tendon/nerve glide tolerance, grip/pinch capacity, pillar pain, CRPS screen and work-specific hand demand before loading progression.'),
 updated_at=now()
where body_region='wrist_hand';
update public.exercises
set evidence_level=case when evidence_level is null or evidence_level='not_reviewed' then 'B' else evidence_level end,
 clinical_tier=greatest(coalesce(clinical_tier,0),2), is_recommendation_candidate=true,
 contraindications=public._clinical_pack_append_text_array(contraindications,array['post-op infection/wound issue, neurovascular compromise, compartment concern, CRPS escalation, hardware failure or tendon rupture concern','exercise violates immobilization, lifting, weight-bearing, gripping, incision/scar or surgeon-specific restriction','exercise worsens paresthesia, pillar pain, edema, tendon irritation, scar sensitivity, night pain or 24-hour response']::text[]),
 cautions=public._clinical_pack_append_text_array(cautions,array['distal radius ORIF progression emphasizes edema control, finger/forearm/wrist ROM, scar mobility, gradual grip, proprioception and loading only when union/hardware/surgeon criteria allow','carpal tunnel release progression emphasizes wound protection, tendon/nerve glides, scar desensitization, gentle grip/pinch and ergonomic return-to-work without symptom flare','monitor swelling, sensation, capillary refill, scar sensitivity, tendon irritation, CRPS signs and next-day response before progressing resistance or weight-bearing']::text[]),
 description_ko=coalesce(description_ko,'요골 원위부 ORIF/수근관 유리술 후 재활에서 상처, 부종, 신경혈관 상태, ROM, 힘줄/신경 활주, 그립/핀치와 24시간 반응을 기준으로 단계적으로 진행하는 운동 후보입니다.'), updated_at=now()
where exercise_code like 'EX_WRST_%' or exercise_code like 'EX_HAND_%' or body_region='wrist_hand' or body_region='upper_extremity' or body_region_normalized='wrist_hand' or body_region_normalized='upper_extremity';
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v1-thr-hip-arthroscopy-precautions','THR and Hip Arthroscopy Precautions','THR/Hip Arthroscopy Protocol Pack v1. Respect surgical approach, WB/ROM restrictions, dislocation precautions, labral repair/capsular closure restrictions, wound/DVT/infection screen and surgeon clearance before progressing gait, ROM, strengthening, running or sport.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','postop-batch-v1-thr-hip-arthroscopy','source_quality','curated_protocol_summary')),
('web_pages','clinical-pack-v1-thr-hip-arthroscopy-progression','THR and Hip Arthroscopy Loading Progression','THR/Hip Arthroscopy Protocol Pack v1. Progress from protection, gait and low-load activation to gluteal control, hip strength, balance, functional loading, running and sport only when pain/night pain, gait, ROM, strength, precautions and 24-hour response are acceptable.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','postop-batch-v1-thr-hip-arthroscopy','source_quality','curated_protocol_summary')),
('web_pages','clinical-pack-v1-distal-radius-orif-progression','Distal Radius ORIF Rehabilitation Progression','Distal Radius ORIF Protocol Pack v1. Progress edema control, finger/forearm/wrist ROM, scar mobility, grip, proprioception and weight-bearing while monitoring wound, neurovascular status, tendon irritation/rupture, hardware/union restrictions, CRPS features and work demands.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','postop-batch-v1-distal-radius-orif','source_quality','curated_protocol_summary')),
('web_pages','clinical-pack-v1-carpal-tunnel-release-progression','Carpal Tunnel Release Rehabilitation Progression','Carpal Tunnel Release Protocol Pack v1. Progress wound protection, tendon/nerve glides, scar desensitization, gentle grip/pinch, pillar pain management and ergonomic return-to-work while monitoring infection, recurrent/worsening neurologic symptoms, thenar weakness and symptom flare.', 'clinical_protocol_pack', jsonb_build_object('evidence_pack','postop-batch-v1-carpal-tunnel-release','source_quality','curated_protocol_summary'))
on conflict (source_type, source_id) do update set title=excluded.title, content=excluded.content, category=excluded.category, metadata=excluded.metadata, updated_at=now();
update public.vector_search
set content=case when content ilike '%Post-op Protocol Packs Batch v1:%' then content else concat_ws(E'\n',content,'Post-op Protocol Packs Batch v1: enriched with THR/hip arthroscopy, distal radius ORIF and carpal tunnel release restrictions, red flags, phase criteria and return-to-work/sport progression.') end,
 metadata=coalesce(metadata,'{}'::jsonb)||jsonb_build_object('evidence_pack','postop-protocol-packs-batch-v1','source_quality','postop_protocol_batch_pack'), updated_at=now()
where (source_type='assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('HOOS','LEFS','HIP_RSI','ROM_HIP','NPRS','VAS','PSFS','TUG','6MWT','DASH','QUICKDASH','PRWE','GRIP','ROM_WRIST','ROM_ELBOW')))
   or (source_type='special_tests' and source_id in ('ST_HIP_001','ST_HIP_002','ST_HIP_003','ST_HIP_004','ST_HIP_005','ST_HIP_006','ST_HIP_011','ST_HIP_012','ST_HIP_015','ST_HIP_016','ST_HIP_017','ST_HIP_019','ST_HIP_020','ST_WRST_001','ST_WRST_002','ST_WRST_003','ST_WRST_004','ST_WRST_005','ST_WRST_006','ST_WRST_007','ST_WRST_008','ST_WRST_009','ST_WRST_010'))
   or (source_type='exercises' and source_id in (select id::text from public.exercises where is_recommendation_candidate is true and (exercise_code like 'EX_HIP_%' or body_region='hip' or body_region_normalized='hip' or exercise_code like 'EX_WRST_%' or exercise_code like 'EX_HAND_%' or body_region='wrist_hand' or body_region='upper_extremity' or body_region_normalized='wrist_hand' or body_region_normalized='upper_extremity')))
   or (source_type='web_pages' and source_id in ('clinical-pack-v1-thr-hip-arthroscopy-precautions','clinical-pack-v1-thr-hip-arthroscopy-progression','clinical-pack-v1-distal-radius-orif-progression','clinical-pack-v1-carpal-tunnel-release-progression'));
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
