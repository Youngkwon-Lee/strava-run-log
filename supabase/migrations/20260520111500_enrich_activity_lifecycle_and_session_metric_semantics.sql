create or replace function public.trg_project_lifecycle_from_activity_session()
returns trigger
language plpgsql
security invoker
set search_path to ''
as $$
declare
  v_event_type text;
  v_event_kind text;
  v_event_family text;
  v_performed_by text;
  v_label text;
  v_description text;
  v_metrics jsonb := coalesce(NEW.metrics, '{}'::jsonb);
  v_timeseries_ref jsonb := coalesce(NEW.timeseries_ref, '{}'::jsonb);
  v_exercise_log jsonb := coalesce(NEW.exercise_log, '[]'::jsonb);
  v_sport_name text;
  v_competition_name text;
  v_competition_result text;
  v_training_focus text;
  v_exercise_log_count integer;
begin
  v_event_type := case NEW.activity_type
    when 'clinic_exercise' then 'clinic_exercise'
    when 'gym_training' then 'gym_session'
    when 'competition' then 'competition'
    when 'group_class' then 'group_class'
    when 'daily_walk' then 'daily_walk'
    when 'telehealth' then 'telehealth'
    when 'assessment' then 'activity_assessment'
    when 'other' then 'other_activity'
    else 'home_exercise'
  end;

  v_event_kind := case NEW.activity_type
    when 'clinic_exercise' then 'activity.clinic_exercise'
    when 'gym_training' then 'activity.gym_session'
    when 'competition' then 'activity.competition'
    when 'group_class' then 'activity.group_class'
    when 'daily_walk' then 'activity.daily_walk'
    when 'telehealth' then 'activity.telehealth'
    when 'assessment' then 'activity.assessment'
    when 'other' then 'activity.other'
    else 'activity.home_exercise'
  end;

  v_event_family := case NEW.activity_type
    when 'daily_walk' then 'wellness'
    when 'other' then 'wellness'
    when 'assessment' then 'assessment'
    when 'telehealth' then 'clinical'
    else 'training'
  end;

  v_performed_by := case
    when NEW.source in ('apple_health', 'samsung_health', 'garmin', 'imu', 'camera') then 'device'
    else 'patient'
  end;

  v_sport_name := coalesce(
    nullif(v_metrics ->> 'sport_name', ''),
    nullif(v_metrics ->> 'sport', ''),
    nullif(v_timeseries_ref ->> 'sport_name', ''),
    nullif(v_timeseries_ref ->> 'sport', '')
  );
  v_competition_name := coalesce(
    nullif(v_metrics ->> 'competition_name', ''),
    nullif(v_timeseries_ref ->> 'competition_name', ''),
    nullif(v_metrics ->> 'event_name', ''),
    nullif(v_timeseries_ref ->> 'event_name', '')
  );
  v_competition_result := coalesce(
    nullif(v_metrics ->> 'competition_result', ''),
    nullif(v_timeseries_ref ->> 'competition_result', ''),
    nullif(v_metrics ->> 'result', ''),
    nullif(v_timeseries_ref ->> 'result', '')
  );
  v_training_focus := coalesce(
    nullif(v_metrics ->> 'training_focus', ''),
    nullif(v_timeseries_ref ->> 'training_focus', ''),
    nullif(v_metrics ->> 'movement_profile', ''),
    nullif(v_timeseries_ref ->> 'movement_profile', '')
  );
  v_description := coalesce(nullif(NEW.notes, ''), nullif(NEW.difficulty_note, ''));
  v_exercise_log_count := case
    when jsonb_typeof(v_exercise_log) = 'array' then jsonb_array_length(v_exercise_log)
    else null
  end;

  v_label := case NEW.activity_type
    when 'competition' then coalesce(v_competition_name, case when v_sport_name is not null then v_sport_name || ' 대회' else null end, '대회')
    when 'gym_training' then coalesce(case when v_sport_name is not null then v_sport_name || ' 훈련' else null end, '헬스장')
    when 'home_exercise' then case when v_exercise_log_count is not null and v_exercise_log_count > 0 then '홈운동 ' || v_exercise_log_count || '개' else '홈운동' end
    when 'clinic_exercise' then '클리닉 운동'
    when 'group_class' then '그룹 수업'
    when 'daily_walk' then '걷기'
    when 'telehealth' then '원격 활동'
    when 'assessment' then '활동 평가'
    else '활동'
  end;

  perform public.upsert_person_lifecycle_event(
    NEW.subject_person_id,
    NEW.organization_id,
    NEW.episode_id,
    v_event_family,
    v_event_type,
    v_event_kind,
    NEW.performed_at,
    v_performed_by,
    NEW.created_by,
    'activity_sessions',
    NEW.id::text,
    v_label,
    v_description,
    jsonb_strip_nulls(jsonb_build_object(
      'activity_type', NEW.activity_type,
      'source', NEW.source,
      'status', NEW.status,
      'duration_seconds', NEW.duration_seconds,
      'encounter_id', NEW.encounter_id,
      'care_plan_id', NEW.care_plan_id,
      'has_timeseries', NEW.has_timeseries,
      'metrics', v_metrics,
      'exercise_log', v_exercise_log,
      'exercise_log_count', v_exercise_log_count,
      'difficulty_note', NEW.difficulty_note,
      'timeseries_ref', v_timeseries_ref,
      'sport_name', v_sport_name,
      'competition_name', v_competition_name,
      'competition_result', v_competition_result,
      'training_focus', v_training_focus,
      'distance_m', coalesce(nullif(v_metrics ->> 'distance_m', ''), nullif(v_timeseries_ref ->> 'distance_m', '')),
      'steps', coalesce(nullif(v_metrics ->> 'steps', ''), nullif(v_timeseries_ref ->> 'steps', '')),
      'calories_kcal', coalesce(
        nullif(v_metrics ->> 'calories_kcal', ''),
        nullif(v_metrics ->> 'calories', ''),
        nullif(v_timeseries_ref ->> 'calories_kcal', ''),
        nullif(v_timeseries_ref ->> 'calories', '')
      ),
      'rpe', coalesce(nullif(v_metrics ->> 'rpe', ''), nullif(v_timeseries_ref ->> 'rpe', '')),
      'pain_pre', coalesce(nullif(v_metrics ->> 'pain_pre', ''), nullif(v_timeseries_ref ->> 'pain_pre', '')),
      'pain_post', coalesce(nullif(v_metrics ->> 'pain_post', ''), nullif(v_timeseries_ref ->> 'pain_post', '')),
      'heart_rate_avg', coalesce(nullif(v_metrics ->> 'heart_rate_avg', ''), nullif(v_timeseries_ref ->> 'heart_rate_avg', '')),
      'heart_rate_max', coalesce(nullif(v_metrics ->> 'heart_rate_max', ''), nullif(v_timeseries_ref ->> 'heart_rate_max', '')),
      'completion_rate', coalesce(nullif(v_metrics ->> 'completion_rate', ''), nullif(v_timeseries_ref ->> 'completion_rate', ''))
    ))
  );

  return NEW;
