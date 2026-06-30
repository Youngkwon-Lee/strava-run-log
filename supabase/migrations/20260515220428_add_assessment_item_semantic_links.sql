create table if not exists public.assessment_template_item_semantic_links (
  id uuid primary key default gen_random_uuid(),
  form_template_id integer not null references public.assessment_form_templates(id) on delete cascade,
  score_key text not null,
  question_number integer,
  binding_role text not null default 'result',
  observation_taxonomy_id uuid references public.observation_taxonomy(id) on delete set null,
  clinical_concept_id uuid references public.clinical_concepts(id) on delete set null,
  terminology_registry_id uuid references public.terminology_registry(id) on delete set null,
  observation_code text,
  observation_code_system text default 'http://physiokorea.com/fhir/observation',
  display_override text,
  category text[],
  default_value_type text,
  default_unit text,
  body_site_code character varying(50),
  body_site_display character varying(255),
  laterality character varying(20),
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  status text not null default 'active',
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint assessment_template_item_semantic_links_binding_role_check
    check (binding_role = any (array[
      'result'::text,
      'aggregate'::text,
      'context'::text,
      'body_site'::text,
      'screening_flag'::text,
      'derived_score'::text
    ])),
  constraint assessment_template_item_semantic_links_status_check
    check (status = any (array['draft'::text, 'active'::text, 'deprecated'::text])),
  constraint assessment_template_item_semantic_links_value_type_check
    check (default_value_type is null or default_value_type = any (array[
      'quantity'::text,
      'string'::text,
      'boolean'::text,
      'integer'::text,
      'json'::text
    ])),
  constraint assessment_template_item_semantic_links_laterality_check
    check (laterality is null or laterality::text = any (array[
      'left'::text,
      'right'::text,
      'bilateral'::text
    ])),
  constraint assessment_template_item_semantic_links_target_required
    check (
      observation_taxonomy_id is not null
      or clinical_concept_id is not null
      or terminology_registry_id is not null
      or observation_code is not null
      or body_site_code is not null
    ),
  constraint assessment_template_item_semantic_links_code_system_required
    check (
      observation_code is null
      or observation_code_system is not null
    ),
  constraint assessment_template_item_semantic_links_unique
    unique (form_template_id, score_key, binding_role)
);
comment on table public.assessment_template_item_semantic_links
  is 'Item-level semantic binding registry for assessment_form_templates.items. Bridges score_key to local observation codes, clinical concepts, and external terminology.';
comment on column public.assessment_template_item_semantic_links.binding_role
  is 'result=item response, aggregate=instrument total_score, context=non-measurement metadata, body_site/body region hints, derived_score=projected/calculated result.';
create index if not exists idx_assessment_item_semantic_links_lookup
  on public.assessment_template_item_semantic_links (form_template_id, score_key, binding_role, status);
create index if not exists idx_assessment_item_semantic_links_taxonomy
  on public.assessment_template_item_semantic_links (observation_taxonomy_id);
create index if not exists idx_assessment_item_semantic_links_concept
  on public.assessment_template_item_semantic_links (clinical_concept_id);
create index if not exists idx_assessment_item_semantic_links_code
  on public.assessment_template_item_semantic_links (observation_code, observation_code_system);
alter table public.assessment_template_item_semantic_links enable row level security;
drop policy if exists assessment_item_semantic_links_read_all on public.assessment_template_item_semantic_links;
create policy assessment_item_semantic_links_read_all
  on public.assessment_template_item_semantic_links
  for select
  to authenticated
  using (true);
drop policy if exists assessment_item_semantic_links_service_write on public.assessment_template_item_semantic_links;
create policy assessment_item_semantic_links_service_write
  on public.assessment_template_item_semantic_links
  for all
  to service_role
  using (true)
  with check (true);
drop trigger if exists assessment_item_semantic_links_set_updated_at on public.assessment_template_item_semantic_links;
create trigger assessment_item_semantic_links_set_updated_at
  before update on public.assessment_template_item_semantic_links
  for each row execute function public.set_updated_at();
insert into public.clinical_concepts (
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  source_table,
  source_record_id_text,
  source_code,
  source_code_system,
  definition,
  properties,
  status
)
select
  'assessment_template:' || lower(aft.form_code),
  aft.form_name,
  aft.form_name_korean,
  'assessment_template',
  array['core']::text[],
  'assessment_form_templates',
  aft.id::text,
  aft.form_code,
  'http://physiokorea.com/fhir/assessment-template',
  aft.description,
  jsonb_strip_nulls(jsonb_build_object(
    'category', aft.category,
    'body_region', aft.body_region,
    'icf_code', aft.icf_code,
    'is_active', aft.is_active
  )),
  case when aft.is_active then 'active' else 'deprecated' end
