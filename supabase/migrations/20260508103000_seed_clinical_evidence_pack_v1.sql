-- Clinical Evidence Pack v1
-- Purpose:
-- - Fill high-impact evidence gaps used by Knowledge AI clinical recommendation RAG.
-- - Prioritize low back/radiculopathy, knee, shoulder, hip, and ankle screening.
-- - Mark a small reviewed exercise set as recommendation candidates with safety notes.
--
-- Notes:
-- - This is not a complete literature database.
-- - References are intentionally guideline/systematic-review level and conservative.
-- - Detailed numeric claims should stay in curated source rows, not be hallucinated by LLMs.

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
-- ---------------------------------------------------------------------------
-- 1) Special tests: reference_list + Korean search keywords
-- ---------------------------------------------------------------------------

update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Vroomen PCAJ, de Krom MCTFM, Knottnerus JA. Diagnostic value of history and physical examination in patients suspected of lumbosacral nerve root compression. J Neurol Neurosurg Psychiatry. 2002.',
    'Majlesi J, Togay H, Unalan H, Toprak S. The sensitivity and specificity of the Slump and Straight Leg Raising tests in patients with lumbar disc herniation. J Clin Rheumatol. 2008.',
    'Academy of Orthopaedic Physical Therapy/JOSPT. Interventions for the Management of Acute and Chronic Low Back Pain: Revision 2021. J Orthop Sports Phys Ther. 2021. doi:10.2519/jospt.2021.0304',
    'NICE NG59. Low back pain and sciatica in over 16s: assessment and management. 2016, updated 2020.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '요통 방사통 좌골신경통 신경근증 디스크 추간판 탈출증 신경 긴장 신경역학 하지직거상 슬럼프 감별진단'),
  updated_at = now()
where id in ('ST_LUMB_001', 'ST_LUMB_002', 'ST_LUMB_003', 'ST_LUMB_015', 'ST_LUMB_019', 'ST_LUMB_020');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Benjaminse A, Gokeler A, van der Schans CP. Clinical diagnosis of an anterior cruciate ligament rupture: a meta-analysis. J Orthop Sports Phys Ther. 2006. doi:10.2519/jospt.2006.2011',
    'Logerstedt DS, Scalzitti DA, Risberg MA, et al. Knee Stability and Movement Coordination Impairments: Knee Ligament Sprain Revision 2017. J Orthop Sports Phys Ther. 2017.',
    'Huang W, Zhang Y, Yao Z, Ma L. Clinical examination tests for anterior cruciate ligament tears: systematic review and meta-analysis. Commonly cited diagnostic-accuracy evidence.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '무릎 전방십자인대 ACL 불안정성 라크만 전방전위 피벗시프트 급성 외상 스포츠 손상 혈관절증 giving way'),
  updated_at = now()
where id in ('ST_KNEE_001', 'ST_KNEE_002', 'ST_KNEE_008');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Hegedus EJ, Cook C, Hasselblad V, Goode A, McCrory DC. Physical examination tests for assessing a torn meniscus in the knee: a systematic review with meta-analysis. J Orthop Sports Phys Ther. 2007.',
    'Smith BE, Thacker D, Crewesmith A, Hall M. Special tests for assessing meniscal tears within the knee: a systematic review and meta-analysis. Evid Based Med. 2015.',
    'NICE and primary-care MSK pathways: combine meniscal tests with history, effusion, locking/catching, and functional limitation; do not rely on one isolated test.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '무릎 반월상연골 meniscus 맥머레이 테살리 관절선 압통 잠김 catching locking 회전 통증 스포츠 손상'),
  updated_at = now()
where id in ('ST_KNEE_003', 'ST_KNEE_007');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Hegedus EJ, Goode A, Campbell S, et al. Physical examination tests of the shoulder: a systematic review with meta-analysis of individual tests. Br J Sports Med. 2008.',
    'Hegedus EJ, Goode AP, Cook CE, et al. Which physical examination tests provide clinicians with the most value when examining the shoulder? Update of a systematic review with meta-analysis. Br J Sports Med. 2012.',
    'Rotator cuff-related shoulder pain CPG and shoulder assessment reviews: interpret impingement/rotator cuff tests as clusters, not single definitive tests.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '어깨 회전근개 충돌증후군 견봉하 통증 니어 호킨스 케네디 엠프티캔 조브 외전 통증 근력저하'),
  updated_at = now()
