create table if not exists public.agent_runs (
  run_id uuid primary key,
  patient_id uuid null,
  encounter_id uuid null,
  agent_name text not null,
  status text not null,
  mode text not null,
  model text null,
  started_at timestamptz not null default now(),
  finished_at timestamptz null,
  duration_ms integer null,
  retry_count integer not null default 0,
  input_summary text null,
  output_summary text null,
  error_message text null
);

create table if not exists public.background_jobs (
  job_id uuid primary key,
  patient_id uuid null,
  encounter_id uuid null,
  job_type text not null,
  status text not null,
  attempts integer not null default 0,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  started_at timestamptz null,
  finished_at timestamptz null,
  last_error text null
);

alter table if exists public.agent_runs enable row level security;
alter table if exists public.background_jobs enable row level security;

drop policy if exists "agent runs full access" on public.agent_runs;
create policy "agent runs full access" on public.agent_runs for all using (true) with check (true);

drop policy if exists "background jobs full access" on public.background_jobs;
create policy "background jobs full access" on public.background_jobs for all using (true) with check (true);;
