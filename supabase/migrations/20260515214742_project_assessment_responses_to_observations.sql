-- Project assessment form responses into atomic observations.
--
-- This closes the previous no-op parser path: assessment_form_responses already
-- had a trigger, but the live database did not have instrument_parser_mapping.
-- The new projector uses assessment_form_templates.items as the SSOT where
-- available, with a conservative fallback for intake/self-assessment keys.

create schema if not exists private;
alter table public.observations
  drop constraint if exists observations_source_type_check;
alter table public.observations
  add constraint observations_source_type_check
  check (source_type = any (array[
    'manual'::text,
    'device'::text,
    'patient_report'::text,
    'ai'::text,
    'import'::text,
    'form'::text
  ])) not valid;
alter table public.observations
  validate constraint observations_source_type_check;
alter table public.observations
  drop constraint if exists obs_has_context;
alter table public.observations
  add constraint obs_has_context
  check (
    encounter_id is not null
    or activity_session_id is not null
    or form_response_id is not null
  ) not valid;
alter table public.observations
  validate constraint obs_has_context;
create or replace function private.assessment_jsonb_numeric(p_value jsonb)
returns numeric
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v_text text;
begin
  if p_value is null or p_value = 'null'::jsonb then
    return null;
  end if;

  v_text := btrim(p_value #>> '{}');

  if v_text ~ '^-?[0-9]+([.][0-9]+)?$' then
    return v_text::numeric;
  end if;

  return null;
end;
$function$;
create or replace function private.assessment_normalized_form_code(p_form_code text)
returns text
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v_code text;
begin
  v_code := upper(regexp_replace(coalesce(nullif(p_form_code, ''), 'ASSESSMENT'), '[^A-Za-z0-9_]+', '_', 'g'));
  v_code := regexp_replace(v_code, '_+', '_', 'g');
  v_code := trim(both '_' from v_code);

  if v_code = '' then
    v_code := 'ASSESSMENT';
  end if;

  if v_code ~ '^[0-9]' then
    v_code := 'FORM_' || v_code;
  end if;

  return v_code;
end;
$function$;
create or replace function private.assessment_response_candidate_value(
  p_responses jsonb,
  p_score_key text,
  p_form_code text
)
returns table(response_value jsonb, response_path text, response_key text)
language plpgsql
stable
set search_path to ''
as $function$
declare
  v_responses jsonb := coalesce(p_responses, '{}'::jsonb);
  v_candidates text[] := array[]::text[];
  v_candidate text;
  v_suffix text;
begin
  if p_score_key is null or btrim(p_score_key) = '' then
    return;
  end if;

  v_candidates := array_append(v_candidates, p_score_key);

  if upper(coalesce(p_form_code, '')) like 'ROM\_%' escape '\' then
    v_suffix := regexp_replace(lower(p_score_key), '^[a-z]*rom_', '');
    if v_suffix <> lower(p_score_key) then
      v_candidates := array_append(v_candidates, v_suffix);
    end if;
  end if;

  foreach v_candidate in array v_candidates loop
    if v_candidate is null or btrim(v_candidate) = '' then
      continue;
    end if;

    if jsonb_typeof(v_responses) = 'object' and v_responses ? v_candidate then
      response_value := v_responses -> v_candidate;
      response_path := v_candidate;
      response_key := v_candidate;
      return next;
      return;
    end if;

    if jsonb_typeof(v_responses -> 'responses') = 'object'
       and (v_responses -> 'responses') ? v_candidate then
      response_value := v_responses -> 'responses' -> v_candidate;
      response_path := 'responses.' || v_candidate;
      response_key := v_candidate;
      return next;
      return;
    end if;
  end loop;
end;
$function$;
create or replace function private.assessment_projection_laterality(
  p_score_key text,
  p_response_key text
)
returns text
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v_key text := lower(coalesce(nullif(p_response_key, ''), p_score_key, ''));
begin
  if v_key ~ '(^|_)(left|l)$' then
    return 'left';
  end if;

  if v_key ~ '(^|_)(right|r)$' then
    return 'right';
  end if;

  return null;
end;
$function$;
create or replace function private.assessment_projection_code(
  p_form_code text,
  p_score_key text,
  p_response_key text
)
returns text
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v_form_code text := private.assessment_normalized_form_code(p_form_code);
  v_key text := lower(coalesce(nullif(p_response_key, ''), p_score_key, 'value'));
  v_region text;
  v_movement text;
  v_code text;
begin
  if v_key in ('vas_score', 'vas') then
    return 'VAS';
  end if;

  if v_key in ('nprs_score', 'nprs') then
    return 'NPRS';
  end if;

  if v_form_code in ('VAS', 'NPRS')
     and v_key in ('score', 'total_score', lower(v_form_code) || '_score') then
    return v_form_code;
  end if;

  if v_form_code like 'ROM\_%' escape '\' then
    v_region := lower(regexp_replace(v_form_code, '^ROM_', ''));
    v_movement := lower(coalesce(nullif(p_response_key, ''), p_score_key, 'value'));
    v_movement := regexp_replace(v_movement, '^[a-z]*rom_', '');
    v_movement := replace(v_movement, 'lat_flex', 'lateral_flexion');
    v_movement := replace(v_movement, 'int_rot', 'internal_rotation');
    v_movement := replace(v_movement, 'ext_rot', 'external_rotation');

    if v_movement = 'ir' then
      v_movement := 'internal_rotation';
    elsif v_movement = 'er' then
      v_movement := 'external_rotation';
    elsif v_movement = 'df' then
      v_movement := 'dorsiflexion';
    elsif v_movement = 'pf' then
      v_movement := 'plantarflexion';
    end if;

    if v_movement ~ '_l$' then
      v_movement := regexp_replace(v_movement, '_l$', '_left');
    elsif v_movement ~ '_r$' then
      v_movement := regexp_replace(v_movement, '_r$', '_right');
    end if;

    v_movement := regexp_replace(v_movement, '[^a-z0-9_]+', '_', 'g');
    v_movement := regexp_replace(v_movement, '_+', '_', 'g');
    v_movement := trim(both '_' from v_movement);

    return 'ROM_' || v_region || '_' || coalesce(nullif(v_movement, ''), 'value');
  end if;

  v_code := v_form_code || '_' || regexp_replace(coalesce(nullif(p_response_key, ''), p_score_key, 'value'), '[^A-Za-z0-9_]+', '_', 'g');
  v_code := regexp_replace(v_code, '_+', '_', 'g');
  return trim(both '_' from v_code);
end;
$function$;
create or replace function private.assessment_projection_categories(
  p_template_category text,
  p_form_code text
)
returns text[]
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v_category text := lower(coalesce(nullif(p_template_category, ''), 'assessment'));
  v_form_code text := private.assessment_normalized_form_code(p_form_code);
begin
  if v_form_code like 'ROM\_%' escape '\' or v_category = 'rom' then
    return array['exam', 'physical-exam', 'rom']::text[];
  end if;

  if v_category in ('mmt', 'strength') then
    return array['exam', 'physical-exam', 'strength']::text[];
  end if;

  if v_category in ('special_test', 'special-test') then
    return array['exam', 'physical-exam', 'special-test']::text[];
  end if;

  if v_category in ('function', 'functional', 'disability', 'balance', 'disease_activity', 'adl', 'mobility') then
    return array['survey', 'functional-exam', v_category]::text[];
  end if;

  if v_category = 'pain' or v_form_code in ('VAS', 'NPRS') then
    return array['survey', 'pain']::text[];
  end if;

  if v_form_code like '%INTAKE%' then
    return array['survey', 'intake']::text[];
  end if;

  if v_form_code like '%SELF_ASSESSMENT%' then
    return array['survey', 'self-assessment']::text[];
  end if;

  return array_remove(array['survey', nullif(v_category, 'assessment')], null);
end;
$function$;
create or replace function private.assessment_projection_value_type(
  p_value jsonb,
  p_item jsonb,
  p_score_key text
)
returns text
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v_json_type text := jsonb_typeof(p_value);
  v_text text;
  v_answer_type text := lower(coalesce(p_item ->> 'type', p_item ->> 'answer_type', p_item ->> 'input_type', ''));
  v_key text := lower(coalesce(p_score_key, ''));
begin
  if p_value is null or p_value = 'null'::jsonb then
    return null;
  end if;

  if v_json_type = 'number' then
    return 'quantity';
  end if;

  if v_json_type = 'boolean' then
    return 'boolean';
  end if;

  if v_json_type in ('array', 'object') then
    if p_value in ('[]'::jsonb, '{}'::jsonb) then
      return null;
    end if;
    return 'json';
  end if;

  if v_json_type = 'string' then
    v_text := btrim(p_value #>> '{}');
    if v_text = '' then
      return null;
    end if;

    if v_text ~ '^-?[0-9]+([.][0-9]+)?$'
       and (
         v_answer_type in ('number', 'numeric', 'integer', 'slider', 'scale', 'score')
         or v_key ~ '(score|vas|nprs|flexion|extension|abduction|rotation|dorsiflexion|plantarflexion|basdai|koos|lefs|odi|ndi|dash|spadi|bbs|tug)'
       ) then
      return 'quantity';
    end if;

    return 'string';
  end if;

  return 'json';
end;
$function$;
create or replace function private.assessment_projectable_fallback_key(p_key text)
returns boolean
language plpgsql
immutable
set search_path to ''
as $function$
declare
  v_key text := lower(coalesce(p_key, ''));
begin
  if v_key in (
    'completed_items',
    'submitted_from',
    'algorithm_path',
    'notes',
    'additional_notes'
  ) then
    return false;
  end if;

  return v_key ~ '(pain|vas|nprs|score|red_flag|body_part|history|chief_complaint|functional|goal|duration|onset|aggravating|relieving|allerg|medication|medical|surgical|family|social|clinical_result|movement_profile|sport|flexion|extension|abduction|rotation|dorsiflexion|plantarflexion|basdai|koos|lefs|odi|ndi|dash|spadi|bbs|tug|psfs|mmt|rom)';
end;
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
  v_value_type text;
  v_quantity numeric;
  v_string text;
  v_boolean boolean;
  v_json jsonb;
  v_unit text;
  v_body_site text;
  v_region text;
  v_laterality text;
  v_created_by uuid := coalesce(p_performer_person_id, p_subject_person_id);
  v_context jsonb;
begin
  if p_form_response_id is null
     or p_subject_person_id is null
     or p_organization_id is null
     or v_created_by is null then
    return false;
  end if;

  v_value_type := private.assessment_projection_value_type(p_response_value, coalesce(p_item, '{}'::jsonb), p_score_key);

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

  v_unit := nullif(coalesce(p_item ->> 'unit', p_item ->> 'value_unit'), '');
  if v_unit is null and p_is_aggregate then
    v_unit := 'score';
  elsif v_unit is null and v_code like 'ROM\_%' escape '\' then
    v_unit := 'deg';
  end if;

  v_region := lower(regexp_replace(coalesce(p_template_body_region, ''), '[^A-Za-z0-9_]+', '_', 'g'));
  if v_region = '' and v_code like 'ROM\_%' escape '\' then
    v_region := split_part(v_code, '_', 2);
  end if;

  v_body_site := nullif(left(v_region, 50), '');
  v_laterality := private.assessment_projection_laterality(p_score_key, p_response_key);

  v_context := jsonb_strip_nulls(jsonb_build_object(
    'projector', 'assessment_form_response_to_observation_v1',
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
    'item', nullif(coalesce(p_item, '{}'::jsonb), '{}'::jsonb)
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
    private.assessment_projection_categories(p_template_category, v_form_code),
    v_code,
    v_code_display,
    'http://physiokorea.com/fhir/observation',
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
    nullif(coalesce(p_template_body_region, v_region), ''),
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

  if v_total_value is not null then
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
create or replace function private.trg_project_assessment_response_observations()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  perform private.project_assessment_response_to_observations(new.id);
  return new;
end;
$function$;
drop trigger if exists after_assessment_form_response_insert on public.assessment_form_responses;
drop trigger if exists trg_project_assessment_response_observations_insert on public.assessment_form_responses;
drop trigger if exists trg_project_assessment_response_observations_update on public.assessment_form_responses;
drop function if exists public.trigger_parse_assessment_to_observations();
create trigger trg_project_assessment_response_observations_insert
  after insert on public.assessment_form_responses
  for each row
  execute function private.trg_project_assessment_response_observations();
create trigger trg_project_assessment_response_observations_update
  after update of responses, total_score, assessment_date, organization_id, encounter_id, performer_person_id on public.assessment_form_responses
  for each row
  when (
    old.responses is distinct from new.responses
    or old.total_score is distinct from new.total_score
    or old.assessment_date is distinct from new.assessment_date
    or old.organization_id is distinct from new.organization_id
    or old.encounter_id is distinct from new.encounter_id
    or old.performer_person_id is distinct from new.performer_person_id
  )
  execute function private.trg_project_assessment_response_observations();
create or replace view public.v_soap_objective
with (security_invoker='on')
as
select
  encounter_id,
  subject_person_id,
  organization_id,
  max(
    case
      when code like 'VAS%' then value_quantity
      else null::numeric
    end
  ) as vas_score,
  json_agg(
    case
      when code like 'ROM_%' then json_build_object('code', code, 'value', value_quantity, 'unit', value_unit, 'laterality', laterality)
      else null::json
    end
  ) filter (where code like 'ROM_%') as rom_measurements,
  json_agg(
    case
      when code like 'MMT%' then json_build_object('code', code, 'value', value_quantity)
      else null::json
    end
  ) filter (where code like 'MMT%') as mmt_measurements,
  json_agg(
    case
      when source_type in ('form', 'assessment') and value_type in ('quantity', 'integer') then
        json_build_object('code', code, 'code_display', code_display, 'value', coalesce(value_quantity, value_integer::numeric), 'interpretation', interpretation)
      else null::json
    end
  ) filter (where source_type in ('form', 'assessment') and value_type in ('quantity', 'integer')) as functional_scores,
  max(
    case
      when code in ('BBS', 'BBS-score') then value_quantity
      else null::numeric
    end
  ) as bbs_score,
  max(
    case
      when code in ('TUG', 'TUG-time') then value_quantity
      else null::numeric
    end
  ) as tug_time,
  (
    select count(*)::bigint
    from public.observations st
    where st.encounter_id = o.encounter_id
      and (
        st.category @> array['special-test']::text[]
        or st.code like 'SLR_%'
        or st.code like 'SLUMP_%'
        or st.code in ('SLR', 'SLUMP')
      )
  ) as special_test_count,
  min(effective_datetime) as first_measurement,
  max(effective_datetime) as last_measurement,
  count(*) as total_observations
from public.observations o
where encounter_id is not null
group by encounter_id, subject_person_id, organization_id;
do $function$
declare
  v_projected integer;
begin
  select coalesce(sum(private.project_assessment_response_to_observations(id)), 0)
  into v_projected
  from public.assessment_form_responses;

  raise notice 'Projected % assessment observations from existing form responses', v_projected;
end;
$function$;
comment on function private.project_assessment_response_to_observations(uuid)
  is 'Projects one assessment_form_responses row into atomic observations using assessment_form_templates.items plus conservative intake/self-assessment fallback keys.';
comment on function private.trg_project_assessment_response_observations()
  is 'Trigger wrapper for assessment_form_responses -> observations projection.';