from public.assessment_form_templates aft
where aft.form_code in ('VAS', 'NPRS', 'BASDAI', 'DASH', 'ODI', 'NDI', 'ROM_KNEE', 'ROM_LUMBAR')
on conflict (concept_key) do update
set
  display = excluded.display,
  display_ko = excluded.display_ko,
  source_record_id_text = excluded.source_record_id_text,
  source_code = excluded.source_code,
  source_code_system = excluded.source_code_system,
  definition = excluded.definition,
  properties = excluded.properties,
  status = excluded.status,
  updated_at = now();
insert into public.observation_taxonomy (
  code,
  code_system,
  code_display,
  category,
  default_value_type,
  default_unit,
  data_source,
  notes,
  is_active
)
values
  ('VAS', 'http://physiokorea.com/fhir/observation', 'Visual Analog Scale', array['pain']::text[], 'quantity', 'score', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true),
  ('NPRS', 'http://physiokorea.com/fhir/observation', 'Numeric Pain Rating Scale', array['pain']::text[], 'quantity', 'score', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true),
  ('BASDAI', 'http://physiokorea.com/fhir/observation', 'Bath Ankylosing Spondylitis Disease Activity Index', array['functional']::text[], 'quantity', 'score', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true),
  ('DASH', 'http://physiokorea.com/fhir/observation', 'Disabilities of Arm, Shoulder and Hand', array['disability']::text[], 'quantity', 'score', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true),
  ('ODI', 'http://physiokorea.com/fhir/observation', 'Oswestry Disability Index', array['disability']::text[], 'quantity', 'score', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true),
  ('NDI', 'http://physiokorea.com/fhir/observation', 'Neck Disability Index', array['disability']::text[], 'quantity', 'score', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true),
  ('ROM_knee_flexion', 'http://physiokorea.com/fhir/observation', 'Knee Flexion ROM', array['rom']::text[], 'quantity', 'deg', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true),
  ('ROM_knee_extension', 'http://physiokorea.com/fhir/observation', 'Knee Extension ROM', array['rom']::text[], 'quantity', 'deg', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true),
  ('ROM_lumbar_lateral_flexion_left', 'http://physiokorea.com/fhir/observation', 'Lumbar Left Lateral Flexion ROM', array['rom']::text[], 'quantity', 'deg', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true),
  ('ROM_lumbar_lateral_flexion_right', 'http://physiokorea.com/fhir/observation', 'Lumbar Right Lateral Flexion ROM', array['rom']::text[], 'quantity', 'deg', 'assessment_template_item_semantics', 'Seeded from assessment template semantics wave', true)
on conflict (code, code_system) do update
set
  code_display = excluded.code_display,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  data_source = excluded.data_source,
  notes = excluded.notes,
  is_active = excluded.is_active,
  updated_at = now();
with template_items as (
  select
    aft.form_code,
    aft.form_name,
    aft.category,
    item
  from public.assessment_form_templates aft
  cross join lateral jsonb_array_elements(aft.items) item
  where aft.form_code in ('BASDAI', 'DASH', 'ODI', 'NDI')
    and item ? 'score_key'
)
insert into public.observation_taxonomy (
  code,
  code_system,
  code_display,
  category,
  default_value_type,
  default_unit,
  data_source,
  notes,
  is_active
)
select
  ti.form_code || '_' || (ti.item ->> 'score_key'),
  'http://physiokorea.com/fhir/observation',
  ti.form_name || ': ' || coalesce(nullif(ti.item ->> 'question_text', ''), ti.item ->> 'score_key'),
  case
    when lower(ti.category) = 'disability' then array['disability']::text[]
    when lower(ti.category) in ('function', 'functional', 'disease_activity') then array['functional']::text[]
    else array['survey']::text[]
  end,
  case
    when lower(coalesce(ti.item ->> 'answer_type', '')) in ('number', 'slider', 'radio') then 'quantity'
    else 'string'
  end,
  case
    when lower(coalesce(ti.item ->> 'answer_type', '')) in ('number', 'slider', 'radio') then 'score'
    else null
  end,
  'assessment_template_item_semantics',
  'Seeded from assessment template item metadata',
  true
from template_items ti
on conflict (code, code_system) do update
set
  code_display = excluded.code_display,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  data_source = excluded.data_source,
  notes = excluded.notes,
  is_active = excluded.is_active,
  updated_at = now();
