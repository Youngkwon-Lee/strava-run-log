create or replace function public.project_assessment_context_lifecycle_events(
  p_assessment_response_id uuid
)
returns integer
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_response record;
  v_source_type text;
  v_event_type text;
  v_performed_by text;
  v_prefix text;
  v_projected_count integer := 0;
  v_profile_label text;
  v_profile_description text;
begin
  select
    afr.id,
    afr.form_template_id,
    afr.responses,
    afr.subject_person_id,
    afr.performer_person_id,
    afr.encounter_id,
    afr.organization_id,
    afr.assessment_date,
    afr.created_at,
    afr.source_type,
    afr.notes,
    enc.episode_id,
    coalesce(aft.form_code, afr.form_template_id) as form_code
  into v_response
  from public.assessment_form_responses afr
  left join public.encounters enc
    on enc.id = afr.encounter_id
  left join public.assessment_form_templates aft
    on aft.id::text = afr.form_template_id
    or aft.form_code = afr.form_template_id
  where afr.id = p_assessment_response_id
  order by
    case when aft.id::text = afr.form_template_id then 0 else 1 end,
    aft.id
  limit 1;

  if not found or v_response.subject_person_id is null then
    return 0;
  end if;

  v_source_type := coalesce(v_response.source_type::text, 'clinical');

  if v_source_type in ('patient_self', 'patient_self_report') then
    v_event_type := 'self_assessment';
    v_performed_by := 'patient';
    v_prefix := '자가평가';
  elsif v_source_type = 'intake_form' then
    v_event_type := 'intake_assessment';
    v_performed_by := 'patient';
    v_prefix := '인테이크';
  else
    v_event_type := 'clinical_assessment';
    v_performed_by := 'provider';
    v_prefix := '평가';
  end if;

  if v_response.responses ? 'history'
     and jsonb_typeof(v_response.responses -> 'history') in ('object', 'array')
     and (v_response.responses -> 'history') not in ('{}'::jsonb, '[]'::jsonb) then
    perform public.upsert_person_lifecycle_event(
      v_response.subject_person_id,
      v_response.organization_id,
      v_response.episode_id,
      'assessment',
      v_event_type,
      'assessment.context.history',
      coalesce(v_response.assessment_date, v_response.created_at),
      v_performed_by,
      v_response.performer_person_id,
      'assessment_form_responses',
      v_response.id::text,
      v_prefix || ' 병력',
      null,
      jsonb_strip_nulls(jsonb_build_object(
        'form_template_id', v_response.form_template_id,
        'form_code', v_response.form_code,
        'source_type', v_source_type,
        'encounter_id', v_response.encounter_id,
        'body_part', v_response.responses ->> 'body_part',
        'history', v_response.responses -> 'history'
      ))
    );
    v_projected_count := v_projected_count + 1;
  end if;

  if v_response.responses ? 'red_flags'
     and jsonb_typeof(v_response.responses -> 'red_flags') in ('object', 'array')
     and (v_response.responses -> 'red_flags') not in ('{}'::jsonb, '[]'::jsonb) then
    perform public.upsert_person_lifecycle_event(
      v_response.subject_person_id,
      v_response.organization_id,
      v_response.episode_id,
      'assessment',
      v_event_type,
      'assessment.context.red_flags',
      coalesce(v_response.assessment_date, v_response.created_at),
      v_performed_by,
      v_response.performer_person_id,
      'assessment_form_responses',
      v_response.id::text,
      v_prefix || ' 레드 플래그',
      null,
      jsonb_strip_nulls(jsonb_build_object(
        'form_template_id', v_response.form_template_id,
        'form_code', v_response.form_code,
        'source_type', v_source_type,
        'encounter_id', v_response.encounter_id,
        'body_part', v_response.responses ->> 'body_part',
        'red_flags', v_response.responses -> 'red_flags'
      ))
    );
    v_projected_count := v_projected_count + 1;
  end if;

  if v_response.responses ? 'clinical_result'
     and jsonb_typeof(v_response.responses -> 'clinical_result') = 'object'
     and (v_response.responses -> 'clinical_result') <> '{}'::jsonb then
    perform public.upsert_person_lifecycle_event(
      v_response.subject_person_id,
      v_response.organization_id,
      v_response.episode_id,
      'assessment',
      v_event_type,
      'assessment.context.result',
      coalesce(v_response.assessment_date, v_response.created_at),
      v_performed_by,
      v_response.performer_person_id,
      'assessment_form_responses',
      v_response.id::text,
      v_prefix || ' 분류 결과',
      nullif(v_response.responses #>> '{clinical_result,classification}', ''),
      jsonb_strip_nulls(jsonb_build_object(
        'form_template_id', v_response.form_template_id,
        'form_code', v_response.form_code,
        'source_type', v_source_type,
        'encounter_id', v_response.encounter_id,
        'body_part', v_response.responses ->> 'body_part',
        'classification', v_response.responses #>> '{clinical_result,classification}',
        'confidence', v_response.responses #>> '{clinical_result,confidence}',
        'alert', v_response.responses #>> '{clinical_result,alert}',
        'clinical_result', v_response.responses -> 'clinical_result'
      ))
    );
    v_projected_count := v_projected_count + 1;
  end if;

  if v_response.responses ? 'algorithm_path'
     and jsonb_typeof(v_response.responses -> 'algorithm_path') = 'array'
     and (v_response.responses -> 'algorithm_path') <> '[]'::jsonb then
    perform public.upsert_person_lifecycle_event(
      v_response.subject_person_id,
      v_response.organization_id,
      v_response.episode_id,
      'assessment',
      v_event_type,
      'assessment.context.algorithm_path',
      coalesce(v_response.assessment_date, v_response.created_at),
      v_performed_by,
      v_response.performer_person_id,
      'assessment_form_responses',
      v_response.id::text,
      v_prefix || ' 분류 경로',
      concat('decision steps: ', jsonb_array_length(v_response.responses -> 'algorithm_path')),
      jsonb_strip_nulls(jsonb_build_object(
        'form_template_id', v_response.form_template_id,
        'form_code', v_response.form_code,
        'source_type', v_source_type,
        'encounter_id', v_response.encounter_id,
        'body_part', v_response.responses ->> 'body_part',
        'step_count', jsonb_array_length(v_response.responses -> 'algorithm_path'),
        'algorithm_path', v_response.responses -> 'algorithm_path'
      ))
    );
    v_projected_count := v_projected_count + 1;
  end if;

  if coalesce(nullif(v_response.responses ->> 'sport_name_label', ''), nullif(v_response.responses ->> 'sport_name', '')) is not null
     or nullif(v_response.responses ->> 'movement_profile', '') is not null
     or nullif(v_response.responses ->> 'movement_profile_label', '') is not null
     or nullif(v_response.responses ->> 'season_phase_label', '') is not null
     or nullif(v_response.responses ->> 'primary_goal_label', '') is not null
     or nullif(v_response.responses ->> 'limiting_factor_label', '') is not null then
    v_profile_label := coalesce(
      nullif(v_response.responses ->> 'sport_name_label', ''),
      nullif(v_response.responses ->> 'sport_name', ''),
      '스포츠'
    );
    v_profile_description := concat_ws(
      ' · ',
      coalesce(nullif(v_response.responses ->> 'movement_profile_label', ''), nullif(v_response.responses ->> 'movement_profile', '')),
      nullif(v_response.responses ->> 'season_phase_label', ''),
      nullif(v_response.responses ->> 'primary_goal_label', '')
    );

    perform public.upsert_person_lifecycle_event(
      v_response.subject_person_id,
      v_response.organization_id,
      v_response.episode_id,
      'assessment',
      v_event_type,
      'assessment.context.sports_profile',
      coalesce(v_response.assessment_date, v_response.created_at),
      v_performed_by,
      v_response.performer_person_id,
      'assessment_form_responses',
      v_response.id::text,
      v_profile_label || ' 프로필',
      nullif(v_profile_description, ''),
      jsonb_strip_nulls(jsonb_build_object(
        'form_template_id', v_response.form_template_id,
        'form_code', v_response.form_code,
        'source_type', v_source_type,
        'encounter_id', v_response.encounter_id,
        'sport_name', coalesce(v_response.responses ->> 'sport_name_label', v_response.responses ->> 'sport_name'),
        'movement_profile', v_response.responses ->> 'movement_profile',
        'movement_profile_label', v_response.responses ->> 'movement_profile_label',
        'season_phase', coalesce(v_response.responses ->> 'season_phase_label', v_response.responses ->> 'season_phase'),
        'primary_goal', coalesce(v_response.responses ->> 'primary_goal_label', v_response.responses ->> 'primary_goal'),
        'limiting_factor', coalesce(v_response.responses ->> 'limiting_factor_label', v_response.responses ->> 'limiting_factor'),
        'sport_demand_summary', v_response.responses ->> 'sport_demand_summary',
        'sport_taxonomy_summary', v_response.responses ->> 'sport_taxonomy_summary',
        'movement_demand_labels', v_response.responses -> 'movement_demand_labels',
        'effective_movement_demand_labels', v_response.responses -> 'effective_movement_demand_labels'
      ))
    );
    v_projected_count := v_projected_count + 1;
  end if;

  if v_response.responses ? 'sport_follow_up_summary'
     and jsonb_typeof(v_response.responses -> 'sport_follow_up_summary') = 'array'
     and (v_response.responses -> 'sport_follow_up_summary') <> '[]'::jsonb then
    perform public.upsert_person_lifecycle_event(
      v_response.subject_person_id,
      v_response.organization_id,
      v_response.episode_id,
      'assessment',
      v_event_type,
      'assessment.context.sports_follow_up',
      coalesce(v_response.assessment_date, v_response.created_at),
      v_performed_by,
      v_response.performer_person_id,
      'assessment_form_responses',
      v_response.id::text,
      '스포츠 follow-up',
      nullif(v_response.responses -> 'sport_follow_up_summary' ->> 0, ''),
      jsonb_strip_nulls(jsonb_build_object(
        'form_template_id', v_response.form_template_id,
        'form_code', v_response.form_code,
        'source_type', v_source_type,
        'encounter_id', v_response.encounter_id,
        'sport_name', coalesce(v_response.responses ->> 'sport_name_label', v_response.responses ->> 'sport_name'),
        'movement_profile', coalesce(v_response.responses ->> 'movement_profile_label', v_response.responses ->> 'movement_profile'),
        'sport_follow_up_summary', v_response.responses -> 'sport_follow_up_summary'
      ))
    );
    v_projected_count := v_projected_count + 1;
  end if;

  return v_projected_count;
end;
$$;
revoke execute on function public.project_assessment_context_lifecycle_events(uuid) from public, anon;
grant execute on function public.project_assessment_context_lifecycle_events(uuid) to authenticated, service_role;
create or replace function public.trg_project_lifecycle_assessment_context()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
begin
  perform public.project_assessment_context_lifecycle_events(NEW.id);
  return NEW;
end;
$$;
revoke execute on function public.trg_project_lifecycle_assessment_context() from public, anon;
grant execute on function public.trg_project_lifecycle_assessment_context() to authenticated, service_role;
drop trigger if exists trg_lifecycle_project_assessment_context_insert on public.assessment_form_responses;
create trigger trg_lifecycle_project_assessment_context_insert
  after insert on public.assessment_form_responses
  for each row
  execute function public.trg_project_lifecycle_assessment_context();
select coalesce(sum(public.project_assessment_context_lifecycle_events(afr.id)), 0) as backfilled_assessment_context_events
from public.assessment_form_responses afr
where afr.responses ?| array[
  'history',
  'red_flags',
  'clinical_result',
  'algorithm_path',
  'sport_follow_up_summary',
  'movement_profile',
  'sport_name_label',
  'sport_name',
  'season_phase_label',
  'primary_goal_label',
  'limiting_factor_label'
];
