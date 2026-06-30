-- Ankle/Foot Evidence Pack v2
-- Purpose: strengthen RAG for lateral ankle sprain, chronic ankle instability, Achilles/plantar foot reasoning.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[] language sql immutable as $$
  select array(select distinct v from unnest(coalesce(base,'{}'::text[]) || coalesce(extras,'{}'::text[])) t(v) where v is not null and btrim(v) <> '' order by v)
$$;
update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, case when form_code = 'FAAM' then 8 when form_code = 'LEFS' then 9 else 5 end),
  mdc_value = coalesce(mdc_value, case when form_code = 'FAAM' then 11 when form_code = 'LEFS' then 9.3 else 5 end),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, case when form_code = 'LEFS' then 80 else 100 end),
  max_possible_score = coalesce(max_possible_score, case when form_code = 'LEFS' then 80 else 100 end),
  higher_is_better = true,
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Foot and ankle outcome measurement literature; FAAM/LEFS/AOFAS and functional balance test clinical use'),
  condition_overrides = coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition','ankle_foot_sprain_instability_achilles_plantar',
    'interpretation','Use with pain irritability, swelling/effusion, weight-bearing tolerance, dorsiflexion ROM, balance/proprioception, calf capacity, hop/agility quality and patient-specific sport/work goals. FAAM/LEFS/AOFAS higher is better.',
    'references',jsonb_build_array('FAAM clinical measurement literature','LEFS clinical measurement literature','Ottawa Ankle Rules','JOSPT 2021 Lateral Ankle Ligament Sprains CPG')
  )),
  updated_at = now()
where form_code in ('FAAM','LEFS','AOFAS','ROM_ANKLE','SLS_BAL');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Bachmann LM et al. Accuracy of Ottawa ankle rules to exclude fractures of the ankle and mid-foot: systematic review. BMJ. 2003.',
    'Martin RL, Davenport TE, Fraser JJ, et al. Ankle Stability and Movement Coordination Impairments: Lateral Ankle Ligament Sprains Revision 2021. J Orthop Sports Phys Ther. 2021.',
    'APTA/JOSPT lateral ankle ligament sprain clinical practice guideline principles.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '발목 염좌 lateral ankle sprain ATFL CFL Ottawa ankle rule 오타와 발목 규칙 골절 감별 체중부하 전방전위 거골경사 부종 멍 압통 만성 발목 불안정 CAI'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret lateral ankle tests with injury mechanism, Ottawa Ankle Rule/fracture screen, swelling/ecchymosis, focal malleolar/base-5th/navicular tenderness, weight-bearing ability, guarding, delayed re-test when acutely painful, and chronic instability history. Do not clear fracture or syndesmosis risk from a single ligament laxity test.'),
  updated_at = now()
where id in ('ST_ANKL_001','ST_ANKL_002');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Syndesmotic ankle sprain examination literature; use external rotation, squeeze and fibular translation tests as a cluster.',
    'Sports ankle syndesmosis rehabilitation and return-to-sport clinical principles.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '높은 발목 염좌 syndesmosis 경비인대결합 external rotation squeeze fibular translation mortise widening 장기 회복 회전 손상'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: suspect syndesmosis/high ankle sprain when pain is proximal/anterior, external-rotation mechanism, difficulty with push-off, positive squeeze/external-rotation/fibular translation cluster, or prolonged weight-bearing limitation; consider imaging/medical referral when unstable or fracture signs are present.'),
  updated_at = now()
where id in ('ST_ANKL_004','ST_ANKL_005','ST_ANKL_011');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Achilles tendon rupture clinical examination literature; Thompson/Simmonds calf squeeze test.',
    'Achilles tendinopathy loading and calf capacity rehabilitation clinical literature.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '아킬레스건 파열 Achilles rupture Thompson Simmonds calf squeeze 발꿈치 들기 불가 calf raise gap palpation 급성 종아리 통증'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: absent plantarflexion on Thompson/Simmonds, palpable gap, sudden pop, marked plantarflexion weakness or inability to perform heel raise should trigger urgent medical/surgical referral consideration. Partial tears may need combined history, palpation, strength and imaging.'),
  updated_at = now()
where id = 'ST_ANKL_003';
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Chronic ankle instability functional assessment literature including Star Excursion/Y-Balance, hop tests and weight-bearing lunge.',
    'Lateral ankle sprain CPG: balance, neuromuscular control, dorsiflexion and return-to-sport criteria.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '만성 발목 불안정 CAI 기능적 불안정 SEBT Y-balance hop test weight bearing lunge WBLT dorsiflexion return to sport 재발 위험'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: functional ankle tests should be interpreted with side-to-side symmetry, movement quality, apprehension/giving-way, swelling/24h response, dorsiflexion limitation, calf capacity and sport/work demand; pass/fail should not rely on distance/time alone.'),
  updated_at = now()
