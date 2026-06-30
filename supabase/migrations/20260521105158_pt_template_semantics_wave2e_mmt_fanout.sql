drop index if exists public.idx_observations_idempotent_key;
create unique index idx_observations_idempotent_key
  on public.observations using btree (form_response_id, code, laterality) nulls not distinct
  where (form_response_id is not null);
create or replace function private.project_assessment_item_observation_v2(
  p_form_response_id uuid,
  p_form_template_id text,
  p_form_code text,
  p_form_name text,
  p_template_category text,
  p_template_body_region text,
  p_template_icf_code text,
  p_template_snomed_code text,
  p_subject_person_id uuid,
  p_performer_person_id uuid,
  p_encounter_id uuid,
  p_organization_id uuid,
  p_assessment_date timestamptz,
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
  v_mmt_target_code text;
  v_mmt_target_display text;
  v_projection_code text;
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

  if v_form_code = 'MMT'
     and not p_is_aggregate
     and p_score_key in ('mmt_left', 'mmt_right') then
    select
      nullif(btrim(afr.responses ->> 'mmt_muscle'), ''),
      ot.code_display
    into
      v_mmt_target_code,
      v_mmt_target_display
    from public.assessment_form_responses afr
    left join public.observation_taxonomy ot
      on ot.code = afr.responses ->> 'mmt_muscle'
    where afr.id = p_form_response_id
      and afr.responses ->> 'mmt_muscle' like 'MMT\_%' escape '\'
    limit 1;

    if v_mmt_target_code is not null then
      v_projection_code := v_code;
      v_code := v_mmt_target_code;
      v_code_display := coalesce(v_mmt_target_display, v_code_display);
    end if;
  end if;

  if v_binding.default_value_type is not null
     and v_form_code = 'MMT'
     and p_score_key in ('mmt_left', 'mmt_right') then
    v_value_type := v_binding.default_value_type;
  elsif v_binding.default_value_type is not null
     and v_value_type is not null
     and v_binding.default_value_type = v_value_type then
    v_value_type := v_binding.default_value_type;
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
    if v_form_code = 'MMT' and p_score_key in ('mmt_left', 'mmt_right') then
      v_json := private.assessment_mmt_grade_json(p_response_value);
      if v_json is null then
        return false;
      end if;
    else
      v_json := p_response_value;
    end if;
  end if;

  v_unit := coalesce(nullif(v_binding.default_unit, ''), nullif(coalesce(p_item ->> 'unit', p_item ->> 'value_unit'), ''));
  if v_unit is null and p_is_aggregate then
    v_unit := 'score';
  elsif v_unit is null and v_code like 'ROM\_%' escape '\' then
    v_unit := 'deg';
  end if;

  v_region := lower(regexp_replace(coalesce(p_template_body_region, ''), '[^A-Za-z0-9_]+', '_', 'g'));
  if v_mmt_target_code is not null then
    v_region := split_part(lower(v_mmt_target_code), '_', 2);
  elsif v_region = '' and v_code like 'ROM\_%' escape '\' then
    v_region := split_part(v_code, '_', 2);
  end if;

  v_body_site := coalesce(nullif(v_binding.body_site_code, ''), nullif(left(v_region, 50), ''));
  v_body_site_display := coalesce(
    nullif(v_binding.body_site_display, ''),
    nullif(coalesce(p_template_body_region, initcap(replace(v_region, '_', ' '))), '')
  );
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
    'representation', case
      when v_form_code = 'MMT' and p_score_key in ('mmt_left', 'mmt_right') then 'mmt_grade_json'
      else null
    end,
    'mmt_target_code', v_mmt_target_code,
    'fanout', case
      when v_mmt_target_code is null then null
      else jsonb_build_object(
        'from_observation_code', coalesce(v_projection_code, v_binding.observation_code),
        'to_observation_code', v_mmt_target_code,
        'wave', 'pt_template_semantics_wave2e'
      )
    end,
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
  on conflict (form_response_id, code, laterality) where form_response_id is not null
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
update public.observations grade_obs
set
  code = target_obs.value_string,
  code_display = ot.code_display,
  body_site_code = lower(split_part(target_obs.value_string, '_', 2)),
  body_site_display = initcap(replace(lower(split_part(target_obs.value_string, '_', 2)), '_', ' ')),
  measurement_context = jsonb_strip_nulls(
    coalesce(grade_obs.measurement_context, '{}'::jsonb)
    || jsonb_build_object(
      'mmt_target_code', target_obs.value_string,
      'fanout', jsonb_build_object(
        'from_observation_code', 'MMT_generic',
        'to_observation_code', target_obs.value_string,
        'wave', 'pt_template_semantics_wave2e'
      )
    )
  ),
  updated_at = now()
from public.observations target_obs
left join public.observation_taxonomy ot
  on ot.code = target_obs.value_string
where grade_obs.form_response_id = target_obs.form_response_id
  and grade_obs.code = 'MMT_generic'
  and grade_obs.source_type = 'form'
  and target_obs.code = 'mmt_target_muscle'
  and target_obs.value_string like 'MMT\_%' escape '\';
