-- Observation-first clinical reasoning MVP.
-- Purpose:
-- - keep observations as the factual SSOT
-- - add a lightweight rule registry for Observation -> Clinical Concept
-- - add reviewable patient/encounter-level reasoning assertions
-- - seed a narrow low-back / hip / gait vertical slice

begin;
create table if not exists public.clinical_concept_observation_rules (
  id uuid primary key default gen_random_uuid(),
  observation_taxonomy_id uuid references public.observation_taxonomy(id) on delete set null,
  observation_code text not null,
  observation_code_system text not null default 'http://physiokorea.com/fhir/observation',
  concept_id uuid not null references public.clinical_concepts(id) on delete cascade,
  rule_key text not null,
  rule_status text not null default 'active',
  body_region text,
  laterality_policy text not null default 'inherit',
  value_match jsonb not null default '{}'::jsonb,
  context_requirements jsonb not null default '{}'::jsonb,
  confidence_weight numeric not null default 0.7,
  rationale_template text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint clinical_concept_observation_rules_key_unique
    unique (observation_code, observation_code_system, concept_id, rule_key),
  constraint clinical_concept_observation_rules_status_check
    check (rule_status = any (array['draft','active','deprecated']::text[])),
  constraint clinical_concept_observation_rules_laterality_check
    check (laterality_policy = any (array['none','inherit','required','either_side']::text[])),
  constraint clinical_concept_observation_rules_weight_check
    check (confidence_weight >= 0 and confidence_weight <= 1)
);
create table if not exists public.clinical_hypothesis_rules (
  id uuid primary key default gen_random_uuid(),
  rule_key text not null unique,
  hypothesis_concept_id uuid not null references public.clinical_concepts(id) on delete cascade,
  body_region text,
  specialty_scope text[] not null default array['core']::text[],
  required_evidence jsonb not null default '[]'::jsonb,
  supporting_evidence jsonb not null default '[]'::jsonb,
  contradicting_evidence jsonb not null default '[]'::jsonb,
  missing_data_prompts jsonb not null default '[]'::jsonb,
  score_threshold numeric not null default 0.65,
  intervention_targets jsonb not null default '[]'::jsonb,
  outcome_signals jsonb not null default '[]'::jsonb,
  rule_status text not null default 'active',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint clinical_hypothesis_rules_scope_check
    check (cardinality(specialty_scope) >= 1),
  constraint clinical_hypothesis_rules_score_check
    check (score_threshold >= 0 and score_threshold <= 1),
  constraint clinical_hypothesis_rules_status_check
    check (rule_status = any (array['draft','active','deprecated']::text[]))
);
create table if not exists public.clinical_reasoning_assertions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  subject_person_id uuid not null references public.persons(id) on delete cascade,
  encounter_id uuid references public.encounters(id) on delete set null,
  assertion_type text not null,
  concept_id uuid references public.clinical_concepts(id) on delete set null,
  hypothesis_rule_id uuid references public.clinical_hypothesis_rules(id) on delete set null,
  label text not null,
  status text not null default 'candidate',
  confidence numeric,
  evidence_observation_ids uuid[] not null default array[]::uuid[],
  evidence_concept_ids uuid[] not null default array[]::uuid[],
  contradicting_observation_ids uuid[] not null default array[]::uuid[],
  missing_data jsonb not null default '[]'::jsonb,
  suggested_next_checks jsonb not null default '[]'::jsonb,
  suggested_interventions jsonb not null default '[]'::jsonb,
  expected_outcomes jsonb not null default '[]'::jsonb,
  rationale text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.persons(id) on delete set null,
  reviewed_by uuid references public.persons(id) on delete set null,
  reviewed_at timestamp with time zone,
  effective_datetime timestamp with time zone not null default now(),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint clinical_reasoning_assertions_type_check
    check (assertion_type = any (array[
      'clinical_concept',
      'hypothesis',
      'intervention_target',
      'outcome_signal'
    ]::text[])),
  constraint clinical_reasoning_assertions_status_check
    check (status = any (array[
      'candidate',
      'confirmed',
      'deferred',
      'rejected',
      'superseded'
    ]::text[])),
  constraint clinical_reasoning_assertions_confidence_check
    check (confidence is null or (confidence >= 0 and confidence <= 1))
);
create index if not exists idx_clinical_concept_observation_rules_code
  on public.clinical_concept_observation_rules
  (observation_code, observation_code_system, rule_status);
