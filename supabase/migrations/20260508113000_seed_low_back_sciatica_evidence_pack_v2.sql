-- Low Back / Sciatica Evidence Pack v2
-- Purpose:
-- - Strengthen Knowledge AI RAG for low back pain and radiating leg pain.
-- - Add outcome measure interpretation, centralization/directional preference,
--   neurological screen, and lumbar exercise progression matrix.
-- - Include web_pages/guideline chunks in ClinicalRagSearchService via code change.

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
-- 1) Outcome measures: ODI / NPRS / PSFS / VAS low-back interpretation
-- ---------------------------------------------------------------------------

update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, 6),
  mdc_value = coalesce(mdc_value, 12.8),
  mdc_95 = coalesce(mdc_95, 12.8),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, 100),
  max_possible_score = coalesce(max_possible_score, 100),
  higher_is_better = false,
  severity_thresholds = coalesce(severity_thresholds, '{}'::jsonb) || jsonb_build_object(
    'low_back_v2', jsonb_build_object(
      'minimal', '0-20%',
      'moderate', '21-40%',
      'severe', '41-60%',
      'crippled', '61-80%',
      'bed_bound_or_exaggerating', '81-100%',
      'interpretation_note', 'Use with patient-specific goals and clinical irritability; do not interpret ODI alone.'
    )
  ),
  condition_overrides = coalesce(condition_overrides, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition', 'low_back_pain_or_sciatica',
    'mcid', '6-10 ODI points often used as clinically meaningful change; confirm with baseline severity and patient goals',
    'mdc95', 12.8,
    'references', jsonb_build_array('Fritz & Irrgang 2001', 'Ostelo et al. 2008')
  )),
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Fritz & Irrgang 2001; Ostelo et al. 2008'),
  evidence_year = coalesce(evidence_year, 2008),
  action_on_mcid_achieved = coalesce(action_on_mcid_achieved, 'Reassess functional goals, progress loading/exposure, and update home program if symptoms remain stable.'),
  action_on_worsened = coalesce(action_on_worsened, 'Screen red flags and neurological change; reduce irritability-provoking load and reassess plan.'),
  action_on_no_change = coalesce(action_on_no_change, 'Check adherence, directional preference, psychosocial barriers, and whether exercise dose matches irritability.'),
  updated_at = now()
where form_code = 'ODI';
update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, 2),
  mdc_value = coalesce(mdc_value, 2.1),
  mdc_95 = coalesce(mdc_95, 2.1),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, 10),
  max_possible_score = coalesce(max_possible_score, 10),
  higher_is_better = false,
  severity_thresholds = coalesce(severity_thresholds, '{}'::jsonb) || jsonb_build_object(
    'pain_intensity_v2', jsonb_build_object(
      'mild', '1-3/10',
      'moderate', '4-6/10',
      'severe', '7-10/10',
      'interpretation_note', 'Track baseline, within-session response, 24-hour response, and distribution/centralization rather than pain intensity alone.'
    )
  ),
  condition_overrides = coalesce(condition_overrides, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition', 'low_back_pain_or_sciatica',
    'mcid', 'about 2 points or 30% change is commonly used for pain improvement',
    'mdc95', 2.1,
    'references', jsonb_build_array('Childs et al. 2005', 'Farrar et al. 2001')
  )),
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Childs et al. 2005; Farrar et al. 2001'),
  evidence_year = coalesce(evidence_year, 2005),
  action_on_mcid_achieved = coalesce(action_on_mcid_achieved, 'Progress activity exposure and function-specific loading while monitoring symptom distribution.'),
  action_on_worsened = coalesce(action_on_worsened, 'Check red flags, neurological deficit, and whether symptoms peripheralized after loading.'),
  action_on_no_change = coalesce(action_on_no_change, 'Review directional preference, adherence, sleep/stress load, and exercise dose.'),
  updated_at = now()
