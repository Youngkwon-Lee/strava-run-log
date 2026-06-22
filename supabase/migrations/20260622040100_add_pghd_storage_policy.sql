alter table public.run_log_runs
  add column if not exists data_classification text not null default 'PGHD',
  add column if not exists raw_size_bytes integer,
  add column if not exists telemetry_ref jsonb,
  add column if not exists raw_retention_until timestamptz;

do $$
begin
  if to_regprocedure('public.set_run_log_runs_updated_at()') is not null then
    alter function public.set_run_log_runs_updated_at()
      set search_path = public, pg_temp;
  end if;
end;
$$;

comment on column public.run_log_runs.data_classification is
  'Data classification for provider-originated records. Default is PGHD.';

comment on column public.run_log_runs.raw_size_bytes is
  'Approximate UTF-8 byte size of the canonical raw JSON payload at ingest time.';

comment on column public.run_log_runs.telemetry_ref is
  'Pointer or summary for high-volume telemetry stored outside run_log_runs.raw.';

comment on column public.run_log_runs.raw_retention_until is
  'Optional retention timestamp for raw payload pruning while keeping typed summary columns.';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'run_log_runs_raw_size_budget'
      and conrelid = 'public.run_log_runs'::regclass
  ) then
    alter table public.run_log_runs
      add constraint run_log_runs_raw_size_budget
      check (raw_size_bytes is null or raw_size_bytes <= 65536)
      not valid;
  end if;
end;
$$;

create index if not exists run_log_runs_data_classification_idx
  on public.run_log_runs (data_classification);

create index if not exists run_log_runs_raw_retention_until_idx
  on public.run_log_runs (raw_retention_until)
  where raw_retention_until is not null;

create or replace view public.run_log_weekly_summaries
with (security_invoker = true) as
select
  date_trunc('week', start_date)::date as week_start,
  subject_person_id,
  organization_id,
  org_client_profile_id,
  user_id,
  source,
  count(*)::integer as run_count,
  round((sum(coalesce(distance_meters, 0)) / 1000.0)::numeric, 2) as total_km,
  sum(coalesce(moving_time_sec, 0))::integer as moving_time_sec,
  round((sum(coalesce(moving_time_sec, 0)) / 60.0)::numeric, 0)::integer as moderate_minutes,
  case
    when sum(coalesce(distance_meters, 0)) > 0 then
      round((sum(coalesce(moving_time_sec, 0)) / (sum(coalesce(distance_meters, 0)) / 1000.0))::numeric, 0)::integer
    else null
  end as average_pace_sec_per_km,
  round(avg(average_heartrate)::numeric, 0)::integer as average_heartrate,
  round(avg(average_cadence)::numeric, 0)::integer as average_cadence,
  min(start_date) as first_run_at,
  max(start_date) as last_run_at
from public.run_log_runs
where start_date is not null
group by
  date_trunc('week', start_date)::date,
  subject_person_id,
  organization_id,
  org_client_profile_id,
  user_id,
  source;

comment on view public.run_log_weekly_summaries is
  'Query helper for dashboard-ready weekly PGHD run summaries. It avoids reading dense raw payloads for trend views.';