where id in ('ST_SHLDR_001', 'ST_SHLDR_002', 'ST_SHLDR_003');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Reiman MP, Goode AP, Hegedus EJ, Cook CE, Wright AA. Diagnostic accuracy of clinical tests for the diagnosis of hip femoroacetabular impingement/labral pathology: systematic review evidence.',
    'Cibulka MT, White DM, Woehrle J, et al. Hip Pain and Mobility Deficits—Hip Osteoarthritis: Clinical Practice Guidelines. J Orthop Sports Phys Ther. 2009; updates and current hip CPGs should be considered.',
    'Use FABER/FADIR with symptom location, ROM, gait, and differential diagnosis; positive findings are not pathology-specific alone.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '고관절 FAI 충돌증후군 관절순 FABER FADIR 패트릭 사타구니 통증 둔부통증 가동범위 감별진단'),
  updated_at = now()
where id in ('ST_HIP_001', 'ST_HIP_002', 'ST_HIP_010');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Martin RL, Davenport TE, Fraser JJ, et al. Ankle Stability and Movement Coordination Impairments: Lateral Ankle Ligament Sprains Revision 2021. J Orthop Sports Phys Ther. 2021. doi:10.2519/jospt.2021.0302',
    'Bachmann LM, Kolb E, Koller MT, Steurer J, ter Riet G. Accuracy of Ottawa ankle rules to exclude fractures of the ankle and mid-foot: systematic review. BMJ. 2003.',
    'Ottawa Ankle Rules: use for fracture referral screening after acute ankle trauma; ligament tests should be interpreted with timing, swelling, pain, and ability to bear weight.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '발목 염좌 외측인대 ATFL CFL 전방전위 거골경사 오타와 발목 규칙 골절 감별 체중부하 불안정성'),
  updated_at = now()
where id in ('ST_ANKL_001', 'ST_ANKL_002');
-- ---------------------------------------------------------------------------
-- 2) Exercises: mark reviewed core recommendations and safety notes
-- ---------------------------------------------------------------------------

update public.exercises
set
  evidence_level = 'B',
  clinical_tier = greatest(coalesce(clinical_tier, 0), 2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'progressive neurological deficit',
    'new bowel/bladder dysfunction or saddle anesthesia',
    'unexplained fever, malignancy suspicion, or severe night pain',
    'acute fracture or major trauma not medically cleared'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'keep symptoms centralizing or stable; stop/regress if distal leg pain, numbness, or weakness increases',
    'start with low load and neutral-spine control; avoid breath-holding and aggressive end-range loading',
    'dose by irritability: low irritability can progress volume; high irritability requires shorter holds and more rest'
  ]::text[]),
  description_ko = coalesce(description_ko, '요통/방사통 환자에게 적용 가능한 저부하 안정화 또는 단계적 노출 운동. 증상 반응을 확인하며 진행한다.'),
  exercise_name_ko = coalesce(exercise_name_ko, case exercise_code
    when 'pk_bird_dog' then '버드독'
    when 'pk_side_plank' then '사이드 플랭크'
    when 'pk_hip_bridge' then '힙 브릿지'
    else exercise_name_ko
  end),
  updated_at = now()
where exercise_code in ('pk_bird_dog', 'pk_side_plank', 'pk_hip_bridge', 'edb_Side_Bridge', 'edb_Pelvic_Tilt_Into_Bridge');
update public.exercises
set
  evidence_level = 'B',
  clinical_tier = greatest(coalesce(clinical_tier, 0), 2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'acute fracture, suspected cauda equina, or progressive neurological deficit',
    'worsening distal neurological symptoms during repeated movement or neural loading'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'use slider before tensioner for irritable radicular symptoms',
    'avoid aggressive stretching into reproduction of distal symptoms',
    'monitor 24-hour symptom response before progressing repetitions or range'
  ]::text[]),
  description_ko = coalesce(description_ko, '신경 증상 과민도를 고려해 slider 중심으로 시작하고, 원위부 증상 증가 시 즉시 강도를 낮춘다.'),
  updated_at = now()
