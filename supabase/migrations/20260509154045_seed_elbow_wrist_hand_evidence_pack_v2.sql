-- Elbow/Wrist/Hand Evidence Pack v2
-- Purpose: strengthen RAG for lateral/medial elbow tendinopathy, UCL/cubital tunnel,
-- carpal tunnel, De Quervain, wrist/hand instability, thumb/finger injuries, neurovascular/fracture red flags,
-- and graded tendon/nerve/grip/upper-extremity loading progressions.

create or replace function public._clinical_pack_append_text_array(base text[], extras text[])
returns text[] language sql immutable as $$
  select array(select distinct v from unnest(coalesce(base,'{}'::text[]) || coalesce(extras,'{}'::text[])) t(v) where v is not null and btrim(v) <> '' order by v)
$$;
update public.assessment_form_templates
set
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, case when form_code = 'GRIP' then 100 when form_code = 'ARAT' then 57 when form_code = 'FMA_UE' then 66 else 100 end),
  max_possible_score = coalesce(max_possible_score, case when form_code = 'GRIP' then 100 when form_code = 'ARAT' then 57 when form_code = 'FMA_UE' then 66 else 100 end),
  higher_is_better = case when form_code in ('DASH','QUICKDASH','PRWE') then false when form_code in ('ROM_ELBOW','ROM_WRIST') then false else true end,
  mcid_value = coalesce(mcid_value, case when form_code = 'DASH' then 10.2 when form_code = 'QUICKDASH' then 16 when form_code = 'PRWE' then 11 when form_code = 'GRIP' then 6 when form_code in ('ROM_ELBOW','ROM_WRIST') then 5 else 8 end),
  mdc_value = coalesce(mdc_value, case when form_code = 'DASH' then 12.7 when form_code = 'QUICKDASH' then 19 when form_code = 'PRWE' then 11 when form_code = 'GRIP' then 8 when form_code in ('ROM_ELBOW','ROM_WRIST') then 5 else 8 end),
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Elbow/wrist/hand outcome measurement literature; DASH/QuickDASH/PRWE/grip/ROM clinical use'),
  condition_overrides = coalesce(condition_overrides,'[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition','elbow_wrist_hand_tendon_nerve_instability_fracture_screen',
    'interpretation','Use with symptom location, irritability, grip/load tolerance, sensory/motor screen, ROM, occupational/sport demand, tissue-healing stage, red flags, and 24-hour response. DASH/QuickDASH/PRWE are lower-is-better disability scores; grip is capacity; elbow/wrist ROM is impairment context.',
    'references',jsonb_build_array('DASH/QuickDASH upper-limb outcome measurement literature','PRWE wrist outcome measurement literature','Grip dynamometry clinical measurement literature')
  )),
  updated_at = now()
where form_code in ('DASH','QUICKDASH','PRWE','GRIP','ROM_ELBOW','ROM_WRIST','ASES','ARAT','FMA_UE');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Lateral elbow tendinopathy clinical assessment literature: pain with resisted wrist/finger extension and grip/load reproduction.',
    'Tendon loading principles: classify irritability and progress isometric, isotonic, eccentric/heavy-slow resistance, and task-specific grip/load exposure using 24-hour response.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '외측상과염 테니스엘보 lateral epicondylalgia Cozen Mill resisted wrist extension grip pain tendon loading common extensor tendon'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret lateral elbow tendinopathy using localized lateral epicondyle/common extensor pain, Cozen/Mill/resisted middle-finger or grip reproduction, irritability, grip capacity, work/sport load and 24-hour response. Screen cervical radicular referral, radial tunnel features, fracture/instability and neurological deficits when symptoms are atypical.'),
  updated_at = now()
