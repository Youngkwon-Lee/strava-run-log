set lock_timeout = '10s';
set statement_timeout = '120s';

create table if not exists public.pghd_activity_events (
  id uuid primary key default gen_random_uuid(),
  source text not null,
  external_id text not null,
  source_record_type text not null default 'activity_event',
  activity_type text not null default 'running',
  subject_person_id uuid,
  organization_id uuid,
  org_client_profile_id uuid,
  pghd_connection_id uuid references public.pghd_connections(id) on delete set null,
  user_id text,
  name text,
  started_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer,
  metrics jsonb not null default '{}'::jsonb,
  raw jsonb not null default '{}'::jsonb,
  data_classification text not null default 'PGHD',
  imported_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pghd_activity_events_source_external_id_key unique (source, external_id),
  constraint pghd_activity_events_source_record_type_check
    check (source_record_type in ('activity_event', 'daily_summary', 'sample_bundle', 'manual_entry')),
  constraint pghd_activity_events_data_classification_check
    check (data_classification in ('PGHD', 'derived', 'system'))
);

alter table public.pghd_activity_events enable row level security;

comment on table public.pghd_activity_events is
  'Provider-originated PGHD activity event staging table. Generic parent layer for running, walking, cycling, rehab exercise, and wearable summary projections.';

comment on column public.pghd_activity_events.metrics is
  'Compact normalized metrics for the activity event. Dense telemetry should live outside this row and be referenced from raw or a future telemetry table.';

comment on column public.pghd_activity_events.raw is
  'Provider payload or normalized source envelope retained for traceability. Keep compact; do not store dense GPS or per-second watch samples here.';

create index if not exists pghd_activity_events_subject_started_idx
  on public.pghd_activity_events (subject_person_id, started_at desc);

create index if not exists pghd_activity_events_connection_started_idx
  on public.pghd_activity_events (pghd_connection_id, started_at desc);

create index if not exists pghd_activity_events_source_started_idx
  on public.pghd_activity_events (source, started_at desc);

create index if not exists pghd_activity_events_activity_type_started_idx
  on public.pghd_activity_events (activity_type, started_at desc);

create index if not exists pghd_activity_events_raw_gin_idx
  on public.pghd_activity_events using gin (raw);

create or replace function public.set_pghd_activity_events_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_pghd_activity_events_updated_at on public.pghd_activity_events;
create trigger set_pghd_activity_events_updated_at
before update on public.pghd_activity_events
for each row
execute function public.set_pghd_activity_events_updated_at();

alter table public.run_log_runs
  add column if not exists pghd_activity_event_id uuid references public.pghd_activity_events(id) on delete set null;

comment on column public.run_log_runs.pghd_activity_event_id is
  'Optional link to the generic PGHD activity event row. run_log_runs remains the running-specific projection/compatibility layer.';

create index if not exists run_log_runs_pghd_activity_event_id_idx
  on public.run_log_runs (pghd_activity_event_id);

alter table public.human_state_snapshot_inputs
  add column if not exists pghd_activity_event_id uuid references public.pghd_activity_events(id) on delete cascade;

comment on column public.human_state_snapshot_inputs.pghd_activity_event_id is
  'Optional generic PGHD activity event provenance. Existing run_log_run_id provenance remains supported for running projections.';

create index if not exists human_state_snapshot_inputs_pghd_activity_event_idx
  on public.human_state_snapshot_inputs (pghd_activity_event_id);