where exercise_code in ('pk_nerve_glide_median');
update public.exercises
set
  evidence_level = 'B',
  clinical_tier = greatest(coalesce(clinical_tier, 0), 2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'acute ACL/PCL rupture or unstable knee not medically cleared',
    'suspected fracture, infection, or severe effusion with inability to bear weight'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'maintain knee alignment; avoid dynamic valgus and sharp joint-line pain',
    'progress closed-chain load gradually and monitor swelling next day',
    'regress plyometric/agility tasks until pain, effusion, and control are acceptable'
  ]::text[]),
  description_ko = coalesce(description_ko, '무릎 재활에서 근력·고유수용성·기능 조절을 단계적으로 회복하기 위한 운동. 부종/통증 반응을 기준으로 진행한다.'),
  updated_at = now()
where exercise_code in ('pk_straight_leg_raise', 'EX_KNEE_PRP_004', 'EX_KNEE_PRP_005', 'EX_KNEE_PRP_006', 'EX_KNEE_PRP_007');
update public.exercises
set
  evidence_level = 'B',
  clinical_tier = greatest(coalesce(clinical_tier, 0), 2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'acute dislocation, suspected full-thickness tear with marked weakness, or fracture not cleared',
    'red flag systemic symptoms or severe night pain requiring medical review'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'keep symptoms below acceptable threshold; avoid repeated painful arc loading early',
    'prioritize scapular control and low-load rotator cuff activation before heavy resistance',
    'progress external rotation volume gradually and monitor next-day irritability'
  ]::text[]),
  description_ko = coalesce(description_ko, '어깨 회전근개/견갑 조절 회복을 위한 저부하 강화 운동. 통증 호와 야간통, 근력저하를 함께 확인한다.'),
  exercise_name_ko = coalesce(exercise_name_ko, case exercise_code
    when 'pk_shoulder_external_rotation' then '견관절 외회전'
    else exercise_name_ko
  end),
  updated_at = now()
where exercise_code in ('pk_shoulder_external_rotation', 'edb_External_Rotation', 'edb_External_Rotation_with_Band');
update public.exercises
set
  evidence_level = 'B',
  clinical_tier = greatest(coalesce(clinical_tier, 0), 2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'positive Ottawa Ankle Rule or suspected fracture before imaging/medical clearance',
    'syndesmosis injury, neurovascular compromise, or tendon rupture suspicion'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'progress balance from stable to unstable and eyes open to eyes closed only when pain/swelling are controlled',
    'avoid high-load calf raise progression if swelling or sharp lateral ankle pain increases',
    'monitor ability to bear weight and next-day swelling after proprioception work'
  ]::text[]),
  description_ko = coalesce(description_ko, '발목 염좌/불안정성에서 종아리 근력과 고유수용성 회복을 위한 단계적 운동. 골절/고위험 손상 선별 후 적용한다.'),
  exercise_name_ko = coalesce(exercise_name_ko, case exercise_code
    when 'pk_calf_raise' then '종아리 들기'
    else exercise_name_ko
  end),
  updated_at = now()
where exercise_code in ('pk_calf_raise', 'EX_ANKL_PRP_004', 'EX_ANKL_PRP_005', 'EX_ANKL_PRP_006', 'EX_ANKL_PRP_007');
-- ---------------------------------------------------------------------------
-- 3) Condition library: fill conservative red flag gaps for common regions
-- ---------------------------------------------------------------------------

update public.condition_library
set
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'progressive neurological deficit',
    'new bowel/bladder dysfunction or saddle anesthesia',
    'unexplained fever, weight loss, cancer history, or severe night pain',
    'major trauma or suspected fracture',
    'vascular compromise or infection suspicion'
  ]::text[]),
  updated_at = now()