where id in ('ST_ELBW_001','ST_ELBW_002');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Medial elbow pain and throwing elbow clinical assessment literature.',
    'UCL and flexor-pronator load assessment should be interpreted with throwing/valgus mechanism, ulnar nerve symptoms, ROM loss and sport demand.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '내측상과염 골프엘보 UCL valgus stress moving valgus flexor pronator throwing elbow 척골신경 cubital tunnel'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: combine medial epicondyle/flexor-pronator tenderness, resisted wrist flexion/pronation, valgus stress or moving valgus response, throwing history, ulnar nerve symptoms, ROM loss and return-to-throw demand. Escalate acute pop, gross valgus instability, progressive neurological deficit or suspected fracture/dislocation.'),
  updated_at = now()
where id in ('ST_ELBW_003','ST_ELBW_004','ST_ELBW_005');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Cubital tunnel syndrome and ulnar neuropathy clinical examination literature.',
    'Peripheral nerve entrapment assessment should include sensory distribution, motor weakness, intrinsic atrophy, provocative tests and cervical/double-crush differential.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '주관증후군 cubital tunnel ulnar neuropathy 척골신경 티넬 elbow flexion compression paresthesia intrinsic atrophy double crush'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret cubital tunnel signs with ulnar-distribution paresthesia, night symptoms, elbow-flexion provocation, grip/intrinsic weakness, Froment/intrinsic atrophy screen, cervical/double-crush differential and occupational compression/posture exposure. Progressive weakness or atrophy warrants referral consideration.'),
  updated_at = now()
where id in ('ST_ELBW_006','ST_ELBW_007');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Elbow instability and distal biceps rupture clinical examination literature.',
    'Acute deformity, dislocation/fracture, distal biceps rupture signs, neurovascular compromise or marked strength loss require medical escalation.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '팔꿈치 불안정 PLRI LUCL distal biceps hook test 이두건 파열 fracture dislocation neurovascular red flag'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: posterolateral rotatory instability and distal biceps signs should be interpreted with traumatic mechanism, apprehension/subluxation, supination/flexion strength loss, deformity, bruising and neurovascular screen. Positive hook test or instability after trauma warrants imaging/orthopedic referral consideration.'),
  updated_at = now()
where id in ('ST_ELBW_008','ST_ELBW_009','ST_ELBW_010');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Carpal tunnel syndrome clinical practice and diagnostic accuracy literature.',
    'Median neuropathy assessment should combine symptoms, sensory/motor deficits, Phalen/Tinel/Durkan response, nocturnal pattern, thenar changes and work/medical risk factors.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '수근관증후군 carpal tunnel CTS median nerve Phalen Tinel Durkan numbness tingling thenar atrophy night symptoms'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: interpret CTS tests as a cluster: median-nerve distribution numbness/tingling, nocturnal symptoms, Phalen/Tinel/Durkan reproduction, sensory changes, grip/pinch or thenar weakness, work exposure and systemic risk factors. Thenar atrophy, progressive weakness or acute onset should prompt referral consideration.'),
  updated_at = now()
where id in ('ST_WRST_001','ST_WRST_002','ST_WRST_010');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'De Quervain tenosynovitis and thumb/wrist tendinopathy clinical assessment literature.',
    'Thumb CMC OA and first dorsal compartment pain should be interpreted with location, swelling, load, pinch/grip and differential diagnosis.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '드퀘르벵 De Quervain Finkelstein thumb CMC OA grind test 엄지 통증 radial wrist first dorsal compartment pinch grip'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: combine radial wrist/first dorsal compartment pain, Finkelstein-type provocation, thumb motion/pinch load, swelling and activity exposure. For thumb CMC OA, interpret grind/pinch pain with joint-line tenderness, grip/pinch capacity and functional goals; rule out fracture/instability when traumatic.'),
  updated_at = now()
where id in ('ST_WRST_003','ST_WRST_004');
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Wrist ligament instability, scaphoid fracture and hand neurovascular screening literature.',
    'Traumatic wrist/hand pain requires fracture, scapholunate/TFCC/thumb UCL injury, tendon avulsion, vascular and neurological screen before progressive loading.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '손목 불안정 scapholunate Watson TFCC scaphoid fracture thumb UCL skier thumb Froment Allen neurovascular red flag tendon avulsion'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: after trauma, combine Watson/LT/thumb UCL/vascular/ulnar nerve findings with snuffbox tenderness, swelling, deformity, grip loss, neurovascular screen and mechanism. Suspected scaphoid fracture, Stener lesion, tendon avulsion, vascular compromise, progressive neurological deficit or unstable fracture/dislocation warrants referral/imaging consideration.'),
  updated_at = now()