where id in ('ST_ANKL_014','ST_ANKL_015','ST_ANKL_016','ST_ANKL_017');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Plantar heel pain / plantar fasciopathy clinical examination literature; Windlass test and first-step pain pattern.',
    'Foot/ankle tendinopathy and posterior tibial tendon dysfunction clinical examination principles.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '족저근막염 plantar fasciitis heel pain windlass 첫발 통증 아치 후경골건 편평족 single heel rise 발목 내측 통증'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret plantar fascia/posterior tibial tendon tests with first-step pain, medial calcaneal tenderness, load history, arch/foot posture, single heel-rise capacity, neuro screen and red flags. Rule out fracture, inflammatory/systemic and neuropathic sources when presentation is atypical.'),
  updated_at = now()
where id in ('ST_ANKL_007','ST_ANKL_010','ST_ANKL_012','ST_ANKL_013');
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array['ankle sprain','lateral ankle sprain','발목 염좌','발목 삠','chronic ankle instability','CAI','high ankle sprain','syndesmosis','Achilles tendinopathy','plantar fasciitis','heel pain']::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'positive Ottawa Ankle Rule features, suspected fracture/dislocation, deformity, open wound or inability to bear weight four steps after trauma',
    'neurovascular compromise, progressive numbness/weakness, compartment-like severe pain or vascular symptoms',
    'suspected Achilles rupture with pop, palpable gap, absent Thompson response or inability to perform heel raise',
    'suspected unstable syndesmosis injury, proximal fibular pain, marked mortise instability or persistent inability to push off',
    'infection/systemic symptoms, inflammatory arthritis signs, unexplained severe night pain, cancer/systemic history',
    'post-operative complication, wound issue, DVT symptoms or sudden loss of repair protection'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Evidence Pack v2: classify ankle/foot presentations by trauma vs overuse, Ottawa fracture screen, syndesmosis suspicion, Achilles/plantar fascia/tendon involvement, swelling, weight-bearing tolerance, dorsiflexion ROM, balance/proprioception, calf capacity, giving-way history, irritability and sport/work demands. Use FAAM/LEFS/AOFAS/ROM/SLS with clinical exam rather than PROMs alone.'),
  updated_at = now()
where body_region = 'ankle_foot';
update public.exercises
set
  evidence_level = case when evidence_level is null or evidence_level = 'not_reviewed' then 'B' else evidence_level end,
  clinical_tier = greatest(coalesce(clinical_tier,0),2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'suspected fracture/dislocation, acute Achilles rupture, unstable syndesmosis injury, infection, neurovascular compromise, DVT symptoms or unresolved red flag',
    'post-operative restriction not cleared by surgeon/protocol',
    'exercise causes giving-way, sharp catching, neurological symptoms, marked swelling increase, or significant next-day flare',
    'plyometric/agility loading before pain, swelling, ROM, calf capacity and balance criteria are controlled'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'monitor swelling, pain irritability, weight-bearing tolerance, dorsiflexion ROM, calf raise capacity, balance quality and 24-hour response',
    'progress from protected ROM/isometrics to strength, proprioception, dynamic balance and hop/agility only when criteria are met',
    'for Achilles/plantar fascia symptoms, progress load slowly and avoid sudden high-volume plyometrics or hills/sprints',
    'for syndesmosis or post-op cases, match loading and external-rotation stress to medical clearance/protocol'
  ]::text[]),
  description_ko = coalesce(description_ko, '발목/발 통증, 염좌, 불안정성, 아킬레스/족저근막 문제에서 통증·부종·체중부하·배굴 ROM·균형·종아리 용량·24시간 반응을 확인하며 단계적으로 진행하는 핵심 운동 후보입니다.'),
  updated_at = now()