create index if not exists idx_clinical_concept_observation_rules_concept
  on public.clinical_concept_observation_rules
  (concept_id, rule_status);
create index if not exists idx_clinical_hypothesis_rules_region
  on public.clinical_hypothesis_rules
  (body_region, rule_status);
create index if not exists idx_clinical_reasoning_assertions_patient
  on public.clinical_reasoning_assertions
  (organization_id, subject_person_id, effective_datetime desc);
create index if not exists idx_clinical_reasoning_assertions_encounter
  on public.clinical_reasoning_assertions
  (encounter_id, assertion_type, status);
create index if not exists idx_clinical_reasoning_assertions_concept
  on public.clinical_reasoning_assertions
  (concept_id, status);
create unique index if not exists uq_clinical_reasoning_assertions_active_concept
  on public.clinical_reasoning_assertions (
    organization_id,
    subject_person_id,
    coalesce(encounter_id, '00000000-0000-0000-0000-000000000000'::uuid),
    assertion_type,
    concept_id
  )
  where status in ('candidate', 'confirmed', 'deferred')
    and concept_id is not null;
drop trigger if exists clinical_concept_observation_rules_set_updated_at
  on public.clinical_concept_observation_rules;
create trigger clinical_concept_observation_rules_set_updated_at
  before update on public.clinical_concept_observation_rules
  for each row execute function public.set_updated_at();
drop trigger if exists clinical_hypothesis_rules_set_updated_at
  on public.clinical_hypothesis_rules;
create trigger clinical_hypothesis_rules_set_updated_at
  before update on public.clinical_hypothesis_rules
  for each row execute function public.set_updated_at();
drop trigger if exists clinical_reasoning_assertions_set_updated_at
  on public.clinical_reasoning_assertions;
create trigger clinical_reasoning_assertions_set_updated_at
  before update on public.clinical_reasoning_assertions
  for each row execute function public.set_updated_at();
alter table public.clinical_concept_observation_rules enable row level security;
alter table public.clinical_hypothesis_rules enable row level security;
alter table public.clinical_reasoning_assertions enable row level security;
drop policy if exists clinical_concept_observation_rules_read_all
  on public.clinical_concept_observation_rules;
create policy clinical_concept_observation_rules_read_all
  on public.clinical_concept_observation_rules
  for select
  to authenticated
  using (true);
drop policy if exists clinical_concept_observation_rules_service_write
  on public.clinical_concept_observation_rules;
create policy clinical_concept_observation_rules_service_write
  on public.clinical_concept_observation_rules
  for all
  to service_role
  using (true)
  with check (true);
drop policy if exists clinical_hypothesis_rules_read_all
  on public.clinical_hypothesis_rules;
create policy clinical_hypothesis_rules_read_all
  on public.clinical_hypothesis_rules
  for select
  to authenticated
  using (true);
drop policy if exists clinical_hypothesis_rules_service_write
  on public.clinical_hypothesis_rules;
create policy clinical_hypothesis_rules_service_write
  on public.clinical_hypothesis_rules
  for all
  to service_role
  using (true)
  with check (true);
drop policy if exists clinical_reasoning_assertions_select_member
  on public.clinical_reasoning_assertions;
create policy clinical_reasoning_assertions_select_member
  on public.clinical_reasoning_assertions
  for select
  to authenticated
  using (is_org_member(organization_id));
drop policy if exists clinical_reasoning_assertions_service_write
  on public.clinical_reasoning_assertions;
create policy clinical_reasoning_assertions_service_write
  on public.clinical_reasoning_assertions
  for all
  to service_role
  using (true)
  with check (true);
