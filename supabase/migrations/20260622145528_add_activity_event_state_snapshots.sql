alter table public.run_log_runs
  add column if not exists activity_type text not null default 'running',
  add column if not exists ended_at timestamptz,
  add column if not exists max_heartrate double precision,
  add column if not exists calories double precision,
  add column if not exists source_record_type text not null default 'activity_event',
  add column if not exists imported_at timestamptz not null default now();

comment on column public.run_log_runs.activity_type is
  'Normalized activity type for provider-originated activity events, for example running, walking, cycling, or strength.';

comment on column public.run_log_runs.source_record_type is
  'Provider record granularity. Defaults to activity_event for one workout/session-level record.';

create index if not exists run_log_runs_activity_type_start_date_idx
  on public.run_log_runs (activity_type, start_date desc);

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