with aggregate_forms as (
  select
    aft.id as form_template_id,
    aft.form_code,
    aft.form_name,
    aft.category,
    aft.body_region
  from public.assessment_form_templates aft
  where aft.form_code in ('BASDAI', 'DASH', 'ODI', 'NDI')
)
insert into public.assessment_template_item_semantic_links (
  form_template_id,
  score_key,
  binding_role,
  observation_taxonomy_id,
  clinical_concept_id,
  observation_code,
  observation_code_system,
  display_override,
  category,
  default_value_type,
  default_unit,
  body_site_code,
  body_site_display,
  notes,
  metadata,
  status
)
select
  af.form_template_id,
  'total_score',
  'aggregate',
  ot.id,
  cc.id,
  af.form_code,
  'http://physiokorea.com/fhir/observation',
  af.form_name || ' total score',
  case
    when lower(af.category) = 'disability' then array['survey', 'functional-exam', 'disability']::text[]
    when lower(af.category) = 'disease_activity' then array['survey', 'functional-exam', 'disease_activity']::text[]
    else array['survey', 'functional-exam', 'functional']::text[]
  end,
  'quantity',
  'score',
  left(coalesce(af.body_region, lower(regexp_replace(af.form_code, '[^A-Za-z0-9_]+', '_', 'g'))), 50),
  af.body_region,
  'Seeded aggregate mapping for projected form observations',
  jsonb_build_object('seed', '2026-05-16', 'form_code', af.form_code),
  'active'
from aggregate_forms af
left join public.observation_taxonomy ot
  on ot.code = af.form_code
 and ot.code_system = 'http://physiokorea.com/fhir/observation'
left join public.clinical_concepts cc
  on cc.concept_key = 'assessment_template:' || lower(af.form_code)
on conflict (form_template_id, score_key, binding_role) do update
set
  observation_taxonomy_id = excluded.observation_taxonomy_id,
  clinical_concept_id = excluded.clinical_concept_id,
  observation_code = excluded.observation_code,
  observation_code_system = excluded.observation_code_system,
  display_override = excluded.display_override,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  body_site_code = excluded.body_site_code,
  body_site_display = excluded.body_site_display,
  notes = excluded.notes,
  metadata = excluded.metadata,
  status = excluded.status,
  updated_at = now();
with item_forms as (
  select
    aft.id as form_template_id,
    aft.form_code,
    aft.form_name,
    aft.category,
    aft.body_region,
    item
  from public.assessment_form_templates aft
  cross join lateral jsonb_array_elements(aft.items) item
  where aft.form_code in ('BASDAI', 'DASH', 'ODI', 'NDI')
    and item ? 'score_key'
)
insert into public.assessment_template_item_semantic_links (
  form_template_id,
  score_key,
  question_number,
  binding_role,
  observation_taxonomy_id,
  observation_code,
  observation_code_system,
  display_override,
  category,
  default_value_type,
  default_unit,
  body_site_code,
  body_site_display,
  notes,
  metadata,
  status
)
select
  fi.form_template_id,
  fi.item ->> 'score_key',
  nullif(fi.item ->> 'question_number', '')::integer,
  'result',
  ot.id,
  fi.form_code || '_' || (fi.item ->> 'score_key'),
  'http://physiokorea.com/fhir/observation',
  coalesce(nullif(fi.item ->> 'question_text', ''), fi.item ->> 'score_key'),
  case
    when lower(fi.category) = 'disability' then array['survey', 'functional-exam', 'disability']::text[]
    when lower(fi.category) = 'disease_activity' then array['survey', 'functional-exam', 'disease_activity']::text[]
    else array['survey', 'functional-exam', 'functional']::text[]
  end,
  case
    when lower(coalesce(fi.item ->> 'answer_type', '')) in ('number', 'slider', 'radio') then 'quantity'
    else 'string'
  end,
  case
    when lower(coalesce(fi.item ->> 'answer_type', '')) in ('number', 'slider', 'radio') then 'score'
    else null
  end,
  left(coalesce(fi.body_region, lower(regexp_replace(fi.form_code, '[^A-Za-z0-9_]+', '_', 'g'))), 50),
  fi.body_region,
  'Seeded item mapping for projected form observations',
  jsonb_build_object('seed', '2026-05-16', 'form_code', fi.form_code),
  'active'
from item_forms fi
left join public.observation_taxonomy ot
  on ot.code = fi.form_code || '_' || (fi.item ->> 'score_key')
 and ot.code_system = 'http://physiokorea.com/fhir/observation'
