begin;

with concept_seed(
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  source_table,
  source_code,
  evidence_source,
  status,
  properties
) as (
  values
(
  'low_back_pain',
  'Low back pain',
  '요통',
  'condition',
  array['core', 'msk']::text[],
  'terminology_registry',
  'low_back_pain',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'neck_pain',
  'Neck pain',
  '경부 통증',
  'condition',
  array['core', 'msk']::text[],
  'terminology_registry',
  'neck_pain',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'shoulder_pain',
  'Shoulder pain',
  '어깨 통증',
  'condition',
  array['core', 'msk']::text[],
  'terminology_registry',
  'shoulder_pain',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'knee_pain',
  'Knee pain',
  '무릎 통증',
  'condition',
  array['core', 'msk']::text[],
  'terminology_registry',
  'knee_pain',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'rom_lumbar_flexion',
  'Lumbar flexion ROM',
  '요추 굴곡 ROM',
  'observation',
  array['core', 'msk']::text[],
  'observation_taxonomy',
  'ROM_lumbar_flexion',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'mmt_knee_extension',
  'Knee extension MMT',
  '무릎 신전 근력',
  'observation',
  array['core', 'msk', 'neuro']::text[],
  'observation_taxonomy',
  'MMT_knee_extension',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'gait_pattern_antalgic',
  'Antalgic gait pattern',
  '회피성 보행 패턴',
  'movement_pattern',
  array['core', 'msk']::text[],
  'movement_patterns',
  'gait_pattern_antalgic',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'knee_valgus',
  'Knee valgus',
  '무릎 외반',
  'movement_pattern',
  array['core', 'msk']::text[],
  'movement_patterns',
  'knee_valgus',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'trunk_instability',
  'Trunk instability',
  '체간 불안정성',
  'impairment',
  array['core', 'neuro', 'pediatric']::text[],
  'impairments',
  'trunk_instability',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'head_control_deficit',
  'Head control deficit',
  '머리 조절 저하',
  'impairment',
  array['pediatric', 'neuro']::text[],
  null,
  'head_control_level',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'trunk_control_deficit',
  'Trunk control deficit',
  '체간 조절 저하',
  'impairment',
  array['pediatric', 'neuro']::text[],
  null,
  'trunk_control_level',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'gmfcs',
  'Gross Motor Function Classification System',
  '대운동기능분류체계',
  'observation',
  array['pediatric']::text[],
  'observation_taxonomy',
  'GMFCS',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'gmfm',
  'Gross Motor Function Measure',
  '대운동기능평가',
  'observation',
  array['pediatric']::text[],
  'observation_taxonomy',
  'GMFM',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'feeding_route',
  'Feeding route',
  '섭식 경로',
  'observation',
  array['pediatric']::text[],
  'observation_taxonomy',
  'feeding_route',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'respiratory_support_type',
  'Respiratory support type',
  '호흡보조 유형',
  'observation',
  array['pediatric']::text[],
  'observation_taxonomy',
  'resp_support_type',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'aspiration_risk',
  'Aspiration risk',
  '흡인 위험',
  'risk',
  array['pediatric']::text[],
  null,
  'aspiration_risk',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'contracture_risk',
  'Contracture risk',
  '구축 위험',
  'risk',
  array['pediatric', 'neuro']::text[],
  null,
  'contracture_risk',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'positive_slr',
  'Positive straight leg raise',
  '하지직거상 양성',
  'special_test',
  array['msk', 'neuro']::text[],
  'special_tests',
  'SLR',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'slump_test_positive',
  'Positive slump test',
  '슬럼프 테스트 양성',
  'special_test',
  array['msk', 'neuro']::text[],
  'special_tests',
  'SLUMP',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
),
(
  'home_program_adherence',
  'Home program adherence',
  '홈프로그램 이행도',
  'other',
  array['core', 'pediatric', 'msk', 'neuro', 'wellness']::text[],
  'observation_taxonomy',
  'home_program_adherence',
  'seed:v1',
  'active',
  '{"seed_version":"v1"}'::jsonb
)
)
insert into public.clinical_concepts (
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  source_table,
  source_code,
  definition,
  status,
  properties
)
select
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  source_table,
  source_code,
  evidence_source,
  status,
  properties
from concept_seed
on conflict (concept_key) do update
set
  display = excluded.display,
  display_ko = excluded.display_ko,
  concept_domain = excluded.concept_domain,
  specialty_scope = excluded.specialty_scope,
  source_table = excluded.source_table,
  source_code = excluded.source_code,
  definition = excluded.definition,
  status = excluded.status,
  properties = excluded.properties;