where id in ('ST_WRST_005','ST_WRST_006','ST_WRST_007','ST_WRST_008','ST_WRST_009');
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array['elbow pain','wrist pain','hand pain','tennis elbow','lateral epicondylalgia','golfer elbow','medial epicondylalgia','cubital tunnel syndrome','carpal tunnel syndrome','De Quervain','thumb CMC OA','wrist instability','TFCC injury','scaphoid fracture screen','trigger finger','mallet finger','팔꿈치 통증','손목 통증','손 통증','외측상과염','내측상과염','수근관증후군','드퀘르벵','방아쇠수지']::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'acute trauma with deformity, suspected fracture/dislocation, open wound, inability to move fingers, or severe bony tenderness',
    'snuffbox tenderness or suspected scaphoid fracture, unstable carpal injury, thumb UCL complete tear/Stener lesion, tendon avulsion or mallet fracture fragment',
    'neurovascular compromise: cool/pale hand, absent/delayed capillary refill, abnormal Allen test, expanding swelling, severe pain with passive stretch, or compartment syndrome concern',
    'progressive sensory loss, progressive motor weakness, thenar/intrinsic atrophy, wrist drop, or rapidly worsening nerve symptoms',
    'infection signs, fever, marked redness/warmth, septic bursitis/tenosynovitis concern, bite wound, or immunocompromised/systemic symptoms',
    'post-operative complication, wound issue, hardware failure suspicion, CRPS features or sudden loss of function after surgery'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Evidence Pack v2: classify elbow/wrist/hand presentations by tendon overload (lateral/medial epicondylalgia, De Quervain, trigger finger), peripheral nerve entrapment (cubital/carpal/Guyon/radial nerve), ligament/instability or fracture screen, OA/CMC, bursitis/infection, post-operative state and work/sport load demand. Combine symptom location, irritability, grip/pinch capacity, ROM, sensory/motor screen, neurovascular status and 24-hour response.'),
  updated_at = now()
where body_region in ('elbow','wrist_hand','wrist','hand');
update public.exercises
set
  evidence_level = case when evidence_level is null or evidence_level = 'not_reviewed' then 'B' else evidence_level end,
  clinical_tier = greatest(coalesce(clinical_tier,0),2),
  is_recommendation_candidate = true,
  contraindications = public._clinical_pack_append_text_array(contraindications, array[
    'suspected fracture/dislocation, scaphoid fracture, unstable wrist/hand ligament injury, tendon avulsion/rupture, neurovascular compromise, compartment syndrome, infection/septic bursitis/tenosynovitis, or unresolved severe red flag',
    'progressive sensory loss, progressive motor weakness, thenar/intrinsic atrophy, wrist drop, severe night/rest pain or rapidly worsening neurological symptoms',
    'post-operative restriction not cleared by surgeon/protocol, wound issue, hardware failure suspicion, CRPS flare, or sudden loss of function after surgery',
    'exercise causes sharp joint pain, increasing paresthesia, marked grip loss, swelling escalation, color/temperature change, or next-day flare beyond tolerance'
  ]::text[]),
  cautions = public._clinical_pack_append_text_array(cautions, array[
    'monitor pain irritability, grip/pinch capacity, ROM, sensory/motor screen, swelling, work/sport load, ergonomic exposure and 24-hour response',
    'progress from education/load modification, pain-controlled ROM and isometrics to isotonic/eccentric/heavy-slow tendon loading, grip/pinch capacity, nerve/tendon glides and task-specific exposure',
    'for nerve entrapment, avoid sustained provocative compression/tension early; use symptom-guided nerve gliding and ergonomic/postural changes',
    'for wrist/hand trauma or instability, confirm fracture/ligament/tendon red flags are cleared before closed-chain or high-load gripping progression'
  ]::text[]),
  description_ko = coalesce(description_ko, '팔꿈치/손목/손 통증, 힘줄 과부하, 수근관/주관증후군, 드퀘르벵, 손목 불안정, 그립/핀치 기능 회복에서 통증 과민성·감각/운동·부종·ROM·그립·24시간 반응을 확인하며 단계적으로 진행하는 핵심 운동 후보입니다.'),
  updated_at = now()