on conflict (form_template_id, score_key, binding_role) do update
set
  question_number = excluded.question_number,
  observation_taxonomy_id = excluded.observation_taxonomy_id,
  observation_code = excluded.observation_code,
  observation_code_system = excluded.observation_code_system,
  display_override = excluded.display_override,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  body_site_code = excluded.body_site_code,
  body_site_display = excluded.body_site_display,
  notes = excluded.notes,
  metadata = excluded.metadata,
  status = excluded.status,
  updated_at = now();
with simple_forms as (
  select
    aft.id as form_template_id,
    aft.form_code,
    aft.form_name,
    aft.category,
    aft.body_region,
    item
  from public.assessment_form_templates aft
  cross join lateral jsonb_array_elements(aft.items) item
  where (aft.form_code = 'VAS' and item ->> 'score_key' = 'vas_score')
     or (aft.form_code = 'NPRS' and item ->> 'score_key' = 'nprs_score')
)
insert into public.assessment_template_item_semantic_links (
  form_template_id,
  score_key,
  question_number,
  binding_role,
  observation_taxonomy_id,
  clinical_concept_id,
  observation_code,
  observation_code_system,
  display_override,
  category,
  default_value_type,
  default_unit,
  body_site_code,
  body_site_display,
  notes,
  metadata,
  status
)
select
  sf.form_template_id,
  sf.item ->> 'score_key',
  nullif(sf.item ->> 'question_number', '')::integer,
  'result',
  ot.id,
  cc.id,
  sf.form_code,
  'http://physiokorea.com/fhir/observation',
  sf.form_name,
  array['survey', 'pain']::text[],
  'quantity',
  'score',
  left(coalesce(sf.body_region, 'general'), 50),
  coalesce(sf.body_region, 'general'),
  'Seeded item mapping for pain scale form observations',
  jsonb_build_object('seed', '2026-05-16', 'form_code', sf.form_code),
  'active'
from simple_forms sf
left join public.observation_taxonomy ot
  on ot.code = sf.form_code
 and ot.code_system = 'http://physiokorea.com/fhir/observation'
left join public.clinical_concepts cc
  on cc.concept_key = 'assessment_template:' || lower(sf.form_code)
on conflict (form_template_id, score_key, binding_role) do update
set
  question_number = excluded.question_number,
  observation_taxonomy_id = excluded.observation_taxonomy_id,
  clinical_concept_id = excluded.clinical_concept_id,
  observation_code = excluded.observation_code,
  observation_code_system = excluded.observation_code_system,
  display_override = excluded.display_override,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  body_site_code = excluded.body_site_code,
  body_site_display = excluded.body_site_display,
  notes = excluded.notes,
  metadata = excluded.metadata,
  status = excluded.status,
  updated_at = now();
with rom_bindings(form_code, score_key, observation_code, display_override, body_site_code, body_site_display, laterality) as (
  values
    ('ROM_KNEE', 'krom_flexion', 'ROM_knee_flexion', 'Flexion', 'knee', 'knee', null),
    ('ROM_KNEE', 'krom_extension', 'ROM_knee_extension', 'Extension', 'knee', 'knee', null),
    ('ROM_LUMBAR', 'lrom_flexion', 'ROM_lumbar_flexion', 'Flexion', 'lumbar', 'lumbar', null),
    ('ROM_LUMBAR', 'lrom_extension', 'ROM_lumbar_extension', 'Extension', 'lumbar', 'lumbar', null),
    ('ROM_LUMBAR', 'lrom_lat_flex_l', 'ROM_lumbar_lateral_flexion_left', 'Left Lateral Flexion', 'lumbar', 'lumbar', 'left'),
    ('ROM_LUMBAR', 'lrom_lat_flex_r', 'ROM_lumbar_lateral_flexion_right', 'Right Lateral Flexion', 'lumbar', 'lumbar', 'right')
)
insert into public.assessment_template_item_semantic_links (
  form_template_id,
  score_key,
  question_number,
  binding_role,
  observation_taxonomy_id,
  clinical_concept_id,
  observation_code,
  observation_code_system,
  display_override,
  category,
  default_value_type,
  default_unit,
  body_site_code,
  body_site_display,
  laterality,
  notes,
  metadata,
  status
)
select
  aft.id,
  rb.score_key,
  nullif(item ->> 'question_number', '')::integer,
  'result',
  ot.id,
  cc.id,
  rb.observation_code,
  'http://physiokorea.com/fhir/observation',
  rb.display_override,
  array['exam', 'physical-exam', 'rom']::text[],
  'quantity',
  'deg',
  rb.body_site_code,
  rb.body_site_display,
  rb.laterality,
  'Seeded ROM movement-level mapping for projected form observations',
  jsonb_build_object('seed', '2026-05-16', 'form_code', rb.form_code),
  'active'