where form_code in ('NPRS', 'VAS');
update public.assessment_form_templates
set
  mcid_value = coalesce(mcid_value, 2),
  mdc_value = coalesce(mdc_value, 2),
  mdc_95 = coalesce(mdc_95, 2.3),
  score_min = coalesce(score_min, 0),
  score_max = coalesce(score_max, 10),
  max_possible_score = coalesce(max_possible_score, 10),
  higher_is_better = true,
  severity_thresholds = coalesce(severity_thresholds, '{}'::jsonb) || jsonb_build_object(
    'function_v2', jsonb_build_object(
      'interpretation_note', 'Use 3-5 patient-selected activities; average score. Higher is better. Reassess activities if goals change.'
    )
  ),
  condition_overrides = coalesce(condition_overrides, '[]'::jsonb) || jsonb_build_array(jsonb_build_object(
    'condition', 'low_back_pain_or_sciatica',
    'mcid', 'about 2 points on average score is commonly used as meaningful functional improvement',
    'mdc95', 2.3,
    'references', jsonb_build_array('Stratford et al. 1995', 'Horn et al. 2012')
  )),
  evidence_level = coalesce(evidence_level, 'B'),
  evidence_source = coalesce(evidence_source, 'Stratford et al. 1995; Horn et al. 2012'),
  evidence_year = coalesce(evidence_year, 2012),
  action_on_mcid_achieved = coalesce(action_on_mcid_achieved, 'Progress patient-specific functional exposure and set the next meaningful activity goal.'),
  action_on_worsened = coalesce(action_on_worsened, 'Identify which task worsened and regress load, range, duration, or context.'),
  action_on_no_change = coalesce(action_on_no_change, 'Re-check whether selected activity is specific, measurable, and relevant to current complaints.'),
  updated_at = now()
where form_code = 'PSFS';
-- ---------------------------------------------------------------------------
-- 2) Low back / sciatica condition rows
-- ---------------------------------------------------------------------------

update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array[
    'non-specific low back pain', 'mechanical low back pain', '허리통증', '비특이적 요통', '기계적 요통', 'centralization', 'directional preference'
  ]::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'new bowel/bladder dysfunction or saddle anesthesia',
    'progressive neurological deficit or bilateral neurological symptoms',
    'unexplained fever, weight loss, cancer history, immunosuppression, or severe unrelenting night pain',
    'major trauma, osteoporosis risk, or suspected fracture',
    'abdominal/vascular symptoms or non-mechanical pain pattern'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Evidence Pack v2: classify by irritability, symptom distribution, centralization/peripheralization, directional preference, neurological screen, and function goals. Use ODI/NPRS/PSFS trends to guide dose progression rather than pain score alone.'),
  differential_diagnosis = public._clinical_pack_append_text_array(differential_diagnosis, array[
    'lumbar radiculopathy', 'lumbar spinal stenosis', 'hip osteoarthritis', 'sacroiliac joint pain', 'fracture/infection/malignancy red flags', 'vascular claudication'
  ]::text[]),
  updated_at = now()
where icd10_code in ('M54.5', 'S33.5', 'M51.2', 'M47.82', 'M48.0');
update public.condition_library
set
  common_aliases = public._clinical_pack_append_text_array(common_aliases, array[
    'sciatica', 'lumbar radiculopathy', 'nerve root pain', '좌골신경통', '요추 신경근증', '하지 방사통'
  ]::text[]),
  red_flags = public._clinical_pack_append_text_array(red_flags, array[
    'progressive motor weakness, foot drop, or worsening reflex loss',
    'new bowel/bladder dysfunction or saddle anesthesia',
    'bilateral radicular symptoms or rapidly expanding numbness',
    'infection, cancer, fracture, or inflammatory disease suspicion'
  ]::text[]),
  clinical_presentation = concat_ws(E'\n', clinical_presentation, 'Evidence Pack v2: document dermatomal sensory change, myotomal weakness, reflexes, SLR/Crossed SLR/Slump response, symptom centralization/peripheralization, and 24-hour response to loading. Prefer graded exposure and matched directional movement when symptoms centralize or remain stable.'),
  differential_diagnosis = public._clinical_pack_append_text_array(differential_diagnosis, array[
    'cauda equina syndrome', 'peripheral neuropathy', 'hip pathology', 'vascular claudication', 'lumbar spinal stenosis', 'lumbosacral plexopathy'
  ]::text[]),
  updated_at = now()
