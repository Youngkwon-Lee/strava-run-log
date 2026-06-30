-- PGHD run-log activity event bridge.
-- Ports the strava-run-log activity-event and human-state snapshot schema into
-- the PhysioApp-owned Supabase migration lineage.

create table if not exists public.run_log_runs (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  external_id text not null,
  user_id text,
  name text,
  start_date timestamptz,
  start_date_local text,
  distance_meters double precision,
  moving_time_sec integer,
  pace_sec_per_km integer,
  average_heartrate double precision,
  average_cadence double precision,
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint run_log_runs_source_external_id_key unique (source, external_id)
);
do $$
begin
  if to_regclass('public.pghd_connections') is not null then
    alter table public.pghd_connections
      drop constraint if exists pghd_connections_provider_check;

    alter table public.pghd_connections
      add constraint pghd_connections_provider_check
      check (
        provider in (
          'apple_health',
          'apple-health',
          'health_connect',
          'health-connect',
          'google_fit',
          'google-fit',
          'fitbit',
          'garmin',
          'google_calendar',
          'google-calendar',
          'strava'
        )
      );
  end if;
end;
$$;
alter table public.run_log_runs enable row level security;
alter table public.run_log_runs
  add column if not exists subject_person_id uuid,
  add column if not exists organization_id uuid,
  add column if not exists org_client_profile_id uuid,
  add column if not exists activity_session_id uuid,
  add column if not exists linked_at timestamptz,
  add column if not exists data_classification text not null default 'PGHD',
  add column if not exists raw_size_bytes integer,
  add column if not exists telemetry_ref jsonb,
  add column if not exists raw_retention_until timestamptz,
  add column if not exists pghd_connection_id uuid,
  add column if not exists activity_type text not null default 'running',
  add column if not exists ended_at timestamptz,
  add column if not exists max_heartrate double precision,
  add column if not exists calories double precision,
  add column if not exists source_record_type text not null default 'activity_event',
  add column if not exists imported_at timestamptz not null default now();
comment on table public.run_log_runs is
  'Normalized PGHD activity-event records ingested from Strava, Apple Health, and future providers.';
comment on column public.run_log_runs.raw is
  'Canonical camelCase provider payload used by the application; typed columns are indexed query helpers.';
comment on column public.run_log_runs.data_classification is
  'Data classification for provider-originated records. Default is PGHD.';
comment on column public.run_log_runs.raw_size_bytes is
  'Approximate UTF-8 byte size of the canonical raw JSON payload at ingest time.';
comment on column public.run_log_runs.telemetry_ref is
  'Pointer or summary for high-volume telemetry stored outside run_log_runs.raw.';
comment on column public.run_log_runs.raw_retention_until is
  'Optional retention timestamp for raw payload pruning while keeping typed summary columns.';
comment on column public.run_log_runs.pghd_connection_id is
  'Resolved provider connection id from pghd_connections when a run can be mapped to a person/provider account.';
comment on column public.run_log_runs.activity_type is
  'Normalized activity type for provider-originated activity events, for example running, walking, cycling, or strength.';
comment on column public.run_log_runs.source_record_type is
  'Provider record granularity. Defaults to activity_event for one workout/session-level record.';
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

  if to_regclass('public.persons') is not null
    and not exists (
      select 1 from pg_constraint
      where conname = 'run_log_runs_subject_person_id_fkey'
        and conrelid = 'public.run_log_runs'::regclass
    )
  then
    alter table public.run_log_runs
      add constraint run_log_runs_subject_person_id_fkey
      foreign key (subject_person_id) references public.persons(id) on delete set null
      not valid;
  end if;

  if to_regclass('public.organizations') is not null
    and not exists (
      select 1 from pg_constraint
      where conname = 'run_log_runs_organization_id_fkey'
        and conrelid = 'public.run_log_runs'::regclass
    )
  then
    alter table public.run_log_runs
      add constraint run_log_runs_organization_id_fkey
      foreign key (organization_id) references public.organizations(id) on delete set null
      not valid;
  end if;

  if to_regclass('public.org_client_profile') is not null
    and not exists (
      select 1 from pg_constraint
      where conname = 'run_log_runs_org_client_profile_id_fkey'
        and conrelid = 'public.run_log_runs'::regclass
    )
  then
    alter table public.run_log_runs
      add constraint run_log_runs_org_client_profile_id_fkey
      foreign key (org_client_profile_id) references public.org_client_profile(id) on delete set null
      not valid;
  end if;

  if to_regclass('public.activity_sessions') is not null
    and not exists (
      select 1 from pg_constraint
      where conname = 'run_log_runs_activity_session_id_fkey'
        and conrelid = 'public.run_log_runs'::regclass
    )
  then
    alter table public.run_log_runs
      add constraint run_log_runs_activity_session_id_fkey
      foreign key (activity_session_id) references public.activity_sessions(id) on delete set null
      not valid;
  end if;

  if to_regclass('public.pghd_connections') is not null
    and not exists (
      select 1 from pg_constraint
      where conname = 'run_log_runs_pghd_connection_id_fkey'
        and conrelid = 'public.run_log_runs'::regclass
    )
  then
    alter table public.run_log_runs
      add constraint run_log_runs_pghd_connection_id_fkey
      foreign key (pghd_connection_id) references public.pghd_connections(id) on delete set null
      not valid;
  end if;