where body_region in ('lumbar_spine', 'cervical_spine', 'thoracic_spine', 'multi_region')
  and (red_flags is null or cardinality(red_flags) = 0);
update public.condition_library
set
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'acute fracture or inability to bear weight after trauma',
    'neurovascular compromise',
    'infection signs or rapidly worsening swelling',
    'suspected tendon rupture or compartment syndrome'
  ]::text[]),
  updated_at = now()
where body_region in ('knee', 'ankle_foot', 'hip', 'shoulder')
  and (red_flags is null or cardinality(red_flags) = 0);
-- ---------------------------------------------------------------------------
-- 4) Assessment forms: set evidence level for common outcome measures
-- ---------------------------------------------------------------------------

update public.assessment_form_templates
set evidence_level = coalesce(evidence_level, 'B')
where form_code in (
  'ODI', 'NDI', 'KOOS', 'LEFS', 'DASH', 'QUICKDASH', 'SPADI', 'ASES',
  'CONSTANT_MURLEY', 'PENN_SHOULDER', 'BARTHEL', 'TUG', 'BERG_BALANCE',
  'FGA', 'DGI', 'NPRS', 'VAS', 'PSFS'
);
-- ---------------------------------------------------------------------------
-- 5) Keep vector_search text/metadata searchable immediately after migration.
--    Embeddings can be regenerated later; BM25/keyword fallback gets updated now.
-- ---------------------------------------------------------------------------

update public.vector_search
set
  content = concat_ws(E'\n', content, 'Evidence Pack v1: 임상 라이브러리 검색 근거 보강. 요통/방사통, ACL/meniscus, shoulder impingement/rotator cuff, hip FAI/labral, ankle sprain/Ottawa rule 관련 reference_list와 한국어 키워드가 보강됨. 답변 시 단일 검사를 확정 진단으로 쓰지 말고 병력/증상/기능/검사 클러스터와 함께 해석한다.'),
  metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('evidence_pack', 'clinical-evidence-pack-v1', 'review_status', 'reference_list_seeded'),
  updated_at = now()
where source_type = 'special_tests'
  and source_id in (
    'ST_LUMB_001','ST_LUMB_002','ST_LUMB_003','ST_LUMB_015','ST_LUMB_019','ST_LUMB_020',
    'ST_KNEE_001','ST_KNEE_002','ST_KNEE_003','ST_KNEE_007','ST_KNEE_008',
    'ST_SHLDR_001','ST_SHLDR_002','ST_SHLDR_003',
    'ST_HIP_001','ST_HIP_002','ST_HIP_010',
    'ST_ANKL_001','ST_ANKL_002'
  );
update public.vector_search
set
  content = concat_ws(E'\n', content, 'Evidence Pack v1: 추천 운동 후보로 검토됨. evidence_level B, clinical_tier >= 2, contraindications/cautions 보강. 진행성 신경학적 결손, cauda equina 의심, 골절/감염/혈관 손상 의심, 급성 불안정성 등은 적용 전 의학적 확인 필요.'),
  metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('evidence_pack', 'clinical-evidence-pack-v1', 'review_status', 'exercise_safety_seeded'),
  updated_at = now()
where source_type = 'exercises'
  and source_id in (
    select id::text
    from public.exercises
    where exercise_code in (
      'pk_bird_dog','pk_side_plank','pk_hip_bridge','edb_Side_Bridge','edb_Pelvic_Tilt_Into_Bridge',
      'pk_nerve_glide_median',
      'pk_straight_leg_raise','EX_KNEE_PRP_004','EX_KNEE_PRP_005','EX_KNEE_PRP_006','EX_KNEE_PRP_007',
      'pk_shoulder_external_rotation','edb_External_Rotation','edb_External_Rotation_with_Band',
      'pk_calf_raise','EX_ANKL_PRP_004','EX_ANKL_PRP_005','EX_ANKL_PRP_006','EX_ANKL_PRP_007'
    )
  );
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