where exercise_code in (
  'edb_Wrist_Circles','edb_Wrist_Roller','edb_Wrist_Rotations_with_Straight_Bar','edb_Finger_Curls','edb_Cable_Wrist_Curl','edb_Palms-Down_Dumbbell_Wrist_Curl_Over_A_Bench','edb_Palms-Down_Wrist_Curl_Over_A_Bench','edb_Palms-Up_Barbell_Wrist_Curl_Over_A_Bench','edb_Palms-Up_Dumbbell_Wrist_Curl_Over_A_Bench','edb_Seated_Dumbbell_Palms-Down_Wrist_Curl','edb_Seated_Dumbbell_Palms-Up_Wrist_Curl','edb_Seated_One-Arm_Dumbbell_Palms-Down_Wrist_Curl','edb_Seated_One-Arm_Dumbbell_Palms-Up_Wrist_Curl','edb_Seated_Palm-Up_Barbell_Wrist_Curl','edb_Seated_Palms-Down_Barbell_Wrist_Curl','edb_Standing_Palms-Up_Barbell_Behind_The_Back_Wrist_Curl','edb_Reverse_Barbell_Curl','edb_Hammer_Curls','edb_Zottman_Curl','edb_Triceps_Stretch','edb_Overhead_Triceps',
  'EX_ELBW_MOB_001','EX_ELBW_MOB_002','EX_ELBW_MOB_003','EX_ELBW_MOB_005','EX_ELBW_MOB_009','EX_ELBW_MOB_011','EX_ELBW_NMR_011','EX_ELBW_SGT_001','EX_ELBW_SGT_002','EX_ELBW_SGT_004','EX_ELBW_SGT_010','EX_ELBW_SGT_011','EX_ELBW_SGT_014','EX_ELBW_STB_001','EX_ELBW_STB_005','EX_ELBW_STB_006','EX_ELBW_STR_001','EX_ELBW_STR_004','EX_ELBW_STR_010','EX_ELBW_FNC_004','EX_ELBW_FNC_005','EX_ELBW_FNC_012',
  'EX_WRST_MOB_001','EX_WRST_MOB_002','EX_WRST_MOB_003','EX_WRST_MOB_005','EX_WRST_MOB_009','EX_WRST_MOB_011','EX_WRST_NMR_011','EX_WRST_PRP_001','EX_WRST_PRP_003','EX_WRST_PRP_007','EX_WRST_SGT_001','EX_WRST_SGT_002','EX_WRST_SGT_004','EX_WRST_SGT_010','EX_WRST_SGT_011','EX_WRST_SGT_013','EX_WRST_SGT_014','EX_WRST_SGT_015','EX_WRST_STB_001','EX_WRST_STB_005','EX_WRST_STB_006','EX_WRST_STB_014','EX_WRST_STR_001','EX_WRST_STR_004','EX_WRST_STR_010','EX_WRST_STR_011','EX_WRST_FNC_004','EX_WRST_FNC_011','EX_WRST_FNC_012','EX_WRST_FNC_013','EX_WRST_CRD_004'
);
insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
('web_pages','clinical-pack-v2-upperext-outcome-measures','Elbow/Wrist/Hand Outcome Measures: DASH, QuickDASH, PRWE, Grip, ROM','Clinical Evidence Pack v2. Upper-extremity outcomes. DASH/QuickDASH/PRWE are lower-is-better disability scores; grip is capacity and should be compared with side-to-side, dominance, pain and task demand; elbow/wrist ROM is impairment context. Interpret with symptom location, irritability, sensory/motor screen, work/sport load, red flags and 24-hour response. PRTEE was not present in the live form table at time of seeding.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','upperext-v2','source_quality','curated_summary','topics',jsonb_build_array('DASH','QuickDASH','PRWE','grip strength','elbow ROM','wrist ROM'))),
('web_pages','clinical-pack-v2-upperext-tendinopathy-loading','Elbow/Wrist/Hand Tendinopathy Loading Progression','Clinical Evidence Pack v2. Tendon-load reasoning for lateral/medial epicondylalgia, De Quervain and trigger-finger style presentations: classify irritability, modify aggravating grip/pinch/wrist extension/pronation-supination load, start with pain-controlled isometrics/ROM, progress to isotonic/eccentric/heavy-slow resistance, grip/pinch capacity and task-specific exposure using pain and 24-hour response.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','upperext-v2','source_quality','curated_summary','topics',jsonb_build_array('lateral epicondylalgia','medial epicondylalgia','De Quervain','tendon loading','grip'))),
('web_pages','clinical-pack-v2-upperext-nerve-clusters','Carpal/Cubital Tunnel and Upper-Extremity Nerve Clusters','Clinical Evidence Pack v2. Peripheral nerve reasoning: combine symptom distribution, nocturnal symptoms, Phalen/Tinel/Durkan or cubital tunnel flexion-compression response, sensory changes, grip/pinch/intrinsic or thenar weakness, occupational compression/tension exposure, cervical/double-crush differential and progressive deficit screen. Thenar/intrinsic atrophy, progressive weakness or acute onset warrants referral consideration.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','upperext-v2','source_quality','curated_summary','topics',jsonb_build_array('carpal tunnel','cubital tunnel','ulnar neuropathy','median nerve','nerve glides'))),
('web_pages','clinical-pack-v2-upperext-red-flags-instability','Elbow/Wrist/Hand Red Flags, Instability and Fracture Screen','Clinical Evidence Pack v2. Upper-extremity red flags: acute trauma with deformity, suspected fracture/dislocation, snuffbox tenderness/scaphoid fracture suspicion, thumb UCL/Stener lesion, tendon avulsion/rupture, neurovascular compromise, infection/septic bursitis/tenosynovitis, compartment syndrome, progressive neurological deficit, CRPS/post-op complication or sudden loss of function. Clear these before progressive closed-chain or high-load gripping.', 'clinical_evidence_pack', jsonb_build_object('evidence_pack','upperext-v2','source_quality','curated_summary','topics',jsonb_build_array('fracture screen','scaphoid','thumb UCL','neurovascular','red flags')))
on conflict (source_type, source_id) do update
set title=excluded.title, content=excluded.content, category=excluded.category, metadata=excluded.metadata, updated_at=now();
update public.vector_search
set content = case when content ilike '%Clinical Evidence Pack v2:%' then content else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: elbow/wrist/hand evidence enriched with outcome interpretation, tendon-loading progression, nerve-entrapment clusters, instability/fracture/neurovascular red flags, and grip/pinch/task-specific progression criteria.') end,
    metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object('evidence_pack','upperext-v2','source_quality','upperext_evidence_pack'),
    updated_at = now()
where (source_type='assessment_form_templates' and source_id in (select id::text from public.assessment_form_templates where form_code in ('DASH','QUICKDASH','PRWE','GRIP','ROM_ELBOW','ROM_WRIST','ASES','ARAT','FMA_UE')))
   or (source_type='special_tests' and (source_id like 'ST_ELBW_%' or source_id like 'ST_WRST_%'))
   or (source_type='exercises' and source_id in (select id::text from public.exercises where is_recommendation_candidate is true and (body_region in ('elbow','wrist_hand','wrist','hand') or exercise_code like 'EX_ELBW_%' or exercise_code like 'EX_WRST_%')))
   or (source_type='web_pages' and metadata->>'evidence_pack' = 'upperext-v2');
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