where body_region = 'ankle_foot'
  and exercise_code in (
    'EX_ANKL_MOB_009','EX_ANKL_MOB_011','EX_ANKL_STR_001','EX_ANKL_STR_004','EX_ANKL_STR_011','EX_ANKL_STR_012',
    'EX_ANKL_SGT_001','EX_ANKL_SGT_002','EX_ANKL_SGT_003','EX_ANKL_SGT_004','EX_ANKL_SGT_009','EX_ANKL_SGT_010','EX_ANKL_SGT_011','EX_ANKL_SGT_014',
    'EX_ANKL_BAL_001','EX_ANKL_BAL_003','EX_ANKL_BAL_005','EX_ANKL_BAL_006','EX_ANKL_BAL_007','EX_ANKL_BAL_008','EX_ANKL_BAL_011','EX_ANKL_BAL_015',
    'EX_ANKL_PRP_001','EX_ANKL_PRP_004','EX_ANKL_PRP_005','EX_ANKL_PRP_006','EX_ANKL_PRP_008','EX_ANKL_PRP_014',
    'EX_ANKL_STB_002','EX_ANKL_STB_004','EX_ANKL_STB_005','EX_ANKL_STB_006','EX_ANKL_STB_008','EX_ANKL_STB_010',
    'EX_ANKL_FNC_002','EX_ANKL_FNC_008','EX_ANKL_FNC_009','EX_ANKL_FNC_010','EX_ANKL_FNC_014','EX_ANKL_FNC_015',
    'EX_ANKL_PLY_003','EX_ANKL_PLY_004','EX_ANKL_PLY_005','EX_ANKL_PLY_013'
  );
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v2-ankle-outcome-measures','Ankle/Foot Outcome Measures: FAAM, LEFS, AOFAS, ROM, SLS','Clinical Evidence Pack v2. Ankle/foot outcomes. FAAM, LEFS and AOFAS are generally higher-is-better function scores; ankle ROM/WBLT and single-leg stance/balance tests add impairment and functional capacity context. Interpret meaningful change with baseline severity, swelling, weight-bearing tolerance, dorsiflexion, calf capacity, balance and patient-specific sport/work goals. Do not use PROMs alone.','clinical_evidence_pack',jsonb_build_object('evidence_pack','ankle-v2','source_quality','curated_summary','topics',jsonb_build_array('FAAM','LEFS','AOFAS','ankle ROM','single-leg stance'))),
('web_pages','clinical-pack-v2-ankle-ottawa-ligament-tests','Ankle Ottawa Rule and Lateral Ligament Test Cluster','Clinical Evidence Pack v2. Lateral ankle sprain reasoning: screen Ottawa Ankle Rule/fracture risk first, then interpret anterior drawer and talar tilt with mechanism, swelling, ecchymosis, focal tenderness, weight-bearing ability, guarding and timing from injury. A single laxity test is not enough to clear fracture, syndesmosis injury or return-to-sport readiness.','clinical_evidence_pack',jsonb_build_object('evidence_pack','ankle-v2','source_quality','curated_summary','topics',jsonb_build_array('Ottawa Ankle Rule','anterior drawer','talar tilt','lateral ankle sprain'))),
('web_pages','clinical-pack-v2-ankle-syndesmosis-achilles-red-flags','Ankle Syndesmosis, Achilles and Red Flags','Clinical Evidence Pack v2. Red flags/escalation: suspected fracture/dislocation, inability to bear weight, neurovascular compromise, severe progressive pain, suspected Achilles rupture (pop/gap/absent Thompson/heel-raise inability), unstable syndesmosis/high ankle sprain signs, infection/systemic symptoms and post-op complications. Syndesmosis tests are interpreted as a cluster with external-rotation mechanism, proximal/anterior pain and persistent push-off difficulty.','clinical_evidence_pack',jsonb_build_object('evidence_pack','ankle-v2','source_quality','curated_summary','topics',jsonb_build_array('syndesmosis','Achilles rupture','red flags','Thompson test'))),
('web_pages','clinical-pack-v2-ankle-exercise-progression-matrix','Ankle/Foot Exercise Progression Matrix','Clinical Evidence Pack v2. Ankle/foot progression matrix. High irritability/acute: protection, education, swelling control, pain-free ROM, isometrics, gentle weight-bearing and gait as tolerated. Moderate: calf/ankle strengthening, dorsiflexion mobility, proprioception, static-to-dynamic balance, step/stair tasks. Low irritability/return: single-leg strength/endurance, perturbation, Y-balance/SEBT quality, agility, hopping/plyometrics and sport/work-specific progression only when swelling, ROM, calf capacity, balance, giving-way and 24-hour response are controlled.','clinical_evidence_pack',jsonb_build_object('evidence_pack','ankle-v2','source_quality','curated_summary','topics',jsonb_build_array('exercise progression','balance','calf strengthening','proprioception','return to sport')))
on conflict (source_type, source_id) do update
set title=excluded.title, content=excluded.content, category=excluded.category, metadata=excluded.metadata, updated_at=now();
update public.vector_search
set content = case when content ilike '%Clinical Evidence Pack v2:%' then content else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: ankle/foot evidence enriched with outcome interpretation, Ottawa/fracture screen, test-cluster reasoning, red flags, and progression criteria.') end,
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('evidence_pack','ankle-v2','source_quality','ankle_evidence_pack'),
    updated_at = now()
where (source_type='assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('FAAM','LEFS','AOFAS','ROM_ANKLE','SLS_BAL')))
   or (source_type='special_tests' and source_id in ('ST_ANKL_001','ST_ANKL_002','ST_ANKL_003','ST_ANKL_004','ST_ANKL_005','ST_ANKL_007','ST_ANKL_010','ST_ANKL_011','ST_ANKL_012','ST_ANKL_013','ST_ANKL_014','ST_ANKL_015','ST_ANKL_016','ST_ANKL_017'))
   or (source_type='exercises' and source_id in (select id::text from public.exercises where body_region='ankle_foot' and is_recommendation_candidate is true))
   or (source_type='web_pages' and (title ilike '%ankle%' or title ilike '%foot%' or title ilike '%Achilles%' or title ilike '%plantar%'));
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