where icd10_code in ('M54.1', 'G54.1', 'G83.4');
-- ---------------------------------------------------------------------------
-- 3) Centralization / directional preference / neuro screen special-test rows
-- ---------------------------------------------------------------------------

update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'Werneke MW, Hart DL. Centralization phenomenon and prognosis in low back pain: commonly cited MDT/prognosis literature.',
    'May S, Aina A. Centralization and directional preference: a systematic review. Man Ther. 2012.',
    'Academy of Orthopaedic Physical Therapy/JOSPT. Low Back Pain CPG Revision 2021.',
    'NICE NG59. Low back pain and sciatica in over 16s: assessment and management.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '중심화 말초화 directional preference 방향선호 반복운동 MDT 맥켄지 요통 방사통 재평가 24시간 반응'),
  interpretation = concat_ws(E'\n', interpretation, 'Evidence Pack v2: centralization or stable proximalization during repeated movement supports matched directional loading/progression; peripheralization or neurological worsening requires regression and reassessment.'),
  updated_at = now()
where id = 'ST_LUMB_011';
update public.special_tests
set
  reference_list = public._clinical_pack_append_text_array(reference_list, array[
    'APTA/JOSPT Low Back Pain CPG Revision 2021: neurological screening and subgrouping are recommended when leg symptoms are present.',
    'NICE NG59: consider alternative diagnoses and urgent referral for serious or progressive neurological signs.'
  ]::text[]),
  clinical_keywords_ko = concat_ws(' ', clinical_keywords_ko, '신경학적 검사 근절 감각 근력 반사 L4 L5 S1 foot drop 진행성 근력저하 배뇨 배변 saddle anesthesia'),
  updated_at = now()
where body_region = 'spine'
  and id in ('ST_LUMB_001', 'ST_LUMB_002', 'ST_LUMB_003');
-- ---------------------------------------------------------------------------
-- 4) Lumbar progression matrix: curated RAG rows
-- ---------------------------------------------------------------------------

insert into public.vector_search (source_type, source_id, title, content, category, metadata)
values
(
  'web_pages',
  'clinical-pack-v2-lbp-outcome-measures',
  'Low Back/Sciatica Outcome Measures: ODI, NPRS, PSFS interpretation',
  'Clinical Evidence Pack v2. 요통/방사통 outcome interpretation. ODI: lower is better, 0-100%; commonly use about 6-10 points for clinically meaningful change and MDC95 around 12.8 when interpreting individual change. NPRS/VAS: lower is better; about 2 points or 30% improvement is commonly meaningful; monitor distribution and 24-hour response, not intensity alone. PSFS: higher is better; about 2 points average improvement is meaningful; use patient-selected activity goals. Always combine with red flags, neuro screen, irritability, centralization/peripheralization, adherence, sleep/stress, and function goals.',
  'clinical_evidence_pack',
  jsonb_build_object('evidence_pack', 'low-back-sciatica-v2', 'source_quality', 'curated_summary', 'topics', jsonb_build_array('ODI','NPRS','VAS','PSFS','MCID','MDC','low back pain','sciatica'))
),
(
  'web_pages',
  'clinical-pack-v2-lbp-centralization-directional-preference',
  'Low Back/Sciatica Centralization and Directional Preference',
  'Clinical Evidence Pack v2. Centralization/directional preference. During repeated movement or sustained positioning, centralization/proximalization or stable symptoms supports matching the movement direction and gradually progressing range, volume, or load. Peripheralization, increasing distal leg pain/numbness/weakness, or next-day flare beyond acceptable threshold requires regression and reassessment. Track baseline distribution, within-session response, neurological status, and 24-hour response. Do not use a single response as a diagnosis; combine with history, irritability, SLR/Slump, neuro screen, and function.',
  'clinical_evidence_pack',
  jsonb_build_object('evidence_pack', 'low-back-sciatica-v2', 'source_quality', 'curated_summary', 'topics', jsonb_build_array('centralization','peripheralization','directional preference','MDT','low back pain','sciatica'))
),
(
  'web_pages',
  'clinical-pack-v2-lbp-neuro-screen-red-flags',
  'Low Back/Sciatica Neurological Screen and Red Flags',
  'Clinical Evidence Pack v2. Neuro screen for radiating leg pain: document dermatomal sensation, myotomal strength, reflexes, SLR/Crossed SLR/Slump, gait, heel/toe walking, and symptom distribution. Red flags/urgent referral: new bowel or bladder dysfunction, saddle anesthesia, progressive motor weakness or foot drop, bilateral neurological symptoms, infection/cancer/fracture suspicion, severe unrelenting night pain, systemic symptoms, or non-mechanical pain pattern. If neurological signs worsen after exercise, stop progression and reassess.',
  'clinical_evidence_pack',
  jsonb_build_object('evidence_pack', 'low-back-sciatica-v2', 'source_quality', 'curated_summary', 'topics', jsonb_build_array('neurological screen','red flags','SLR','Slump','cauda equina','radiculopathy'))
),
(
  'web_pages',
  'clinical-pack-v2-lbp-exercise-progression-matrix',
  'Low Back/Sciatica Exercise Progression Matrix',
  'Clinical Evidence Pack v2. Lumbar progression matrix. High irritability: education, symptom monitoring, short-duration walking, unloaded neutral-spine control, gentle directional movement if symptoms centralize/stay stable, avoid aggressive stretching or loaded flexion/extension. Moderate irritability: hip hinge drill, bird dog, side plank regression, hip bridge, graded walking/sitting exposure, slider-type neural mobility if radicular symptoms are irritable. Low irritability: progress hold time/reps/resistance, loaded hip hinge, anti-rotation/anti-extension core, work/sport-specific graded exposure. Progress only if pain is acceptable, distal symptoms do not increase, neuro status is stable, and 24-hour response is acceptable.',
  'clinical_evidence_pack',
  jsonb_build_object('evidence_pack', 'low-back-sciatica-v2', 'source_quality', 'curated_summary', 'topics', jsonb_build_array('exercise progression','bird dog','side plank','hip bridge','walking','graded exposure','nerve glide'))
)
on conflict (source_type, source_id) do update
set
  title = excluded.title,
  content = excluded.content,
  category = excluded.category,
  metadata = excluded.metadata,
  updated_at = now();