end;
$$;
create index if not exists run_log_runs_start_date_idx
  on public.run_log_runs (start_date desc);
create index if not exists run_log_runs_user_id_start_date_idx
  on public.run_log_runs (user_id, start_date desc);
create index if not exists run_log_runs_source_start_date_idx
  on public.run_log_runs (source, start_date desc);
create index if not exists run_log_runs_raw_gin_idx
  on public.run_log_runs using gin (raw);
create index if not exists run_log_runs_subject_person_start_date_idx
  on public.run_log_runs (subject_person_id, start_date desc);
create index if not exists run_log_runs_activity_session_id_idx
  on public.run_log_runs (activity_session_id);
create index if not exists run_log_runs_data_classification_idx
  on public.run_log_runs (data_classification);
create index if not exists run_log_runs_raw_retention_until_idx
  on public.run_log_runs (raw_retention_until)
  where raw_retention_until is not null;
create index if not exists run_log_runs_pghd_connection_id_idx
  on public.run_log_runs (pghd_connection_id);
create index if not exists run_log_runs_activity_type_start_date_idx
  on public.run_log_runs (activity_type, start_date desc);
create or replace function public.set_run_log_runs_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists set_run_log_runs_updated_at on public.run_log_runs;
create trigger set_run_log_runs_updated_at
before update on public.run_log_runs
for each row
execute function public.set_run_log_runs_updated_at();
drop policy if exists run_log_runs_select on public.run_log_runs;
create policy run_log_runs_select
  on public.run_log_runs
  for select
  to authenticated
  using (
    subject_person_id = public.get_my_person_id()
    or public.can_access_client_via_org(subject_person_id)
    or public.is_org_member(organization_id)
  );
drop policy if exists run_log_runs_service_role_all on public.run_log_runs;
create policy run_log_runs_service_role_all
  on public.run_log_runs
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
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
create table if not exists public.human_state_snapshots (
  id uuid primary key default gen_random_uuid(),
  subject_person_id uuid not null,
  organization_id uuid,
  org_client_profile_id uuid,
  state_type text not null,
  value double precision not null,
  confidence double precision not null default 0.5,
  calculated_at timestamptz not null default now(),
  window_start timestamptz,
  window_end timestamptz,
  source text not null default 'run_log',
  provider_source text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint human_state_snapshots_state_type_check
    check (state_type in ('fitness', 'fatigue', 'recovery', 'injury_risk', 'adherence', 'training_load')),
  constraint human_state_snapshots_value_finite_check
    check (value = value and value not in ('Infinity'::float8, '-Infinity'::float8)),
  constraint human_state_snapshots_confidence_range_check
    check (confidence >= 0 and confidence <= 1)
);
alter table public.human_state_snapshots enable row level security;
alter table public.human_state_snapshots
  add column if not exists provider_source text;
comment on table public.human_state_snapshots is
  'Derived human state values calculated from PGHD activity events and related inputs.';
comment on column public.human_state_snapshots.value is
  'Normalized state value. Each state_type defines its own interpretation and display scale.';
comment on column public.human_state_snapshots.provider_source is
  'Provider or upstream PGHD source used as state input, for example apple-health or strava.';