-- Qualitative observation taxonomy seed: first low-back / hip / gait slice.
insert into public.observation_taxonomy (
  code,
  code_system,
  code_display,
  category,
  default_value_type,
  default_unit,
  data_source,
  notes,
  icf_codes,
  interpretation_guide,
  body_site_applicable,
  laterality_applicable,
  is_active
) values
  (
    'obs_msk_movement_hip_hinge_poor',
    'http://physiokorea.com/fhir/observation',
    'Hip hinge poor',
    array['movement','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Qualitative observation for poor hip hinge strategy.',
    array['b760','d410','d430'],
    '{"observation_domain":"msk","finding_family":"movement","synonyms":["poor hinge","lumbar-dominant bend"],"clinical_meaning":"Suggests impaired hip/trunk load sharing or movement coordination during sagittal-plane loading.","concept_candidates":["movement_coordination_deficit"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    false,
    false,
    true
  ),
  (
    'obs_msk_movement_lumbar_dominant_pattern',
    'http://physiokorea.com/fhir/observation',
    'Lumbar dominant movement pattern',
    array['movement','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Qualitative observation for lumbar-dominant bending or loading.',
    array['b760','d410','d430'],
    '{"observation_domain":"msk","finding_family":"movement","synonyms":["excessive lumbar flexion","back-dominant bend"],"clinical_meaning":"Suggests poor hip/trunk load-sharing strategy.","concept_candidates":["movement_coordination_deficit"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    false,
    false,
    true
  ),
  (
    'obs_msk_symptom_flexion_pain',
    'http://physiokorea.com/fhir/observation',
    'Flexion pain response',
    array['symptom_response','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Pain or symptom increase with flexion-oriented movement.',
    array['b280','d410'],
    '{"observation_domain":"msk","finding_family":"symptom_response","synonyms":["pain with flexion","flexion-sensitive pain"],"clinical_meaning":"May support flexion sensitivity, load intolerance, or neural sensitivity depending on co-findings.","concept_candidates":["load_intolerance","neural_mechanosensitivity"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    false,
    false,
    true
  ),
  (
    'obs_msk_gait_trendelenburg',
    'http://physiokorea.com/fhir/observation',
    'Trendelenburg gait',
    array['gait','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Qualitative gait observation for pelvic drop or compensated Trendelenburg pattern.',
    array['b730','b760','b770','d450'],
    '{"observation_domain":"msk","finding_family":"gait","synonyms":["hip drop gait","pelvic drop during stance"],"clinical_meaning":"Suggests impaired frontal-plane lumbopelvic or hip abductor control during stance.","concept_candidates":["lumbopelvic_control_deficit"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    true,
    true,
    true
  ),
  (
    'obs_msk_balance_pelvic_drop_sls',
    'http://physiokorea.com/fhir/observation',
    'Pelvic drop in single-leg stance',
    array['balance','movement','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Pelvic drop during single-leg stance or single-leg task.',
    array['b755','b760','d415'],
    '{"observation_domain":"msk","finding_family":"balance","synonyms":["contralateral pelvic drop","hip drop"],"clinical_meaning":"Suggests lumbopelvic or hip abductor control deficit in single-leg support.","concept_candidates":["lumbopelvic_control_deficit","balance_strategy_deficit"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    true,
    true,
    true
  ),
  (
    'obs_msk_balance_weight_shift_asymmetry',
    'http://physiokorea.com/fhir/observation',
    'Weight shift asymmetry',
    array['balance','gait','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Observable asymmetry in stance, transfer, squat, or gait loading.',
    array['b755','b760','d410','d415'],
    '{"observation_domain":"msk","finding_family":"balance","synonyms":["offloading","side preference"],"clinical_meaning":"Suggests balance strategy deficit, pain avoidance, or unilateral load intolerance depending on context.","concept_candidates":["balance_strategy_deficit","load_intolerance"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    false,
    true,
    true
  ),
  (
    'obs_msk_movement_dynamic_valgus',
    'http://physiokorea.com/fhir/observation',
    'Dynamic knee valgus',
    array['movement','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Medial knee drift or dynamic valgus during single-leg, squat, landing, or step-down task.',
    array['b760','d410','d455'],
    '{"observation_domain":"msk","finding_family":"movement","synonyms":["knee collapse","medial knee drift"],"clinical_meaning":"Suggests lower-limb dynamic alignment or motor control deficit under load.","concept_candidates":["movement_coordination_deficit"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    true,
    true,
    true
  ),
  (
    'obs_msk_gait_antalgic',
    'http://physiokorea.com/fhir/observation',
    'Antalgic gait',
    array['gait','pain','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Pain-avoidance gait or limping pattern.',
    array['b280','b770','d450'],
    '{"observation_domain":"msk","finding_family":"gait","synonyms":["pain-avoidance gait","limping"],"clinical_meaning":"Suggests pain-limited loading tolerance.","concept_candidates":["load_intolerance"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    false,
    true,
    true
  ),
  (
    'obs_msk_balance_sls_instability',
    'http://physiokorea.com/fhir/observation',
    'Single-leg stance instability',
    array['balance','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Observable instability, excessive sway, or loss of control during single-leg stance.',
    array['b755','b760','d415'],
    '{"observation_domain":"msk","finding_family":"balance","synonyms":["unstable SLS","excessive sway"],"clinical_meaning":"Suggests static balance, lumbopelvic control, or proximal control deficit.","concept_candidates":["balance_strategy_deficit","lumbopelvic_control_deficit"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    false,
    true,
    true
  ),
  (
    'obs_msk_special_test_slr_symptom_reproduction',
    'http://physiokorea.com/fhir/observation',
    'SLR symptom reproduction',
    array['special_test','neuro','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Straight Leg Raise reproduces concordant neural or limb symptoms.',
    array['b280','b265','d410'],
    '{"observation_domain":"msk","finding_family":"special_test","synonyms":["SLR positive","straight leg raise positive"],"clinical_meaning":"Supports neural mechanosensitivity hypothesis when symptoms are concordant.","concept_candidates":["neural_mechanosensitivity"],"severity_scale":["positive","mild","moderate","severe"]}'::jsonb,
    true,
    true,
    true
  ),
  (
    'obs_msk_special_test_slump_symptom_reproduction',
    'http://physiokorea.com/fhir/observation',
    'Slump symptom reproduction',
    array['special_test','neuro','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Slump test reproduces concordant neural or limb symptoms.',
    array['b280','b265','d410'],
    '{"observation_domain":"msk","finding_family":"special_test","synonyms":["Slump positive","neural tension"],"clinical_meaning":"Supports neural mechanosensitivity or symptom irritability hypothesis when symptoms are concordant.","concept_candidates":["neural_mechanosensitivity"],"severity_scale":["positive","mild","moderate","severe"]}'::jsonb,
    false,
    true,
    true
  ),
  (
    'obs_msk_gait_reduced_push_off',
    'http://physiokorea.com/fhir/observation',
    'Reduced push-off',
    array['gait','msk','clinical_reasoning'],
    'string',
    null,
    'encounter_observation',
    'Reduced propulsion or terminal stance push-off during gait.',
    array['b730','b760','b770','d450'],
    '{"observation_domain":"msk","finding_family":"gait","synonyms":["poor propulsion","weak terminal stance"],"clinical_meaning":"Suggests plantarflexor power, load tolerance, or gait propulsion deficit.","concept_candidates":["load_intolerance"],"severity_scale":["present","mild","moderate","severe"]}'::jsonb,
    true,
    true,
    true
  )
on conflict (code, code_system) do update set
  code_display = excluded.code_display,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  data_source = excluded.data_source,
  notes = excluded.notes,
  icf_codes = excluded.icf_codes,
  interpretation_guide = excluded.interpretation_guide,
  body_site_applicable = excluded.body_site_applicable,
  laterality_applicable = excluded.laterality_applicable,
  is_active = true,
  updated_at = now();
insert into public.clinical_concepts (
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  definition,
  properties,
  status
) values
  (
    'lumbopelvic_control_deficit',
    'Lumbopelvic Control Deficit',
    '요골반 조절 결손',
    'impairment',
    array['core','msk'],
    'Reduced ability to control pelvis, trunk, and hip alignment during stance, gait, or loading tasks.',
    '{"icf":["b760","b770","d450"],"reasoning_layer":"clinical_concept"}'::jsonb,
    'active'
  ),
  (
    'movement_coordination_deficit',
    'Movement Coordination Deficit',
    '움직임 협응 결손',
    'impairment',
    array['core','msk','neuro'],
    'Reduced ability to coordinate task-specific movement strategy, timing, or load sharing.',
    '{"icf":["b760","d410","d430"],"reasoning_layer":"clinical_concept"}'::jsonb,
    'active'
  ),
  (
    'load_intolerance',
    'Load Intolerance',
    '부하 내성 저하',
    'impairment',
    array['core','msk'],
    'Reduced tolerance to mechanical loading, often expressed as pain, avoidance, or delayed symptom response.',
    '{"icf":["b280","d410","d450"],"reasoning_layer":"clinical_concept"}'::jsonb,
    'active'
  ),
  (
    'neural_mechanosensitivity',
    'Neural Mechanosensitivity',
    '신경 기계민감성',
    'impairment',
    array['core','msk','neuro'],
    'Increased symptom response to neural loading or sensitizing positions.',
    '{"icf":["b280","b265","d410"],"reasoning_layer":"clinical_concept"}'::jsonb,
    'active'
  ),
  (
    'balance_strategy_deficit',
    'Balance Strategy Deficit',
    '균형 전략 결손',
    'impairment',
    array['core','msk','neuro'],
    'Reduced ability to select or execute static, anticipatory, or dynamic balance strategies.',
    '{"icf":["b755","b760","d415","d450"],"reasoning_layer":"clinical_concept"}'::jsonb,
    'active'
  ),
  (
    'hip_hinge_dysfunction',
    'Hip Hinge Dysfunction',
    '힙힌지 기능장애',
    'movement_pattern',
    array['core','msk'],
    'A reviewable movement-pattern hypothesis where sagittal-plane loading is managed with poor hip hinge and excessive lumbar dominance.',
    '{"reasoning_layer":"hypothesis","mvp_family":"low_back_hip_gait"}'::jsonb,
    'active'
  ),
  (
    'lumbopelvic_control_gait_asymmetry',
    'Lumbopelvic Control-Driven Gait Asymmetry',
    '요골반 조절 관련 보행 비대칭',
    'movement_pattern',
    array['core','msk'],
    'A reviewable hypothesis that gait or stance asymmetry is being driven by lumbopelvic control deficits.',
    '{"reasoning_layer":"hypothesis","mvp_family":"low_back_hip_gait"}'::jsonb,
    'active'
  ),
  (
    'flexion_neural_sensitivity_pattern',
    'Flexion-Related Neural Sensitivity Pattern',
    '굴곡 관련 신경 민감성 패턴',
    'movement_pattern',
    array['core','msk','neuro'],
    'A reviewable hypothesis that flexion intolerance is partly supported by neural mechanosensitivity findings.',
    '{"reasoning_layer":"hypothesis","mvp_family":"low_back_hip_gait"}'::jsonb,
    'active'
  ),
  (
    'hip_hinge_retraining',
    'Hip Hinge Retraining',
    '힙힌지 재훈련',
    'intervention_target',
    array['core','msk'],
    'Intervention target focused on retraining hip-dominant bending and load-sharing strategy.',
    '{"reasoning_layer":"intervention_target"}'::jsonb,
    'active'
  ),
  (
    'motor_control_training',
    'Motor Control Training',
    '운동조절 훈련',
    'intervention_target',
    array['core','msk','neuro'],
    'Intervention target focused on controlled task execution and coordination.',
    '{"reasoning_layer":"intervention_target"}'::jsonb,
    'active'
  ),
  (
    'graded_load_exposure',
    'Graded Load Exposure',
    '점진적 부하 노출',
    'intervention_target',
    array['core','msk'],
    'Intervention target focused on graded exposure to tolerated loading.',
    '{"reasoning_layer":"intervention_target"}'::jsonb,
    'active'
  ),
  (
    'neural_mobility_symptom_guided',
    'Symptom-Guided Neural Mobility',
    '증상 기반 신경 가동성',
    'intervention_target',
    array['core','msk','neuro'],
    'Intervention target focused on symptom-guided neural loading and mobility education.',
    '{"reasoning_layer":"intervention_target"}'::jsonb,
    'active'
  )
on conflict (concept_key) do update set
  display = excluded.display,
  display_ko = excluded.display_ko,
  concept_domain = excluded.concept_domain,
  specialty_scope = excluded.specialty_scope,
  definition = excluded.definition,
  properties = coalesce(public.clinical_concepts.properties, '{}'::jsonb) || excluded.properties,
  status = 'active',
  updated_at = now();
with rule_seed as (
  select *
  from (
    values
      ('hip_hinge_poor_to_movement_coordination', 'obs_msk_movement_hip_hinge_poor', 'movement_coordination_deficit', 'lumbar', 'inherit', 0.75, 'Hip hinge quality supports movement coordination reasoning.'),
      ('lumbar_dominant_to_movement_coordination', 'obs_msk_movement_lumbar_dominant_pattern', 'movement_coordination_deficit', 'lumbar', 'inherit', 0.70, 'Lumbar-dominant loading supports movement coordination reasoning.'),
      ('flexion_pain_to_load_intolerance', 'obs_msk_symptom_flexion_pain', 'load_intolerance', 'lumbar', 'inherit', 0.55, 'Flexion pain can support load intolerance when paired with loading or movement findings.'),
      ('flexion_pain_to_neural_mechanosensitivity', 'obs_msk_symptom_flexion_pain', 'neural_mechanosensitivity', 'lumbar', 'inherit', 0.45, 'Flexion pain can support neural sensitivity when paired with neurodynamic findings.'),
      ('trendelenburg_to_lumbopelvic_control', 'obs_msk_gait_trendelenburg', 'lumbopelvic_control_deficit', 'hip', 'required', 0.80, 'Trendelenburg pattern supports lumbopelvic control reasoning.'),
      ('pelvic_drop_sls_to_lumbopelvic_control', 'obs_msk_balance_pelvic_drop_sls', 'lumbopelvic_control_deficit', 'hip', 'required', 0.80, 'Pelvic drop in single-leg support supports lumbopelvic control reasoning.'),
      ('pelvic_drop_sls_to_balance_strategy', 'obs_msk_balance_pelvic_drop_sls', 'balance_strategy_deficit', 'hip', 'required', 0.55, 'Pelvic drop may also reflect balance strategy limitations in single-leg support.'),
      ('weight_shift_asymmetry_to_balance_strategy', 'obs_msk_balance_weight_shift_asymmetry', 'balance_strategy_deficit', 'lower_limb', 'inherit', 0.70, 'Weight-shift asymmetry supports balance strategy reasoning.'),
      ('weight_shift_asymmetry_to_load_intolerance', 'obs_msk_balance_weight_shift_asymmetry', 'load_intolerance', 'lower_limb', 'inherit', 0.50, 'Weight-shift asymmetry may reflect load avoidance when pain context is present.'),
      ('dynamic_valgus_to_movement_coordination', 'obs_msk_movement_dynamic_valgus', 'movement_coordination_deficit', 'knee', 'required', 0.70, 'Dynamic valgus supports lower-limb movement coordination reasoning.'),
      ('antalgic_gait_to_load_intolerance', 'obs_msk_gait_antalgic', 'load_intolerance', 'lower_limb', 'inherit', 0.80, 'Antalgic gait supports pain-limited load tolerance reasoning.'),
      ('sls_instability_to_balance_strategy', 'obs_msk_balance_sls_instability', 'balance_strategy_deficit', 'lower_limb', 'required', 0.75, 'Single-leg stance instability supports balance strategy reasoning.'),
      ('sls_instability_to_lumbopelvic_control', 'obs_msk_balance_sls_instability', 'lumbopelvic_control_deficit', 'hip', 'required', 0.55, 'Single-leg stance instability may support lumbopelvic control reasoning when paired with pelvic or gait findings.'),
      ('slr_reproduction_to_neural_mechanosensitivity', 'obs_msk_special_test_slr_symptom_reproduction', 'neural_mechanosensitivity', 'lumbar', 'required', 0.85, 'Concordant SLR symptom reproduction strongly supports neural mechanosensitivity reasoning.'),
      ('slump_reproduction_to_neural_mechanosensitivity', 'obs_msk_special_test_slump_symptom_reproduction', 'neural_mechanosensitivity', 'lumbar', 'inherit', 0.85, 'Concordant Slump symptom reproduction strongly supports neural mechanosensitivity reasoning.'),
      ('reduced_push_off_to_load_intolerance', 'obs_msk_gait_reduced_push_off', 'load_intolerance', 'ankle_foot', 'required', 0.55, 'Reduced push-off may support load tolerance or propulsion reasoning.')
  ) as v(rule_key, observation_code, concept_key, body_region, laterality_policy, confidence_weight, rationale_template)
)
insert into public.clinical_concept_observation_rules (
  observation_taxonomy_id,
  observation_code,
  observation_code_system,
  concept_id,
  rule_key,
  body_region,
  laterality_policy,
  value_match,
  confidence_weight,
  rationale_template,
  metadata,
  rule_status
)
select
  ot.id,
  seed.observation_code,
  'http://physiokorea.com/fhir/observation',
  cc.id,
  seed.rule_key,
  seed.body_region,
  seed.laterality_policy,
  '{"accepted_values":["present","positive","mild","moderate","severe"]}'::jsonb,
  seed.confidence_weight,
  seed.rationale_template,
  '{"mvp_family":"low_back_hip_gait","seed_wave":"observation_first_mvp_2026_06_11"}'::jsonb,
  'active'
from rule_seed seed
join public.clinical_concepts cc
  on cc.concept_key = seed.concept_key
join public.observation_taxonomy ot
  on ot.code = seed.observation_code
 and ot.code_system = 'http://physiokorea.com/fhir/observation'
on conflict (observation_code, observation_code_system, concept_id, rule_key) do update set
  observation_taxonomy_id = excluded.observation_taxonomy_id,
  body_region = excluded.body_region,
  laterality_policy = excluded.laterality_policy,
  value_match = excluded.value_match,
  confidence_weight = excluded.confidence_weight,
  rationale_template = excluded.rationale_template,
  metadata = coalesce(public.clinical_concept_observation_rules.metadata, '{}'::jsonb) || excluded.metadata,
  rule_status = 'active',
  updated_at = now();
insert into public.clinical_hypothesis_rules (
  rule_key,
  hypothesis_concept_id,
  body_region,
  specialty_scope,
  required_evidence,
  supporting_evidence,
  contradicting_evidence,
  missing_data_prompts,
  score_threshold,
  intervention_targets,
  outcome_signals,
  rule_status,
  metadata
)
select
  seed.rule_key,
  cc.id,
  seed.body_region,
  seed.specialty_scope,
  seed.required_evidence,
  seed.supporting_evidence,
  seed.contradicting_evidence,
  seed.missing_data_prompts,
  seed.score_threshold,
  seed.intervention_targets,
  seed.outcome_signals,
  'active',
  seed.metadata
from (
  values
    (
      'hyp_hip_hinge_dysfunction_mvp',
      'hip_hinge_dysfunction',
      'lumbar',
      array['core','msk']::text[],
      '[{"type":"observation","code":"obs_msk_movement_hip_hinge_poor"},{"type":"concept","key":"movement_coordination_deficit"}]'::jsonb,
      '[{"type":"observation","code":"obs_msk_movement_lumbar_dominant_pattern","weight":0.30},{"type":"observation","code":"obs_msk_symptom_flexion_pain","weight":0.20}]'::jsonb,
      '[{"type":"risk","key":"red_flag_present"},{"type":"concept","key":"progressive_neurologic_deficit"}]'::jsonb,
      '[{"prompt":"Re-test hip hinge unloaded and loaded."},{"prompt":"Compare symptom response during hip-dominant vs lumbar-dominant strategy."}]'::jsonb,
      0.65,
      '[{"concept_key":"hip_hinge_retraining"},{"concept_key":"motor_control_training"}]'::jsonb,
      '[{"signal":"improved_hip_hinge_quality"},{"signal":"reduced_flexion_pain_response"}]'::jsonb,
      '{"mvp_family":"low_back_hip_gait","seed_wave":"observation_first_mvp_2026_06_11"}'::jsonb
    ),
    (
      'hyp_lumbopelvic_control_gait_asymmetry_mvp',
      'lumbopelvic_control_gait_asymmetry',
      'hip',
      array['core','msk']::text[],
      '[{"type":"concept","key":"lumbopelvic_control_deficit"}]'::jsonb,
      '[{"type":"observation","code":"obs_msk_gait_trendelenburg","weight":0.35},{"type":"observation","code":"obs_msk_balance_pelvic_drop_sls","weight":0.30},{"type":"observation","code":"obs_msk_balance_sls_instability","weight":0.20},{"type":"observation","code":"obs_msk_balance_weight_shift_asymmetry","weight":0.20}]'::jsonb,
      '[{"type":"risk","key":"acute_unstable_neuro_sign"}]'::jsonb,
      '[{"prompt":"Confirm side, stance phase, and symptom/loading relationship."},{"prompt":"Compare single-leg stance and gait symmetry."}]'::jsonb,
      0.65,
      '[{"concept_key":"motor_control_training"},{"concept_key":"graded_load_exposure"}]'::jsonb,
      '[{"signal":"improved_stance_control"},{"signal":"improved_gait_symmetry"},{"signal":"improved_weight_shift"}]'::jsonb,
      '{"mvp_family":"low_back_hip_gait","seed_wave":"observation_first_mvp_2026_06_11"}'::jsonb
    ),
    (
      'hyp_flexion_neural_sensitivity_pattern_mvp',
      'flexion_neural_sensitivity_pattern',
      'lumbar',
      array['core','msk','neuro']::text[],
      '[{"type":"concept","key":"neural_mechanosensitivity"}]'::jsonb,
      '[{"type":"observation","code":"obs_msk_special_test_slr_symptom_reproduction","weight":0.35},{"type":"observation","code":"obs_msk_special_test_slump_symptom_reproduction","weight":0.35},{"type":"observation","code":"obs_msk_symptom_flexion_pain","weight":0.20}]'::jsonb,
      '[{"type":"risk","key":"progressive_neurologic_deficit"},{"type":"risk","key":"red_flag_present"}]'::jsonb,
      '[{"prompt":"Confirm concordant symptom reproduction and sensitizer response."},{"prompt":"Screen progressive neurologic signs before progression."}]'::jsonb,
      0.70,
      '[{"concept_key":"neural_mobility_symptom_guided"},{"concept_key":"graded_load_exposure"}]'::jsonb,
      '[{"signal":"reduced_symptom_reproduction"},{"signal":"improved_neurodynamic_tolerance"}]'::jsonb,
      '{"mvp_family":"low_back_hip_gait","seed_wave":"observation_first_mvp_2026_06_11"}'::jsonb
    )
) as seed(
  rule_key,
  hypothesis_concept_key,
  body_region,
  specialty_scope,
  required_evidence,
  supporting_evidence,
  contradicting_evidence,
  missing_data_prompts,
  score_threshold,
  intervention_targets,
  outcome_signals,
  metadata
)
join public.clinical_concepts cc
  on cc.concept_key = seed.hypothesis_concept_key
on conflict (rule_key) do update set
  hypothesis_concept_id = excluded.hypothesis_concept_id,
  body_region = excluded.body_region,
  specialty_scope = excluded.specialty_scope,
  required_evidence = excluded.required_evidence,
  supporting_evidence = excluded.supporting_evidence,
  contradicting_evidence = excluded.contradicting_evidence,
  missing_data_prompts = excluded.missing_data_prompts,
  score_threshold = excluded.score_threshold,
  intervention_targets = excluded.intervention_targets,
  outcome_signals = excluded.outcome_signals,
  rule_status = 'active',
  metadata = coalesce(public.clinical_hypothesis_rules.metadata, '{}'::jsonb) || excluded.metadata,
  updated_at = now();
commit;
