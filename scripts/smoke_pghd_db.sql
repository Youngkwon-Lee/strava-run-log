begin;

create temp table _pghd_smoke_context (
  seed_connection_id uuid,
  subject_person_id uuid,
  provider text,
  provider_user_id text,
  external_id text,
  run_id uuid,
  activity_session_id uuid
) on commit drop;

insert into _pghd_smoke_context (
  seed_connection_id,
  subject_person_id,
  provider,
  provider_user_id,
  external_id
)
select
  id,
  person_id,
  provider,
  coalesce(provider_user_id, 'db-smoke-user'),
  'db_pghd_smoke_' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS')
from public.pghd_connections
where person_id is not null
order by updated_at desc nulls last, created_at desc nulls last
limit 1;

do $$
begin
  if not exists (select 1 from _pghd_smoke_context) then
    raise exception 'PGHD DB smoke requires at least one pghd_connections row with person_id';
  end if;
end
$$;

with inserted_run as (
  insert into public.run_log_runs (
    source,
    external_id,
    user_id,
    name,
    start_date,
    distance_meters,
    moving_time_sec,
    pace_sec_per_km,
    average_heartrate,
    average_cadence,
    subject_person_id,
    pghd_connection_id,
    data_classification,
    raw_size_bytes,
    raw
  )
  select
    'db-smoke',
    external_id,
    provider_user_id,
    'PGHD DB smoke run',
    '2026-06-22T21:10:00+09:00'::timestamptz,
    5120,
    1910,
    373,
    148,
    172,
    subject_person_id,
    seed_connection_id,
    'PGHD',
    256,
    jsonb_build_object(
      'source', 'db-smoke',
      'externalId', external_id,
      'userId', provider_user_id,
      'smoke', true
    )
  from _pghd_smoke_context
  returning id
)
update _pghd_smoke_context context
set run_id = inserted_run.id
from inserted_run;

with inserted_session as (
  insert into public.activity_sessions (
    subject_person_id,
    activity_type,
    source,
    status,
    performed_at,
    duration_seconds,
    metrics,
    exercise_log,
    notes,
    has_timeseries
  )
  select
    run_log_runs.subject_person_id,
    'competition',
    'apple_health',
    'completed',
    run_log_runs.start_date,
    run_log_runs.moving_time_sec,
    jsonb_build_object(
      'distance_meters', run_log_runs.distance_meters,
      'moving_time_sec', run_log_runs.moving_time_sec,
      'provider_source', run_log_runs.source,
      'provider_external_id', run_log_runs.external_id
    ),
    jsonb_build_object(
      'provider_table', 'run_log_runs',
      'provider_source', run_log_runs.source,
      'provider_external_id', run_log_runs.external_id
    ),
    'PGHD DB smoke test',
    false
  from public.run_log_runs
  join _pghd_smoke_context context on context.run_id = run_log_runs.id
  returning id
)
update _pghd_smoke_context context
set activity_session_id = inserted_session.id
from inserted_session;

update public.run_log_runs run
set
  activity_session_id = context.activity_session_id,
  linked_at = now()
from _pghd_smoke_context context
where run.id = context.run_id;

select
  true as ok,
  context.external_id,
  context.run_id is not null as run_inserted,
  context.seed_connection_id is not null as pghd_connection_reused,
  context.activity_session_id is not null as activity_session_inserted,
  exists (
    select 1
    from public.run_log_weekly_summaries summary
    where summary.source = 'db-smoke'
      and summary.user_id = context.provider_user_id
      and summary.subject_person_id = context.subject_person_id
      and summary.run_count >= 1
  ) as weekly_summary_visible,
  exists (
    select 1
    from public.run_log_runs run
    where run.id = context.run_id
      and run.activity_session_id = context.activity_session_id
      and run.subject_person_id = context.subject_person_id
      and run.pghd_connection_id = context.seed_connection_id
  ) as run_linked
from _pghd_smoke_context context;

rollback;