with alias_seed(
  concept_key,
  alias_text,
  normalized_alias,
  language_code,
  alias_type,
  source,
  is_preferred
) as (
  values
(
  'low_back_pain',
  '요통',
  '요통',
  'ko',
  'synonym',
  'seed:v1',
  false
),
(
  'low_back_pain',
  '허리 아픔',
  '허리 아픔',
  'ko',
  'surface_form',
  'seed:v1',
  false
),
(
  'low_back_pain',
  '허리 통증',
  '허리 통증',
  'ko',
  'surface_form',
  'seed:v1',
  false
),
(
  'low_back_pain',
  'LBP',
  'lbp',
  'en',
  'abbreviation',
  'seed:v1',
  false
),
(
  'low_back_pain',
  'low back pain',
  'low back pain',
  'en',
  'synonym',
  'seed:v1',
  false
),
(
  'head_control_deficit',
  'poor head control',
  'poor head control',
  'en',
  'synonym',
  'seed:v1',
  false
),
(
  'head_control_deficit',
  '머리 가누기 약함',
  '머리 가누기 약함',
  'ko',
  'surface_form',
  'seed:v1',
  false
),
(
  'head_control_deficit',
  '머리 컨트롤 저하',
  '머리 컨트롤 저하',
  'ko',
  'surface_form',
  'seed:v1',
  false
),
(
  'feeding_route',
  'oral feeding',
  'oral feeding',
  'en',
  'surface_form',
  'seed:v1',
  false
),
(
  'feeding_route',
  'PEG feeding',
  'peg feeding',
  'en',
  'surface_form',
  'seed:v1',
  false
),
(
  'feeding_route',
  '튜브 feeding',
  '튜브 feeding',
  'ko',
  'surface_form',
  'seed:v1',
  false
),
(
  'feeding_route',
  '구강섭취',
  '구강섭취',
  'ko',
  'synonym',
  'seed:v1',
  false
),
(
  'feeding_route',
  'PEG',
  'peg',
  'en',
  'abbreviation',
  'seed:v1',
  false
),
(
  'positive_slr',
  'SLR positive',
  'slr positive',
  'en',
  'surface_form',
  'seed:v1',
  false
),
(
  'positive_slr',
  'positive SLR',
  'positive slr',
  'en',
  'surface_form',
  'seed:v1',
  false
),
(
  'positive_slr',
  '하지직거상 양성',
  '하지직거상 양성',
  'ko',
  'synonym',
  'seed:v1',
  false
),
(
  'positive_slr',
  'straight leg raise positive',
  'straight leg raise positive',
  'en',
  'surface_form',
  'seed:v1',
  false
),
(
  'home_program_adherence',
  'HEP adherence',
  'hep adherence',
  'en',
  'abbreviation',
  'seed:v1',
  false
),
(
  'home_program_adherence',
  'home program adherence',
  'home program adherence',
  'en',
  'synonym',
  'seed:v1',
  false
),
(
  'home_program_adherence',
  '숙제운동 수행도',
  '숙제운동 수행도',
  'ko',
  'surface_form',
  'seed:v1',
  false
),
(
  'home_program_adherence',
  '홈프로그램 이행',
  '홈프로그램 이행',
  'ko',
  'synonym',
  'seed:v1',
  false
)
)
insert into public.concept_aliases (
  concept_id,
  alias_text,
  normalized_alias,
  language_code,
  alias_type,
  source,
  is_preferred
)
select
  cc.id,
  a.alias_text,
  a.normalized_alias,
  a.language_code,
  a.alias_type,
  a.source,
  a.is_preferred
from alias_seed a
join public.clinical_concepts cc
  on cc.concept_key = a.concept_key
on conflict (concept_id, normalized_alias, language_code, alias_type) do update
set
  alias_text = excluded.alias_text,
  source = excluded.source,
  is_preferred = excluded.is_preferred;

with relationship_seed(
  source_concept_key,
  relationship_type,
  target_concept_key,
  weight,
  specialty_scope,
  evidence_source
) as (
  values
(
  'feeding_route',
  'related_to',
  'aspiration_risk',
  0.8,
  array['pediatric']::text[],
  'seed:v1'
),
(
  'respiratory_support_type',
  'related_to',
  'aspiration_risk',
  0.8,
  array['pediatric']::text[],
  'seed:v1'
)
)
insert into public.concept_relationships (
  source_concept_id,
  relationship_type,
  target_concept_id,
  weight,
  specialty_scope,
  evidence_source
)
select
  src.id,
  r.relationship_type,
  tgt.id,
  r.weight,
  r.specialty_scope,
  r.evidence_source
from relationship_seed r
join public.clinical_concepts src
  on src.concept_key = r.source_concept_key
join public.clinical_concepts tgt
  on tgt.concept_key = r.target_concept_key
on conflict (source_concept_id, relationship_type, target_concept_id) do update
set
  weight = excluded.weight,
  specialty_scope = excluded.specialty_scope,
  evidence_source = excluded.evidence_source;

commit;;
