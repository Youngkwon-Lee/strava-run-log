-- Human State DataOps projection storage.
-- Stores derived Event -> State projections with lineage, without making
-- semantic read models the raw source of truth.

create table if not exists public.client_state_projection_runs (
  id uuid primary key default gen_random_uuid(),
  projection_id text not null unique,
  schema_version text not null check (schema_version = 'human-state-dataops.v1'),
  client_id uuid not null references public.persons (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  generated_at timestamptz not null,
  snapshot_json jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.client_state_projection_runs is
  'Versioned Human State DataOps projection runs for a client. Each run anchors derived source events, state records, and lineage edges.';
create table if not exists public.client_state_projection_events (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.client_state_projection_runs (id) on delete cascade,
  event_key text not null,
  client_id uuid not null references public.persons (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  kind text not null check (kind in (
    'observation.pain',
    'assessment.function',
    'assessment.adherence',
    'data_quality.issue'
  )),
  source_table text not null,
  source_id text not null,
  occurred_at timestamptz,
  quality_status text not null check (quality_status in ('valid', 'quality_issue')),
  attributes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (run_id, event_key)
);
comment on table public.client_state_projection_events is
  'Normalized source event rows used by a Human State DataOps projection run.';
create table if not exists public.client_state_records (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.client_state_projection_runs (id) on delete cascade,
  state_key text not null,
  client_id uuid not null references public.persons (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  kind text not null check (kind in (
    'pain.irritability',
    'pain.trend',
    'function.outcome',
    'function.mcid',
    'adherence.risk',
    'data_quality.summary',
    'state.flag'
  )),
  label text not null,
  value_json jsonb,
  band text check (band in ('low', 'moderate', 'high', 'unknown')),
  trend text check (trend in ('improving', 'worsening', 'stable', 'unknown')),
  mcid_status text check (mcid_status in ('achieved', 'missed', 'stable', 'no_baseline', 'no_rule', 'unknown')),
  severity text check (severity in ('info', 'watch', 'risk')),
  observed_at timestamptz,
  computed_at timestamptz not null,
  source_event_keys text[] not null default '{}',
  created_at timestamptz not null default now(),
  unique (run_id, state_key)
);
comment on table public.client_state_records is
  'Derived client state records computed from DataOps source events.';
create table if not exists public.client_state_lineage_edges (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.client_state_projection_runs (id) on delete cascade,
  from_event_key text not null,
  to_state_key text not null,
  transform text not null,
  created_at timestamptz not null default now(),
  unique (run_id, from_event_key, to_state_key, transform)
);
comment on table public.client_state_lineage_edges is
  'Lineage edges connecting projection source events to derived state records.';
create index if not exists idx_client_state_projection_runs_client_time
  on public.client_state_projection_runs (client_id, generated_at desc);
create index if not exists idx_client_state_projection_runs_org_client_time
  on public.client_state_projection_runs (organization_id, client_id, generated_at desc);
create index if not exists idx_client_state_projection_events_run
  on public.client_state_projection_events (run_id);
create index if not exists idx_client_state_projection_events_source
  on public.client_state_projection_events (source_table, source_id);
create index if not exists idx_client_state_records_run_kind
  on public.client_state_records (run_id, kind);
create index if not exists idx_client_state_records_client_kind
  on public.client_state_records (client_id, kind, computed_at desc);
create index if not exists idx_client_state_lineage_edges_run
  on public.client_state_lineage_edges (run_id);
create index if not exists idx_job_queue_human_state_dataops_dedup
  on public.job_queue (
    job_type,
    status,
    (payload ->> 'clientId'),
    (payload ->> 'orgId')
  )
  where job_type = 'client_state_dataops_refresh'
    and status = 'pending';
alter table public.client_state_projection_runs enable row level security;
alter table public.client_state_projection_events enable row level security;
alter table public.client_state_records enable row level security;
alter table public.client_state_lineage_edges enable row level security;
drop policy if exists client_state_projection_runs_select on public.client_state_projection_runs;
create policy client_state_projection_runs_select
  on public.client_state_projection_runs
  for select
  to authenticated
  using (
    public.can_access_client_via_org(client_id)
    or public.is_org_member(organization_id)
  );
drop policy if exists client_state_projection_runs_service_role_all on public.client_state_projection_runs;
create policy client_state_projection_runs_service_role_all
  on public.client_state_projection_runs
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
drop policy if exists client_state_projection_events_select on public.client_state_projection_events;
create policy client_state_projection_events_select
  on public.client_state_projection_events
  for select
  to authenticated
  using (
    public.can_access_client_via_org(client_id)
    or public.is_org_member(organization_id)
  );
drop policy if exists client_state_projection_events_service_role_all on public.client_state_projection_events;
create policy client_state_projection_events_service_role_all
  on public.client_state_projection_events
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
drop policy if exists client_state_records_select on public.client_state_records;
create policy client_state_records_select
  on public.client_state_records
  for select
  to authenticated
  using (
    public.can_access_client_via_org(client_id)
    or public.is_org_member(organization_id)
  );
drop policy if exists client_state_records_service_role_all on public.client_state_records;
create policy client_state_records_service_role_all
  on public.client_state_records
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
drop policy if exists client_state_lineage_edges_select on public.client_state_lineage_edges;
create policy client_state_lineage_edges_select
  on public.client_state_lineage_edges
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.client_state_projection_runs runs
      where runs.id = client_state_lineage_edges.run_id
        and (
          public.can_access_client_via_org(runs.client_id)
          or public.is_org_member(runs.organization_id)
        )
    )
  );
drop policy if exists client_state_lineage_edges_service_role_all on public.client_state_lineage_edges;
create policy client_state_lineage_edges_service_role_all
  on public.client_state_lineage_edges
  to service_role
  using ((select auth.role()) = 'service_role')
  with check ((select auth.role()) = 'service_role');