do $$
begin
  if to_regclass('public.persons') is not null
    and not exists (
      select 1 from pg_constraint
      where conname = 'human_state_snapshots_subject_person_id_fkey'
        and conrelid = 'public.human_state_snapshots'::regclass
    )
  then
    alter table public.human_state_snapshots
      add constraint human_state_snapshots_subject_person_id_fkey
      foreign key (subject_person_id) references public.persons(id) on delete cascade
      not valid;
  end if;

  if to_regclass('public.organizations') is not null
    and not exists (
      select 1 from pg_constraint
      where conname = 'human_state_snapshots_organization_id_fkey'
        and conrelid = 'public.human_state_snapshots'::regclass
    )
  then
    alter table public.human_state_snapshots
      add constraint human_state_snapshots_organization_id_fkey
      foreign key (organization_id) references public.organizations(id) on delete set null
      not valid;
  end if;

  if to_regclass('public.org_client_profile') is not null
    and not exists (
      select 1 from pg_constraint
      where conname = 'human_state_snapshots_org_client_profile_id_fkey'
        and conrelid = 'public.human_state_snapshots'::regclass
    )
  then
    alter table public.human_state_snapshots
      add constraint human_state_snapshots_org_client_profile_id_fkey
      foreign key (org_client_profile_id) references public.org_client_profile(id) on delete set null
      not valid;
  end if;
end;
$$;
create index if not exists human_state_snapshots_subject_calculated_idx
  on public.human_state_snapshots (subject_person_id, calculated_at desc);
create index if not exists human_state_snapshots_subject_state_calculated_idx
  on public.human_state_snapshots (subject_person_id, state_type, calculated_at desc);
drop index if exists public.human_state_snapshots_natural_key_idx;
create unique index human_state_snapshots_natural_key_idx
  on public.human_state_snapshots (
    subject_person_id,
    coalesce(organization_id, '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(org_client_profile_id, '00000000-0000-0000-0000-000000000000'::uuid),
    state_type,
    source,
    coalesce(provider_source, ''),
    coalesce(window_start, '-infinity'::timestamptz)
  );
create or replace function public.set_human_state_snapshots_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists set_human_state_snapshots_updated_at on public.human_state_snapshots;
create trigger set_human_state_snapshots_updated_at
before update on public.human_state_snapshots
for each row
execute function public.set_human_state_snapshots_updated_at();
drop policy if exists human_state_snapshots_select on public.human_state_snapshots;
create policy human_state_snapshots_select
  on public.human_state_snapshots
  for select
  to authenticated
  using (
    subject_person_id = public.get_my_person_id()
    or public.can_access_client_via_org(subject_person_id)
    or public.is_org_member(organization_id)
  );
drop policy if exists human_state_snapshots_service_role_all on public.human_state_snapshots;
create policy human_state_snapshots_service_role_all
  on public.human_state_snapshots
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
create table if not exists public.human_state_snapshot_inputs (
  snapshot_id uuid not null references public.human_state_snapshots(id) on delete cascade,
  run_log_run_id uuid not null references public.run_log_runs(id) on delete cascade,
  weight double precision not null default 1,
  created_at timestamptz not null default now(),
  primary key (snapshot_id, run_log_run_id),
  constraint human_state_snapshot_inputs_weight_finite_check
    check (weight = weight and weight not in ('Infinity'::float8, '-Infinity'::float8))
);
alter table public.human_state_snapshot_inputs enable row level security;
comment on table public.human_state_snapshot_inputs is
  'Traceability join table linking derived state snapshots to source activity events.';
create index if not exists human_state_snapshot_inputs_run_log_run_idx
  on public.human_state_snapshot_inputs (run_log_run_id);
drop policy if exists human_state_snapshot_inputs_select on public.human_state_snapshot_inputs;
create policy human_state_snapshot_inputs_select
  on public.human_state_snapshot_inputs
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.human_state_snapshots snapshots
      where snapshots.id = human_state_snapshot_inputs.snapshot_id
        and (
          snapshots.subject_person_id = public.get_my_person_id()
          or public.can_access_client_via_org(snapshots.subject_person_id)
          or public.is_org_member(snapshots.organization_id)
        )
    )
  );
drop policy if exists human_state_snapshot_inputs_service_role_all on public.human_state_snapshot_inputs;
create policy human_state_snapshot_inputs_service_role_all
  on public.human_state_snapshot_inputs
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
