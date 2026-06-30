create or replace function public.trigger_parse_assessment_to_observations()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_parser_record record;
  v_parser_function text;
  v_parser_func_regprocedure regprocedure;
  v_output_observations jsonb;
  v_observation_item jsonb;
  v_subject_id uuid;
  v_performer_id uuid;
  v_org_id uuid;
begin
  if to_regclass('public.instrument_parser_mapping') is null then
    raise notice 'instrument_parser_mapping table missing. Skipping observation generation for form %', new.form_template_id;
    return new;
  end if;

  select parser_function_name, output_observations into v_parser_record
  from instrument_parser_mapping
  where form_template_id = new.form_template_id and enabled = true
  limit 1;

  if v_parser_record is null then
    raise notice 'No parser found for form: %', new.form_template_id;
    return new;
  end if;

  v_parser_function := v_parser_record.parser_function_name;

  v_parser_func_regprocedure := to_regprocedure(v_parser_function || '(jsonb)');
  if v_parser_func_regprocedure is null then
    raise warning 'Parser function does not exist: %. Skipping observation generation.', v_parser_function;
    return new;
  end if;

  v_subject_id := new.subject_person_id;
  v_performer_id := new.performer_person_id;
  v_org_id := coalesce(
    new.organization_id,
    (select organization_id from encounters where id = new.encounter_id limit 1)
  );

  begin
    execute 'select ' || v_parser_function || '($1)' into v_output_observations using new.responses;
  exception when others then
    raise warning 'Parser execution failed for %: %', v_parser_function, sqlerrm;
    return new;
  end;

  for v_observation_item in select jsonb_array_elements(v_output_observations) loop
    if v_observation_item is null then
      continue;
    end if;

    case v_observation_item->>'value_type'
      when 'quantity' then
        insert into observations (
          fhir_id, category, code, code_display, value_type, value_quantity, value_unit,
          effective_datetime, encounter_id, subject_person_id, performer_person_id,
          source_type, created_by, organization_id, status, form_response_id
        ) values (
          gen_random_uuid(), array['survey'], v_observation_item->>'code', v_observation_item->>'code',
          'quantity', (v_observation_item->>'value_quantity')::numeric, v_observation_item->>'value_unit',
          now(), new.encounter_id, v_subject_id, v_performer_id,
          'manual', v_performer_id, v_org_id, 'final', new.id
        )
        on conflict (form_response_id, code) where form_response_id is not null do nothing;

      when 'string' then
        insert into observations (
          fhir_id, category, code, code_display, value_type, value_string,
          effective_datetime, encounter_id, subject_person_id, performer_person_id,
          source_type, created_by, organization_id, status, form_response_id
        ) values (
          gen_random_uuid(), array['survey'], v_observation_item->>'code', v_observation_item->>'code',
          'string', v_observation_item->>'value_string',
          now(), new.encounter_id, v_subject_id, v_performer_id,
          'manual', v_performer_id, v_org_id, 'final', new.id
        )
        on conflict (form_response_id, code) where form_response_id is not null do nothing;

      when 'boolean' then
        insert into observations (
          fhir_id, category, code, code_display, value_type, value_boolean,
          effective_datetime, encounter_id, subject_person_id, performer_person_id,
          source_type, created_by, organization_id, status, form_response_id
        ) values (
          gen_random_uuid(), array['survey'], v_observation_item->>'code', v_observation_item->>'code',
          'boolean', (v_observation_item->>'value_boolean')::boolean,
          now(), new.encounter_id, v_subject_id, v_performer_id,
          'manual', v_performer_id, v_org_id, 'final', new.id
        )
        on conflict (form_response_id, code) where form_response_id is not null do nothing;

      when 'integer' then
        insert into observations (
          fhir_id, category, code, code_display, value_type, value_integer,
          effective_datetime, encounter_id, subject_person_id, performer_person_id,
          source_type, created_by, organization_id, status, form_response_id
        ) values (
          gen_random_uuid(), array['survey'], v_observation_item->>'code', v_observation_item->>'code',
          'integer', (v_observation_item->>'value_integer')::integer,
          now(), new.encounter_id, v_subject_id, v_performer_id,
          'manual', v_performer_id, v_org_id, 'final', new.id
        )
        on conflict (form_response_id, code) where form_response_id is not null do nothing;

      when 'json' then
        insert into observations (
          fhir_id, category, code, code_display, value_type, value_json,
          effective_datetime, encounter_id, subject_person_id, performer_person_id,
          source_type, created_by, organization_id, status, form_response_id
        ) values (
          gen_random_uuid(), array['survey'], v_observation_item->>'code', v_observation_item->>'code',
          'json', v_observation_item->'value_json',
          now(), new.encounter_id, v_subject_id, v_performer_id,
          'manual', v_performer_id, v_org_id, 'final', new.id
        )
        on conflict (form_response_id, code) where form_response_id is not null do nothing;

      else
        raise warning 'Unknown value_type: %', v_observation_item->>'value_type';
    end case;
  end loop;

  return new;
end;
$function$;