end;
$$;
revoke execute on function public.trg_project_lifecycle_from_activity_session() from public, anon;
grant execute on function public.trg_project_lifecycle_from_activity_session() to authenticated, service_role;
drop trigger if exists trg_lifecycle_project_activity_session_update on public.activity_sessions;
drop trigger if exists trg_lifecycle_project_activity_session_episode_update on public.activity_sessions;
create trigger trg_lifecycle_project_activity_session_update
  after update of activity_type, source, status, performed_at, duration_seconds, metrics, exercise_log, notes, difficulty_note, has_timeseries, timeseries_ref, encounter_id, care_plan_id, organization_id, episode_id
  on public.activity_sessions
  for each row
  execute function public.trg_project_lifecycle_from_activity_session();
with activity_projection as (
  select
    act.id::text as source_id,
    case act.activity_type
      when 'clinic_exercise' then 'clinic_exercise'
      when 'gym_training' then 'gym_session'
      when 'competition' then 'competition'
      when 'group_class' then 'group_class'
      when 'daily_walk' then 'daily_walk'
      when 'telehealth' then 'telehealth'
      when 'assessment' then 'activity_assessment'
      when 'other' then 'other_activity'
      else 'home_exercise'
    end as event_type,
    case act.activity_type
      when 'clinic_exercise' then 'activity.clinic_exercise'
      when 'gym_training' then 'activity.gym_session'
      when 'competition' then 'activity.competition'
      when 'group_class' then 'activity.group_class'
      when 'daily_walk' then 'activity.daily_walk'
      when 'telehealth' then 'activity.telehealth'
      when 'assessment' then 'activity.assessment'
      when 'other' then 'activity.other'
      else 'activity.home_exercise'
    end as event_kind,
    case act.activity_type
      when 'daily_walk' then 'wellness'
      when 'other' then 'wellness'
      when 'assessment' then 'assessment'
      when 'telehealth' then 'clinical'
      else 'training'
    end as event_family,
    case
      when act.source in ('apple_health', 'samsung_health', 'garmin', 'imu', 'camera') then 'device'
      else 'patient'
    end as performed_by,
    case act.activity_type
      when 'competition' then coalesce(
        nullif(coalesce(act.metrics ->> 'competition_name', act.timeseries_ref ->> 'competition_name', act.metrics ->> 'event_name', act.timeseries_ref ->> 'event_name'), ''),
        case
          when coalesce(act.metrics ->> 'sport_name', act.metrics ->> 'sport', act.timeseries_ref ->> 'sport_name', act.timeseries_ref ->> 'sport') is not null
            then coalesce(act.metrics ->> 'sport_name', act.metrics ->> 'sport', act.timeseries_ref ->> 'sport_name', act.timeseries_ref ->> 'sport') || ' 대회'
          else null
        end,
        '대회'
      )
      when 'gym_training' then coalesce(
        case
          when coalesce(act.metrics ->> 'sport_name', act.metrics ->> 'sport', act.timeseries_ref ->> 'sport_name', act.timeseries_ref ->> 'sport') is not null
            then coalesce(act.metrics ->> 'sport_name', act.metrics ->> 'sport', act.timeseries_ref ->> 'sport_name', act.timeseries_ref ->> 'sport') || ' 훈련'
          else null
        end,
        '헬스장'
      )
      when 'home_exercise' then case
        when jsonb_typeof(coalesce(act.exercise_log, '[]'::jsonb)) = 'array'
          and jsonb_array_length(coalesce(act.exercise_log, '[]'::jsonb)) > 0
          then '홈운동 ' || jsonb_array_length(coalesce(act.exercise_log, '[]'::jsonb)) || '개'
        else '홈운동'
      end
      when 'clinic_exercise' then '클리닉 운동'
      when 'group_class' then '그룹 수업'
      when 'daily_walk' then '걷기'
      when 'telehealth' then '원격 활동'
      when 'assessment' then '활동 평가'
      else '활동'
    end as label,
    coalesce(nullif(act.notes, ''), nullif(act.difficulty_note, '')) as description,
    jsonb_strip_nulls(jsonb_build_object(
      'activity_type', act.activity_type,
      'source', act.source,
      'status', act.status,
      'duration_seconds', act.duration_seconds,
      'encounter_id', act.encounter_id,
      'care_plan_id', act.care_plan_id,
      'has_timeseries', act.has_timeseries,
      'metrics', coalesce(act.metrics, '{}'::jsonb),
      'exercise_log', coalesce(act.exercise_log, '[]'::jsonb),
      'exercise_log_count', case
        when jsonb_typeof(coalesce(act.exercise_log, '[]'::jsonb)) = 'array'
          then jsonb_array_length(coalesce(act.exercise_log, '[]'::jsonb))
        else null
      end,
      'difficulty_note', act.difficulty_note,
      'timeseries_ref', coalesce(act.timeseries_ref, '{}'::jsonb),
      'sport_name', coalesce(act.metrics ->> 'sport_name', act.metrics ->> 'sport', act.timeseries_ref ->> 'sport_name', act.timeseries_ref ->> 'sport'),
      'competition_name', coalesce(act.metrics ->> 'competition_name', act.timeseries_ref ->> 'competition_name', act.metrics ->> 'event_name', act.timeseries_ref ->> 'event_name'),
      'competition_result', coalesce(act.metrics ->> 'competition_result', act.timeseries_ref ->> 'competition_result', act.metrics ->> 'result', act.timeseries_ref ->> 'result'),
      'training_focus', coalesce(act.metrics ->> 'training_focus', act.timeseries_ref ->> 'training_focus', act.metrics ->> 'movement_profile', act.timeseries_ref ->> 'movement_profile'),
      'distance_m', coalesce(act.metrics ->> 'distance_m', act.timeseries_ref ->> 'distance_m'),
      'steps', coalesce(act.metrics ->> 'steps', act.timeseries_ref ->> 'steps'),
      'calories_kcal', coalesce(act.metrics ->> 'calories_kcal', act.metrics ->> 'calories', act.timeseries_ref ->> 'calories_kcal', act.timeseries_ref ->> 'calories'),
      'rpe', coalesce(act.metrics ->> 'rpe', act.timeseries_ref ->> 'rpe'),
      'pain_pre', coalesce(act.metrics ->> 'pain_pre', act.timeseries_ref ->> 'pain_pre'),
      'pain_post', coalesce(act.metrics ->> 'pain_post', act.timeseries_ref ->> 'pain_post'),
      'heart_rate_avg', coalesce(act.metrics ->> 'heart_rate_avg', act.timeseries_ref ->> 'heart_rate_avg'),
      'heart_rate_max', coalesce(act.metrics ->> 'heart_rate_max', act.timeseries_ref ->> 'heart_rate_max'),
      'completion_rate', coalesce(act.metrics ->> 'completion_rate', act.timeseries_ref ->> 'completion_rate')
    )) as metadata
  from public.activity_sessions act
)
update public.person_lifecycle_events ple
set
  event_type = ap.event_type,
  event_kind = ap.event_kind,
  event_family = ap.event_family,
  performed_by = ap.performed_by,
  label = ap.label,
  description = ap.description,
  metadata = ap.metadata