-- Mark existing low-back guideline chunks so AI evidence card can surface source quality.
update public.vector_search
set
  metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('evidence_pack', 'low-back-sciatica-v2', 'source_quality', 'external_guideline_or_fact_sheet'),
  content = case
    when content ilike '%Clinical Evidence Pack v2:%' then content
    else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: low back/sciatica guideline source available for AI evidence card. Use as external guideline/fact-sheet context; do not invent recommendation grades or numeric claims not present in the source chunk.')
  end,
  updated_at = now()
where source_type = 'web_pages'
  and (
    title ilike '%Low back pain%'
    or title ilike '%sciatica%'
    or title ilike '%APTA%'
    or title ilike '%NICE%'
  );
-- Update vector rows for affected assessment templates and centralization test.
update public.vector_search
set
  content = case
    when content ilike '%Clinical Evidence Pack v2:%' then content
    else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: low back/sciatica interpretation enriched with MCID/MDC, severity/action guidance, and patient-specific function context.')
  end,
  metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('evidence_pack', 'low-back-sciatica-v2', 'source_quality', 'outcome_measure_interpretation'),
  updated_at = now()
where source_type = 'assessment_form_templates'
  and source_id in (
    select id::text from public.assessment_form_templates where form_code in ('ODI','NPRS','VAS','PSFS')
  );
update public.vector_search
set
  content = case
    when content ilike '%Clinical Evidence Pack v2:%' then content
    else concat_ws(E'\n', content, 'Clinical Evidence Pack v2: centralization/peripheralization and directional preference interpretation added. Use with symptom distribution, SLR/Slump, neuro screen, and 24-hour response.')
  end,
  metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('evidence_pack', 'low-back-sciatica-v2', 'source_quality', 'centralization_directional_preference'),
  updated_at = now()
where source_type = 'special_tests'
  and source_id in ('ST_LUMB_011', 'ST_LUMB_001', 'ST_LUMB_002', 'ST_LUMB_003');
drop function if exists public._clinical_pack_append_text_array(text[], text[]);
