create table if not exists public.runs (
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
  constraint runs_source_external_id_key unique (source, external_id)
);

alter table public.runs enable row level security;

comment on table public.runs is
  'Normalized run history records ingested from Strava, Apple Health, and future providers.';

comment on column public.runs.raw is
  'Canonical camelCase run payload used by the application; typed columns are indexed query helpers.';

create index if not exists runs_start_date_idx on public.runs (start_date desc);
create index if not exists runs_user_id_start_date_idx on public.runs (user_id, start_date desc);
create index if not exists runs_source_start_date_idx on public.runs (source, start_date desc);
create index if not exists runs_raw_gin_idx on public.runs using gin (raw);

create or replace function public.set_runs_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_runs_updated_at on public.runs;
create trigger set_runs_updated_at
before update on public.runs
for each row
execute function public.set_runs_updated_at();