from rom_bindings rb
join public.assessment_form_templates aft
  on aft.form_code = rb.form_code
left join lateral (
  select item
  from jsonb_array_elements(aft.items) item
  where item ->> 'score_key' = rb.score_key
  limit 1
) matched on true
left join public.observation_taxonomy ot
  on ot.code = rb.observation_code
 and ot.code_system = 'http://physiokorea.com/fhir/observation'
left join public.clinical_concepts cc
  on cc.concept_key = 'assessment_template:' || lower(rb.form_code)
on conflict (form_template_id, score_key, binding_role) do update
set
  question_number = excluded.question_number,
  observation_taxonomy_id = excluded.observation_taxonomy_id,
  clinical_concept_id = excluded.clinical_concept_id,
  observation_code = excluded.observation_code,
  observation_code_system = excluded.observation_code_system,
  display_override = excluded.display_override,
  category = excluded.category,
  default_value_type = excluded.default_value_type,
  default_unit = excluded.default_unit,
  body_site_code = excluded.body_site_code,
  body_site_display = excluded.body_site_display,
  laterality = excluded.laterality,
  notes = excluded.notes,
  metadata = excluded.metadata,
  status = excluded.status,
  updated_at = now();
create or replace function private.assessment_item_semantic_binding(
  p_form_template_id text,
  p_form_code text,
  p_score_key text,
  p_binding_role text
)
returns table (
  binding_id uuid,
  binding_status text,
  observation_taxonomy_id uuid,
  clinical_concept_id uuid,
  terminology_registry_id uuid,
  observation_code text,
  observation_code_system text,
  display_override text,
  category text[],
  default_value_type text,
  default_unit text,
  body_site_code text,
  body_site_display text,
  laterality text,
  metadata jsonb
)
language sql
stable
set search_path to ''
as $function$
  select
    l.id,
    l.status,
    l.observation_taxonomy_id,
    l.clinical_concept_id,
    l.terminology_registry_id,
    l.observation_code,
    l.observation_code_system,
    l.display_override,
    l.category,
    l.default_value_type,
    l.default_unit,
    l.body_site_code::text,
    l.body_site_display::text,
    l.laterality::text,
    l.metadata
  from public.assessment_template_item_semantic_links l
  join public.assessment_form_templates aft
    on aft.id = l.form_template_id
  where l.status = 'active'
    and l.score_key = p_score_key
    and l.binding_role = p_binding_role
    and (
      aft.id::text = p_form_template_id
      or aft.form_code = p_form_code
    )
  order by
    case when aft.id::text = p_form_template_id then 0 else 1 end,
    l.question_number nulls last,
    l.created_at
  limit 1;
$function$;
create or replace function private.upsert_assessment_observation(
  p_form_response_id uuid,
  p_form_template_id text,
  p_subject_person_id uuid,
  p_performer_person_id uuid,
  p_organization_id uuid,
  p_encounter_id uuid,
  p_assessment_date timestamp with time zone,
  p_form_code text,
  p_form_name text,
  p_template_category text,
  p_template_body_region text,
  p_template_icf_code text,
  p_template_snomed_code text,
  p_score_key text,
  p_response_key text,
  p_response_path text,
  p_response_value jsonb,
  p_item jsonb,
  p_is_aggregate boolean default false
)
returns boolean
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_form_code text := private.assessment_normalized_form_code(coalesce(nullif(p_form_code, ''), p_form_template_id));
  v_code text;
  v_code_display text;
  v_code_system text := 'http://physiokorea.com/fhir/observation';
  v_value_type text;
  v_quantity numeric;
  v_string text;
  v_boolean boolean;
  v_json jsonb;
  v_unit text;
  v_body_site text;
  v_body_site_display text;
  v_region text;
  v_laterality text;
  v_created_by uuid := coalesce(p_performer_person_id, p_subject_person_id);
  v_context jsonb;
  v_category text[];
  v_binding_role text := case when p_is_aggregate then 'aggregate' else 'result' end;
  v_binding record;