from activity_projection ap
where ple.source_table = 'activity_sessions'
  and ple.source_id = ap.source_id;
with taxonomy_seed (
  code,
  code_display,
  category,
  default_value_type,
  default_unit,
  notes
) as (
  values
    ('pain_nrs_pre', 'Session pain NRS before activity', array['activity', 'pain']::text[], 'integer', '/10', 'Session-level numeric pain rating captured before an activity session.'),
    ('pain_nrs_post', 'Session pain NRS after activity', array['activity', 'pain']::text[], 'integer', '/10', 'Session-level numeric pain rating captured after an activity session.'),
    ('rpe_borg', 'Session Borg rating of perceived exertion', array['activity', 'exertion']::text[], 'integer', '/20', 'Session-level Borg RPE captured from activity session metrics.'),
    ('session_hr_avg', 'Session average heart rate', array['activity', 'vital-signs']::text[], 'quantity', 'bpm', 'Average heart rate projected from activity session metrics.'),
    ('session_hr_max', 'Session maximum heart rate', array['activity', 'vital-signs']::text[], 'quantity', 'bpm', 'Maximum heart rate projected from activity session metrics.'),
    ('steps_count', 'Session step count', array['activity', 'steps']::text[], 'integer', 'steps', 'Step count projected from activity session metrics.'),
    ('session_distance', 'Session distance', array['activity', 'distance']::text[], 'quantity', 'm', 'Distance projected from activity session metrics.'),
    ('session_calories', 'Session calories burned', array['activity', 'energy']::text[], 'quantity', 'kcal', 'Calories burned projected from activity session metrics.')
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
  ts.code,
  'http://physiokorea.com/fhir/observation',
  ts.code_display,
  ts.category,
  ts.default_value_type,
  ts.default_unit,
  'activity_session_metrics',
  ts.notes,
  true
from taxonomy_seed ts
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
with concept_seed (
  concept_key,
  display,
  display_ko,
  source_code,
  definition
) as (
  values
    ('session_pain_pre', 'Session pain before activity', '활동 전 통증', 'pain_nrs_pre', 'Pain score captured before the activity session starts.'),
    ('session_pain_post', 'Session pain after activity', '활동 후 통증', 'pain_nrs_post', 'Pain score captured after the activity session ends.'),
    ('session_rpe', 'Session perceived exertion', '세션 자각운동강도', 'rpe_borg', 'Perceived exertion captured for a completed activity session.'),
    ('session_heart_rate_average', 'Session average heart rate', '세션 평균 심박수', 'session_hr_avg', 'Average heart rate measured during an activity session.'),
    ('session_heart_rate_maximum', 'Session maximum heart rate', '세션 최대 심박수', 'session_hr_max', 'Maximum heart rate measured during an activity session.'),
    ('session_step_count', 'Session step count', '세션 걸음 수', 'steps_count', 'Step count captured during an activity session.'),
    ('session_distance_total', 'Session distance total', '세션 이동 거리', 'session_distance', 'Distance covered during an activity session.'),
    ('session_calories_burned', 'Session calories burned', '세션 소비 칼로리', 'session_calories', 'Calories burned during an activity session.')
)
insert into public.clinical_concepts (
  concept_key,
  display,
  display_ko,
  concept_domain,
  specialty_scope,
  source_table,
  source_code,
  source_code_system,
  definition,
  properties,
  status
)
select
  cs.concept_key,
  cs.display,
  cs.display_ko,
  'observation',
  array['core', 'trainer', 'wellness']::text[],
  'observation_taxonomy',
  cs.source_code,
  'http://physiokorea.com/fhir/observation',
  cs.definition,
  jsonb_build_object('seed', '2026-05-20', 'wave', 'activity_lifecycle_enrichment'),
  'active'
from concept_seed cs
on conflict (concept_key) do update
set
  display = excluded.display,
  display_ko = excluded.display_ko,
  source_table = excluded.source_table,
  source_code = excluded.source_code,
  source_code_system = excluded.source_code_system,
  definition = excluded.definition,
  properties = excluded.properties,
  status = excluded.status,
  updated_at = now();
