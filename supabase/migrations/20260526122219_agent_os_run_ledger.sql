-- Agent OS run ledger.
--
-- Do not reuse public.agent_runs for this layer: that table is a locked
-- legacy observability table. The AI-native company OS needs a separate
-- approval-first ledger with typed gates and traces.

create table if not exists public.agent_os_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references public.organizations(id) on delete set null,
  lane_id text not null,
  title text not null,
  description text not null default '',
  status text not null default 'intake',
  priority text not null default 'medium',
  workflow_ids text[] not null default array[]::text[],
  owner_agents text[] not null default array[]::text[],
  green_level text,
  artifacts jsonb not null default '[]'::jsonb,
  created_by_person_id uuid references public.persons(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint agent_os_runs_lane_id_check check (
    lane_id in ('feature', 'maintenance', 'devops', 'mlops', 'growth', 'db-data', 'ops-finance')
  ),
  constraint agent_os_runs_status_check check (
    status in ('intake', 'planning', 'waiting-for-approval', 'building', 'reviewing', 'deploying', 'completed', 'blocked')
  ),
  constraint agent_os_runs_priority_check check (
    priority in ('low', 'medium', 'high', 'urgent')
  ),
  constraint agent_os_runs_green_level_check check (
    green_level is null
    or green_level in ('typecheck', 'targeted', 'package', 'workspace', 'merge-ready', 'release-ready')
  )
);

create table if not exists public.agent_os_approvals (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.agent_os_runs(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete set null,
  gate text not null,
  label text not null,
  status text not null default 'pending',
  required_by_agent text not null,
  decided_by_person_id uuid references public.persons(id) on delete set null,
  decided_at timestamptz,
  decision_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint agent_os_approvals_gate_check check (
    gate in ('plan', 'issue', 'pull-request', 'migration', 'preview', 'production')
  ),
  constraint agent_os_approvals_status_check check (
    status in ('pending', 'approved', 'rejected', 'waived')
  ),
  constraint agent_os_approvals_required_by_agent_check check (
    required_by_agent in ('orchestrator', 'planner', 'frontend', 'backend', 'db', 'qa', 'devops')
  )
);

create table if not exists public.agent_os_trace_events (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.agent_os_runs(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete set null,
  agent_id text not null,
  tone text not null default 'neutral',
  title text not null,
  summary text not null default '',
  failure_class text,
  green_level text,
  worker_state text,
  artifact_href text,
  created_at timestamptz not null default now(),
  constraint agent_os_trace_events_agent_id_check check (
    agent_id in ('orchestrator', 'planner', 'frontend', 'backend', 'db', 'qa', 'devops')
  ),
  constraint agent_os_trace_events_tone_check check (
    tone in ('neutral', 'success', 'warning', 'danger')
  ),
  constraint agent_os_trace_events_green_level_check check (
    green_level is null
    or green_level in ('typecheck', 'targeted', 'package', 'workspace', 'merge-ready', 'release-ready')
  )
);

create index if not exists agent_os_runs_org_status_created_idx
  on public.agent_os_runs (organization_id, status, created_at desc);

create index if not exists agent_os_runs_lane_status_idx
  on public.agent_os_runs (lane_id, status);

create index if not exists agent_os_approvals_run_status_idx
  on public.agent_os_approvals (run_id, status);

create index if not exists agent_os_approvals_org_status_idx
  on public.agent_os_approvals (organization_id, status);

create index if not exists agent_os_trace_events_run_created_idx
  on public.agent_os_trace_events (run_id, created_at asc);

alter table public.agent_os_runs enable row level security;
alter table public.agent_os_approvals enable row level security;
alter table public.agent_os_trace_events enable row level security;

drop policy if exists agent_os_runs_service_role_all on public.agent_os_runs;
create policy agent_os_runs_service_role_all
  on public.agent_os_runs
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists agent_os_runs_org_member_read on public.agent_os_runs;
create policy agent_os_runs_org_member_read
  on public.agent_os_runs
  for select
  to authenticated
  using (
    organization_id is not null
    and (select public.is_org_member(organization_id))
  );

drop policy if exists agent_os_approvals_service_role_all on public.agent_os_approvals;
create policy agent_os_approvals_service_role_all
  on public.agent_os_approvals
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists agent_os_approvals_org_member_read on public.agent_os_approvals;
create policy agent_os_approvals_org_member_read
  on public.agent_os_approvals
  for select
  to authenticated
  using (
    organization_id is not null
    and (select public.is_org_member(organization_id))
  );

drop policy if exists agent_os_trace_events_service_role_all on public.agent_os_trace_events;
create policy agent_os_trace_events_service_role_all
  on public.agent_os_trace_events
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists agent_os_trace_events_org_member_read on public.agent_os_trace_events;
create policy agent_os_trace_events_org_member_read
  on public.agent_os_trace_events
  for select
  to authenticated
  using (
    organization_id is not null
    and (select public.is_org_member(organization_id))
  );

drop trigger if exists agent_os_runs_set_updated_at on public.agent_os_runs;
create trigger agent_os_runs_set_updated_at
  before update on public.agent_os_runs
  for each row execute function public.set_updated_at();

drop trigger if exists agent_os_approvals_set_updated_at on public.agent_os_approvals;
create trigger agent_os_approvals_set_updated_at
  before update on public.agent_os_approvals
  for each row execute function public.set_updated_at();

revoke all on public.agent_os_runs from anon, authenticated;
revoke all on public.agent_os_approvals from anon, authenticated;
revoke all on public.agent_os_trace_events from anon, authenticated;

grant select on public.agent_os_runs to authenticated;
grant select on public.agent_os_approvals to authenticated;
grant select on public.agent_os_trace_events to authenticated;

grant all on public.agent_os_runs to service_role;
grant all on public.agent_os_approvals to service_role;
grant all on public.agent_os_trace_events to service_role;

comment on table public.agent_os_runs is
  'AI-native company OS mission runs. Separate from legacy agent_runs observability.';
comment on table public.agent_os_approvals is
  'Human approval gates for Agent OS mission runs.';
comment on table public.agent_os_trace_events is
  'Typed trace events emitted by Agent OS harnesses and workers.';
;