begin
  if p_form_response_id is null
     or p_subject_person_id is null
     or p_organization_id is null
     or v_created_by is null then
    return false;
  end if;

  select *
  into v_binding
  from private.assessment_item_semantic_binding(
    p_form_template_id,
    v_form_code,
    p_score_key,
    v_binding_role
  );

  v_value_type := private.assessment_projection_value_type(p_response_value, coalesce(p_item, '{}'::jsonb), p_score_key);

  if v_binding.default_value_type is not null
     and v_value_type is not null
     and v_binding.default_value_type = v_value_type then
    v_value_type := v_binding.default_value_type;
  end if;

  if v_value_type is null then
    return false;
  end if;

  if p_is_aggregate then
    v_code := v_form_code;
    v_code_display := coalesce(nullif(p_form_name, ''), v_form_code) || ' total score';
  else
    v_code := private.assessment_projection_code(v_form_code, p_score_key, p_response_key);
    v_code_display := coalesce(
      nullif(p_item ->> 'question_text', ''),
      nullif(p_item ->> 'label', ''),
      nullif(p_item ->> 'question', ''),
      nullif(p_item ->> 'title', ''),
      v_code
    );
  end if;

  if v_binding.observation_code is not null then
    v_code := v_binding.observation_code;
  end if;

  if v_binding.observation_code_system is not null then
    v_code_system := v_binding.observation_code_system;
  end if;

  if v_binding.display_override is not null then
    v_code_display := v_binding.display_override;
  end if;

  if v_value_type = 'quantity' then
    v_quantity := private.assessment_jsonb_numeric(p_response_value);
    if v_quantity is null then
      return false;
    end if;
  elsif v_value_type = 'string' then
    v_string := nullif(btrim(p_response_value #>> '{}'), '');
    if v_string is null then
      return false;
    end if;
  elsif v_value_type = 'boolean' then
    v_boolean := (p_response_value #>> '{}')::boolean;
  elsif v_value_type = 'json' then
    v_json := p_response_value;
  end if;

  v_unit := coalesce(nullif(v_binding.default_unit, ''), nullif(coalesce(p_item ->> 'unit', p_item ->> 'value_unit'), ''));
  if v_unit is null and p_is_aggregate then
    v_unit := 'score';
  elsif v_unit is null and v_code like 'ROM\_%' escape '\' then
    v_unit := 'deg';
  end if;

  v_region := lower(regexp_replace(coalesce(p_template_body_region, ''), '[^A-Za-z0-9_]+', '_', 'g'));
  if v_region = '' and v_code like 'ROM\_%' escape '\' then
    v_region := split_part(v_code, '_', 2);
  end if;

  v_body_site := coalesce(nullif(v_binding.body_site_code, ''), nullif(left(v_region, 50), ''));
  v_body_site_display := coalesce(nullif(v_binding.body_site_display, ''), nullif(coalesce(p_template_body_region, v_region), ''));
  v_laterality := coalesce(nullif(v_binding.laterality, ''), private.assessment_projection_laterality(p_score_key, p_response_key));
  v_category := coalesce(v_binding.category, private.assessment_projection_categories(p_template_category, v_form_code));

  v_context := jsonb_strip_nulls(jsonb_build_object(
    'projector', 'assessment_form_response_to_observation_v2',
    'source_table', 'assessment_form_responses',
    'form_response_id', p_form_response_id,
    'form_template_id', p_form_template_id,
    'form_code', v_form_code,
    'form_name', p_form_name,
    'template_category', p_template_category,
    'template_icf_code', p_template_icf_code,
    'template_snomed_code', p_template_snomed_code,
    'score_key', p_score_key,
    'response_key', p_response_key,
    'response_path', p_response_path,
    'is_aggregate', p_is_aggregate,
    'item', nullif(coalesce(p_item, '{}'::jsonb), '{}'::jsonb),
    'semantic_binding', case
      when v_binding.binding_id is null then null
      else jsonb_build_object(
        'id', v_binding.binding_id,
        'status', v_binding.binding_status,
        'observation_taxonomy_id', v_binding.observation_taxonomy_id,
        'clinical_concept_id', v_binding.clinical_concept_id,
        'terminology_registry_id', v_binding.terminology_registry_id,
        'binding_role', v_binding_role,
        'observation_code', v_binding.observation_code,
        'observation_code_system', v_binding.observation_code_system
      )
    end
  ));

  insert into public.observations (
    fhir_id,
    status,
    category,
    code,
    code_display,
    code_system,
    subject_person_id,
    organization_id,
    encounter_id,
    performer_person_id,
    value_type,
    value_quantity,
    value_unit,
    value_string,
    value_boolean,
    value_json,
    effective_datetime,
    issued,
    created_by,
    source_type,
    form_response_id,
    instrument_id,
    body_site_code,
    body_site_display,
    laterality,
    measurement_context
  ) values (
    gen_random_uuid()::text,
    'final',
    v_category,
    v_code,
    v_code_display,
    v_code_system,
    p_subject_person_id,
    p_organization_id,
    p_encounter_id,
    p_performer_person_id,
    v_value_type,
    v_quantity,
    v_unit,
    v_string,
    v_boolean,
    v_json,
    coalesce(p_assessment_date, now()),
    now(),
    v_created_by,
    'form',
    p_form_response_id,
    left(v_form_code, 50),
    v_body_site,
    v_body_site_display,
    v_laterality,
    v_context
  )
  on conflict (form_response_id, code) where form_response_id is not null
  do update set
    status = excluded.status,
    category = excluded.category,
    code_display = excluded.code_display,
    code_system = excluded.code_system,
    encounter_id = excluded.encounter_id,
    performer_person_id = excluded.performer_person_id,
    value_type = excluded.value_type,
    value_quantity = excluded.value_quantity,
    value_unit = excluded.value_unit,
    value_string = excluded.value_string,
    value_boolean = excluded.value_boolean,
    value_integer = null,
    value_json = excluded.value_json,
    effective_datetime = excluded.effective_datetime,
    issued = excluded.issued,
    source_type = excluded.source_type,
    instrument_id = excluded.instrument_id,
    body_site_code = excluded.body_site_code,
    body_site_display = excluded.body_site_display,
    laterality = excluded.laterality,
    measurement_context = excluded.measurement_context,
    updated_by = excluded.created_by,
    updated_at = now();

  return true;
end;
$function$;
create or replace function private.project_assessment_response_to_observations(p_form_response_id uuid)
returns integer
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_response record;
  v_item jsonb;
  v_score_key text;
  v_value record;
  v_projected_count integer := 0;
  v_projected_paths text[] := array[]::text[];
  v_org_id uuid;
  v_org_count integer;
  v_single_org_id uuid;
  v_form_code text;
  v_total_value jsonb;
  v_fallback_key text;
  v_fallback_value jsonb;
  v_fallback_path text;
  v_inserted boolean;
begin
  select
    afr.id,
    afr.form_template_id,
    afr.responses,
    afr.subject_person_id,
    afr.performer_person_id,
    afr.encounter_id,
    afr.organization_id as response_organization_id,
    afr.assessment_date,
    afr.total_score,
    afr.source_type as response_source_type,
    enc.organization_id as encounter_organization_id,
    aft.id as template_id,
    aft.form_code,
    aft.form_name,
    aft.category,
    aft.body_region,
    aft.items,
    aft.icf_code,
    aft.snomed_code
  into v_response
  from public.assessment_form_responses afr
  left join public.encounters enc
    on enc.id = afr.encounter_id
  left join public.assessment_form_templates aft
    on aft.id::text = afr.form_template_id
    or aft.form_code = afr.form_template_id
  where afr.id = p_form_response_id
  order by
    case when aft.id::text = afr.form_template_id then 0 else 1 end,
    aft.id
  limit 1;

  if not found then
    return 0;
  end if;

  if v_response.subject_person_id is null then
    return 0;
  end if;

  v_org_id := coalesce(v_response.response_organization_id, v_response.encounter_organization_id);

  if v_org_id is null then
    select count(*), min(oc.organization_id::text)::uuid
    into v_org_count, v_single_org_id
    from public.org_clients oc
    where oc.person_id = v_response.subject_person_id
      and coalesce(oc.status, 'active') = 'active';

    if v_org_count = 1 then
      v_org_id := v_single_org_id;
    end if;
  end if;

  if v_org_id is null then
    return 0;
  end if;

  v_form_code := coalesce(nullif(v_response.form_code, ''), v_response.form_template_id, 'ASSESSMENT');

  if v_response.total_score is not null then
    v_total_value := to_jsonb(v_response.total_score);
  elsif jsonb_typeof(coalesce(v_response.responses, '{}'::jsonb)) = 'object'
        and coalesce(v_response.responses, '{}'::jsonb) ? 'total_score'
        and private.assessment_jsonb_numeric(v_response.responses -> 'total_score') is not null then
    v_total_value := v_response.responses -> 'total_score';
  end if;

  if v_total_value is not null
     and private.assessment_normalized_form_code(v_form_code) not like 'ROM\_%' escape '\' then
    v_inserted := private.upsert_assessment_observation(
      v_response.id,
      v_response.form_template_id,
      v_response.subject_person_id,
      v_response.performer_person_id,
      v_org_id,
      v_response.encounter_id,
      v_response.assessment_date,
      v_form_code,
      v_response.form_name,
      v_response.category,
      v_response.body_region,
      v_response.icf_code,
      v_response.snomed_code,
      'total_score',
      'total_score',
      'total_score',
      v_total_value,
      jsonb_build_object('unit', 'score', 'question_text', coalesce(v_response.form_name, v_form_code) || ' total score'),
      true
    );

    if v_inserted then
      v_projected_count := v_projected_count + 1;
      v_projected_paths := array_append(v_projected_paths, 'total_score');
    end if;
  end if;

  if jsonb_typeof(v_response.items) = 'array' then
    for v_item in
      select value
      from jsonb_array_elements(v_response.items)
    loop
      v_score_key := coalesce(
        nullif(v_item ->> 'score_key', ''),
        nullif(v_item ->> 'key', ''),
        nullif(v_item ->> 'id', '')
      );

      if v_score_key is null then
        continue;
      end if;

      for v_value in
        select *
        from private.assessment_response_candidate_value(v_response.responses, v_score_key, v_form_code)
      loop
        v_inserted := private.upsert_assessment_observation(
          v_response.id,
          v_response.form_template_id,
          v_response.subject_person_id,
          v_response.performer_person_id,
          v_org_id,
          v_response.encounter_id,
          v_response.assessment_date,
          v_form_code,
          v_response.form_name,
          v_response.category,
          v_response.body_region,
          v_response.icf_code,
          v_response.snomed_code,
          v_score_key,
          v_value.response_key,
          v_value.response_path,
          v_value.response_value,
          v_item,
          false
        );

        if v_inserted then
          v_projected_count := v_projected_count + 1;
          v_projected_paths := array_append(v_projected_paths, v_value.response_path);
        end if;
      end loop;
    end loop;
  end if;

  if jsonb_typeof(coalesce(v_response.responses, '{}'::jsonb)) = 'object' then
    for v_fallback_key, v_fallback_value in
      select key, value
      from jsonb_each(v_response.responses)
    loop
      v_fallback_path := v_fallback_key;
      if v_fallback_path = any(v_projected_paths)
         or (
           private.assessment_normalized_form_code(v_form_code) like 'ROM\_%' escape '\'
           and lower(v_fallback_key) = 'body_part'
         )
         or not private.assessment_projectable_fallback_key(v_fallback_key) then
        continue;
      end if;

      v_inserted := private.upsert_assessment_observation(
        v_response.id,
        v_response.form_template_id,
        v_response.subject_person_id,
        v_response.performer_person_id,
        v_org_id,
        v_response.encounter_id,
        v_response.assessment_date,
        v_form_code,
        v_response.form_name,
        coalesce(v_response.category, v_response.response_source_type),
        v_response.body_region,
        v_response.icf_code,
        v_response.snomed_code,
        v_fallback_key,
        v_fallback_key,
        v_fallback_path,
        v_fallback_value,
        jsonb_build_object('fallback', true, 'question_text', v_fallback_key),
        false
      );

      if v_inserted then
        v_projected_count := v_projected_count + 1;
        v_projected_paths := array_append(v_projected_paths, v_fallback_path);
      end if;
    end loop;

    if jsonb_typeof(v_response.responses -> 'responses') = 'object' then
      for v_fallback_key, v_fallback_value in
        select key, value
        from jsonb_each(v_response.responses -> 'responses')
      loop
        v_fallback_path := 'responses.' || v_fallback_key;
        if v_fallback_path = any(v_projected_paths)
           or (
             private.assessment_normalized_form_code(v_form_code) like 'ROM\_%' escape '\'
             and lower(v_fallback_key) = 'body_part'
           )
           or not private.assessment_projectable_fallback_key(v_fallback_key) then
          continue;
        end if;

        v_inserted := private.upsert_assessment_observation(
          v_response.id,
          v_response.form_template_id,
          v_response.subject_person_id,
          v_response.performer_person_id,
          v_org_id,
          v_response.encounter_id,
          v_response.assessment_date,
          v_form_code,
          v_response.form_name,
          coalesce(v_response.category, v_response.response_source_type),
          v_response.body_region,
          v_response.icf_code,
          v_response.snomed_code,
          v_fallback_key,
          v_fallback_key,
          v_fallback_path,
          v_fallback_value,
          jsonb_build_object('fallback', true, 'question_text', v_fallback_key),
          false
        );

        if v_inserted then
          v_projected_count := v_projected_count + 1;
          v_projected_paths := array_append(v_projected_paths, v_fallback_path);
        end if;
      end loop;
    end if;
  end if;

  return v_projected_count;
end;
$function$;
do $function$
declare
  v_projected integer;
begin
  select coalesce(sum(private.project_assessment_response_to_observations(id)), 0)
  into v_projected
  from public.assessment_form_responses;

  raise notice 'Reprojected % assessment observations after semantic link seeding', v_projected;
end;
$function$;
